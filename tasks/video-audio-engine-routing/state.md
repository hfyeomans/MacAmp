# State: Video Audio Engine Routing

> **Purpose:** Route AVPlayer video audio through AVAudioEngine via `MTAudioProcessingTap` so video gets EQ + visualization. Includes engine config change observer (deferred from AirPlay PR #69).
> **Created:** 2026-03-14
> **Sprint:** S3, Wave S3-2 (sequential after S3-1 merges)
> **Status:** PLAN APPROVED — ready for spike phase pending S3-1 merge

---

## Current Status

**Phase:** Plan complete, Oracle gate cleared. Implementation gated on Phase 0 A/V drift spike.
**Last Updated:** 2026-04-27.

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

## Next Steps (after S3-1 merges)

1. Re-read affected files at HEAD post-S3-1 merge; reconcile drift on `AudioEngineController.swift`.
2. Cut throwaway branch `spike/vaer-av-drift-measurement`.
3. Execute Phase 0 spike: 5-min runs per file, 5 video files (44.1k + 48k mp4/mov mixes).
4. Apply ladder rule:
   - < 30 ms across all 5 → ship without sync (Path NONE).
   - 30–100 ms → enable `AVPlayer.masterClock`; rerun (Path A).
   - Still 30–100 ms → enable pre-roll buffering; rerun (Path B).
   - Still > 100 ms → KILL SWITCH; cancel task and restore branch.
5. Write findings to `research.md` "Phase 0 — Spike Results"; delete spike branch.
6. Cut implementation branch `feat/video-audio-engine-routing`.
7. Execute Phase 1 (engine config observer) → Phase 7 (tests) per todo.md.
8. Run TSan-enabled tests via xcodebuildmcp.
9. Run Oracle code-review gate.
10. Open PR #C.
