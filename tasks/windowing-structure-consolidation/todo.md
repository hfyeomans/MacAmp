# Todo: Windowing Structure Consolidation

> **Description:** Checklist for preparing and executing the post-S1 windowing ownership cleanup.
> **Purpose:** Keep the work bounded, mechanical where possible, and easy to verify.

---

- [ ] Produce a source-to-target mapping for all candidate windowing files
- [ ] Decide which `Models/*Window*` files are truly generic windowing types vs feature-local state
- [ ] Decide whether `WindowCoordinator` belongs wholly in `Windowing/Coordination/` or needs partial decomposition first
- [ ] Move the agreed generic files into `Windowing/`
- [ ] Update project/resource metadata if required
- [ ] Regenerate Xcode project if paths change
- [ ] Build and manually verify multi-window behaviors
- [ ] Document any deferred or ambiguous files in `placeholder.md`
