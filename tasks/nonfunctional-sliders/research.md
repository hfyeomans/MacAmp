# Research: Slider Input Regression

## Context
- User reports from Phase 1A validation indicate buttons respond but sliders do not.
- This regression appeared immediately after swapping `UnifiedDockView`'s SwiftUI `WindowGroup` for manual `NSWindowController` instances.
- Goal: trace how pointer/drag events flow from the new AppKit windows into SwiftUI slider components.

## Key Observations

1. **SwiftUI Slider Implementation**
   - `WinampVolumeSlider` (`MacAmpApp/Views/Components/WinampVolumeSlider.swift:1-120`) and `WinampBalanceSlider` (`same file:133-220`) rely on `DragGesture(minimumDistance: 0)` attached to a transparent `GeometryReader` overlay.
   - On each drag change they compute the pointer’s local `x` location inside the slider’s bounds and mutate the bound value (volume/balance) directly.
   - These gestures previously worked inside `UnifiedDockView` because SwiftUI handled the responder chain for us.

2. **Manual Window Hosting**
   - `WinampMainWindowController`, `WinampEqualizerWindowController`, and `WinampPlaylistWindowController` now each create a `BorderlessWindow` and set `window.contentView = NSHostingView(rootView: …)` (`MacAmpApp/Windows/*.swift`).
   - No `NSHostingController` is involved, and no additional gesture-specific window configuration (e.g., `acceptsMouseMovedEvents`) is performed.
   - `WindowCoordinator` only calls `window.makeFirstResponder(window.contentView)` during presentation; no ongoing responder maintenance exists after focus shifts.

3. **BorderlessWindow limitations**
   - Current subclass (`MacAmpApp/Windows/BorderlessWindow.swift`) only overrides `canBecomeKey`, `canBecomeMain`, and `acceptsFirstMouse(for:)`.
   - It does not force `acceptsMouseMovedEvents = true` nor does it forward `mouseDragged`/`mouseMoved` events when the window is activating. A standard AppKit window automatically toggles these when SwiftUI owns the window, but that work is absent here.

4. **Missing Window Accessor behavior**
   - The legacy `UnifiedDockView` used `WindowAccessor` to configure each SwiftUI-managed window instance (see `/tmp/UnifiedDockView.swift:72-142`). SwiftUI created the window, so the accessor ran *after* the window and its hosting controller were fully set up, guaranteeing that gesture recognizers (DragGesture, WindowDragGesture, etc.) were registered before we mutated style masks.
   - In the new manual controllers, we configure the `NSWindow` before attaching the SwiftUI hierarchy. There is no equivalent hook that re-applies gesture-friendly flags once SwiftUI installs recognizers.

5. **Plan Deliverables confirm expectation**
   - `tasks/magnetic-docking-foundation/plan.md:200-340` states Phase 1A still requires “buttons/sliders trigger behavior” as a validation checkpoint. Broken sliders therefore constitute a true regression, not a deferred feature.

## Hypothesis
- Because the Borderless windows are instantiated and shown *before* SwiftUI installs its recognizers, AppKit never enables mouse-moved tracking for them. Drag gestures (sliders, scrubbing, EQ faders) therefore never receive the continuous movement events they rely on, while simple button clicks still work.
- Additionally, using bare `NSHostingView` bypasses `NSHostingController`’s default responder forwarding, so the SwiftUI gesture system is missing the controller-level plumbing that previously bridged events from AppKit to SwiftUI transactions.

## Evidence Gaps / Next Steps
1. Confirm whether enabling `window.acceptsMouseMovedEvents = true` restores drag delivery.
2. Compare behavior when using `NSHostingController` as the `contentViewController` (instead of assigning only `NSHostingView`) to reintroduce the responder + gesture wiring that SwiftUI normally sets up.
3. Audit other windows (EQ, playlist) once a fix exists, ensuring they share the same hosting pattern.
4. After changes, manually verify that volume, balance, position, and EQ sliders all respond to drag input without requiring a second click.
