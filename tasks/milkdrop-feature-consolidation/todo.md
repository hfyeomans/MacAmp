# Todo: Milkdrop Feature Consolidation

> **Description:** Checklist for preparing and executing the Milkdrop / Butterchurn ownership cleanup. Deferred to post-S3 Structure Sprint (D-STRUCTURE decision 2026-03-15).
> **Purpose:** Keep the feature move deliberate, verifiable, and separate from the urgent runtime fix.

---

- [ ] Produce a source-to-target mapping for all Milkdrop / Butterchurn Swift files
- [ ] Produce a source-to-target mapping for `Butterchurn/` resources
- [ ] Decide the final location for Milkdrop chrome files under `Features/Milkdrop/`
- [ ] Move the agreed feature files into `Features/Milkdrop/`
- [ ] Move `Butterchurn/` resources into a feature-owned resources path
- [ ] Update project/resource metadata if required
- [ ] Regenerate Xcode project if paths change
- [ ] Build and verify resource loading in both Xcode Debug and packaged app flows
