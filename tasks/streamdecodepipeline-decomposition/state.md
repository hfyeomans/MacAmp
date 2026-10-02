# State: StreamDecodePipeline Decomposition

Updated: 2026-10-02

**Status:** DEFERRED. Roadmap slot SS-2 (`tasks/_context/plan.md`): Structure Sprint, re-baselined after S3-4 merges (S3-3 and S3-4 both edit this file). Not started; no branch.

Re-evaluates splitting `MacAmpApp/Audio/Streaming/StreamDecodePipeline.swift`, and brings `DecodeContext` under the ADR-3a `@unchecked Sendable` concurrency contract.

## Decision (2026-03-25)

Deferred after the responsibility sweep: the file has one cohesive responsibility (HTTP stream decode lifecycle, classified Justified), and extracting `DecodeContext` would widen `private` to `internal` (Principle 5). The same reasoning cancelled SkinManager Step 4 and the VisualizerPipeline decomposition.

## Re-evaluation triggers

| Trigger | State |
|---|---|
| File grows past 800 lines | Fired: 825 lines at `b3894d9`. Projection after S3-3 and S3-4: `research.md`. |
| A genuinely new responsibility | Pending. The pause gate is lifecycle complexity; judge again after S3-3 (HLS branch) and S3-4 (`StreamBackend`). |
| `DecodeContext` gains external consumers | Not fired: still `private` (`:525`). |

## Added scope

`DecodeContext` concurrency-contract retrofit. It is `@unchecked Sendable` and queue-confined but predates the ADR-3a header-contract plus gate-test discipline (`docs/MACAMP_ARCHITECTURE_GUIDE.md:1514`, which names it the next retrofit; adopters in `research.md`). It is due whether or not the split goes ahead (`plan.md` step 3).

## Blockers

None beyond sequencing (S3-3, S3-4).
