# Task State: Swift 6.4 / macOS 27 Readiness

> **Purpose:** Prepare MacAmp for the Swift 6.4 language mode and macOS 27 — inventory what changes, decide what to adopt vs defer, and settle the deployment-target question with an ADR.
> **Created:** 2026-09-05
> **Sprint:** S4-1 (Post-Structure-Sprint)
> **Status:** 📋 **QUEUED** — blocked on the Post-S3 Structure Sprint. Research not started.

---

## Predecessors

| Predecessor | Why | Status |
|-------------|-----|--------|
| S3-2 `avplayer-native-video-dsp` → PR #C merged | The branch that introduced `Audio/VideoDSP/` (ADR-3a `@unchecked Sendable` containment, `Synchronization.Atomic`/`Mutex`) must land before its concurrency surface can be re-evaluated under a new language mode | 🔧 in progress |
| S3-3 `hls-streaming-support` → merged | S3 must close before the Structure Sprint starts | queued |
| S3-4 `ogg-vorbis-support` → merged | Adds vendored C deps + `Package.swift` / `project.yml` changes that a tools-version bump would touch | queued |
| Post-S3 Structure Sprint | File-move consolidation is a stop-the-world pass; a language-mode bump on top of moving files doubles the conflict surface | not started |

> **Allowance:** the **research half** of this task touches no code and may run opportunistically earlier (during S3 or the Structure Sprint). Only the implementation half is gated on the Structure Sprint landing.
>
> **Ordering vs S4-2 `github-issues-triage` is an ASSUMPTION pending user confirmation.** The user mandated only that the GitHub-issue fixes come after the `.swift` rearrangement. S4-1 is placed first because its deprecation findings may change how the S4-2 issues are fixed. See `_context/state.md` decision D-S4.

---

## Current toolchain vs project pins (verified 2026-09-05)

| Axis | Machine / toolchain | Project pin | Gap |
|------|--------------------|-------------|-----|
| macOS (host) | 27.0 (`26A5425a`) | — | Host is two majors ahead of the deployment target |
| Xcode | 27.0 (`27A5194q`) | `project.yml` declares `xcodeVersion: 26.0` | Cosmetic drift, known; fix as part of this task |
| Swift toolchain | 6.4 | — | — |
| Swift language mode | — | `SWIFT_VERSION` 6.2 | The bump this task evaluates |
| SwiftPM | — | swift-tools-version 6.2 | Bump decision paired with the above |
| Deployment target | — | macOS 15.0 | The ADR below decides whether to raise it |

The Swift **module** name is `MacAmp` (`PRODUCT_NAME`); `MacAmpApp` is the scheme. Mangled symbols read `_$s6MacAmp…`.

---

## Research questions

**(a) What flips when `SWIFT_VERSION` → 6.4?**
Concurrency defaults, stdlib additions (e.g. `InlineArray`, `Span`), deprecations, and strict-concurrency diagnostics. Specifically: what it means for the **ADR-3a `@unchecked Sendable` containment** (the Gate 1 header contract + `RenderThreadSafe` marker protocol + the Gate 3a/3b/3c reflection tests) and for the `Synchronization.Atomic` / `Mutex` usage in `MacAmpApp/Audio/VideoDSP/`.

**(b) What's new in SwiftUI on macOS 26/27 that MacAmp can adopt?**
Weighted against the project's constraint that the UI must stay 1:1 pixel-faithful to classic Winamp skins.

**(c) What does macOS 27 add or deprecate across the AppKit + AV surface MacAmp depends on?**
AppKit (Liquid Glass), toolbars, WebKit-in-SwiftUI (Butterchurn runs in WebKit), AVFoundation / `MTAudioProcessingTap` (the whole S3-2 video-DSP architecture rests on it), AVAudioEngine.

**(d) Should the deployment target be raised (15 → 26 or 27)?**
What it unlocks and what it breaks for skins + windowing, and what it costs in addressable users.

---

## Key ADR to write

**ADR-1: Deployment target.** Stay on macOS 15.0, or raise to 26 / 27. This is the decision that gates most of (b) and (c) — every "adopt this new API" answer is conditional on it. The ADR must state the user-reach cost, the APIs unlocked, the APIs that would need `if #available` fallbacks either way, and a kill switch.

Secondary ADRs likely needed: language-mode bump (`SWIFT_VERSION` + swift-tools-version, together or staged), and the fate of the ADR-3a containment gates under 6.4 semantics.

---

## Deliverables

| File | Content |
|------|---------|
| `research.md` | Change inventory + impact matrix per MacAmp subsystem (Audio, VideoDSP, Skins, Windowing, Milkdrop/WebKit, Views) |
| `plan.md` | Adopt/defer decision per item + the deployment-target ADR. **Oracle-gated ≥ 9/10 before any code.** |
| `todo.md` | Phased work-item checklist |

---

## Status log

| Date | Entry |
|------|-------|
| 2026-09-05 | Folder scaffolded. Queued as S4-1. No research started. |
