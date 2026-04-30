# State: Video Audio Engine Routing

> **Purpose:** Route AVPlayer video audio through AVAudioEngine via `MTAudioProcessingTap` so video gets EQ + visualization. Includes engine config change observer (deferred from AirPlay PR #69).
> **Created:** 2026-03-14
> **Sprint:** S3, Wave S3-2 (sequential after S3-1 merges)
> **Status:** PHASE 0 ✅ COMPLETE — Path NONE; implementation in progress on `feat/video-audio-engine-routing`

---

## Current Status

**Phase:** Phase 0 complete (Path NONE confirmed empirically). Phase 1 (engine config observer) next.
**Last Updated:** 2026-04-30.

### Phase 0 outcome (spike findings — full detail in `research.md`)

- **Decision:** Path NONE per plan §5.4 — frequency-locked clocks confirmed; no sync code needed.
- **Slope across 5 files:** mean -0.75 ms/sec, 95% CI [-6.4, +4.9] ms/sec — statistically zero.
- **Constant -200 ms phase offset:** AVPlayer pipeline depth (decoded-time vs presentation-time per Gemini synthesis), not perceptible drift. Empirically defer to plan §5.3 perception test during implementation.
- **Plan §9 Phase 4 collapses to no-op** (todo §4.NONE only).
- **Plan §7.5 AudioConverter is load-bearing**, not optional — without it, 44.1 kHz audio plays as discontinuous bursts every ~76 ms.
- **Spike branch:** `spike/vaer-av-drift-measurement` deleted (4 commits, never pushed) per §5.5. Findings committed on main as `1d4eca1`.

### Artifacts

| File | Status |
|------|--------|
| `research.md` | ✅ Complete and Oracle-validated (9 actionable items applied, 2026-03-22 → 2026-04-27 refresh for engine config observer scope) |
| `plan.md` | ✅ Complete — Oracle iter 3: **9.4/10 APPROVED** |
| `todo.md` | ✅ Complete (derived from plan) |
| `depreciated.md` | Empty (no deprecated code yet) |
| `placeholder.md` | Empty (none yet) |

### Oracle Iterations (plan + todo)

| # | Score | Verdict |
|---|------:|---------|
| 1 | 7.2/10 | CONDITIONAL |
| 2 | 8.7/10 | CONDITIONAL |
| 3 | **9.4/10** | **APPROVED** |

---

## Branch + Wave

- **Branch:** `feat/video-audio-engine-routing`
- **Spike branch:** `spike/vaer-av-drift-measurement` (throwaway)
- **Wave:** S3-2 sequential (after S3-1 merges)
- **PR target:** PR #C
- **Predecessors:** S3-1A (`mainwindow-visualizer-isolation`) + S3-1B (`stream-pause-tail`) must merge first. spt may have changed `AudioEngineController.swift`; vaer rebase must handle.
- **Successors:** S3-3 (`hls-streaming-support`), S3-4 (`ogg-vorbis-support`)

---

## Key Plan Decisions

| # | Decision |
|---|----------|
| 1 | A/V sync strategy is a 4-step ladder with quantitative gates: NONE → `AVPlayer.masterClock` → pre-roll buffering → KILL SWITCH (>100ms drift). Phase 0 spike measures empirically; data picks strategy. |
| 2 | `supportsAudioProcessing` flag (single existing flag, not separate EQ/viz flags as research had assumed) gets a new `.video` branch. No new capability flags fabricated. |
| 3 | Engine configuration change observer included in this task (deferred from AirPlay PR #69). New `Audio/AudioEngineConfigurationObserver.swift` (~80 LOC) — debounced `AVAudioEngine.configurationChangeNotification` observer; triggers source-node reconnect when output route changes. |
| 4 | `MTAudioProcessingTap` C-convention callbacks via `Unmanaged<Context>` plumbing in new `Audio/VideoAudioTap.swift` (~250 LOC). |
| 5 | Mutual exclusion enforced across three engine paths (local/stream/video). |
| 6 | AudioPlayer wires `onEngineReconfigured` callbacks with explicit `currentSeekID` bumping + 100/200 ms guard release. Removed visualizer-tap-removal at audio→video switch. |
| 7 | Tap watchdog + fallback flag — if tap stops firing mid-playback, restore AVPlayer volume to user-set value, disable EQ/viz for that session, surface non-fatal error. |

---

## File Inventory

**New production files (2):**
- `Audio/VideoAudioTap.swift` (~250 LOC)
- `Audio/AudioEngineConfigurationObserver.swift` (~80 LOC)

**New test files (5):**
- `VideoAudioTapTests`
- `AudioEngineControllerVideoBridgeTests`
- `EngineConfigObserverTests`
- `AudioPlayerVideoCapabilityTests`
- `VideoTapFallbackTests`

**Modified (4):**
- `Audio/AudioEngineController.swift` (`videoSourceNode`, `activateVideoBridge` / `deactivateVideoBridge`, engine config observer wiring, mutual exclusion)
- `Audio/AudioPlayer.swift` (engine config callbacks, video bridge activation, tap watchdog + fallback flag, `isEngineRendering` + `snapshotButterchurnFrame` updates)
- `Audio/VideoPlaybackController.swift` (`loadVideo` accepts `audioTap`, new `detachAudioTap()`, unified teardown)
- `Audio/PlaybackCoordinator.swift` (three-branch `supportsAudioProcessing`, subscribes to `onEngineReconfigured` to refresh stream workgroup)
- `project.yml` (add new files)

---

## Next Steps (Phase 0 complete; implementation in progress)

1. ✅ Phase 0 spike: harness built, ran on 5-clip clipperboard corpus, Path NONE confirmed.
2. ✅ Findings written to `research.md` "Phase 0 — Spike Results"; spike branch deleted.
3. ✅ `feat/video-audio-engine-routing` cut from main.
4. ⏭ Re-read every "Files Affected" source listed in `plan.md` at HEAD to reconcile line-number drift. Known drift in `AudioPlayer.swift` (now 763 lines): see `_context/resume-prompt.md` "First Action" for the symbol-by-symbol map.
5. ⏭ Execute todo Phase 1 (engine config observer per plan §6).
6. ⏭ Phase 2 (MTAudioProcessingTap per plan §7) — note the spike's MinimalTap is gone with the spike branch; production wrapper is built fresh per plan §7.
7. ⏭ Phase 3 (engine source node + wiring per plan §8).
8. ⏭ **Skip Phase 4** (sync strategy) — Path NONE per Phase 0; mark todo §4.NONE done as the only Phase 4 item.
9. ⏭ Phase 5 (tap-failure watchdog + fallback per plan §10).
10. ⏭ Phase 6 (capability flag surface per plan §11).
11. ⏭ Phase 7 (tests + manual verification + drift target re-confirmation per plan §12 / §14).
12. ⏭ TSan-on builds + tests after each phase via xcodebuildmcp.
13. ⏭ Codex Oracle code-review gate (≥9/10) before pushing PR #C.
