# State: HLS Streaming Support

> **Purpose:** Add audio-only HLS protocol support (M3U8 + AAC ADTS, master/media playlists, live + VOD) to the unified audio pipeline.
> **Created:** 2026-03-14
> **Sprint:** S3, Wave S3-3 (sequential after S3-2 merges)
> **Status:** PLAN APPROVED — ready for implementation pending S3-1 + S3-2 merges

---

## Current Status

**Phase:** Plan complete, Oracle gate cleared.
**Last Updated:** 2026-04-27.

### Artifacts

| File | Status |
|------|--------|
| `research.md` | ✅ Complete (Oracle 7/10 → 8/8 actionable items applied, 2026-04-27) |
| `plan.md` | ✅ Complete — Oracle iter 4: **9.0/10 APPROVED** (1273 lines) |
| `todo.md` | ✅ Complete (175 lines, derived from plan) |
| `depreciated.md` | Empty (no deprecated code yet) |
| `placeholder.md` | Empty (none yet) |

### Oracle Iterations (plan + todo)

| # | Score | Verdict |
|---|------:|---------|
| 1 | 7.0/10 | CONDITIONAL |
| 2 | 8.0/10 | CONDITIONAL |
| 3 | 8.0/10 | CONDITIONAL |
| 4 | **9.0/10** | **APPROVED** |

16 actionable findings + 11 nitpicks applied across 4 rounds. 1 nitpick rejected (project convention `depreciated.md`). 2 OGG-side nitpicks deferred to OGG plan author.

---

## Branch + Wave

- **Branch:** `feat/hls-streaming-support`
- **Spike:** none
- **Wave:** S3-3 sequential (after S3-2 merges)
- **PR target:** PR #D
- **Predecessors:** S3-1 (`stream-pause-tail`) and S3-2 (`video-audio-engine-routing`) must merge first.
- **Successors:** `ogg-vorbis-support` (S3-4) — must rebase its plan against post-HLS HEAD; HLS plan §17.1 includes a detailed OGG rebase checklist.

**Pre-flight (PF.1 – PF.5 in todo):** re-read every `Files Affected` source at HEAD post-merge; reconcile any line-number drift before Phase 1.

---

## Key Plan Decisions

| # | Decision |
|---|----------|
| 1 | v1 scope locked: AAC ADTS only; master + media playlists; live + VOD. NO TS/fMP4/LL-HLS/ABR/DRM/HLS-video. |
| 2 | Integration: **Option A** — new `HLSSegmentFeeder` feeds bytes into existing `DecodeContext.handleIncomingData` via injected `@Sendable (Data) -> Void` closure. Preserves Principle 5 (no visibility leaks). |
| 3 | Two new `StreamTerminationReason` cases: `.streamFinished` (VOD natural end), `.unsupportedFormat` (DRM/fMP4/no-audio-variant). Prevents reconnect loops on permanent failures. |
| 4 | New `MacAmpApp/Audio/HLS/` subfolder separate from `Audio/Streaming/` — communicates HLS as transport-orchestration concern. |
| 5 | Two-token stale-callback gating (`pipelineGeneration` + `pauseEpoch`) protects orthogonal invariants. |
| 6 | `OSAllocatedUnfairLock<UInt64>` for generation snapshot — explicitly avoids `MainActor.assumeIsolated` deadlock trap. |
| 7 | Defense-in-depth: parser-level ASBD + `mFormatFlags` + magic-cookie compare with `parserFatalState` flag against silent format corruption. |
| 8 | HLS pause integrates with S3-1B's `pauseByUser`/`resumeByUser` barrier API. v1 keeps it simple — re-fetch playlist on resume + always invoke `parser.reset()`. |
| 9 | AHA Rule of Three deferral: `StreamFormatHint` enum belongs in S3-4 OGG (3rd codec). HLS does not preempt it. |
| 10 | `ClassifyError` mapping decided at error-construction site (HLS-malformed → `.unsupportedFormat`, legacy-malformed → `.playlistResolutionFailed`) — eliminates reconnect-loop risk by construction. |

---

## File Inventory

**New (3 files, ~750-1000 LOC):**
- `MacAmpApp/Audio/HLS/M3U8Parser.swift` (~225 LOC)
- `MacAmpApp/Audio/HLS/HLSSegmentFeeder.swift` (~350 LOC)
- `Tests/MacAmpTests/HLSStreamingTests.swift` (~300 LOC)

**Modified (3 files):**
- `Audio/StreamDecodePipeline.swift` (+160/-10)
- `Audio/AudioFileStreamParser.swift` (+40 — new `reset()` hook)
- `Audio/StreamPlayer.swift` (+12)

---

## Next Steps (implementation, after S3-2 merges)

1. Pre-flight: PF.1 – PF.5 (re-read at HEAD).
2. Optional: Gemini re-run if any open question warrants (research §"Gemini Research Findings" pending).
3. Create worktree on `feat/hls-streaming-support`.
4. Phase 1: M3U8Parser → Phase 2: parser.reset() → Phase 3: HLSSegmentFeeder → … Phase 7: tests.
5. Run TSan-enabled tests via xcodebuildmcp.
6. Run Oracle code-review gate after implementation.
7. Open PR #D.
