# Plan

1. Inventory the simplification branch relative to `main` and identify deleted files, removed symbols, and new shared utilities.
2. Verify deleted symbols are not still referenced through normal call sites, selectors, or reflection-like patterns.
3. Inspect behavior-preserving consolidations:
   - `supportsEQ` / `supportsBalance` -> `supportsAudioProcessing`
   - `Size2D` pixel conversion helpers -> `toPixels()`
   - duplicated menu target classes -> `MenuActionTarget` / `MenuItemFactory`
   - duplicated time formatting helpers -> `TimeFormatting`
   - duplicated queue confinement assertions -> `QueueConfined`
   - duplicated video seek completion closures -> `videoSeekCompletion`
4. Run a macOS build and tests to catch stale references, conformance issues, or project wiring fallout.
5. Return review findings ordered by severity, or explicitly state no findings and note residual risk/gaps.
