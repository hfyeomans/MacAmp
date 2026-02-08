# Research: Winamp AirPlay Overlay Trigger

## Existing Implementations
- The Webamp clone places a transparent anchor (`#about`) absolutely over the Winamp logo to intercept clicks (see `webamp_clone/packages/webamp/js/components/MainWindow/index.tsx`).
- The native SwiftUI `WinampMainWindow` (`MacAmpApp/Views/WinampMainWindow.swift`) renders sprites with `ZStack(at:)` helpers; there is currently no hitbox overlay near the Winamp text/logo area.
- No existing `AVRoutePickerView` wrapper or other AirPlay integrations exist in the SwiftUI target (only unrelated `WindowAccessor` uses `NSViewRepresentable`).

## AVRoutePickerView Behaviour (macOS 15+)
- `AVRoutePickerView` is an AppKit view (`NSView`) shipped with AVKit that presents the system AirPlay device chooser.
- The control must be interacted with directly; there is no public API to programmatically open/close the popover. Apple’s documentation (and WWDC examples) require presenting `AVRoutePickerView` itself. Attempted programmatic tricks (`performClick`, etc.) are private/unsupported.
- The view respects Auto Layout; you can hide its default glyph by setting `isBordered = false` and adjusting `alphaValue`, but the hit target remains the view bounds.
- You can constrain the view to any frame (minimum recommended 22×22 points for accessibility). Larger frames help pointer targeting.
- `AVRoutePickerView` supports `delegate` for route selection events, and `prioritizesVideoDevices` to control default behaviour; neither affects presentation.

## Overlay Pattern Considerations
- Since programmatic presentation is unsupported, the most reliable pattern is to place the picker view directly above the visual element that should act as the button.
- SwiftUI overlay can host an `NSViewRepresentable` while keeping the sprite visible underneath when the picker has a fully transparent background.
- Need to offset the representable to match Winamp coordinates (around the "WINAMP" lettering on the title bar). That sprite region is roughly 13×15 px in classic assets (match Webamp CSS).
- Use `.allowsHitTesting(true)` only on the picker container; optionally wrap in `Color.clear` to expand hitbox while keeping layout predictable.
- Because SwiftUI layout is pixel-perfect here (absolute coordinates), prefer using the existing `.at(CGPoint)` helper to place the picker overlay.

## Accessibility & macOS Specifics
- Provide an accessibility label (`accessibilityLabel("Open AirPlay devices")`) on the representable wrapper for VoiceOver support.
- Ensure minimum hit area ~22×22 points for accessibility; expand invisible tappable area if necessary while still aligning to logo visually.
- For macOS Sequoia/Tahoe the picker popover appears centered on the picker view rect; choose a frame that doesn't clip near window edges.
