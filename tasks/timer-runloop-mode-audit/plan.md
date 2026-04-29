# Plan: Timer.scheduledTimer Run-Loop Mode Audit

> **Status:** IN PROGRESS — branch `fix/timer-runloop-mode-audit` cut from `main` at `883d085`.
> **Sprint:** Post-S3-1A follow-up (independent of other S3 work).
> **Branch:** `fix/timer-runloop-mode-audit`
> **PR target:** PR #G

---

## 1. Problem Statement

The codebase has three coexisting forms of timer-on-RunLoop scheduling:

- **Pattern A (1 callsite, mwvi-canonical):** `Timer(timeInterval:repeats:block:)` + `RunLoop.main.add(timer, forMode: .common)` + assignment.
- **Pattern B (4 callsites):** `Timer.scheduledTimer(...)` + later `RunLoop.main.add(timer, forMode: .common)`. Functionally correct (the same timer is registered on both `.default` and `.common` modes; Apple permits a timer to be in multiple modes in the same RunLoop) but stylistically inconsistent and has a quieter failure mode if the `.common` add is ever removed (the timer silently degrades to `.default`-only).
- **Buggy (2 callsites):** `Timer.scheduledTimer(...)` with **no** `.common` add. Both are in `ButterchurnPresetManager` (`cycleTimer`, `trackTitleTimer`). Fires only in `.default` mode → pauses during any gesture.

The user-visible defect (HIGH severity) reported in the original audit — Winamp marquee freeze during slider drag — was based on a misread; that callsite already has the `.common` add and the marquee scrolls correctly during gestures (manually verified by user on `main` 2026-04-29). The two LOW-severity Butterchurn defects are real.

This task **normalizes all 6 non-Pattern-A callsites onto Pattern A** so the codebase has one canonical run-loop-mode idiom. The 2 Butterchurn callsites get fixed in the process.

## 2. Non-Goals

- **Not** rewriting any timer's behavior or interval.
- **Not** changing what each timer does — only **how** it's constructed and scheduled.
- **Not** introducing a `Timer.scheduledOnCommon(...)` extension helper. With 7 Pattern-A callsites after this task, AHA Rule-of-Three is exceeded; extracting a helper is an obvious next step but is its own concern (visibility, `Sendable` checks, where the extension lives, comment-as-doc placement). Tracked as a follow-up below.
- **Not** auditing other timer APIs (`DispatchSourceTimer`, `Timer.publish`, `RunLoop.perform(after:)`, `Task.sleep` loops). Out of scope for this task; covered separately if regressions appear.

## 3. Files to Modify (6 callsites in 5 files)

### File 1: `MacAmpApp/Audio/AudioEngineController.swift` (Pattern B → A)

Lines 207-224. Convert `progressTimer` setup.

```swift
// Before:
func startProgressTimer() {
    progressTimer?.invalidate()
    let timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
        // ... body ...
    }
    progressTimer = timer
    RunLoop.main.add(timer, forMode: .common)
}

// After:
func startProgressTimer() {
    progressTimer?.invalidate()
    // .common mode keeps this firing during gestures (.default would pause in .eventTracking).
    let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
        // ... body ...
    }
    RunLoop.main.add(timer, forMode: .common)
    progressTimer = timer
}
```

### File 2: `MacAmpApp/Audio/StreamPlayer.swift` (Pattern B → A)

Lines 232-244. Convert `elapsedTimer` setup. Same shape as File 1.

### File 3: `MacAmpApp/Views/Windows/VideoWindowChromeView.swift` (Pattern B → A)

Lines 216-234. Convert `metadataScrollTimer` setup. The current code uses an `if let timer = metadataScrollTimer { RunLoop.main.add(...) }` guard which becomes unnecessary when we move to manual construction.

### File 4: `MacAmpApp/Views/MainWindow/WinampMainWindowInteractionState.swift` (Pattern B → A)

Lines 30-53. Convert `scrollTimer` setup. Same `if let` simplification as File 3.

### File 5+6: `MacAmpApp/ViewModels/ButterchurnPresetManager.swift` (Buggy → A) — TWO callsites

- Lines 204-213 (`cycleTimer`)
- Lines 232-244 (`trackTitleTimer`)

Convert both to Pattern A. These currently have no `.common` add.

## 4. Acceptance Criteria

- All 6 callsites use Pattern A: manual `Timer(...)` + `RunLoop.main.add(timer, forMode: .common)` + assignment.
- Each Pattern A callsite has a single-line comment explaining why `.common` is required.
- Build clean with TSan ON.
- All 59 tests pass with TSan ON.
- Manual: Butterchurn preset cycle continues during a 6-second slider drag (was: paused). Set cycle interval to ~5s for testing.
- Manual: Marquee title scrolls during slider drag (no regression — was already working).
- Audit re-run: `rg -n "Timer\.scheduledTimer" MacAmpApp/` returns zero matches in production code (post-conversion). Only `Timer(timeInterval:...)` appears.

## 5. Stop Criteria / Rollback

- If TSan flags any new race, halt and consult Oracle. The pattern conversion is mechanical (init order swap), so race risk is essentially zero, but `Timer(timeInterval:repeats:block:)` does have subtly different threading guarantees from `scheduledTimer` and we should confirm.
- If any timer stops firing entirely after the conversion, halt — that means we forgot the `RunLoop.main.add(...)` somewhere.
- If a callsite turns out to require `.default`-mode-only behavior (none we know of, but Oracle should confirm), revert that single callsite and document why.
- Rollback: `git revert <commit>` restores the original mixed Pattern A/B/buggy state.

## 6. Verification

- V.1 — Manual: marquee scroll during 5-second slider drag (smoke; should already work).
- V.2 — Manual: Butterchurn preset cycle ticking during 6-second slider drag (real test of the bug-fix portion).
- V.3 — Manual: Butterchurn track-title overlay refresh during slider drag (real test of the second buggy callsite).
- V.4 — `xcodebuildmcp macos build --json '{"extraArgs":["-enableThreadSanitizer","YES"]}'` passes.
- V.5 — `xcodebuildmcp macos test --json '{"extraArgs":["-enableThreadSanitizer","YES"]}'` passes (59/59).
- V.6 — Audit re-run: `rg -n "Timer\.scheduledTimer" MacAmpApp/` returns zero. Pattern is normalized.

## 7. Commit + PR Plan

Single commit. Total expected diff: ~36 added, ~30 removed across 5 source files (mostly line reordering + comment additions), plus 4 task-doc updates.

Suggested commit message:

```
refactor(runloop): normalize all timers onto Pattern A (.common mode)

The codebase had three coexisting forms of timer-on-RunLoop scheduling:

  * Pattern A (1 callsite, mwvi-canonical): Timer(...) + .common add.
  * Pattern B (4 callsites): scheduledTimer + later .common add.
  * Buggy (2 ButterchurnPresetManager callsites): scheduledTimer with
    no .common add at all — paused during gestures.

Pattern B is functionally equivalent to A (a timer can be registered on
multiple modes within one RunLoop), but Pattern A has clearer intent and
a louder failure mode if the .common add is ever removed (the timer
becomes unscheduled rather than silently .default-only).

This commit normalizes all 6 non-A callsites onto Pattern A:

  - AudioEngineController.progressTimer        (B → A)
  - StreamPlayer.elapsedTimer                  (B → A)
  - VideoWindowChromeView.metadataScrollTimer  (B → A)
  - WinampMainWindowInteractionState.scrollTimer (B → A)
  - ButterchurnPresetManager.cycleTimer        (Buggy → A)
  - ButterchurnPresetManager.trackTitleTimer   (Buggy → A)

The two ButterchurnPresetManager bugs (LOW severity) are fixed as a
side-effect of the consistency pass: their auto-preset cycle and track-
title overlay refresh no longer pause during user gestures.

Mirrors the pattern in mwvi commit 6a6bbf2 (VisualizerPipeline.pollTimer).

Build clean with TSan ON; all 59 tests pass.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
```

## 8. Future-Proofing — Helper Extension (separate task)

After this task lands, all 7 timer-on-RunLoop callsites in `MacAmpApp/` use Pattern A literally. AHA Rule of Three is exceeded by 4×. The boilerplate is mechanical and easy to forget the `.common` add on a future addition.

A `Timer.scheduledOnCommon(every:repeats:_:)` extension would centralize the pattern:

```swift
extension Timer {
    /// Schedule a repeating timer on RunLoop.main in .common mode so it
    /// continues firing during user gestures (default Timer.scheduledTimer
    /// uses .default mode and pauses during .eventTracking).
    @discardableResult
    static func scheduledOnCommon(
        every interval: TimeInterval,
        repeats: Bool = true,
        _ block: @escaping @Sendable (Timer) -> Void
    ) -> Timer {
        let timer = Timer(timeInterval: interval, repeats: repeats, block: block)
        RunLoop.main.add(timer, forMode: .common)
        return timer
    }
}
```

This is **not** done in this task because:

1. It expands the diff and PR scope into adding a new public API.
2. The `Sendable` annotation on the closure may surface concurrency-checker edge cases at some callsites that warrant individual review (e.g., Pattern A callsites currently use `[weak self]` + `MainActor.assumeIsolated` patterns that interact with `@Sendable`).
3. Where the extension lives (a new `Utilities/Timer+CommonMode.swift` file) is its own naming/placement decision that touches `project.yml`.

Tracked as a follow-up task: `timer-scheduled-on-common-extension` (to be created post-merge of this PR).
