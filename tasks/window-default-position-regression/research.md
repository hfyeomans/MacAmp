# Window Default Position Regression — Research

## What we know
- Reporter observed `setDefaultPositions()` place the classic Winamp stack at y=500/384/152, but by the time logs were captured the origins drifted upward to 711/595/479. The deltas (+211 main/+211 EQ/+327 playlist) show something later in `WindowCoordinator.init` is overriding the freshly-set frames.
- `WindowCoordinator` (`MacAmpApp/ViewModels/WindowCoordinator.swift`) sets default frames **before** calling `resizeMainAndEQWindows(doubled:)` (lines 70-110). After that point, no other initializer step touches frames except `WindowSnapManager` reactions.

## Code inspection
- `resizeMainAndEQWindows` (same file, lines ~193-255) recalculates sizes for Main/EQ based on `WinampSizes`. It explicitly adjusts `newMainFrame.origin.y -= mainDelta` so that the *top* edge stays fixed when height changes. When the target height is **smaller** than the current window height, `mainDelta` is negative and the subtraction becomes an addition, pushing the origin upward by `abs(mainDelta)` pixels.
- The constructor builds `BorderlessWindow` instances using a `contentRect` sized at `WinampSizes` (275×116). However, the SwiftUI view (`WinampMainWindow`) applies `.scaleEffect(settings.isDoubleSizeMode ? 2 : 1, anchor: .topLeading)` followed by `.fixedSize()`. Before `settings.isDoubleSizeMode` propagates, AppKit often reports an inflated `frame.size.height` (e.g., 327) when the host view still uses its pre-scale intrinsic metrics. This means the very first call to `resizeMainAndEQWindows` sees a “current” height larger than the canonical constant, so its top-anchored adjustment raises the origins by exactly the observed deltas.
- No other init step sets frames. `presentWindowsWhenReady()`, window level setup, observers, snap registration, and delegate assignment all act on visibility/observers only.

## Hypothesis
- Because `resizeMainAndEQWindows(doubled:)` runs **after** `setDefaultPositions()`, its top-anchored resizing undoes the earlier stacking any time the current window height differs from `WinampSizes.main.height` / `.equalizer.height`. This explains why main/EQ origins end up 211 px higher and why the playlist (which never passes through `resizeMainAndEQWindows`) keeps its previous origin 152 yet appears “floated” above EQ after the others jump.

## Candidate fixes
1. Apply initial resizing **before** setting default positions so that `setDefaultPositions()` operates on the final window heights, avoiding post-position adjustments.
2. Alternatively, modify `resizeMainAndEQWindows` to optionally keep the *bottom* edge fixed during bootstrapping, but that complicates later double-size transitions (where anchoring to the top edge was intentional).
3. Add DEBUG-only helper logging after each init phase to confirm the culprit and guard against regressions.

