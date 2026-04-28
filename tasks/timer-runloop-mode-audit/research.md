# Research: Timer.scheduledTimer Run-Loop Mode Audit

> **Created:** 2026-04-28
> **Origin:** Discovered while diagnosing the mwvi (`mainwindow-visualizer-isolation`) spectrum-analyzer freeze. Gemini's deep research surfaced the root cause: `VisualizerPipeline.startPollTimer` was using `Timer.scheduledTimer(withTimeInterval:repeats:block:)` without explicit `.common`-mode registration, so it paused during user gestures (run loop in `.eventTracking`). Fixed in mwvi commit `6a6bbf2`. This task audits whether the same bug pattern exists elsewhere in MacAmp.
> **Sprint:** Post-S3-1A follow-up. Independent of S3-2 / S3-3 / S3-4.

---

## The Bug Pattern

When `Timer.scheduledTimer(withTimeInterval:repeats:block:)` is invoked, it creates a Timer **and** schedules it on the **current run loop in `.default` mode** (per Apple's docs). During an active `DragGesture` (or any AppKit event tracking — window resize, scroll, menu navigation), the main run loop switches to `.eventTracking` mode. `.default`-mode timers are **paused** for the duration of the gesture. They resume when the gesture ends.

The fix is to construct the Timer manually and register it on `.common` mode:

```swift
// Buggy:
fooTimer = Timer.scheduledTimer(withTimeInterval: 1.0/30.0, repeats: true) { [weak self] _ in
    // ... fires only in .default mode → pauses during gestures
}

// Correct:
let timer = Timer(timeInterval: 1.0/30.0, repeats: true) { [weak self] _ in
    // ... body
}
RunLoop.main.add(timer, forMode: .common)
fooTimer = timer
```

`.common` mode includes `.default`, `.eventTracking`, and `.modalPanel`. Timers added on `.common` continue firing during gestures.

---

## Audit: every `Timer.scheduledTimer` call site in `MacAmpApp/`

`rg -n "Timer\.scheduledTimer" MacAmpApp/` (audit date 2026-04-28, post-mwvi-Phase-1C):

### ✅ Already-correct call sites (pattern follows `.common`-mode add)

| File | Line | Purpose | Status |
|---|---:|---|---|
| `MacAmpApp/Audio/AudioEngineController.swift` | 209 | `progressTimer` — playback progress + time display updates | ✅ explicitly adds to `.common` mode at line 223 |
| `MacAmpApp/Audio/StreamPlayer.swift` | 235 | `elapsedTimer` — internet-radio elapsed-time clock | ✅ explicitly adds to `.common` at line 243 |
| `MacAmpApp/Views/Windows/VideoWindowChromeView.swift` | 220 | `metadataScrollTimer` — video-window metadata scroll | ✅ explicitly adds to `.common` at line 232 |
| `MacAmpApp/Audio/VisualizerPipeline.swift` | 426 | `pollTimer` — audio data poll for visualizer | ✅ FIXED in mwvi commit `6a6bbf2` (post-mwvi-Phase-1C) |

### ❌ Buggy call sites (no `.common`-mode add — defaults to `.default`)

| File | Line | Purpose | Severity | User-visible failure mode during gesture |
|---|---:|---|---|---|
| `MacAmpApp/Views/MainWindow/WinampMainWindowInteractionState.swift` | 34 | `scrollTimer` — Winamp main-window marquee title scroll (every 0.15 s) | **HIGH** | Title text freezes during any volume / balance / position slider drag, during shade/clutter button hold, during window-move drag |
| `MacAmpApp/ViewModels/ButterchurnPresetManager.swift` | 208 | `cycleTimer` — Butterchurn auto-preset-cycling (configurable interval, default ~30 s) | **LOW** | Preset cycling pauses for the duration of any gesture. Long gestures could miss a cycle tick |
| `MacAmpApp/ViewModels/ButterchurnPresetManager.swift` | 239 | `trackTitleTimer` — Butterchurn track-title overlay refresh (configurable interval) | **LOW** | Overlay refresh pauses during gestures. Would only matter if a track changes mid-gesture |

**Impact assessment:**

- **HIGH (1 callsite):** `WinampMainWindowInteractionState.scrollTimer`. The Winamp marquee scrolling text in the main window's track-info area is a defining piece of Winamp visual fidelity. It pausing during every slider drag is a noticeable defect, more visible than the visualizer freeze (because every track change triggers scrolling and the user frequently interacts with sliders during playback).
- **LOW (2 callsites):** Both Butterchurn timers fire at multi-second intervals, so a brief gesture (a few seconds of slider drag) is unlikely to miss a tick. The bug is real but its user-visible impact is small.

---

## Why didn't the responsibility sweep (PR #74) catch this?

The 2026-03-25 responsibility sweep (`tasks/responsibility-sweep/research.md`) audited 109 files for SRP + AHA + cohesion + state-ownership concerns. Its checklist did not include "audit producer-side run-loop modes for gesture-pause behavior" because (a) the symptom only manifests during user gestures, which the sweep did not exercise, and (b) the bug pattern looks correct at a glance — `Timer.scheduledTimer` is a standard idiomatic API. The mismatch was invisible without runtime gesture testing **or** a structural search for the pattern "`Timer.scheduledTimer` without immediately-following `RunLoop.main.add(...)`".

This task is the structural-search version: it explicitly compares the *complete* pattern (Timer + add-to-runloop) across all callsites and flags those missing the second step.

---

## Files Analyzed

- `MacAmpApp/Audio/AudioEngineController.swift:205-224`
- `MacAmpApp/Audio/StreamPlayer.swift:225-244`
- `MacAmpApp/Audio/VisualizerPipeline.swift:422-432` (fixed in mwvi)
- `MacAmpApp/Views/Windows/VideoWindowChromeView.swift:213-234`
- `MacAmpApp/Views/MainWindow/WinampMainWindowInteractionState.swift:25-50`
- `MacAmpApp/ViewModels/ButterchurnPresetManager.swift:200-260`
- `tasks/mainwindow-visualizer-isolation/research.md` (Phase 0 + lessons learned)
- `~/.claude/projects/-Users-hank-dev-src-MacAmp/memory/feedback_pipeline_end_to_end_diagnosis.md`
