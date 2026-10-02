# Todo: StreamDecodePipeline Decomposition

Updated: 2026-10-02

Checklist for SS-2, derived from `plan.md`.

## Re-evaluation

- [x] Responsibility map (`research.md`, at `b3894d9`)
- [ ] Re-baseline the map at post-OGG HEAD and set a new size target
- [ ] Go/no-go per the pre-decomposition gate in `tasks/_context/principles.md`; ADR with kill switch
- [ ] `DecodeContext` concurrency contract: header contract plus DEBUG gate test; add it to the ARCH GUIDE contract list

## If go

- [ ] Branch `refactor/streamdecodepipeline-decomposition`; set `state.md` to IN PROGRESS
- [ ] Extract `DecodeContext` to `Audio/Streaming/DecodeContext.swift` (`private` to `internal`)
- [ ] Extract `SessionDelegateProxy` to `Audio/Streaming/SessionDelegateProxy.swift`
- [ ] Extract playlist resolution (plus the format hint, per step 2) to `Audio/Streaming/PlaylistResolver.swift`
- [ ] Check generation-token, shutdown and callback semantics across the new files
- [ ] `xcodegen generate`; build and test with Thread Sanitizer
- [ ] Manual radio test (`plan.md` Verification)
- [ ] One `/codex:review --base main`; fix what affects correctness
- [ ] PR for owner review

## Close-out

- [ ] Update `state.md` and `tasks/_context/` with the outcome
