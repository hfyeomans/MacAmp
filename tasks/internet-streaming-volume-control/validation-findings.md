# Validation Findings: Internet Streaming Volume Control

> **Date:** 2026-02-14
> **Validators:** memory-work-validator, windowcoord-validator, Oracle (gpt-5.3-codex, xhigh reasoning)

---

## Summary

Three-pass validation of the internet-streaming-volume-control plan against recent codebase changes:

1. **memory-work-validator:** Found 10 updates needed (SPSC refactor makes prerequisite complete)
2. **windowcoord-validator:** No impact from WindowCoordinator work
3. **Oracle (gpt-5.3-codex):** Confirmed all 10 updates, found 4 additional issues

---

## Validator 1: Memory/CPU Optimization Findings (10 Updates)

### Applied Updates

| # | Finding | Severity | Status |
|---|---------|----------|--------|
| 1 | Phase 2 prerequisite is COMPLETE (SPSC refactor) | CRITICAL | Applied to research.md, plan.md, state.md |
| 2 | Stale line references (493, 509, 518) in research.md | HIGH | Applied — old lines replaced with current references |
| 3 | SPSC pattern provides ring buffer template | MEDIUM | Applied — note added to plan.md Phase 2 section |
| 4 | Bar count is 20, not 19 | LOW | Applied — all "19-bar" replaced with "20-bar" in plan.md |
| 5 | Feasibility upgrade for Approach C (tap-read) | HIGH | Applied — 6-7/10 upgraded to 8.5/10 |
| 6 | Plan should reference SPSC pattern | MEDIUM | Applied — VisualizerSharedBuffer referenced in plan.md |
| 7 | clearData() exists and should be noted | MEDIUM | Applied — noted in plan.md Phase 2 section |
| 8 | state.md blocker is resolved | HIGH | Applied — marked RESOLVED with details |
| 9 | Plan Goertzel "19-bar" label | LOW | Applied — replaced with "20-bar" |
| 10 | Feasibility matrices need update | HIGH | Applied — both research.md matrices updated |

### Oracle Nuance on Finding #4 (Bar Count)
Pipeline internally uses 20 bars, but UI renders 19 bars (VisualizerView.swift:23). Plan references to "20-bar" are correct for the pipeline, but the user-facing visualization is 19 bars. No plan change needed — pipeline bar count is the relevant metric for Phase 2.

---

## Validator 2: WindowCoordinator Findings

**Result: NO IMPACT.** WindowCoordinator only manages window positioning, docking, and visibility. No modifications to streaming volume control task files required.

---

## Oracle Findings (gpt-5.3-codex, xhigh reasoning)

### Confirmed Validator 1 Updates
All 10 updates confirmed correct and complete with nuances noted above.

### Additional Issues Found by Oracle (4)

| # | Finding | Severity | Status |
|---|---------|----------|--------|
| A1 | `isStreamPlaying` logic wrong for real app flows | HIGH | **Applied** — Fixed to use `currentSource` instead of `currentTrack?.isStream` |
| A2 | Step 1.3 video volume propagation gap | HIGH | **Applied** — Added videoPlaybackController.volume to setVolume() |
| A3 | Balance binding not rerouted through coordinator | MEDIUM | **Applied** — Added rerouting note to Step 1.8 |
| A4 | Startup volume sync path underspecified | MEDIUM | **Applied** — Added startup sync note to Step 1.9 |

### Detail: A1 — isStreamPlaying Logic

**Problem:** Plan used `currentTrack?.isStream == true && streamPlayer.isPlaying` which fails when:
- `currentTrack` is nil (station played directly via `play(station:)` — see PlaybackCoordinator.swift line 133)
- Stream is paused (should still report stream backend active for capability flags)

**Fix:** Changed to check `currentSource` enum case:
```swift
private var isStreamBackendActive: Bool {
    if case .radioStation = currentSource { return true }
    return false
}
```

### Detail: A2 — Video Volume Propagation

**Problem:** Step 1.3 `setVolume()` snippet only updated audioPlayer and streamPlayer, but Step 1.6 removes video volume propagation from AudioPlayer.volume didSet. This creates a gap where video volume is never set.

**Fix:** Added `audioPlayer.videoPlaybackController.volume = volume` to Step 1.3 setVolume().

### Detail: A3 — Balance Binding

**Problem:** Plan routes volume through coordinator (Step 1.5) but doesn't explicitly reroute balance binding. Current UI binds balance directly to `audioPlayer.balance`.

**Fix:** Added note to Step 1.8 that balance binding must also be rerouted through coordinator.

### Detail: A4 — Startup Volume Sync

**Problem:** Persisted volume is loaded in AudioPlayer.init() from UserDefaults, but StreamPlayer starts with default 0.75. PlaybackCoordinator doesn't sync initial volume to StreamPlayer.

**Fix:** Added note to Step 1.9 that PlaybackCoordinator must propagate initial volume to StreamPlayer during init or before first stream play.

### Oracle Feasibility Assessment (Post-Prerequisite)

| Approach | Previous | Updated | Reason |
|----------|----------|---------|--------|
| C: Tap-read (visualization) | 6-7/10 | **8.5/10** | VisualizerPipeline prerequisite complete |
| G: Loopback Bridge | 5.5-6.5/10 | **6.0-7.0/10** | Small bump; main challenges (RT-to-RT buffer, ABR, lifecycle) remain |
| C: Tap-write (EQ) | 3-5/10 | 3-5/10 | Unchanged — custom biquad still very complex |

### Oracle Note on Ring Buffer Lock Strategy

The SPSC VisualizerSharedBuffer uses `os_unfair_lock` which is appropriate for its use case (RT audio thread writing, main thread consuming). However, the Phase 2 ring buffer between MTAudioProcessingTap (RT) and AVAudioEngine render thread (RT) requires **true lock-free SPSC atomics** (head/tail indices with atomic operations). `os_unfair_lock` is NOT suitable for RT-to-RT communication.

### Oracle Volume Routing Concerns

1. Need one clear source of truth for volume (PlaybackCoordinator.volume or AudioPlayer.volume) to avoid drift
2. Must cover ALL paths: UI drag, startup restore, programmatic updates — not just slider events
3. Stream-state detection logic (now fixed with `currentSource`) is critical for correct capability flags

---

## Files Modified

| File | Changes |
|------|---------|
| `research.md` | Status updated, feasibility matrices updated, prerequisite marked complete, bar count fixed, stale line refs removed |
| `plan.md` | Status updated, 19-bar->20-bar, SPSC template reference added, clearData() noted, isStreamPlaying fixed, video volume added, balance rerouting noted, startup sync noted |
| `state.md` | Status updated, prerequisite blocker marked RESOLVED, feasibility numbers updated, progress checkboxes added |
| `validation-findings.md` | NEW — this file |

---

## Conclusion

The internet-streaming-volume-control plan is now validated and up-to-date with all codebase changes from the memory/CPU optimization work. The Phase 2 prerequisite (VisualizerPipeline zero-allocation) is confirmed COMPLETE. Four additional issues found by Oracle have been applied. The plan is ready for user approval and implementation.
