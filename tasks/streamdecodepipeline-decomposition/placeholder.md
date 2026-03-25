# Placeholder Tracking: StreamDecodePipeline Decomposition

> **Description:** Tracks deferred cleanup, dead code, and deduplication targets discovered during decomposition.
> **Purpose:** Checklist for the future simplification/dedup pass (Phase 2.5, after file moves).

---

## Dead Code (Flag for removal in dedup pass)

| Symbol | File:Line | Issue | Status |
|--------|-----------|-------|--------|
| ~~`formatHint(forContentType:)`~~ | ~~StreamDecodePipeline.swift:457~~ | ~~`static` with zero callers~~ | **REMOVED in Phase 2.5** |

## Intentional Non-Duplication (Document, not a bug)

| Pattern | Explanation |
|---|---|
| `extractICYMetaInt` called once from onResponse proxy (line 189) | The `handleHTTPResponse` method (lines 301-305) does NOT call `extractICYMetaInt` again — comment explains why. Single call site, not a duplication. |

## Deduplication Targets (For future Phase 2.5 simplification pass)

None identified in this file. The pipeline code is already well-factored with clear single responsibilities.
