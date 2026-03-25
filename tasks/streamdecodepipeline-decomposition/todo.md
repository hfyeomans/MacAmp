# Todo: StreamDecodePipeline Decomposition

> **Description:** Checklist for executing the `StreamDecodePipeline.swift` decomposition.
> **Updated:** 2026-03-24 (implementation-ready)

---

- [x] Produce a responsibility map for `StreamDecodePipeline.swift`
- [ ] Create branch `refactor/streamdecodepipeline-decomposition`
- [ ] Update state.md to IN PROGRESS
- [ ] Extract `DecodeContext` class to `Audio/Streaming/DecodeContext.swift` (private -> internal)
- [ ] Extract `SessionDelegateProxy` class to `Audio/Streaming/SessionDelegateProxy.swift` (private -> internal)
- [ ] Extract static playlist resolution to `Audio/Streaming/PlaylistResolver.swift` (include PlaylistResolveError)
- [ ] Fold `formatHint(for:)` into `PlaylistResolver.swift` (only 14 lines after Phase 2.5 cleanup)
- [x] ~~Flag dead code `formatHint(forContentType:)` in placeholder.md~~ — removed in Phase 2.5
- [x] Flag intentional `extractICYMetaInt` call pattern in placeholder.md (not a bug)
- [ ] Run `xcodegen generate`
- [ ] XcodeBuildMCP build (Thread Sanitizer enabled)
- [ ] XcodeBuildMCP test
- [ ] Oracle review on extraction
- [ ] Manual test: play internet radio stream, verify metadata/reconnect
- [ ] Push branch -> create PR for user review
- [ ] Update state.md and shared _context/ on completion
