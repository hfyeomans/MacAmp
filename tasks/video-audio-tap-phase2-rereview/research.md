# VideoAudioTap Phase 2 Re-review

Date: 2026-04-30

## Scope

- Re-review `MacAmpApp/Audio/VideoAudioTap.swift` after the Phase 2 must-fix follow-up commit `09cb521`.
- Inspect `Tests/MacAmpTests/VideoAudioTapTests.swift`.
- Verify Core Audio semantics against local Apple SDK headers.

## Files Reviewed

- `MacAmpApp/Audio/VideoAudioTap.swift`
- `Tests/MacAmpTests/VideoAudioTapTests.swift`
- `Package.swift`
- `/Applications/Xcode.app/.../AudioToolbox.framework/.../AudioConverter.h`
- `/Applications/Xcode.app/.../CoreAudioTypes.framework/.../CoreAudioBaseTypes.h`

## Findings

### Mono channel-map semantics are correct

`AudioConverter.h` documents `kAudioConverterChannelMap` as an array indexed by output channel, with each element naming the input channel routed to that output channel. The header includes a mono->stereo example using `{ 0, 0 }`, matching the implementation.

### Surround downmix is not fully enabled

The current surround path sets `kAudioConverterInputChannelLayout` and `kAudioConverterOutputChannelLayout`, but does not set `kAudioConverterPropertyPerformDownmix = 1`.

`AudioConverter.h` documents:

- `kAudioConverterPropertyPerformDownmix` defaults to `0` (`no channel mixing`)
- `kAudioConverterPropertyChannelMixMap` / built-in mixing behavior is only for the downmix path
- `kAudioConverterChannelMap` is explicitly separate from mixing

Conclusion: the code comment claiming the built-in stereo downmix matrix will apply is not substantiated by the current property configuration.

### Channel-count-only layout guessing is heuristic, not correct for common AAC

`surroundLayoutTag(forChannelCount:)` maps:

- `3 -> MPEG_3_0_A`
- `5 -> MPEG_5_0_A`
- `6 -> MPEG_5_1_A`
- `7 -> MPEG_6_1_A`
- `8 -> MPEG_7_1_A`

Apple's `CoreAudioBaseTypes.h` defines common AAC tags differently for several of these counts:

- `AAC_3_0 = MPEG_3_0_B`
- `AAC_5_0 = MPEG_5_0_D`
- `AAC_5_1 = MPEG_5_1_D`
- `AAC_7_1 = MPEG_7_1_B`

AC3/EAC3 tags also differ from the current `MPEG_*_A` defaults. Since mp4/mov often carry AAC-family layouts, the current mapping is only a coarse fallback and can be wrong for common content.

### Bypass predicate is much better, but still not maximally strict

The new predicate correctly adds:

- `mFormatID == kAudioFormatLinearPCM`
- `mBitsPerChannel == 32`
- exact `mBytesPerFrame`
- exact `mChannelsPerFrame == 2`
- exact sample-rate match

Remaining strictness gap:

- no explicit native-endian check (`kAudioFormatFlagsNativeFloatPacked` / `kAudioFormatFlagIsBigEndian`)

This is likely low-risk in AVFoundation practice, but it is the remaining mismatch between "Float bytes in memory" and the bypass path's direct `Float` binding.

### Converter disposal on configuration failure is correct

If `configureChannelMapping(...)` returns `false`, `tapPrepare` disposes the just-created converter before requesting fallback. No converter leak was found in that path.

### Tests do not cover the new fix logic

Current tests cover:

- attach success
- attach failure for no audio track
- detach idempotence
- initial public state

They do not exercise:

- bypass predicate classification
- mono channel-map installation
- surround layout selection
- downmix property configuration / fallback on unsupported channel counts

## Pass-2 Addendum

Reviewed follow-up commit `b9a8478` on top of `09cb521`.

### Surround downmix fix is now complete

`configureChannelMapping(...)` now sets:

- `kAudioConverterInputChannelLayout`
- `kAudioConverterOutputChannelLayout`
- `kAudioConverterPropertyPerformDownmix = 1`

in that order on the surround branch. `AudioConverter.h` does not document an ordering dependency between the two layout properties and `PerformDownmix`, so the current `input -> output -> performDownmix` sequence is acceptable. The only ordering gotcha called out in the header is the incompatibility between `PerformDownmix` and `kAudioConverterChannelMap`; this implementation avoids that by using channel maps only on the mono branch and downmix only on the surround branch.

### Source layout capture is materially better and uses the right byte count

`attach(to:)` now captures the `AudioChannelLayout` bytes from `CMAudioFormatDescriptionGetChannelLayout(...)`, and `configureChannelMapping(...)` passes them back to `AudioConverterSetProperty(kAudioConverterInputChannelLayout, ...)` via `Data.withUnsafeBytes`.

This matches the Core Media / Core Audio contracts:

- `CMAudioFormatDescriptionGetChannelLayout` returns a read-only pointer plus the full layout size.
- `AudioChannelLayout` is a variable-length struct whose byte size must include the trailing `mChannelDescriptions` array when present.
- `AudioConverterSetProperty` takes the property-data size in bytes.

So `UInt32(buffer.count)` is the correct size to pass for metadata-backed variable-length layouts.

### AAC fallback tags are now reasonable

The explicit fallback mapping moved from generic `MPEG_*_A` tags to AAC-family tags for 3-8 channels. That does not make the fallback universally correct for every codec/container, but it is a defensible heuristic once metadata-backed layouts are preferred first.

### Tests now cover the new pure-function logic

`VideoAudioTapTests` now adds eight focused checks for:

- canonical bypass acceptance
- rejection of Float64 / mono / sample-rate mismatch / non-interleaved / integer PCM
- surround fallback-tag coverage for channel counts 3-8
- rejection of non-surround counts

That closes the earlier gap around the newly extracted classification logic. The tests still do not prove runtime `AudioConverterSetProperty(...)` behavior against a real multichannel asset, but that is no longer a Phase 2 correctness blocker.

## Verification Notes

Attempted focused test execution with:

- `xcodebuildmcp swift-package test --package-path /Users/hank/dev/src/MacAmp --test-product MacAmpTests --filter VideoAudioTapTests`

Result:

- blocked by sandboxed manifest compilation (`sandbox-exec: sandbox_apply: Operation not permitted`)
- review conclusions are therefore based on source inspection plus Apple SDK header verification
