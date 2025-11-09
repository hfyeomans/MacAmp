# Implementation TODO
1. Expand `DragContext` to include cluster IDs and base boxes per window, plus cached windows map if needed.
2. Update `beginCustomDrag` to capture cluster membership + base boxes snapshot.
3. Rewrite `updateCustomDrag` to apply cumulative delta to stored base boxes for all cluster members and keep membership static during the drag.
4. Ensure drag cleanup remains intact (endCustomDrag + last origin sync) and update context bookkeeping accordingly.
