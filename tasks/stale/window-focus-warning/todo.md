# Todo

- [ ] Prototype a version of `configureWindow(_:)` that keeps `.titled` while hiding chrome, then verify visual fidelity (deferred; initial attempt reverted).
- [ ] Confirm that the modified window becomes key when activated via dock click or Mission Control, and that the `makeKeyWindow` warnings disappear.
- [ ] If the prototype fails, investigate introducing a custom `NSWindow` subclass through `NSWindowRepresentable` to override `canBecomeKey`.
