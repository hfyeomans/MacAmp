# State: Stream Pause Tail

> **Purpose:** Fix ~0.7s audio tail that plays after pausing an internet radio stream + latent reconnect-during-pause bug.
> **Created:** 2026-03-14
> **Sprint:** S3, Wave S3-1 Worktree B (parallel with `mainwindow-visualizer-isolation`)
> **Status:** PLAN APPROVED — ready for implementation

---

## Current Status

**Phase:** Plan complete, Oracle gate cleared.
**Last Updated:** 2026-04-27.

### Artifacts
| File | Status |
|------|--------|
| `research.md` | ✅ Complete (Oracle 8/8 applied, 2026-04-27) |
| `plan.md` | ✅ Complete — Oracle iter 5: **9.1/10 APPROVED** |
| `todo.md` | ✅ Complete (aligned with plan iter-5) |
| `depreciated.md` | Empty (no deprecated code yet) |
| `placeholder.md` | Empty (none yet) |

### Oracle Iterations (plan + todo)
| # | Score | Verdict |
|---|------:|---------|
| 1 | 7.8/10 | CONDITIONAL |
| 2 | 8.6/10 | CONDITIONAL |
| 3 | 8.9/10 | CONDITIONAL |
| 4 | 8.4/10 | CONDITIONAL |
| 5 | **9.1/10** | **APPROVED** |

---

## Branch + Wave

- **Branch:** `fix/stream-pause-tail`
- **Wave:** S3-1 Worktree B (parallel start with mwvi Worktree A; sequential merge B-after-A)
- **PR target:** PR #B
- **Predecessors:** none
- **Successors:** `video-audio-engine-routing` (S3-2), `hls-streaming-support` (S3-3), `ogg-vorbis-support` (S3-4)

---

## Decisions (resolved)

| # | Question | Decision |
|---|----------|----------|
| OQ1 | `setStreamSilenced` wiring | Forwarder via `AudioPlayer` + closure on `StreamPlayer` assigned at PlaybackCoordinator init (ADR-SPT-4). |
| OQ3 | Live-edge vs paused-snapshot on resume after long pause | Best-effort first; live-edge fallback after 1s prebuffer timeout (ADR-SPT-5). |

ADR-SPT-1 through ADR-SPT-8 all enumerated in plan.md §4.

---

## Next steps (implementation)

1. Create worktree `worktree-stream-pause-tail` on branch `fix/stream-pause-tail`.
2. Execute todo.md phases 1-8 in order.
3. Run TSan-enabled tests via xcodebuildmcp; verify zero new warnings.
4. Run Oracle code-review gate after implementation (`mcp__codex-cli__codex` Review mode against `main`).
5. Open PR #B; rebase onto post-merge HEAD if PR #A merges first.
