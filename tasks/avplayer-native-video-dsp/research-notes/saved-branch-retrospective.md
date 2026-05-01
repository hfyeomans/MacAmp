# Saved-Branch Retrospective: `feat/video-audio-engine-routing` @ `5af91eb`

> Scope: `MacAmpApp/Audio/VideoAudioTap.swift` (primary, 572 lines) and
> `MacAmpApp/Audio/VideoPlaybackController.swift` (call-site context, 350 lines).
> `MacAmpApp/Audio/AudioPlayer.swift` consulted for denylist line confirmation.
> No code is extracted or proposed for reuse here; this is citation + classification only.

---

## Allowlist findings

### 1. C-callback shape: `tapInit / tapFinalize / tapPrepare / tapUnprepare / tapProcess`

**Citations:** `VideoAudioTap.swift` lines 211–572 (five `private let` closures with the correct C-convention signatures).

All five callbacks are declared as module-level `private let` constants typed to their exact `MTAudioProcessingTap*Callback` typealias. `tapInit` receives `clientInfo` (the opaque context pointer) and writes it to `tapStorageOut` (line ~215). `tapFinalize` retrieves it via `MTAudioProcessingTapGetStorage` and releases the +1 (line ~221). `tapPrepare` and `tapProcess` retrieve it with `takeUnretainedValue()` since ownership stays with the `tapFinalize` release path. This is the correct, crash-safe lifetime pattern for a heap object crossing a C API boundary, and it is topology-agnostic.

No pre-Swift-6 idioms in the callback shape itself; the closures are non-`@Sendable` by necessity (render-thread, non-cooperative) and are intentionally outside Swift's isolation model.

### 2. `Unmanaged<Context>` handoff via `MTAudioProcessingTapGetStorage`

**Citations:** `VideoAudioTap.swift` lines ~88–97 (`attach(to:)` — `Unmanaged.passRetained`, `retained.toOpaque()`, storage in `callbacks.clientInfo`), lines ~211–224 (`tapInit` writes `tapStorageOut`, `tapFinalize` calls `Unmanaged.fromOpaque(...).release()`).

The retained pointer is handed to the tap at creation time through `callbacks.clientInfo`, mirrored into per-callback-accessible storage by `tapInit`, and released exactly once in `tapFinalize`. All intermediate retrievals use `takeUnretainedValue()` so no spurious retain/release occurs on the hot render path. This is the only correct way to share Swift heap state with a C-lifetime callback set.

**Swift-6.2 flag:** `VideoAudioTapContext` is declared `@unchecked Sendable` (line ~154). On the new branch this carve-out is acceptable at the C-callback boundary — but the declaration should carry a `// nonisolated(unsafe) carve-out: render thread is non-cooperative` comment (or use `nonisolated(unsafe)` storage on the specific fields) rather than blanket `@unchecked Sendable` on the whole class. Flag for modernization.

### 3. `AudioStreamBasicDescription` inspection in `tapPrepare`

**Citations:** `VideoAudioTap.swift` lines ~228–253 (`tapPrepare` closure body, `shouldBypassConverter` helper at lines ~325–346).

`tapPrepare` reads `processingFormat.pointee` (the upstream PCM ASBD) and passes it to `shouldBypassConverter`, which does an exact field-by-field match against the canonical packed-stereo Float32 layout. Only if every field matches is the converter skipped. The predicate checks `mFormatID`, `mFormatFlags`, `mBitsPerChannel`, `mChannelsPerFrame`, `mBytesPerFrame`, `mBytesPerPacket`, `mFramesPerPacket`, and `mSampleRate`. This exact-match approach (rather than subset matching) is the correct guard because `tapProcess` reads the source buffer assuming the canonical layout on the bypass path.

On the new branch, the bypass predicate is unnecessary (no converter, no ring) but the ASBD-inspection structure — reading the format in `tapPrepare`, storing it on context, using it to branch processing — is directly reusable for detecting channel count and sample rate to configure the new `BiquadCascade` coefficients and the visualizer-feed downmix stride.

No pre-Swift-6 idioms in this section.

### 4. Surround → stereo downmix coefficients (visualizer feed only)

**Citations:** `VideoAudioTap.swift` lines ~348–378 (`inferredSurroundChannelLayoutTag`) and lines ~381–449 (`configureChannelMapping` — `case 1` mono duplication, `default` surround path with `kAudioChannelLayoutTag_AAC_*` tags and `kAudioConverterPropertyPerformDownmix`).

`inferredSurroundChannelLayoutTag` maps channel counts 3–8 to AAC-style `AudioChannelLayoutTag` values (AAC_3_0 through AAC_7_1) as the fallback when no explicit layout is present in the format description. `configureChannelMapping` handles three cases: stereo (no-op), mono (channel map `[0, 0]` — duplicate to both outputs), and surround (install explicit input + stereo output layouts, set `PerformDownmix`). The preference ordering — explicit layout from format description first, AAC-tag inference second — is the correct approach for real-world mp4/m4v audio tracks.

On the new branch, these constants and the three-case dispatch logic are the reference for the visualizer-feed downmix step (step 4 in `tapProcess`). The `AudioConverter` machinery they currently configure is a denylist item; only the channel-layout knowledge transfers.

**Swift-6.2 flag:** `configureChannelMapping` is `private` at file scope and free of pre-Swift-6 patterns. No modernization needed for the logic itself. The `AudioConverterSetProperty` calls that consume the channel layout are denylist-bound; the layout values are not.

### 5. `_test*` seam pattern

**Citations:** `VideoAudioTap.swift` lines ~143–149 (`_testRequestFallback()` under `#if DEBUG`).

A single `#if DEBUG` method exposes internal atomic state mutation as a test seam, allowing Phase 5 watchdog detection tests to drive the fallback path without an attached AVPlayer. The naming convention (`_test` prefix) and `#if DEBUG` guard are the reusable pattern; the specific flag (`fallbackRequested`) is denylist-bound.

No pre-Swift-6 idioms; the seam is already a clean pattern for the new branch's `_testTapProcessInvocationCount` or similar counters.

---

## Modernization flags (Swift 6.2 deltas)

| Item | Location | Issue | New-branch fix |
|---|---|---|---|
| `ManagedAtomic<UInt64>` / `ManagedAtomic<Bool>` | `VideoAudioTapContext` lines 187–188 | `swift-atomics` dependency; pre-Swift-6 atomics | Replace with `Synchronization.Atomic<UInt64>` / `Synchronization.Atomic<Bool>` (Swift 6.0, macOS 15+) |
| `@unchecked Sendable` on `VideoAudioTapContext` | Line ~154 | Blanket suppress suppresses isolation diagnostics | Use `nonisolated(unsafe)` on render-thread-confined stored properties; apply `@unchecked Sendable` only if the class genuinely cannot be annotated per-field |
| `await playerItem.asset.loadTracks(withMediaType:)` | `VideoAudioTap.swift` line ~52 | Already uses async load — compliant | No change needed |
| `await audioTrack.load(.formatDescriptions)` | `VideoAudioTap.swift` line ~62 | Already uses async load — compliant | No change needed |

The `import Atomics` at line 1 is the package-import trigger for the `swift-atomics` dependency. The new branch must not import this package at all; `Synchronization` is stdlib in Swift 6.0.

`kMTAudioProcessingTapCreationFlag_PostEffects` is used at line ~98 (saved branch drains audio out, so PostEffects is correct there). The new branch must evaluate whether `_PreEffects` or `_PostEffects` is correct for in-place modification — this is Q1 in `research.md` and is not resolved by the saved branch's choice (PostEffects was correct for drain semantics, not for in-place EQ).

---

## Denylist confirmations

- **`LockFreeRingBuffer` for video:** `VideoAudioTapContext.ringBuffer: LockFreeRingBuffer` at line 158; `VideoAudioTap.init(ringBuffer:)` at line 41; `AudioPlayer.swift` line 134 (`videoRingBuffer: LockFreeRingBuffer?`). Present and load-bearing on the saved branch; not carried forward.
- **`AVAudioSourceNode` + engine bridge wiring for video:** `AudioPlayer.swift` — `activateStreamBridge` at line 984 and the video bridge setup block at lines ~562–605 wire the ring into an `AVAudioSourceNode`. Not present in `VideoAudioTap.swift` itself, but is the downstream consumer the tap writes to. Not carried forward.
- **`AudioConverter` + Mastering quality tier:** `VideoAudioTap.swift` lines 264–296 (`AudioConverterNew`, `kAudioConverterSampleRateConverterComplexity_Mastering`, `kAudioConverterQuality_Max`). Present and the motivation for the entire topology; not carried forward.
- **`configureChannelMapping` shaped around AudioConverter input contract:** `VideoAudioTap.swift` lines 374–449. The function's internal mechanics call `AudioConverterSetProperty` — these calls are not carried forward even though the channel-layout knowledge they encode is.
- **Watchdog / fallback machinery:** `VideoAudioTap.swift` lines 122–148 (`lastCallbackHostTime`, `fallbackRequested`, `clearFallbackRequested`, `_testRequestFallback`); `AudioPlayer.swift` lines 149–155 (`videoTapWatchdogTask`, `videoTapFallbackActive`), lines 665–782 (`startVideoTapWatchdog`, `stopVideoTapWatchdog`, `engageVideoTapFallback`). Not carried forward.
- **HAL property listener for AirPlay routes:** `AudioPlayer.swift` lines 1315–1362 (`installHALDefaultOutputListener`, `removeHALDefaultOutputListener`, `AudioObjectAddPropertyListenerBlock`). Not carried forward.
- **`AVAudioEngineConfigurationChange` observer for the video path:** `AudioPlayer.swift` lines ~1189–1251 (`handleEngineWillReconfigure` referencing `wasVideoBridge`, `videoBurstGateOpen`). Not carried forward.
- **`videoTapFallbackActive` capability branch:** `AudioPlayer.swift` line 155 (declaration), lines 180–186 (gating logic), line 486 (reset), line 693 (watchdog break). Not carried forward.
- **Phase 7 watchdog gate v2 / 3 s threshold:** `AudioPlayer.swift` lines 85–107 (`videoBurstGateOpen`, `videoReconfigureGateUntilHost`, `videoStallThresholdSeconds = 3`), lines 712–713 (gate check in watchdog loop). Not carried forward.
- **`wasVideoBridge` snapshot field:** `AudioPlayer.swift` lines 1189, 1203, 1251 (references in `handleEngineWillReconfigure`). Already dropped on the current working branch per commit `ffd77c1`; confirmed present only on the saved branch.
- **`swift-atomics` `ManagedAtomic`:** `VideoAudioTap.swift` line 1 (`import Atomics`), lines 187–188 (`ManagedAtomic<UInt64>`, `ManagedAtomic<Bool>`). Not carried forward; superseded by `Synchronization.Atomic`.

---

## TL;DR

The saved branch's `VideoAudioTap.swift` contains two independently reusable structures: the five-callback C-convention shape with `Unmanaged<Context>` / `MTAudioProcessingTapGetStorage` lifetime handoff (topology-agnostic, correct for any `MTAudioProcessingTap` implementation), and the channel-layout knowledge encoded in `inferredSurroundChannelLayoutTag` + the three-case dispatch in `configureChannelMapping` (reusable for the visualizer-feed downmix step on the new branch, minus the `AudioConverter` machinery that currently consumes it). The `AudioStreamBasicDescription` field-by-field inspection pattern in `tapPrepare` is also reusable as the hook for detecting channel count and sample rate to configure in-place DSP. Everything else — the ring buffer, engine bridge wiring, `AudioConverter` + SRC quality tiers, watchdog, HAL listener, fallback flag, and `swift-atomics` atomics — is engine-routing-topology-bound and confirmed present for explicit non-reuse. The one modernization gap that affects the reusable subset is `ManagedAtomic` (`import Atomics`) in `VideoAudioTapContext`; the new branch replaces this with `Synchronization.Atomic` throughout and should also revisit the blanket `@unchecked Sendable` in favor of per-field `nonisolated(unsafe)` carve-outs.
