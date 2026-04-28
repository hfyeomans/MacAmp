# Plan: Timer.scheduledTimer Run-Loop Mode Audit

> **Status:** PLANNED — ready to implement after mwvi PR #A merges.
> **Sprint:** Post-S3-1A follow-up (independent of other S3 work).
> **Branch:** `fix/timer-runloop-mode-audit`
> **PR target:** PR #G (after S3-1, S3-2, S3-3, S3-4 finish; not blocking)

---

## 1. Problem Statement

Three production-code call sites of `Timer.scheduledTimer(withTimeInterval:repeats:block:)` schedule timers on the run loop in `.default` mode only, so they pause during any active gesture (run loop in `.eventTracking`). The most visible defect is the main-window Winamp marquee title scroll freezing during slider drags. This task fixes the three callsites uniformly and adds a structural guard against regression.

## 2. Non-Goals

- **Not** rewriting any timer's behavior or interval.
- **Not** changing what each timer does — only **where** (which run-loop mode) it's scheduled.
- **Not** introducing a new abstraction. Three callsites is below the AHA Rule-of-Three threshold for extraction; we apply the fix in place at each callsite. (Callsite #4 already exists in `AudioEngineController.swift` etc — but that's an *informal* pattern, not an enforced helper.)
- **Not** auditing other timer APIs (`DispatchSourceTimer`, `Timer.publish`, `RunLoop.perform(after:)`, `Task.sleep` loops). Out of scope for this task; covered separately if regressions appear.

## 3. Files to Modify

### File 1: `MacAmpApp/Views/MainWindow/WinampMainWindowInteractionState.swift` (HIGH severity)

Lines 30-50. Convert `Timer.scheduledTimer` to manual `Timer(...)` + `RunLoop.main.add(timer, forMode: .common)`.

```swift
// Before:
scrollTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] _ in
    Task { @MainActor [weak self] in
        // ...
    }
}

// After:
let timer = Timer(timeInterval: 0.15, repeats: true) { [weak self] _ in
    Task { @MainActor [weak self] in
        // ...
    }
}
RunLoop.main.add(timer, forMode: .common)
scrollTimer = timer
```

Add a brief explanatory comment (one line) noting the `.common`-mode requirement so a future contributor doesn't regress this back to `.scheduledTimer`.

### File 2: `MacAmpApp/ViewModels/ButterchurnPresetManager.swift` (LOW severity, both callsites)

Lines 204-213 (`cycleTimer`) and lines 232-244 (`trackTitleTimer`). Same conversion pattern.

## 4. Acceptance Criteria

- All three callsites converted to manual-Timer + `.common`-mode add.
- Visual: with the app open and a track playing, the main-window track title scrolls continuously during a 5-second volume slider drag (was: freezes).
- Build clean with TSan ON.
- All 57 tests pass.
- (No new tests required — these are run-loop-mode fixes; existing tests don't reach into run-loop mode behavior, and writing tests that exercise gesture-vs-timer interactions is high-cost / low-value relative to the structural fix.)

## 5. Stop Criteria / Rollback

- If TSan flags any new race after the fix, halt and consult Oracle (the `.common`-mode add is performed during init, so race risk is minimal but not zero).
- If the marquee scroll is still frozen during gesture after the fix on `WinampMainWindowInteractionState`, halt — that means there's a second cause we haven't found.
- Rollback: standard `git revert <commit>` per file, or full revert if all three turn out wrong (low likelihood).

## 6. Verification

Per Phase 0 mwvi lesson: the symptom (consumer-side freeze) is at the marquee text and the preset cycling. Manual qualitative verification is sufficient — no Instruments spike needed because the diagnosis is already structural.

- V.1 — Manual gesture-during-scroll test on the main-window marquee.
- V.2 — Manual: open Milkdrop window, observe a preset cycle, then mid-cycle drag the volume slider. Confirm cycle still ticks (will require waiting through one full cycle interval; configurable to a short interval like 5 s for testing).
- V.3 — TSan-enabled build + 57-test suite.

## 7. Commit + PR Plan

Single PR, single commit (or three atomic commits, one per file — we'll decide based on size; total expected diff is ~30-40 lines added, ~6 lines removed).

Suggested commit message:

```
fix(runloop): schedule three remaining timers on .common run-loop mode

The Winamp marquee title scroll and the Butterchurn cycle / track-title
timers were using Timer.scheduledTimer(withTimeInterval:repeats:block:)
which adds the timer to the run loop in .default mode. During any active
DragGesture (slider drag, window move, etc.) the main run loop switches
to .eventTracking, pausing those timers for the gesture's duration.
The marquee scroll freezing during slider drags was the most visible
symptom.

Mirrors the fix in mwvi commit 6a6bbf2 for VisualizerPipeline. Three
other timers in the codebase already use the correct .common pattern
(AudioEngineController.progressTimer, StreamPlayer.elapsedTimer,
VideoWindowChromeView.metadataScrollTimer); this commit brings the
remaining three into alignment.

Co-Authored-By: Claude <noreply@anthropic.com>
```

## 8. Future-Proofing (Optional, Out of Scope)

The repeated boilerplate pattern (Timer + add-to-`.common` + assign) appears 6 times after this task. That's exactly at the AHA Rule-of-Three threshold. **Don't extract a helper now** — wait for a 7th callsite or a related refactor. If extraction is eventually warranted, candidate signature:

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

But this is a candidate for a separate task — *not* this one — because adding it requires migrating all 6 callsites and may surface concurrency-checking edge cases that warrant their own review. Tracked in the "Future Work" section of `tasks/_context/state.md`.
