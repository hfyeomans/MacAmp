# Todo: VisualizerPipeline Decomposition

> **Description:** Checklist for preparing and executing the `VisualizerPipeline.swift` decomposition task.
> **Purpose:** Keep the work incremental, verifiable, and safe for visualization/audio behavior.

---

- [ ] Produce a responsibility map for `VisualizerPipeline.swift`
- [ ] Separate orchestration concerns from support/data types
- [ ] Extract the lowest-risk support boundary first
- [ ] Continue extraction until `VisualizerPipeline.swift` is reduced to a clearer coordinator role
- [ ] Update paths and regenerate Xcode project if files move
- [ ] Build and verify visualizer and Butterchurn behavior
- [ ] Record any intentionally deferred seams in `placeholder.md`
