# State: OGG Vorbis Support

> **Purpose:** Add OGG Vorbis decoding for both local files and Icecast streams. Closes Winamp parity gap.
> **Created:** 2026-03-14
> **Sprint:** S3, Wave S3-4 (last task — sequential after S3-3 merges)
> **Status:** PLAN APPROVED — ready for spike phase pending S3-3 merge

---

## Current Status

**Phase:** Plan complete, Oracle gate cleared. Implementation gated on Phase 0a + 0b spikes.
**Last Updated:** 2026-04-27.

### Artifacts

| File | Status |
|------|--------|
| `research.md` | ✅ Complete (Oracle 6.8/10 GO-WITH-CHANGES → 10/10 actionable items applied, 2026-04-27) |
| `plan.md` | ✅ Complete — Oracle iter 3: **9.3/10 APPROVED** (883 lines, 22 sections) |
| `todo.md` | ✅ Complete (245 lines, derived from plan) |
| `depreciated.md` | Empty (no deprecated code yet — `ICYMetadata → StreamMetadata` rename in Phase 6 will not deprecate; renames in place) |
| `placeholder.md` | Empty (none yet) |

### Oracle Iterations (plan + todo)

| # | Score | Verdict |
|---|------:|---------|
| 1 | 8.2/10 | GO-WITH-CHANGES (1 CRITICAL, 3 HIGH, 2 MEDIUM, 1 LOW) |
| 2 | 8.9/10 | GO-WITH-CHANGES (state map drift, callback naming, residual hardcoded test count) |
| 3 | **9.3/10** | **GO** (2 LOW nits applied in trailing pass) |

---

## Branch + Wave

- **Branch:** `feat/ogg-vorbis-support`
- **Spike branches:** `spike/ogg-build-wiring` (Phase 0a, throwaway) + `spike/ogg-local-playback` (Phase 0b, throwaway)
- **Wave:** S3-4 sequential — last task in S3
- **PR target:** PR #E
- **Predecessors:** S3-1, S3-2, S3-3 all merged. All file conflicts resolve in this PR (last in chain).
- **Successors:** none (S3 closes here)

---

## Key Plan Decisions

| # | Decision |
|---|----------|
| 1 | Decoder: **libvorbis + libogg primary** (chained-stream support critical for Icecast). stb_vorbis ruled out (chained-stream gap). |
| 2 | Local-file integration: **Path A-revised** — chained `playerNode.scheduleBuffer` on existing `AVAudioPlayerNode`. Preserves transport contracts (Oracle CRITICAL fix). |
| 3 | Stream integration: **`StreamBackend` enum sum type** inside `StreamDecodePipeline.swift`. NOT a protocol with strategy objects (Principle 6). `DecodeContext` retains all queue-confined state (Principle 3). |
| 4 | Sniff-then-decode pipeline state machine: `Connecting → Sniffing → DecoderSelected → Buffering → Playing`. Buffer up to first complete BOS Ogg page (8 KB cap, 250 ms timeout). |
| 5 | `ICYMetadata` → `StreamMetadata` rename. ICY and Vorbis become adapters. |
| 6 | Chained-format gap fix: `formatReadyFired` collapsed to single decode-queue-confined source of truth. `onChainFormatChange` (pipeline) → `onStreamChainFormatChanged` (StreamPlayer) → `PlaybackCoordinator` deactivate→activate→re-pass workgroup. T13b verifies plumbing. |
| 7 | `VorbisDecoder` uses immutable `Mode` sum-type (`.stream` vs `.seekableFile`) with disjoint state per mode and per-method applicability asserts. |
| 8 | Universal build (`arm64 x86_64`) **mandatory and non-negotiable**. |
| 9 | Strict "completion handler does NOT decode" contract — dedicated producer queue. |
| 10 | Phase 0a + 0b are hard gates. 0a fails → fall back to xcframework (Option 2). 0b fails → escalate, possibly abort task. |

---

## File Inventory

- ~1000 LOC new Swift
- ~250 LOC modified
- ~3 MB vendored C (libogg + libvorbis)
- ~30 KB binary test fixtures
- New `Vendor/libogg/`, `Vendor/libvorbis/` SwiftPM cTargets + modulemaps
- `Package.swift` + `project.yml` updates

---

## Next Steps (after S3-3 merges)

1. Re-read all affected files at HEAD post-S3-3 merge; reconcile drift.
2. Cut throwaway branch `spike/ogg-build-wiring`. Execute Phase 0a (Cvorbis→Cogg actually linked, universal `lipo` proof).
3. If 0a passes: cut `spike/ogg-local-playback`. Execute Phase 0b (chained-buffer transport contract on macOS 15 + macOS 26).
4. If both pass: write findings to research.md, delete spike branches.
5. Cut implementation branch `feat/ogg-vorbis-support`.
6. Execute Phase 1 (vendor) → Phase 10 (binary size measurement) per todo.md.
7. Run TSan-enabled tests via xcodebuildmcp.
8. Run Oracle code-review gate against `main`.
9. Open PR #E.
