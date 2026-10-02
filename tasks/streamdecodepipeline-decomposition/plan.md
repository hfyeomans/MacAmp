# Plan: StreamDecodePipeline Decomposition

Updated: 2026-10-02

Steps for SS-2: re-evaluate the split of `StreamDecodePipeline.swift` and retrofit the `DecodeContext` concurrency contract.

## When and where

Structure Sprint, after S3-4 merges. Work in place in `MacAmpApp/Audio/Streaming/`, which is already the target folder.

## Step 1: Re-baseline

At post-OGG HEAD, redo the responsibility map in `research.md` and set a new size target from it. The March target (697 down to ~380 lines) no longer applies.

## Step 2: Go/no-go

Run the pre-decomposition gate in `tasks/_context/principles.md` and record the result as an ADR with a kill switch (Principle 7). Questions to settle:

- Does extracting `DecodeContext` still require `private` to `internal` (Principle 5), and does the step 3 contract test offset that? After S3-4 it also stores the fileprivate `StreamBackend`, `PipelineLifecycle` and `StreamFormatHint` enums (`research.md`), which would widen with it.
- `SessionDelegateProxy`: S3-3 adds a second, fileprivate proxy in `HLSSegmentFeeder`. Two copies stay below the Rule of Three (Principle 4); do not merge them.
- Playlist resolution and `formatHint(for:)`: redraw the boundary after S3-3 adds `classifyM3UDialect` to `start(url:)` and S3-4 reworks the format hint.

## Step 3: DecodeContext concurrency contract (go or no-go)

- Write the contract at the top of `DecodeContext`: what is confined to the decode queue, which entry points other queues may call, and why `@unchecked Sendable` is needed.
- Add a DEBUG gate test in the style of `VideoTapSendableContractTests`.
- The render-thread field rules (only `Atomic`, `Mutex` and `RenderThreadSafe` fields) do not fit a queue-confined type whose fields are plain `var`s. Define a queue-confinement form of the contract; the existing `QueueConfined` protocol is a candidate.
- Decide whether `SessionDelegateProxy` (also `@unchecked Sendable`) comes under the same contract.
- Add `DecodeContext` to the contract list in the ARCH GUIDE (`:1514`).

## Step 4: Extract (if go)

One commit per extraction:

1. `Audio/Streaming/DecodeContext.swift` (`private` to `internal`), with all its methods.
2. `Audio/Streaming/SessionDelegateProxy.swift` (`private` to `internal`).
3. `Audio/Streaming/PlaylistResolver.swift`: `isPlaylistURL`, `resolvePlaylistURL`, `parsePLS`, `PlaylistResolveError`, plus the format hint if step 2 keeps them together (too small for its own file).

`StreamState` and `StreamTerminationReason` stay nested in `StreamDecodePipeline`: they are tiny and have no separate lifecycle.

## Constraints

- Preserve generation-token, shutdown and callback semantics.
- Do not destabilize the decode-queue to render-thread hand-off.
- Add no stream features in this task.
- Flag duplication and dead code in `placeholder.md`; do not fix it here.

## Verification

- `xcodegen generate`, then build and test with Thread Sanitizer (commands in `tasks/_context/state.md`, Process).
- swiftlint passes on the changed files (`research.md`, File).
- Manual radio test: start, buffering, metadata, format-ready, pause/resume, stop, auto-reconnect, error and termination messages; an M3U or PLS URL; an HLS stream and an OGG stream once S3-3 and S3-4 have shipped.
- One `/codex:review --base main` before the PR; the owner reviews and merges.
