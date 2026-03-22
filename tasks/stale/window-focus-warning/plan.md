# Plan

1. Validate whether we can retain `.titled` in the window style mask while still hiding all chrome, and confirm the visual result matches the retro requirements.
2. If visual parity holds, adjust `configureWindow(_:)` to avoid the `.borderless` mask and rely on `.titled` + hidden title bar; otherwise, explore creating a custom `NSWindowRepresentable` that subclasses `NSWindow` and overrides `canBecomeKey`.
3. Add regression checks ensuring key-window focus works when clicking the dock icon and that macOS Mission Control no longer logs the warning.
