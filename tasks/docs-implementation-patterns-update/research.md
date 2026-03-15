# Research: Docs Audit Findings (Sprint S0)

> **Purpose:** Consolidated findings from 4 parallel doc audit agents.
> **Created:** 2026-03-14
> **Status:** 3/4 agents complete (skill doc still running)

---

## IMPLEMENTATION_PATTERNS.md — 7 Issues

| # | Lines | Severity | Issue |
|---|-------|----------|-------|
| 1 | 2561-2623 | **STALE** | `Task.detached` pattern should show `@concurrent static func` + serialized Task |
| 2 | 1801 | **STALE** | `Task.detached` usage in Thread-Safe Audio State example |
| 3 | 363-376 | **STALE** | Volume didSet missing `streamSourceNode?.volume` / `streamSourceNode?.pan` |
| 4 | 597-609 | **MINOR** | Coordinator routing example doesn't show streamSourceNode propagation |
| 5 | 606 | **STALE** | Balance comment says "Applied via AVAudioEngine bridge" — codebase has stale comment too |
| 6 | 3527 | **INCONSISTENCY** | Footer 1.7.0/2026-02-22 vs header 1.8.0/2026-03-14 |
| 7 | 3060 | **MISSING** | No migration guide for `Task.detached` to `@concurrent static func` |

**Already correct:** Cross-file anti-pattern (3329-3384), all 4 audio patterns, capability flags, AVPlayer-for-streaming removal.

---

## MACAMP_ARCHITECTURE_GUIDE.md — 28 Issues (Top 8)

| # | Lines | Severity | Issue |
|---|-------|----------|-------|
| 1 | 57 | **STALE** | Total Swift files: 79 listed, actual 111 |
| 2 | Multiple | **STALE** | AudioPlayer line count: varies (945-1050) listed, actual 1,143 |
| 3 | 1002-1020 | **STALE** | VideoPlaybackController deinit: old nonisolated(unsafe), actual isolated deinit |
| 4 | 197 | **WRONG** | VideoWindowChromeView.swift listed as deleted — still exists |
| 5 | 239, 4829 | **PHANTOM** | PlaylistManager.swift referenced — doesn't exist (should be PlaylistController) |
| 6 | Section 10 | **MISSING** | No `isolated deinit` or `@concurrent` docs despite extensive use |
| 7 | 102, 106 | **STALE** | File counts: Views 20 listed (actual 44), Models 16 listed (actual 22) |
| 8 | 2567 | **STALE** | "returns nil if video/stream" — streams now have visualizer support |

---

## README.md — 13 Issues (Top 5)

| # | Section | Severity | Issue |
|---|---------|----------|-------|
| 1 | Header/Footer | **INCONSISTENCY** | Version 3.3.0/2026-01-11 vs 3.6.0/2026-02-22 |
| 2 | Inventory | **PHANTOM** | 2 AUDIOPLAYER_REFACTORING docs listed but don't exist on disk |
| 3 | Statistics | **STALE** | "20 Core Technical Documents" listed, actual 18 |
| 4 | Search Index | **STALE** | "Swift 6 patterns" should be "Swift 6.2 patterns" |
| 5 | Diagram | **MISSING** | PLAYLIST_WINDOW.md not in relationship diagram |

---

## Other Docs — Lower Priority

- **RELEASE_BUILD_GUIDE.md:** Missing Swift 6.2 mention, XcodeGen not in prerequisites or CLI workflow
- **PLAYLIST_WINDOW.md:** Footer version mismatch (v1.0.0 should be v1.1.0), scheme name discrepancy
- **SPRITE_SYSTEM_COMPLETE.md:** Duplicate enum cases in code examples (won't compile)
- **WINAMP_SKIN_VARIATIONS.md:** Clean — no issues

---

## BUILDING_RETRO_MACOS_APPS_SKILL.md — Pending (agent still running)
