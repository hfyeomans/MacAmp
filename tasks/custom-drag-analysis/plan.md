# Plan: Stabilize Phase 2 custom drag

## Goal
Stop repelling oscillations and make clusters resilient to fast dragging by mirroring Webamp's cumulative-delta pattern.

## Strategy
1. **Expand DragContext**
   - Store `clusterIDs`, `baseBoxes` (per window), and cached `id -> NSWindow` map for quick access.
   - Preserve virtual screen snapshot + dragged window ID; keep last input delta for no-op detection.

2. **Fix beginCustomDrag**
   - Build virtual space + idToBox snapshot once.
   - Resolve cluster IDs by running `connectedCluster` using the snapshot; hold onto these IDs only (static membership for drag lifetime).
   - Capture `baseBoxes` for each member (dictionary keyed by ObjectIdentifier) from the snapshot so every window has a stable reference.

3. **Rewrite updateCustomDrag**
   - Early exit when context missing or delta unchanged.
   - Rebuild `idToWindow` live to skip deallocated windows, but keep movements based on stored base boxes.
   - Convert cumulative delta to top-left coordinate space, apply to each `baseBox` from context to get the desired location for every window.
   - Snap cluster by first moving dragged window (based on its base box) and computing snap adjustments; apply same snap delta to every window's box (mirrors Webamp: move whole cluster by same final delta).
   - Apply resulting boxes to actual windows without incremental math, ensuring each window uses `baseBox + cumulative delta + snap delta`.
   - Update `context.lastInputDelta` and persist.

4. **End custom drag**
   - Keep as-is except ensure context removed.

5. **Verification**
   - Manual reasoning: confirm cumulative delta path prevents incremental feedback, static cluster prevents dropouts.
   - Outline manual QA steps (drag clusters quickly, ensure they stay grouped and snap magnetically).
