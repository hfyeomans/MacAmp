# Research Notes

- The README advertises drag-and-drop support (“Click the eject button or drag audio files to the window”), but no drag/drop handlers exist in the SwiftUI views; searches for `NSDragging`/`onDrop` return nothing.
- `WinampPlaylistWindow` and `WinampMainWindow` rely exclusively on `NSOpenPanel` helpers for importing audio or playlists. There is no bridging view that adopts `NSViewRepresentable` to expose AppKit drop delegates.
- The modernization architecture (`tasks/swift-modernization-recommendations/ARCHITECTURE.md`) stresses keeping UI mutations on the main actor and avoiding AppKit padding, which will influence any drop-target overlay (likely need a custom NSView-backed host to keep pixel-accurate hit areas).
- Current playlist ingestion path funnels through `PlaylistWindowActions.presentAddFilesPanel(audioPlayer:)`, which dispatches back to the main actor before calling `handleSelectedURLs`. Drag-and-drop should reuse the same `handleSelectedURLs` helper to stay compliant with actor isolation and duplicate checking in `AudioPlayer.addTrack(url:)`.
- No existing code registers drag types on the main playlist list, so future implementation will need to decide whether to accept drops at the window level (for any module) or specifically on the playlist list region.
