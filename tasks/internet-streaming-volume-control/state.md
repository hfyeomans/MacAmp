# State: Internet Streaming Volume Control

> **Purpose:** Tracks the current state of the task including progress, blockers, decisions made, and open questions.

---

## Current Status: PLAN + TODOS COMPLETE — ORACLE REVIEWED — PREREQUISITE VALIDATED

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
- [ ] Plan approved by user
- [ ] Implementation
- [ ] Verification

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

## Blockers

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

## Created Tasks

- `lock-free-ring-buffer` — CREATED with full file structure (research.md, plan.md, state.md, todo.md, depreciated.md, placeholder.md). Research populated from parent task findings.
