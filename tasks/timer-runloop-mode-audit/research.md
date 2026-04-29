# Research: Timer.scheduledTimer Run-Loop Mode Audit

> **Created:** 2026-04-28
> **Revised:** 2026-04-29 (re-audit at HEAD `883d085`; original audit table was textually-only and was inconsistent — see "Audit correction" section below)
> **Origin:** Discovered while diagnosing the mwvi (`mainwindow-visualizer-isolation`) spectrum-analyzer freeze. Gemini's deep research surfaced the root cause: `VisualizerPipeline.startPollTimer` was using `Timer.scheduledTimer(withTimeInterval:repeats:block:)` without explicit `.common`-mode registration, so it paused during user gestures (run loop in `.eventTracking`). Fixed in mwvi commit `6a6bbf2`. This task audits whether the same bug pattern exists elsewhere in MacAmp.
> **Sprint:** Post-S3-1A follow-up. Independent of S3-2 / S3-3 / S3-4.

---

## The Bug Pattern

When `Timer.scheduledTimer(withTimeInterval:repeats:block:)` is invoked, it creates a Timer **and** schedules it on the **current run loop in `.default` mode** (per Apple's docs). During an active `DragGesture` (or any AppKit event tracking — window resize, scroll, menu navigation), the main run loop switches to `.eventTracking` mode. `.default`-mode timers are **paused** for the duration of the gesture. They resume when the gesture ends.

There are two ways to keep a timer firing during gestures, both functionally correct (Apple permits a timer to be registered on multiple modes within the same RunLoop):

```swift
// Pattern A (mwvi-canonical) — construct manually, attach explicitly to .common:
let timer = Timer(timeInterval: 1.0/30.0, repeats: true) { [weak self] _ in
    // ... body
}
RunLoop.main.add(timer, forMode: .common)
fooTimer = timer

// Pattern B (works, but redundant) — schedule first, then ALSO add to .common:
fooTimer = Timer.scheduledTimer(withTimeInterval: 1.0/30.0, repeats: true) { [weak self] _ in
    // ... body
}
if let timer = fooTimer { RunLoop.main.add(timer, forMode: .common) }
```

`.common` mode is a magic constant that expands to all modes registered as common to the run loop (includes `.default`, `.eventTracking`, `.modalPanel`). Timers added on `.common` continue firing during gestures.

**Pattern A is preferred** for three reasons:

1. **Clearer intent.** Construction and scheduling are separate steps; the reader sees "this timer is meant for `.common` mode" at a glance.
2. **Avoids the redundant `.default` registration** that Pattern B leaves in place.
3. **Louder failure mode if the `.common` add is ever removed.** With Pattern A the timer is unscheduled (and visibly does not fire); with Pattern B the timer silently degrades to `.default`-only and the gesture-pause bug returns invisibly.

This task normalizes the codebase on Pattern A.

---

## Audit at HEAD `883d085` (post-mwvi-PR-#80)

`rg -n "Timer\.scheduledTimer" MacAmpApp/` + `rg -n "RunLoop\.main\.add"` + visual inspection of every callsite (audit date 2026-04-29):

### ✅ Pattern A — mwvi-canonical (1 callsite)

| File | Line | Purpose |
|---|---:|---|
| `MacAmpApp/Audio/VisualizerPipeline.swift` | 440-447 | `pollTimer` — visualizer audio-data poll. Fixed in mwvi commit `6a6bbf2`. |

### ⚠️ Pattern B — functionally correct, but stylistically inconsistent (4 callsites)

| File | Line(s) | Purpose | Why convert |
|---|---:|---|---|
| `MacAmpApp/Audio/AudioEngineController.swift` | 209 + 223 | `progressTimer` — playback progress + time display | Pattern A is canonical |
| `MacAmpApp/Audio/StreamPlayer.swift` | 235 + 243 | `elapsedTimer` — stream elapsed-time clock | Pattern A is canonical |
| `MacAmpApp/Views/Windows/VideoWindowChromeView.swift` | 220 + 231-233 | `metadataScrollTimer` — video metadata scroll | Pattern A is canonical |
| `MacAmpApp/Views/MainWindow/WinampMainWindowInteractionState.swift` | 34 + 50-52 | `scrollTimer` — Winamp marquee title scroll | Pattern A is canonical |

### ❌ Buggy — no `.common` add at all (2 callsites)

| File | Line | Purpose | Severity | User-visible failure mode during gesture |
|---|---:|---|---|---|
| `MacAmpApp/ViewModels/ButterchurnPresetManager.swift` | 208 | `cycleTimer` — Butterchurn auto-preset-cycling (configurable interval, default ~15 s) | LOW | Preset cycling pauses for the duration of any gesture. Long gestures could miss a cycle tick. |
| `MacAmpApp/ViewModels/ButterchurnPresetManager.swift` | 239 | `trackTitleTimer` — Butterchurn track-title overlay refresh (configurable interval) | LOW | Overlay refresh pauses during gestures. Would only matter if a track changes mid-gesture. |

**Impact assessment:**

- **LOW (2 callsites):** Both Butterchurn timers fire at multi-second intervals, so a brief gesture (a few seconds of slider drag) is unlikely to miss a tick. The bug is real but its user-visible impact is small.
- **No HIGH-severity user-visible defect remains** post-PR-#80. The `WinampMainWindowInteractionState.scrollTimer` was *labeled* HIGH in the original audit, but in fact it has had the `.common` add since the original Phase 1 scaffolding extraction (commit `997e4d6`, well before mwvi). Manual verification confirmed (by user, 2026-04-29): the marquee continues scrolling during volume/balance slider drags on `main`.

---

## Audit correction (2026-04-29)

The original audit (research.md as written 2026-04-28) was **textual**: it ran `rg -n "Timer\.scheduledTimer"` and visually classified each match as ✓/❌ based on whether it could see a `RunLoop.main.add` in the same code block. Two callsites that DO have the `.common` add a few lines below the `Timer.scheduledTimer` line (`WinampMainWindowInteractionState.scrollTimer`, `VideoWindowChromeView.metadataScrollTimer`) were classified inconsistently: the latter was correctly marked ✓, the former was incorrectly marked ❌. Two callsites where the `.common` add appears immediately after the `Timer.scheduledTimer` line (`AudioEngineController.progressTimer`, `StreamPlayer.elapsedTimer`) were marked ✓ but on the wrong-pattern grounds (they were assumed to be Pattern A like the mwvi fix).

The corrected audit, performed by reading every callsite at HEAD plus running `rg -n "RunLoop\.main\.add" MacAmpApp/`, distinguishes three categories rather than two: Pattern A, Pattern B, and Buggy. This task's revised scope is "normalize all 6 non-A callsites onto Pattern A," not "fix 3 buggy callsites."

The lesson — **always pair a textual `rg` audit with structural `ast-grep` (or at minimum a visual scan of every match's surrounding lines)** — is captured in the existing `feedback_ast_grep_structural_search.md` memory.

---

## Why didn't the responsibility sweep (PR #74) catch this?

The 2026-03-25 responsibility sweep (`tasks/responsibility-sweep/research.md`) audited 109 files for SRP + AHA + cohesion + state-ownership concerns. Its checklist did not include "audit producer-side run-loop modes for gesture-pause behavior" because (a) the symptom only manifests during user gestures, which the sweep did not exercise, and (b) the bug pattern looks correct at a glance — `Timer.scheduledTimer` is a standard idiomatic API. The mismatch was invisible without runtime gesture testing **or** a structural search for the pattern "`Timer.scheduledTimer` without immediately-following `RunLoop.main.add(...)`".

This task is the structural-search version: it explicitly compares the *complete* pattern (Timer + add-to-runloop) across all callsites and flags those missing the second step. It also normalizes the *shape* of the existing correct callsites onto a single canonical form so future contributors have one idiom to copy.

---

## Files Analyzed

- `MacAmpApp/Audio/AudioEngineController.swift:205-224`
- `MacAmpApp/Audio/StreamPlayer.swift:225-244`
- `MacAmpApp/Audio/VisualizerPipeline.swift:430-448` (Pattern A reference; fixed in mwvi)
- `MacAmpApp/Views/Windows/VideoWindowChromeView.swift:213-234`
- `MacAmpApp/Views/MainWindow/WinampMainWindowInteractionState.swift:25-53`
- `MacAmpApp/ViewModels/ButterchurnPresetManager.swift:200-260`
- `tasks/done/mainwindow-visualizer-isolation/research.md` (Phase 0 + lessons learned)
- `~/.claude/projects/-Users-hank-dev-src-MacAmp/memory/feedback_pipeline_end_to_end_diagnosis.md`
- `~/.claude/projects/-Users-hank-dev-src-MacAmp/memory/feedback_ast_grep_structural_search.md`
