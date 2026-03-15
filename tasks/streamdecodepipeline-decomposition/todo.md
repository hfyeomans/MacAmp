# Todo: StreamDecodePipeline Decomposition

> **Description:** Checklist for preparing and executing the `StreamDecodePipeline.swift` decomposition task.
> **Purpose:** Keep the work incremental, verifiable, and safe for the streaming pipeline.

---

- [ ] Produce a responsibility map for `StreamDecodePipeline.swift`
- [ ] Decide which nested/support types should move into dedicated neighbors
- [ ] Extract the lowest-risk support boundary first
- [ ] Continue extraction until the top-level pipeline file has a narrower owner role
- [ ] Update paths and regenerate Xcode project if files move
- [ ] Build and verify startup, buffering, metadata, and error handling
- [ ] Record any intentionally deferred seams in `placeholder.md`
