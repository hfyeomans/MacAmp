# Research: Swift 6.4 / macOS 27 Readiness

> **Status:** STUB — research not started (scaffolded 2026-09-05, S4-1).
> **Gate:** findings feed `plan.md`, which must reach Codex Oracle ≥ 9/10 before any code is written.

---

## Sources to consult

### 1. Local Xcode documentation bundle

Path: `/Applications/Xcode.app/Contents/PlugIns/IDEIntelligenceChat.framework/Versions/A/Resources/AdditionalDocumentation/` (20 files).

Relevant files:

| File | Why |
|------|-----|
| `Swift-Concurrency-Updates.md` | Question (a) — concurrency defaults, strict-concurrency diagnostics vs the ADR-3a containment |
| `Swift-InlineArray-Span.md` | Question (a) — stdlib additions; possible fit for the render-thread buffers in `Audio/VideoDSP/` |
| `SwiftUI-Implementing-Liquid-Glass-Design.md` | Question (b)/(c) |
| `AppKit-Implementing-Liquid-Glass-Design.md` | Question (c) — MacAmp bridges heavily into AppKit via `NSWindow` subclasses |
| `SwiftUI-New-Toolbar-Features.md` | Question (b) |
| `SwiftUI-WebKit-Integration.md` | Question (c) — Butterchurn/Milkdrop runs in WebKit |
| `Foundation-AttributedString-Updates.md` | Question (b) |
| `SwiftData-Class-Inheritance.md` | Low relevance (MacAmp persists via `UserDefaults`, not SwiftData) — skim only |

> ⚠️ **CAVEAT — these filenames match the macOS-26 (WWDC25) generation.** They are the previous major's documentation set. The **macOS 27 / Swift 6.4 deltas are NOT in this bundle** and must be sourced separately (below). Do not present bundle content as macOS 27 behavior.

### 2. Release notes (the authoritative source for the 27 / 6.4 deltas)

- Apple: macOS 27 release notes, Xcode 27 release notes, AVFoundation + AppKit + SwiftUI API diffs.
- swift.org: Swift 6.3 and 6.4 release notes, plus the accepted Swift Evolution proposals between 6.2 and 6.4.

Retrieve via `agy -p` deep research (single comprehensive prompt, preferred over sequential fetches) with WebSearch as a fallback for point lookups.

### 3. `agy -p` prompt outline

Scope it to a synthesis, not a link dump:

1. Enumerate every language/stdlib change between Swift 6.2 and 6.4 — separate **source-breaking** from additive; call out concurrency-model and strict-concurrency-diagnostic changes explicitly.
2. Enumerate the macOS 26 → 27 API deltas for: AppKit windowing + Liquid Glass, SwiftUI, WebKit-in-SwiftUI, AVFoundation (`MTAudioProcessingTap`, `AVPlayer`, `AVPlayerItem`, `AVAudioMix`), AVAudioEngine, `Synchronization`.
3. Flag anything **deprecated or behavior-changed** that a macOS 15.0-deployment-target app would hit when built with the 27 SDK.
4. State, per item, whether it is gated behind a raised deployment target.
5. Cite primary sources (release notes / evolution proposals), not blog posts.

### 4. Codex Oracle gate

Validate the resulting plan with `mcp__codex-cli__codex` (model `gpt-5.5`, `reasoningEffort: xhigh`) per the `codex-oracle-workflow` skill. Iterate until ≥ 9/10.

---

## (a) Swift 6.2 → 6.4 language-mode change inventory

TBD

## (b) SwiftUI on macOS 26/27 — adoption candidates

TBD

## (c) macOS 27 AppKit / WebKit / AVFoundation / AVAudioEngine deltas

TBD

## (d) Deployment target: stay at 15.0, or raise to 26 / 27?

TBD

## Impact matrix per MacAmp subsystem

TBD — one row per subsystem (Audio, Audio/Streaming, Audio/VideoDSP, Skins, Windows/Windowing, Milkdrop/WebKit, Views, Tests), one column per change, marking BREAKS / BLOCKED-ON-TARGET / ADOPT / IGNORE.

## Open questions for the user

TBD
