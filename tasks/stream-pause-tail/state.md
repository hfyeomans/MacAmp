# State: Stream Pause Tail

> **Purpose:** Fix ~0.7s audio tail that plays after pausing an internet radio stream + latent reconnect-during-pause bug.
> **Created:** 2026-03-14
> **Sprint:** S3, Wave S3-1 Worktree B (parallel with `mainwindow-visualizer-isolation`)
> **Status:** IMPLEMENTATION COMPLETE — PR #82 open, awaiting review.

---

## Current Status

**Phase:** PR review.
**Last Updated:** 2026-04-30.
**Branch:** `fix/stream-pause-tail`
**PR:** [#82](https://github.com/hfyeomans/MacAmp/pull/82)
**Tests:** 68/68 pass with TSan (was 59 baseline; +8 new + 1 ring-buffer regression).

### Artifacts
| File | Status |
|------|--------|
| `research.md` | ✅ Complete (Oracle 8/8 applied, 2026-04-27) |
| `plan.md` | ✅ Complete — Oracle iter 5: **9.1/10 APPROVED** |
| `todo.md` | ✅ Implemented end-to-end |
| `depreciated.md` | ✅ Records dead code removed during impl |
| `placeholder.md` | Empty (no stubs left behind) |

### Plan-phase Oracle iterations
| # | Score | Verdict |
|---|------:|---------|
| 1 | 7.8/10 | CONDITIONAL |
| 2 | 8.6/10 | CONDITIONAL |
| 3 | 8.9/10 | CONDITIONAL |
| 4 | 8.4/10 | CONDITIONAL |
| 5 | **9.1/10** | **APPROVED** |

### Implementation-phase review trail (Codex Oracle + parallel code-reviewer agent)
| # | Score | Major finding | Resolution |
|---|------:|---------------|-----------|
| impl-1 | 7.2/10 | Critical: warmup short-circuit on stale pre-pause PCM (race vs `pauseByUser` flush) | Moved `startResumeWarmup()` AFTER `resumeByUser()` await; added `userPaused` re-check inside chained body |
| impl-2 | 8.2/10 | High: `pipelineTransportTask?.cancel()` only cancels chain tail; earlier tasks still run after session reset | Added `transportGeneration`; `chainTransport` captures it and bails after `await prior?.value` if it changed |
| impl-3 | 8.4/10 | High: warmup timeout fallback didn't tear down bridge before `pipeline.start` | Added `onStreamTerminated?()` in fallback before `pipeline.start` |
| impl-4 | 8.6/10 | High: `resume()` else-if-station branch fired `pipeline.start` for `.playing`/`.connecting`/`.buffering` (would re-bind engine to fresh ring without bridge teardown) | Switched on `pipeline.state`: `.idle`/`.error` → live-edge restart; `.connecting`/`.buffering`/`.playing` → no-op + drop gate |
| impl-5 | 8.4/10 | High: duplicate `resume()` during warmup cancels warmup but never drops the gate (silence forever) | `.connecting`/`.buffering`/`.playing` branch now drops the gate; healthy warmup completion fires `onStreamStateChanged` |
| impl-6 | 7.0/10 | High: `clearQueue()` doesn't reset converter (decoder state stale across pause discontinuity); Medium: `resume()` leaks `isBuffering=true` when no station | `AudioConverterReset(converter)` before freeing input buffer; no-station branches now clear `isBuffering` + fire `onStreamStateChanged` |
| impl-7 | 8.4/10 | Medium: 30 ms `Task.sleep` heuristic fails on AirPlay/HDMI (~93 ms quantum); plus parallel agent caught Critical deinit leak (`resumeWarmupTask`/`pipelineTransportTask` not cancelled) | Replaced sleep with structural seqlock + CAS in `LockFreeRingBuffer`; deinit cancels warmup + transport tasks; tests use deterministic `drainTransportChainForTesting()` instead of `Task.yield()` loops |
| impl-8 | 7.0/10 | High: seqlock post-check + unconditional increment leaves a window between check and CAS-less commit | Replaced `wrappingIncrementThenLoad` with `compareExchange(expected: rh, desired: rh + N)`; added DEBUG seam + deterministic regression test |
| impl-9 | **9/10** | **APPROVED** | Comments cleaned up |

---

## Branch + Wave

- **Branch:** `fix/stream-pause-tail`
- **Wave:** S3-1 Worktree B (parallel start with mwvi Worktree A; sequential merge B-after-A)
- **PR:** #82
- **Predecessors:** none
- **Successors:** `video-audio-engine-routing` (S3-2), `hls-streaming-support` (S3-3), `ogg-vorbis-support` (S3-4) — all gated on this merge.

---

## Decisions (resolved)

| # | Question | Decision |
|---|----------|----------|
| OQ1 | `setStreamSilenced` wiring | Forwarder via `AudioPlayer` + closure on `StreamPlayer` assigned at `PlaybackCoordinator.init`. |
| OQ3 | Live-edge vs paused-snapshot on resume after long pause | Best-effort first; live-edge fallback after 1s prebuffer timeout. |

ADRs SPT-1 through SPT-8 enumerated in `plan.md` §4.

---

## Manual smoke-test results (2026-04-30)

All 7 plan §V scenarios confirmed on real SomaFM stream:
- ✅ Pause-tail < 25 ms (subjectively instant; was ~0.7 s)
- ✅ Resume in <500 ms with no clicks/pops
- ✅ Pause + Wi-Fi off 30s + Wi-Fi on + Resume → title stays on station name throughout pause; "Connecting…" appears only on the actual reconnect after Resume
- ✅ Rapid pause/resume spam → UI responsive, no stuck state
- ✅ Local file pause regression check (sample-accurate, unchanged)
- ✅ Multi-rate streams
- ✅ EQ + visualizer interactions correct

---

## Deferred follow-ups

Tracked in `tasks/_context/state.md` (Sprint S3 follow-ups section):

1. **`StreamDecodePipeline.stop()` `.userStopped` lacks generation guard.** Benign double-fire only when `wasActivelyPlaying=false` already cleared by callers. Low priority.
2. **`AudioConverterDecoder.clearQueue()` `assertConfinement()` is debug-only.** Release builds would silently corrupt memory if a future caller invokes it off-queue. Doc-gap, not a present bug.

---

## Next steps

1. Address any reviewer feedback on PR #82.
2. Merge.
3. Post-merge close-out per resume-prompt.md template (move task to `tasks/done/`, update `_context/state.md` + `tasks_index.md` + `resume-prompt.md`, single `chore:` commit).
