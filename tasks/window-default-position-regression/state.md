# State — Window Default Position Regression

- Initial stack placement is now preserved because `resizeMainAndEQWindows(doubled:)` executes **before** `setDefaultPositions()`. The windows are resized to either 1× or 2× before we compute the canonical y positions, so no later step mutates the origins.
- Added `debugLogWindowPositions(step:)` (DEBUG-only) and wired it up after every initializer stage the reporter listed. The logs now clearly show that no call after `setDefaultPositions()` changes the frames, so if a future regression appears we will know immediately which step caused it.
- `setupDoubleSizeObserver()` still handles runtime toggles; the observer is unaffected because only the “initial sizing” invocation moved.
- Remaining work: none for this task unless QA finds another window mover.
