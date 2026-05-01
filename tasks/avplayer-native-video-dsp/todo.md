# Todo: AVPlayer-Native Video DSP

> **Plan:** `tasks/avplayer-native-video-dsp/plan.md`
> **Branch:** `feat/avplayer-native-video-dsp`
> **Status:** 📋 SKELETON — todo derives from plan; plan derives from research. Do NOT execute from this skeleton.

Numbering convention: `<Phase>.<Item>`. Mark `[x]` on completion. Use `[~]` for in-progress, `[!]` for blocked.

---

## Step 1 — Mechanical pivot ✅ COMPLETE

- [x] 1.1 Push `feat/video-audio-engine-routing` to origin as backup (preserved-as-reference)
- [x] 1.2 Cut `feat/avplayer-native-video-dsp` from `main`
- [x] 1.3 Cherry-pick 13 Phase 1 commits (`3ed4356` → `2aa2f18`)
- [x] 1.4 Drop `wasVideoBridge` field from `PreReconfigureSnapshot` (commit `ffd77c1`)
- [x] 1.5 Build + TSan green (72/72)
- [x] 1.6 Scaffold `tasks/avplayer-native-video-dsp/` with 6 canonical files
- [x] 1.7 Create `tasks/_context/s3-2-pivot.md` three-step tracker
- [x] 1.8 Cross-reference pivot tracker from `_context/state.md`, `tasks_index.md`, `resume-prompt.md`
- [x] 1.9 Mark old branch + old task PAUSED

## Step 2 — Research phase ⏭ NEXT

- [ ] 2.1 Phase 0 spike — `MTAudioProcessingTap` in-place buffer modification feasibility (throwaway branch)
- [ ] 2.2 Apple docs review — TN2249, `AVMutableAudioMix`, `MTAudioProcessingTap` SDK header, `AVAudioUnitEQ` reference, WWDC archive
- [ ] 2.3 Reference-branch retrospective — read `feat/video-audio-engine-routing` end-to-end, catalog reusable patterns
- [ ] 2.4 `AVAudioUnitEQ` numerical-match research — frequency-response curves, Q values, gain shape
- [ ] 2.5 Render-thread CPU budget measurement (Apple Silicon + Intel)
- [ ] 2.6 Channel-count / sample-rate handling investigation
- [ ] 2.7 `VisualizerFeed` extraction approach — read existing `VisualizerPipeline` consumer
- [ ] 2.8 Findings written to `research.md`; Oracle research-pass review

## Step 3 — Plan phase ⏭ AFTER STEP 2

- [ ] 3.1 Write `plan.md` from research
- [ ] 3.2 Iterate with Oracle until ≥9/10 APPROVED
- [ ] 3.3 Get user sign-off
- [ ] 3.4 Derive concrete `todo.md` phases from plan
- [ ] 3.5 Begin implementation phases

---

## Implementation phases (placeholder — populated from plan in Step 3)

Will likely take the shape of:

- **Phase 0 spike** — already done in Step 2; recap in this doc once research closes
- **Phase 1** — `BiquadCascade` DSP module + numerical-equivalence tests vs `AVAudioUnitEQ`
- **Phase 2** — `VisualizerFeed` extraction (engine path keeps working)
- **Phase 3** — process-in-place `VideoAudioProcessingTap` (different topology than the saved branch's `VideoAudioTap`)
- **Phase 4** — `AudioPlayer` rewiring for video path
- **Phase 5** — capability-flag simplification (video becomes always-supported, no conditional dimming)
- **Phase 6** — manual verification on real hardware: BT/AirPods route changes, 10+ min playback, all sample rates / channel counts, EQ slider drag while playing, balance, Milkdrop activity, spectrum analyzer
- **Phase 7** — drift retest against Phase 0 corpus, Oracle pre-PR gate, PR #C
