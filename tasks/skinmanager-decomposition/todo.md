# Todo: SkinManager Decomposition

> **Description:** Checklist for preparing and executing the `SkinManager.swift` decomposition task.
> **Purpose:** Keep the work incremental, verifiable, and aligned with the approved project structure.

---

- [ ] Produce a responsibility map for `SkinManager.swift`
- [ ] Decide which responsibilities belong in `Features/Skins/` versus shared skin infrastructure
- [ ] Extract the lowest-risk helper boundary first
- [ ] Continue extraction until `SkinManager.swift` has a clearer, narrower owner role
- [ ] Update paths and regenerate Xcode project if files move
- [ ] Build and verify skin discovery, import, switching, and fallback behavior
- [ ] Record any intentionally deferred seams in `placeholder.md`
