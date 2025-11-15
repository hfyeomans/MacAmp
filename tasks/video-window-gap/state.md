# State

- **Left gap**: Sprite math in `VideoWindowChromeView` already assumes `x = width / 2` anchors at the window edge, but AppKit’s borderless window can still land on half-point origins. Without snapping the NSWindow to integral points, every chrome element inherits that offset and leaves a 1 px seam even though the SwiftUI math is correct. Need to verify by logging `video.frame.origin.x` during drag and clamping via `round` if necessary.
- **Metadata width**: All surplus width (`pixelSize.width - 250`) currently becomes center filler tiles, so the metadata overlay stays at 115 px forever. We should add derived values (e.g., `metadataWidth`, `centerTileRange`) so the right block can grow up to a comfortable max before filler tiles reappear, preserving readability without distorting sprites.
- **Resize jitter**: Drag events still mutate `sizeState` on every boundary crossing, SwiftUI rebuilds the view, and `WindowCoordinator` immediately resizes the NSWindow. Without hysteresis or throttling, the quantized translation toggles between two segment counts whenever the pointer noise crosses a 25/29 px threshold, which the user experiences as jitter. Options: snap NSWindow origins to integers, apply ±4 px hysteresis before changing segments, or debounce NSWindow updates (batch them inside a `Transaction` / `DispatchQueue.main.asyncAfter`).
- **Open items for implementation**:
  - Measure whether the gap disappears when the window origin is forced to rounded values.
  - Decide how far the metadata block should grow (e.g., allocate all surplus width until 300 px, then resume center filler).
  - Pick a jitter mitigation strategy so drag updates stay smooth without reintroducing snap-manager fights.
