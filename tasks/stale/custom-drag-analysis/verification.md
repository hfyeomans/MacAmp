# Verification
- Logic audit: each cluster window's box derives from `baseBoxes` + shared `finalDelta`, so windows cannot overshoot or repel.
- Static membership: `clusterIDs` captured at drag start and reused, so fast drags keep the cluster intact unless a window disappears.
- Recommended manual QA:
  1. Launch app, undock all windows, cluster them via magnetic snapping.
  2. Drag main window quickly across screen: playlist + EQ should remain attached with no oscillation.
  3. Drag cluster into screen edges/corners to confirm snaps move the entire group uniformly.
  4. Break cluster intentionally (separate windows, start new drag) to ensure new context captures the new grouping.
