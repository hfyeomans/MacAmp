# State: Video Audio Engine Routing

> **Purpose:** Route AVPlayer video audio through AVAudioEngine via `MTAudioProcessingTap` so video gets EQ + visualization. Includes engine config change observer (deferred from AirPlay PR #69).
> **Created:** 2026-03-14
> **Sprint:** S3, Wave S3-2 (sequential after S3-1 merges)
> **Status:** PHASE 0 ✅ + PHASE 1 ✅ + PHASE 2 ✅ + PHASE 3 ✅ COMPLETE — implementation in progress on `feat/video-audio-engine-routing`; Phase 5 (tap-failure watchdog) next (Phase 4 is no-op per Phase 0)

---

## Current Status

**Phase:** Phase 0 + 1 + 2 + 3 done. Phase 5 (tap-failure watchdog per plan §10) next; Phase 4 is a no-op per Phase 0 Path NONE.
**Last Updated:** 2026-04-30.
**Branch HEAD:** `1fa5aad`. 24 commits ahead of main (10 Phase-1 + 1 Phase-1 task-folder closeout + 1 Phase-1 SHA-cleanup + 5 Phase-2 + 1 Phase-2 closeout + 6 Phase-3 commits). SHAs may rotate on future rebases — match by commit message.
**Tests:** 90/90 pass with TSan (84 → 90: +4 video-bridge state-machine, +2 video-render-block).

### Phase 1 outcome (engine configuration change observer)

10 commits implementing plan §6 (engine config observer) plus three Oracle-driven follow-ups. The observer gracefully recovers the engine when the user switches output devices (Control Center, AirPlay, HDMI hot-plug, sleep/wake). Local-file and stream paths both verified.

**Commits in order (post-rebase SHAs; oldest → newest):**
- `f34c4a0` add `AudioEngineConfigurationObserver` (plan §6.1)
- `8de8009` re-entrancy guard + pairing-contract docs (Oracle pre-wiring review)
- `eea98de` wire observer into `AudioEngineController` (plan §6.2-§6.3)
- `985eceb` wire reconfigure handlers into `AudioPlayer` (plan §6.4)
- `2f5cdf9` AirPlay-resume fix: AudioPlayer overrides snapshot.currentTime / wasPlaying with its own state (manual-verification regression)
- `53fbba0` `PlaybackCoordinator` workgroup refresh on reconfigure (plan §6.4 last step)
- `2498ca8` `EngineConfigObserverTests` (plan §12.1)
- `c1cb925` cancel pending reconfigure on user-intent actions (Oracle item #2/#4/#7)
- `d735946` lifecycle interruption + start/stop cycle tests (Oracle item #5)
- `6e179d5` plan §6.3 doc update reflecting actual contract (Oracle item #8)
- `d34b882` task-folder state.md / todo.md closeout

**Manual verification result:** local-file + stream playback resume cleanly across local↔external speaker, AirPlay route changes (in/out, paused, mid-track), local↔stream↔local transitions. Observed CoreAudio HAL logs (`!obj`, `!dev`, `nope`) on AirPlay→built-in transitions are device-teardown chatter from the OS, not from MacAmp — see "Architectural notes" below.

### Architectural changes (notable shifts during Phase 1 implementation)

1. **AsyncSequence-based notification observation.** `AudioEngineConfigurationObserver` uses `NotificationCenter.notifications(named:object:)` instead of the older block-based `addObserver`. Establishes the modern Swift 6.2 pattern for notification observation in MacAmp; future similar work should follow it.

2. **Will/did pairing contract with split state ownership.** `PreReconfigureSnapshot` fields are NOT all authoritative:
    - `wasStreamBridge` / `wasVideoBridge`: MacAmp-owned, accurate at notification time.
    - `wasPlaying` / `currentTime`: best-effort placeholders — system stops the engine *before* posting the notification, so `playerNode.isPlaying` is false and `lastRenderTime` is nil. AudioPlayer overrides both with its own state in `handleEngineWillReconfigure` (commit `2f5cdf9`).
    - Documented in plan §6.3 (commit `6e179d5`). Phase 3 candidate refactor: narrow `PreReconfigureSnapshot` to bridge-flags-only.

3. **Reconfigure cancellation contract.** `AudioPlayer.cancelPendingReconfigure()` is called at the start of every user-intent entry point (`play`, `pause`, `stop`, `seek`, `playTrack`). It nils the pending snapshot AND clears `seekGuardActive` / `isHandlingCompletion` (which the will-handler armed and the did-handler is the only path that schedules to release). The early-returned did would otherwise leave both guards stuck on indefinitely. Prevents stale `onDid` from overriding new user intent in the ~150 ms gap between will and did. Documented in plan §6.3 (commit `6e179d5`).

4. **Modern Swift 6.2 idioms applied throughout new code:** `Notification.Name` (not `NSNotification.Name`), `Task.sleep(for: Duration)` (not `nanoseconds:`), `isolated deinit`, `@preconcurrency import AVFoundation` for unannotated frameworks (matching established MacAmp pattern in `StreamDecodePipeline`, `SkinManager`, `SkinArchiveLoader`).

### Phase 2 outcome (MTAudioProcessingTap wrapper)

5 commits (`14d47af` … `749b91d`) implementing plan §7. New file `MacAmpApp/Audio/VideoAudioTap.swift` (~340 LOC) with C-convention callbacks via `Unmanaged<VideoAudioTapContext>`, format-classification helpers, channel-mapping/downmix configuration, and 8 new unit tests. Oracle three-pass review converged at **9.3/10** (passes 1: 8.2 → 2: 8.4 → 3: 9.3).

**Commits in order (oldest → newest):**
- `14d47af` feat(audio): add VideoAudioTap with MTAudioProcessingTap callbacks (plan §7.1-§7.4)
- `48244f4` test(audio): add VideoAudioTap unit tests (plan §12.2 — partial; deeper paths deferred to Phase 7 manual)
- `09cb521` fix(audio): tighten format detection + channel mapping (Oracle pass-1: bypass predicate hardened, mono channel-map duplication, surround layout install)
- `b9a8478` fix(audio): surround downmix + AAC layouts + tests (Oracle pass-2: `kAudioConverterPropertyPerformDownmix=1`, capture source layout from format description, AAC tags fallback, +8 unit tests)
- `749b91d` fix(audio): clear stale channel layout on tap reattach (Oracle pass-3 defensive)

### Phase 2 architectural notes (modern Swift 6.2 idioms)

1. **Auto-managed `MTAudioProcessingTap` CFType** — Swift bridging now exposes the tap output of `MTAudioProcessingTapCreate` as `MTAudioProcessingTap?` directly (no `Unmanaged` boxing). The wrapper holds `var tap: MTAudioProcessingTap?`; ARC handles the +1 retain. `AVMutableAudioMixInputParameters` retains independently. `detach()` simply nils the wrapper's hold; `tapFinalize` fires when the last reference (typically the mix on AVPlayerItem) drops. Plan §7.3 specced manual `Unmanaged` lifecycle — that's no longer needed for the tap itself, only for the `VideoAudioTapContext` passed through `clientInfo`.

2. **Async `attach(to:)` signature** — uses `loadTracks(withMediaType:)` and `load(.formatDescriptions)` (the non-deprecated successors to `tracks(withMediaType:)` / `formatDescriptions`). Plan §7.3 specced sync; the modern Swift 6.2 alternatives are async, so the signature shifted. Phase 3 wires this into a `Task { ... }` after `AVPlayerItem.readyToPlay`.

3. **AudioConverter is load-bearing AND surround-aware** — Phase 0 surfaced sample-rate conversion as load-bearing. Phase 2 Oracle review surfaced two more landmines: `AudioConverter` defaults to channel ROUTING not MIXING on a channel-count change (mono → L+silent-R, 5.1 → drops 4 channels), and even with input/output layouts installed, `kAudioConverterPropertyPerformDownmix` defaults to 0 (no mixing). Both are now configured. Production reads the actual source layout from `CMAudioFormatDescriptionGetChannelLayout` when present, falls back to AAC-style tags by channel count when not.

4. **Testable format-classification helpers** — `shouldBypassConverter(source:expectedSampleRate:)` and `inferredSurroundChannelLayoutTag(forChannelCount:)` extracted as module-level functions and exercised by 8 unit tests. Pure functions reachable via `@testable import MacAmp` (no `@_spi` needed since the test target uses `@testable`).

### Phase 3 outcome (engine source node + wiring)

6 commits implementing plan §8 — `videoSourceNode` joins the engine graph alongside `streamSourceNode`, `AudioPlayer.playTrack` builds a per-track ring + tap and awaits the async attach before activating the bridge, and the AVPlayer's direct audio is muted (`volume = 0`) only after a successful tap install. Oracle two-pass review converged at **9.2/10 → 9.4/10** (cleared the ≥9/10 gate).

**Commits in order (oldest → newest):**
- `dcce548` feat(audio): add video bridge to AudioEngineController (plan §8.1, §8.2 — fields, render block, activate/deactivate, mutual exclusion, volume/balance forwarding, reconfigure refresh)
- `33d9e49` feat(audio): wire AudioPlayer video branch through engine bridge (plan §8.3, §8.4, §8.5, §3.5 — async loadVideo, detachAudioTap ordering, startVideoTrack Task, tearDownVideoBridge, isEngineRendering)
- `4aac795` test(audio): video bridge state machine + render block tests (6 tests covering mutual-exclusion contract and ring drain)
- `3fd4d26` fix(audio): guard video tap attach against player swaps mid-await (post-await `self.player === newPlayer` guard inside loadVideo; drop erroneous detachAudioTap from stale-track bail)
- `7e953bd` fix(audio): tap-identity stale check + cancellable load task (Oracle pass-1: same-URL replay race — switched URL equality → tap identity, stored Task in `videoLoadTask` cancelled by tearDownVideoBridge, gated reconfigure local-audio reschedule on `currentMediaType == .audio`)
- `1fa5aad` fix(audio): cancel video load + drop bridge in AudioPlayer deinit (Oracle pass-2: `tearDownVideoBridge()` runs BEFORE `engine.shutdown()` for cancellation + `audioMix=nil-before-detach` ordering symmetry)

### Phase 3 architectural notes (relevant to Phase 5+ implementers)

1. **Tap identity is the canonical session token, not URL.** Each `startVideoTrack` mints a fresh `VideoAudioTap`; `videoAudioTap === tap` inside the load Task body is the stale-check that survives same-URL replay. URL equality breaks down because replaying the same video produces two taps that are pointer-distinct but URL-identical. Phase 5 watchdog should follow the same pattern when comparing against the active tap.

2. **Async attach + post-await player-identity guard.** `VideoAudioTap.attach(to:)` suspends on `loadTracks(withMediaType:)` / `load(.formatDescriptions)`. While suspended, AudioPlayer can be re-entered (`stop`, `playTrack`, deinit). `VideoPlaybackController.loadVideo` checks `self.player === newPlayer` after the await and bails if a newer setup ran during the suspension — installing the resolved `audioMix` on the new playerItem would otherwise mutate state for a torpedoed session.

3. **Two-tier stale defence.** AudioPlayer's tap-identity check + VideoPlaybackController's player-identity check are independent and cooperating. Either alone leaves a window; together they cover stop-during-await, playTrack-different-URL-during-await, playTrack-same-URL-during-await (replay), and deinit-during-await.

4. **Cancellable load task.** `videoLoadTask: Task<Void, Never>?` is stored on AudioPlayer and cancelled by `tearDownVideoBridge()` (called from stop, playTrack switch, eject, AND isolated deinit). Cancellation is hygiene — the identity guards are load-bearing — but it makes the Task return promptly instead of waiting for asset loading to time out.

5. **Mutual-exclusion contract.** Three engine paths now coexist (`playerNode` / stream bridge / video bridge). `rewireForFile` drops both bridges; `activateStreamBridge` drops the video bridge first; `activateVideoBridge` drops the stream bridge first AND stops `playerNode` if running. AudioPlayer's `tearDownVideoBridge` plus `engine.deactivateVideoBridge` symmetry covers all teardown paths; stream-bridge teardown remains owned by `PlaybackCoordinator` / `StreamPlayer`.

6. **Reconfigure refresh.** `handleEngineDidReconfigure` now refreshes the video-bridge graph format on output route changes, parallel to the stream-bridge refresh. AVAudioEngine inserts an internal converter between the source node's declared rate (the tap's `expectedSampleRate`, fixed at attach time) and the new output rate; the source node itself stays as-is. AudioPlayer's `handleEngineDidReconfigure` local-audio reschedule branch is gated on `currentMediaType == .audio` so a tap-failed video session with stale `engine.audioFile` doesn't get reschedule mid-route-change.

### Phase 3 follow-ups (deferred — not blocking Phase 5)

| # | Item | Phase | Reason for deferral |
|---|------|-------|---------------------|
| 1 | Tap watchdog reads BOTH `lastCallbackHostTime` AND `fallbackRequested` | Phase 5 (plan §10.1) | Phase 5 work — tap is in place and exposes both signals; watchdog is the consumer. |
| 2 | `supportsAudioProcessing` capability flag dimming for tap-fallback path | Phase 6 (plan §11.2) | Out of Phase 3 scope; existing per-plan Phase 6 work covers it. |
| 3 | `snapshotButterchurnFrame` media-type guard relaxation for video bridge | Phase 6 (plan §11.3) | Phase 3 set `isEngineRendering` to include `engine.isVideoBridgeActive`, but `snapshotButterchurnFrame` still gates on `currentMediaType == .audio`. Phase 6 swaps the guard. |
| 4 | Volume `didSet` AVPlayer.volume forwarding gating | Phase 6 (plan §11.6) | Currently `videoPlaybackController.volume = volume` is unconditional. Phase 6 gates this on `videoTapFallbackActive` only (plan §11.6). For now the tap path mutes via `player.volume = 0` directly, overriding the didSet. |

### Phase 2 follow-ups (deferred — not blocking Phase 3)

| # | Item | Phase | Reason for deferral |
|---|------|-------|---------------------|
| 1 | Mono / 5.1 video file integration test (real playback verification) | Phase 7 manual (plan §12.7.4.2/3) | tapPrepare/tapProcess fire only inside Core Audio render-thread callbacks during real playback. Unit-testing the channel-mapping branch would require a heavy AVPlayer-driven integration harness; the plan accepts manual coverage here. |
| 2 | Watchdog reads BOTH `lastCallbackHostTime` AND `fallbackRequested` | Phase 5 (plan §10.1) | Phase 5 work — flagged here so the Phase 5 implementer doesn't miss the dual-signal design. The doc comment on `fallbackRequested` documents the contract. |
| 3 | Reuse-tap-across-attaches model | Phase 3 design choice | Phase 3 plan §3.4 creates a fresh tap per playback session, which avoids reuse entirely. Defensive `sourceChannelLayout = nil` reset already in place if Phase 3 ever changes the model. |

### Phase 1 follow-ups (deferred — not blocking Phase 2)

| # | Item | Phase | Reason for deferral |
|---|------|-------|---------------------|
| 1 | Narrow `PreReconfigureSnapshot` to MacAmp-owned bridge flags only | Phase 3 candidate | Refactor for clarity, not a correctness fix. Folds naturally into Phase 3 when `wasVideoBridge` becomes a real flag. |
| 2 | AudioPlayer-level test for user-intent-during-reconfigure | Integration suite | `pendingReconfigureSnapshot` is private; testing requires either visibility widening (`@testable` doesn't reach private) or a heavier integration harness. The observer-level tests in `d735946` cover the cancel pattern at the contract level. |
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

## Next Steps (Phase 0 ✅ + 1 ✅ + 2 ✅ complete; Phase 3 next)

1. ✅ Phase 0 spike: harness built, ran on 5-clip clipperboard corpus, Path NONE confirmed.
2. ✅ Findings written to `research.md` "Phase 0 — Spike Results"; spike branch deleted.
3. ✅ `feat/video-audio-engine-routing` cut from main.
4. ✅ Phase 1 (engine config observer) — 10 commits + closeout, 72/72 tests pass, manual verification clean across local-file + stream + AirPlay routing.
5. ✅ Phase 2 (MTAudioProcessingTap wrapper per plan §7) — 5 commits, Oracle 9.3/10, 84/84 tests pass with TSan. C-convention callbacks via `Unmanaged<VideoAudioTapContext>`, AudioConverter handles all four format-edge cases per plan §7.5 (mono duplication, surround downmix, non-Float32, sample-rate). Doesn't touch the engine graph — that's Phase 3.
6. ⏭ **Phase 3 (engine source node + wiring per plan §8)** — adds `videoSourceNode` parallel to `streamSourceNode` in `AudioEngineController`. Wires `activateVideoBridge`/`deactivateVideoBridge` with mutual exclusion against the stream bridge. Modifies `AudioPlayer.playTrack` video branch to instantiate `VideoAudioTap` + ring buffer, await `tap.attach(to:)`, assign `playerItem.audioMix`, set `player.volume = 0`. Modifies `VideoPlaybackController.loadVideo` to accept the tap (or have AudioPlayer wire it externally). Wires `wasVideoBridge` to a real flag in Phase 1's `PreReconfigureSnapshot`; the TODO comments at `AudioEngineController.handleEngineWillReconfigure`/`handleEngineDidReconfigure` get filled in here.
7. ⏭ **Skip Phase 4** (sync strategy) — Path NONE per Phase 0; todo §4.NONE already done.
8. ⏭ Phase 5 (tap-failure watchdog + fallback per plan §10) — watchdog must check BOTH `tap.lastCallbackHostTime` stall AND `tap.fallbackRequested` flag.
9. ⏭ Phase 6 (capability flag surface per plan §11) — three-branch `supportsAudioProcessing` (local/stream/video).
10. ⏭ Phase 7 (tests + manual verification + drift target re-confirmation per plan §12 / §14).
11. ⏭ TSan-on builds + tests after each phase via xcodebuildmcp.
12. ⏭ Codex Oracle code-review gate (≥9/10) before pushing PR #C.
