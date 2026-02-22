# State: Internet Streaming Volume Control

> **Purpose:** Tracks the current state of the task including progress, blockers, decisions made, and open questions.

---

## Current Status: PHASE 2 IMPLEMENTATION COMPLETE — Awaiting Manual Verification

## Progress

- [x] Task created with file structure
- [x] Codebase analysis completed
- [x] Documentation review completed
- [x] Gemini deep research completed (round 1: architecture + feasibility)
- [x] Research.md populated with findings
- [x] Oracle review of research (round 1, Grade: B+)
- [x] Gemini deep research (round 2: Swift 6.2+ capabilities)
- [x] Oracle review (round 2: independent web research, Swift 6.2/macOS 26)
- [x] Research.md updated with Swift 6.2 addendum + new approaches
- [x] Oracle review (round 3: MTAudioProcessingTap muting behavior)
- [x] Open questions resolved
- [x] Plan written (plan.md)
- [x] Todos written (todo.md)
- [x] Oracle review of plan + todos (corrections applied)
- [x] Ring buffer task created (tasks/lock-free-ring-buffer/)
- [x] Prerequisite validation complete (VisualizerPipeline SPSC refactor confirmed)
- [x] Oracle comprehensive validation (gpt-5.3-codex, xhigh reasoning, 2026-02-14)
- [x] Plan approved by user (2026-02-22, cross-task Wave 2 approval)
- [x] N1-N6 prerequisites resolved (PR #49 merged 2026-02-21)
- [x] Phase 1 Implementation (commit 463c6a9)
- [x] Oracle review of Phase 1 (gpt-5.3-codex, xhigh reasoning) — 1 finding fixed (stream error capability flags)
- [x] Phase 1 Manual Verification (V1.1-V1.11, passed — user confirmed 2026-02-22)
- [x] Phase 2 Prerequisites (2.0a-2.0d) — all resolved
- [x] Phase 2 Block 1: StreamPlayer MTAudioProcessingTap (2.2a-2.2h) — commit `4194086`
- [x] Phase 2 Block 2: AudioPlayer AVAudioSourceNode + Graph Switching (2.3, 2.4a-c) — commit `d47da07`
- [x] Phase 2 Block 3: PlaybackCoordinator Bridge Lifecycle (2.4c, 2.5) — commit `0ba7b1a`
- [x] Phase 2 Block 4: VisualizerView updates (2.6) — commit `0ba7b1a`
- [x] Phase 2 Block 5: ABR handling (2.7a-2.7d) — integrated into Block 1+2
- [x] Phase 2 Block 6: Telemetry (2.8a-2.8b) — already in LockFreeRingBuffer
- [x] Phase 2 Build + Oracle Review — commit `a5f96b3` (0 P1, 2 P2 fixed, 2 P3 fixed)
- [ ] Phase 2 Verification (V2.1-V2.14)

## Key Decisions

1. **Volume routing:** PlaybackCoordinator (Option B) — Oracle-recommended for clean separation of concerns
2. **Balance during streams:** Disable slider — no AVPlayer .pan property exists
3. **EQ during streams (Phase 1):** Grey out UI with visual indication — architectural limitation of AVPlayer
4. **EQ during streams (Phase 2):** Loopback Bridge architecture (Approach G) gives EQ via existing AVAudioUnitEQ
5. **Phased approach revised:** Phase 1 (volume + capability flags), Phase 2 (Loopback Bridge for full EQ+vis+balance), Phase 3 eliminated
6. **Feasibility recalibration (updated):** Tap-read **8.5/10** (prereq complete), Tap-write EQ 3-5/10, Loopback Bridge **6.0-7.0/10** (prereq complete)
7. **CoreAudio process taps:** Not recommended (entitlement requirements, App Store risk)
8. **Swift 6.2 features:** nonisolated(unsafe) + ~Copyable useful now; InlineArray/Span macOS 26+ only
9. **Double-render prevention:** Zero bufferListInOut in PreEffects tap callback after copying to ring buffer (Oracle-verified, most deterministic approach)
10. **Ring buffer size:** 4096 frames (~85ms @ 48kHz) initial, tunable after stability proven
11. **Ring buffer prototyping:** Separate task recommended — self-contained, highest-risk component, independently testable
12. **Target platforms:** macOS 15+ including macOS 26+ Tahoe

## Phase 2 Commits

1. `4194086` — feat: MTAudioProcessingTap loopback tap on StreamPlayer (T5 Ph2 Block 1)
   - LoopbackTapContext (@unchecked Sendable), 5 top-level @convention(c) callbacks
   - attachLoopbackTap/detachLoopbackTap on StreamPlayer
   - Mono→stereo upmixing, non-interleaved→interleaved conversion
   - Pre-allocated scratch buffers, generation ID ABR handling

2. `d47da07` — feat: AVAudioSourceNode stream bridge + engine graph switching (T5 Ph2 Block 2)
   - streamSourceNode, makeStreamRenderBlock (nonisolated static), activateStreamBridge/deactivateStreamBridge
   - Engine stop/reset/rewire pattern (lesson: hot-swap crashes)
   - isBridgeActive, isEngineRendering computed properties
   - Volume/balance didSet propagation to streamSourceNode

3. `0ba7b1a` — feat: PlaybackCoordinator bridge lifecycle + VisualizerView engine rendering (T5 Ph2 Block 3+4)
   - setupLoopbackBridge/teardownLoopbackBridge/attachBridgeTap on PlaybackCoordinator
   - Bridge lifecycle in all stream play methods (always teardown before setup)
   - Capability flags: !isStreamBackendActive || audioPlayer.isBridgeActive
   - VisualizerView: 4 sites isPlaying → isEngineRendering

4. `a5f96b3` — fix: Oracle review fixes for loopback bridge (T5 Ph2)
   - P2: Ring buffer identity gate in onFormatReady callback
   - P2: Revalidate currentItem after async loadTracks
   - P3: Interleaved fast path limited to channels == 2
   - P3: Explicit isSilence reset on successful read

## Phase 1 Commits

1. `463c6a9` — feat: Stream volume control + capability flags (T5 Phase 1)
   - StreamPlayer volume/balance properties, PlaybackCoordinator routing, capability flags
   - UI dimming for EQ and balance during stream playback
   - Oracle fix: stream error recovery for capability flags

## Oracle Review (Phase 1)

**Reviewer:** gpt-5.3-codex (xhigh reasoning), 2026-02-22

### Finding (Fixed)
- **P2 — Stream error capability flag regression:** `isStreamBackendActive` only checked `currentSource`, not stream error state. After a stream error, EQ/balance controls stayed dimmed. Fixed: check `streamPlayer.error == nil` — error state re-enables controls.

### Verified Correct
- Thread safety: all mutations on @MainActor
- Volume routing: unconditional fan-out to all backends
- Startup sync: init sync + pre-play apply (belt-and-suspenders)
- No local file regression: playerNode.volume/pan paths unchanged
- Binding pattern: asymmetric Binding(get:set:) is correct for coordinator routing

## Oracle Review (Phase 2)

**Reviewer:** gpt-5.3-codex (xhigh reasoning), 2026-02-22

### Findings (All Fixed — commit a5f96b3)
- **P2-1** `onFormatReady` callback race — stale stream A callback could target stream B's ring buffer. Fixed: gate with `rb === ringBuffer` identity check.
- **P2-2** `attachLoopbackTap()` doesn't revalidate `currentItem` after `await loadTracks`. Fixed: verify `player.currentItem === currentItem` after await.
- **P3-1** Interleaved fast path accepted `channels >= 2`, incorrect for >2 channel input. Fixed: `channels == 2`.
- **P3-2** Source node render block never explicitly reset `isSilence` to false. Fixed: `isSilence.pointee = ObjCBool(framesRead == 0)`.

### Verified Correct
- Thread isolation: top-level tap callbacks avoid @MainActor capture; render block from nonisolated static func
- RT-safe hot paths: no locks/logging/tasks in process/render; ring buffer uses atomics + memcpy
- Bridge teardown/setup ordering in all stream entry points
- Producer quiescing before bridge disposal (detach tap → deactivate bridge)
- Format pipeline: stereo interleaved ring buffer → interleaved source node → non-interleaved graph
- Engine rewiring: stop/reset + mixer-output verification
- Capability flags available when bridge active
- Unmanaged lifetime balance correct (passRetained/release in happy + failure paths)
- ABR generation handling wired end-to-end (prepare/unprepare flush + render silence on mismatch)

## Blockers

### Active Blockers

- **N1-N6 Internet Radio Issues (BLOCKING):** Oracle validation (`tasks/internet-radio-review/findings.md`) found 6 issues in the current streaming infrastructure. Phase 1 cannot proceed until at least N1 (HIGH), N2 (MEDIUM), and N5 (MEDIUM) are fixed.
  - **N1 (HIGH):** Playlist navigation broken during stream playback — `currentTrack` is nil during streams, causing next/previous to always jump to index 0
  - **N2 (MEDIUM):** PlayPause indicator desync — coordinator flags not synced with StreamPlayer's KVO-driven state changes
  - **N5 (MEDIUM):** Main window transport indicators bound to AudioPlayer instead of PlaybackCoordinator — shows wrong state during stream playback
  - **N3 (LOW):** externalPlaybackHandler naming confusion — no functional impact, defer
  - **N4 (LOW):** StreamPlayer metadata overwrite — cosmetic, coordinator fallback covers it
  - **N6 (LOW):** Track Info dialog missing live ICY metadata — uses static title instead of displayTitle

### Architectural Blockers (Unchanged)

- AVPlayer cannot feed AVAudioEngine directly (no bridge API in macOS 15 or 26)
- AVPlayer has no .pan property (balance not possible without Loopback Bridge)
- ~~VisualizerPipeline allocates in callback path~~ **RESOLVED** — SPSC shared buffer pattern implemented (VisualizerSharedBuffer + pre-allocated VisualizerScratchBuffers + static makeTapHandler). Zero allocations on audio thread confirmed.
- MTAudioProcessingTap types are non-Sendable in Swift 6 strict mode

## Loopback Bridge Architecture (Confirmed)

Both Gemini and Oracle independently converged on this approach:
```
AVPlayer → MTAudioProcessingTap (PreEffects, zero output) → Ring Buffer → AVAudioSourceNode → AVAudioEngine (EQ + Viz + Balance)
```

## Resolved Questions

1. **Muting approach:** Zero bufferListInOut in tap callback (not player.volume or player.isMuted) — per Apple QA1783, PreEffects tap runs before mix effects; zeroing output is deterministic
2. **Ring buffer size:** 4096 frames (~85ms) — acceptable latency for radio, margin for ABR switches
3. **Ring buffer task:** Yes, create separate `lock-free-ring-buffer` task for prototyping
4. **macOS targets:** macOS 15+ including macOS 26+ Tahoe — InlineArray/Span behind @available guards

## Phase 2 Implementation Notes

**Branch:** `feature/stream-loopback-bridge`
**Lessons learned:** `tasks/_context/claude-mistakes-stream-loopback-bridge.md` — documents all crashes and corrections from failed first attempt. Must be consulted for every implementation decision.

### Key Corrections from Lessons Learned (Applied to Plan)

1. **2.4a hot-swap approach crashed** — Plan says "WITHOUT engine restart" but this caused error -10868. Corrected: follow `rewireForCurrentFile()` stop/reset pattern. Brief silence acceptable for radio.
2. **Render block @MainActor isolation** — Must use `nonisolated private static func makeStreamRenderBlock()` pattern, NOT inline closures. Crash: EXC_BREAKPOINT on audio thread.
3. **Source node format** — Must use interleaved block format matching ring buffer. Non-interleaved "standard" format caused silent audio.
4. **Mixer→output connection** — Must verify after `audioEngine.reset()`. Connection may break silently.
5. **Stream→stream ordering** — Must ALWAYS teardown bridge before setup. Ring buffer flush requires producer quiescence.

## Created Tasks

- `lock-free-ring-buffer` — CREATED with full file structure (research.md, plan.md, state.md, todo.md, depreciated.md, placeholder.md). Research populated from parent task findings.
