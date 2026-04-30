# State: Video Audio Engine Routing

> **Purpose:** Route AVPlayer video audio through AVAudioEngine via `MTAudioProcessingTap` so video gets EQ + visualization. Includes engine config change observer (deferred from AirPlay PR #69).
> **Created:** 2026-03-14
> **Sprint:** S3, Wave S3-2 (sequential after S3-1 merges)
> **Status:** PHASE 0 ✅ + PHASE 1 ✅ COMPLETE — implementation in progress on `feat/video-audio-engine-routing`; Phase 2 (MTAudioProcessingTap wrapper) next

---

## Current Status

**Phase:** Phase 0 ✅ + Phase 1 ✅ done. Phase 2 (MTAudioProcessingTap implementation per plan §7) next.
**Last Updated:** 2026-04-30.
**Branch HEAD:** `e7f8eed` (10 commits ahead of main).
**Tests:** 72/72 pass with TSan.

### Phase 1 outcome (engine configuration change observer)

10 commits implementing plan §6 (engine config observer) plus three Oracle-driven follow-ups. The observer gracefully recovers the engine when the user switches output devices (Control Center, AirPlay, HDMI hot-plug, sleep/wake). Local-file and stream paths both verified.

**Commits in order:**
- `d5081e9` add `AudioEngineConfigurationObserver` (plan §6.1)
- `c454c49` re-entrancy guard + pairing-contract docs (Oracle pre-wiring review)
- `63dda27` wire observer into `AudioEngineController` (plan §6.2-§6.3)
- `d95cccf` wire reconfigure handlers into `AudioPlayer` (plan §6.4)
- `3267091` AirPlay-resume fix: AudioPlayer overrides snapshot.currentTime / wasPlaying with its own state (manual-verification regression)
- `ce7e889` `PlaybackCoordinator` workgroup refresh on reconfigure (plan §6.4 last step)
- `694666c` `EngineConfigObserverTests` (plan §12.1)
- `fabe5e2` cancel pending reconfigure on user-intent actions (Oracle item #2/#4/#7)
- `1052331` lifecycle interruption + start/stop cycle tests (Oracle item #5)
- `e7f8eed` plan §6.3 doc update reflecting actual contract (Oracle item #8)

**Manual verification result:** local-file + stream playback resume cleanly across local↔external speaker, AirPlay route changes (in/out, paused, mid-track), local↔stream↔local transitions. Observed CoreAudio HAL logs (`!obj`, `!dev`, `nope`) on AirPlay→built-in transitions are device-teardown chatter from the OS, not from MacAmp — see "Architectural notes" below.

### Architectural changes (notable shifts during Phase 1 implementation)

1. **AsyncSequence-based notification observation.** `AudioEngineConfigurationObserver` uses `NotificationCenter.notifications(named:object:)` instead of the older block-based `addObserver`. Establishes the modern Swift 6.2 pattern for notification observation in MacAmp; future similar work should follow it.

2. **Will/did pairing contract with split state ownership.** `PreReconfigureSnapshot` fields are NOT all authoritative:
    - `wasStreamBridge` / `wasVideoBridge`: MacAmp-owned, accurate at notification time.
    - `wasPlaying` / `currentTime`: best-effort placeholders — system stops the engine *before* posting the notification, so `playerNode.isPlaying` is false and `lastRenderTime` is nil. AudioPlayer overrides both with its own state in `handleEngineWillReconfigure` (commit `3267091`).
    - Documented in plan §6.3 (commit `e7f8eed`). Phase 3 candidate refactor: narrow `PreReconfigureSnapshot` to bridge-flags-only.

3. **Reconfigure cancellation contract.** `AudioPlayer.cancelPendingReconfigure()` is called at the start of every user-intent entry point (`play`, `pause`, `stop`, `seek`, `playTrack`). The existing did-handler early-return on nil snapshot is the cancel hook. Prevents stale `onDid` from overriding new user intent in the ~150 ms gap between will and did. Documented in plan §6.3 (commit `e7f8eed`).

4. **Modern Swift 6.2 idioms applied throughout new code:** `Notification.Name` (not `NSNotification.Name`), `Task.sleep(for: Duration)` (not `nanoseconds:`), `isolated deinit`, `@preconcurrency import AVFoundation` for unannotated frameworks (matching established MacAmp pattern in `StreamDecodePipeline`, `SkinManager`, `SkinArchiveLoader`).

### Phase 1 follow-ups (deferred — not blocking Phase 2)

| # | Item | Phase | Reason for deferral |
|---|------|-------|---------------------|
| 1 | Narrow `PreReconfigureSnapshot` to MacAmp-owned bridge flags only | Phase 3 candidate | Refactor for clarity, not a correctness fix. Folds naturally into Phase 3 when `wasVideoBridge` becomes a real flag. |
| 2 | AudioPlayer-level test for user-intent-during-reconfigure | Integration suite | `pendingReconfigureSnapshot` is private; testing requires either visibility widening (`@testable` doesn't reach private) or a heavier integration harness. The observer-level test in `1052331` covers the cancel pattern at the contract level. |
| 3 | `supportsAudioProcessing` capability-flag dimming for video tap-fallback | Phase 6 (already in plan §11.2) | Out of Phase 1 scope; the existing per-plan Phase 6 work covers it. |

### Phase 0 outcome (spike findings — full detail in `research.md`)

- **Decision:** Path NONE per plan §5.4 — frequency-locked clocks confirmed; no sync code needed.
- **Slope across 5 files:** mean -0.75 ms/sec, 95% CI [-6.4, +4.9] ms/sec — statistically zero.
- **Constant -200 ms phase offset:** AVPlayer pipeline depth (decoded-time vs presentation-time per Gemini synthesis), not perceptible drift. Empirically defer to plan §5.3 perception test during implementation.
- **Plan §9 Phase 4 collapses to no-op** (todo §4.NONE only).
- **Plan §7.5 AudioConverter is load-bearing**, not optional — without it, 44.1 kHz audio plays as discontinuous bursts every ~76 ms.
- **Spike branch:** `spike/vaer-av-drift-measurement` deleted (4 commits, never pushed) per §5.5. Findings committed on main as `1d4eca1`.

### CoreAudio HAL log observation (informational; not actionable)

When switching output device FROM AirPlay TO built-in speakers, CoreAudio emits a burst of HAL-level errors (`!obj` `kAudioHardwareBadObjectError`, `!dev` `kAudioHardwareBadDeviceError`, `'nope'` HAL-internal). These are OS-level device-teardown messages — internal CoreAudio listeners briefly hold stale references to the just-removed AirPlay device while the device graph stabilizes around built-in output. Apple's own apps emit identical chatter on the same transitions. They appear BEFORE `AVAudioEngineConfigurationChange` fires; our observer wakes up after HAL has settled. Not caused by MacAmp; not fixable from MacAmp; not affecting playback. Documented for future readers who might investigate similar logs.

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

## Next Steps (Phase 0 ✅ + Phase 1 ✅ complete; Phase 2 next)

1. ✅ Phase 0 spike: harness built, ran on 5-clip clipperboard corpus, Path NONE confirmed.
2. ✅ Findings written to `research.md` "Phase 0 — Spike Results"; spike branch deleted.
3. ✅ `feat/video-audio-engine-routing` cut from main.
4. ✅ Phase 1 (engine config observer) — 10 commits, 72/72 tests pass, manual verification clean across local-file + stream + AirPlay routing.
5. ⏭ **Phase 2 (MTAudioProcessingTap wrapper per plan §7)** — `MacAmpApp/Audio/VideoAudioTap.swift` (~250 LOC). Build the production-grade tap: C-convention callbacks, `Unmanaged<Context>` plumbing, ring-buffer producer, **AudioConverter for source-rate mismatches** (Phase 0 surfaced this as load-bearing, not optional). Doesn't touch the engine graph — that's Phase 3.
6. ⏭ Phase 3 (engine source node + wiring per plan §8) — adds `videoSourceNode` parallel to `streamSourceNode`. Wires `wasVideoBridge` to a real flag in the engine; Phase 1's TODO comments at `AudioEngineController.swift` `handleEngineWillReconfigure` / `handleEngineDidReconfigure` get filled in here.
7. ⏭ **Skip Phase 4** (sync strategy) — Path NONE per Phase 0; mark todo §4.NONE done as the only Phase 4 item.
8. ⏭ Phase 5 (tap-failure watchdog + fallback per plan §10).
9. ⏭ Phase 6 (capability flag surface per plan §11).
10. ⏭ Phase 7 (tests + manual verification + drift target re-confirmation per plan §12 / §14).
11. ⏭ TSan-on builds + tests after each phase via xcodebuildmcp.
12. ⏭ Codex Oracle code-review gate (≥9/10) before pushing PR #C.
