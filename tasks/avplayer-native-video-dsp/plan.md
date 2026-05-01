# Plan: AVPlayer-Native Video DSP

> **Task:** `tasks/avplayer-native-video-dsp/`
> **Status:** 📋 SKELETON — placeholder. Plan is written in Step 3, AFTER Step 2 research lands. Do NOT implement from this skeleton.
> **Step gate:** Plan must clear Oracle ≥9/10 before any implementation phase begins (project convention for S3 tasks).

---

## Why this is a skeleton

Per project workflow:
1. Research informs plan (Step 2 → Step 3)
2. Plan iterates with Oracle until ≥9/10 ("APPROVED")
3. Only then does `todo.md` derive from plan and implementation begin

Writing an implementation plan before research validates the architecture's load-bearing assumptions would commit us to an approach that may not survive Phase 0 spike. See `research.md` Q1 — if `MTAudioProcessingTap` doesn't actually support in-place buffer modification, the entire architecture pivots.

---

## What plan.md WILL contain (when written)

Standard S3 plan structure:

1. **Goal** — one-paragraph problem statement, success criteria
2. **Non-goals** — what we're explicitly NOT changing (audio path, streams, visualizer logic, etc.)
3. **Architecture** — data flow diagrams for both pipelines (engine + tap)
4. **Phase decomposition** — typical: Phase 0 spike (already done in Step 2) → Phase 1 `BiquadCascade` DSP module → Phase 2 `VisualizerFeed` extraction → Phase 3 process-in-place tap → Phase 4 AudioPlayer rewiring → Phase 5 strip engine-routing video infrastructure (none on this branch, so this phase may be N/A) → Phase 6 manual verification + drift retest
5. **File-by-file change list** with line-count estimates
6. **ADR (Principle 7)** — what problem it solves, what trade-offs, when to abandon. Including the explicit decision to keep EQ math WET across two implementations (Principle 4 Rule of Three exception for safety/threading boundary).
7. **Risk register** — `MTAudioProcessingTap` in-place feasibility (validated by spike), `AVAudioUnitEQ` numerical match, render-thread CPU, channel-count handling
8. **Test plan** — `BiquadCascade` numerical-equivalence tests, `VisualizerFeed` unit tests, end-to-end manual verification on real hardware (BT/AirPods route changes, 10+ min playback, all sample rates / channel counts)
9. **Oracle iteration log** — score history until ≥9/10
10. **Stop criteria** — kill switches, when to abandon vs persist

---

## Reference: prior task's plan structure

`tasks/video-audio-engine-routing/plan.md` is the template for what S3-2 plans look like — 14 sections, Oracle iterations, ADRs. New plan follows the same shape but for the AVPlayer-native architecture.
