# Placeholder Tracking: StreamDecodePipeline Decomposition

> **Description:** Tracks deferred cleanup, dead code, and deduplication targets discovered during decomposition.
> **Purpose:** Checklist for the future simplification/dedup pass (Phase 2.5, after file moves).

---

## Dead Code (Flag for removal in dedup pass)

| Symbol | File:Line | Issue |
|--------|-----------|-------|
| `formatHint(forContentType:)` | StreamFormatHint.swift (was line 457) | `static` with zero callers in entire codebase. Vestigial or intended for future HLS work. |

## Intentional Non-Duplication (Document, not a bug)

| Location 1 | Location 2 | Explanation |
|---|---|---|
| `extractICYMetaInt` call in onResponse proxy (line 189) | `extractICYMetaInt` call in handleHTTPResponse (line 304) | Proxy call runs on delegate queue for correct ordering; handleHTTPResponse call runs on MainActor for logging only. Comment on lines 311-314 documents this. |

## Deduplication Targets (For future Phase 2.5 simplification pass)

None identified in this file. The pipeline code is already well-factored with clear single responsibilities.
