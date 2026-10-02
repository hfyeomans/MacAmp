# Research: Swift 6.4 / macOS 27 Adoption (S4-1)

Updated: 2026-10-02

**Status:** Not started. Findings feed `plan.md`.

## Sources

### 1. Local Xcode documentation bundle

Path: `/Applications/Xcode.app/Contents/PlugIns/IDEIntelligenceChat.framework/Versions/A/Resources/AdditionalDocumentation/` (20 files).

| File | Why |
|------|-----|
| `Swift-Concurrency-Updates.md` | (a): concurrency defaults and diagnostics vs the ADR-3a containment |
| `Swift-InlineArray-Span.md` | (a): candidates for the DSP and visualizer buffers |
| `SwiftUI-Implementing-Liquid-Glass-Design.md` | (b), (c) |
| `AppKit-Implementing-Liquid-Glass-Design.md` | (c): MacAmp bridges into AppKit through `NSWindow` subclasses |
| `SwiftUI-New-Toolbar-Features.md` | (b) |
| `SwiftUI-WebKit-Integration.md` | (c): Butterchurn runs in WebKit |
| `Foundation-AttributedString-Updates.md` | (b) |
| `SwiftData-Class-Inheritance.md` | Skim only; MacAmp persists through `UserDefaults` |

Caveat: Xcode 27's bundle still carries the WWDC25 (macOS 26) filenames, and whether the content was updated is unchecked. Do not present it as macOS 27 behavior without a second source.

### 2. Release notes (authoritative for the 27 / 6.4 deltas)

- Apple: macOS 27 and Xcode 27 release notes; AVFoundation, AppKit and SwiftUI API diffs.
- swift.org: Swift 6.3 and 6.4 release notes and the Swift Evolution proposals accepted between 6.2 and 6.4.

Retrieve them with one `agy -p` deep-research prompt; use WebSearch for point lookups.

### 3. `agy -p` prompt outline

1. Every language and stdlib change between Swift 6.2 and 6.4, source-breaking separated from additive; call out concurrency-model and strict-concurrency-diagnostic changes.
2. macOS 26 to 27 API deltas for AppKit windowing and Liquid Glass, SwiftUI, WebKit-in-SwiftUI, AVFoundation (`MTAudioProcessingTap`, `AVPlayer`, `AVPlayerItem`, `AVAudioMix`), AVAudioEngine and `Synchronization`.
3. Anything deprecated or behavior-changed for an app with a macOS 27.0 deployment target built with the 27 SDK.
4. Per item, whether it needs the Swift 6.4 language mode or works in 6.2 mode on the 6.4 toolchain.
5. Primary sources only (release notes, evolution proposals), not blog posts.

## Known inputs

- macOS 27-only APIs in use today: only `MTAudioProcessingTapCreateWithPreferredFormat` (`MacAmpApp/Audio/VideoDSP/VideoTap.swift:289`).
- Adoption candidates: whole-mix taps (`AVAudioMixInputParametersTrackMixID`), `InlineArray`, `Array.mutableSpan`, `Span`/`MutableSpan`, `-strict-memory-safety`.
- `tasks/done/lock-free-ring-buffer/plan.md:20` and `research.md:74-87` planned `InlineArray`/`Span` behind `@available(macOS 26, *)` on a macOS 15 base. That platform plan is moot at the 27.0 minimum; no availability gates are needed.

## (a) Swift 6.2 to 6.4 language-mode inventory

TBD. Cover the ADR-3a containment (header contract, `RenderThreadSafe` marker, Gate 3a/3b/3c tests) and `Synchronization.Atomic`/`Mutex` in `MacAmpApp/Audio/VideoDSP/`.

## (b) SwiftUI on macOS 26/27: adoption candidates

TBD. Filter every candidate by the 1:1 pixel-faithful skin constraint.

## (c) macOS 27 AppKit / WebKit / AVFoundation / AVAudioEngine deltas

TBD.

## Impact matrix per subsystem

TBD. One row per subsystem (Audio, Audio/Streaming, Audio/VideoDSP, Skins, Windows/Windowing, Milkdrop/WebKit, Views, Tests; re-derive the rows from the post-Structure-Sprint layout), one column per change, marked BREAKS / ADOPT / IGNORE.

## Open questions for the owner

TBD.
