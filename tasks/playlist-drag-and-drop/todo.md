# Todo

- [ ] Evaluate whether `.onDrop(of:isTargeted:perform:)` in SwiftUI offers enough control for playlist hit targets or if an `NSViewRepresentable` bridge is needed.
- [ ] Reuse `PlaylistWindowActions.handleSelectedURLs` for dropped items to maintain validation and main-actor isolation.
- [ ] Design retro-consistent visual feedback for drop hover (sprite overlay or highlight).
- [ ] Add tests or logging hooks to ensure dropped entries go through the duplicate/pending URL checks in `AudioPlayer`.
