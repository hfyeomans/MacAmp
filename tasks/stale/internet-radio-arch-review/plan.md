# Phase 4 Architecture Alignment Plan

## Goal
Bring internet radio behaviour in line with classic Winamp: HTTP streams behave as ordinary playlist tracks (ephemeral), while the RadioStationLibrary evolves into an optional favourites list for future phases.

## Implementation Outline

1. **Track Model Evolution**
   - Extend `Track` to support file and stream sources without breaking existing `AudioPlayer` logic.
   - Add computed helpers such as `isStream`, derived from `url.isFileURL == false`.
   - Store optional stream metadata (e.g., `initialTitle`, `explicitDuration`) to preserve playlist display before ICY updates.
   - Ensure equality continues to rely on `id` to avoid duplicate playlist entries, and audit any assumptions that metadata loads from local files only.

2. **Playlist Playback Routing**
   - Introduce a single orchestration point (`PlaybackCoordinator`) in the playlist UI.
   - On double-click:
     - If `track.isStream` → `await playbackCoordinator.play(url: track.url)`.
     - Else → existing `audioPlayer.playTrack(track:)`.
   - Expose `PlaybackCoordinator` via the SwiftUI environment (constructed in `MacAmpApp.swift`) so views can access both `AudioPlayer` and `StreamPlayer` state.
   - Confirm coordinator stops the alternate backend before starting the requested source to keep EQ and stream pipelines isolated.

3. **Playlist Population**
   - Update M3U import and “Add URL” flow to create `Track` instances directly in `audioPlayer.playlist`, populating initial metadata (title/duration) from `M3UEntry`.
   - Avoid persisting these entries; RadioStationLibrary should not be mutated during import unless an explicit “Save to Favourites” action is added later.
   - Ensure placeholder metadata for streams keeps UI legible (e.g., fallback title = host or EXTINF title, duration = `0`).

4. **Coordinator ↔ StreamPlayer Contract**
   - Allow `StreamPlayer` to accept lightweight descriptors instead of full `RadioStation` objects. Options:
     - Adapt `StreamPlayer.play` to take `URL` plus optional display info.
     - Or introduce an internal `StreamSource` struct used by both playlist tracks and saved stations.
   - Maintain ICY metadata updates and buffering status; expose them through `PlaybackCoordinator` for UI consumption.

5. **UI State & Buffering Feedback**
   - Extend UI bindings (main window title, playlist status line) to consume coordinator state when current source is a stream.
   - Display “Connecting...” when `StreamPlayer.isBuffering` and fall back to last known metadata once ready.
   - Ensure progress/duration fields gracefully handle streams (no countdown, show blank or “LIVE”).

6. **RadioStationLibrary Future Role**
   - Preserve the class for Phase 5 favourites: continue loading persisted stations into menus, but decouple from playlist ingestion routines.
   - Provide a migration path for existing persisted entries (possibly allow manual injection into playlist through a menu in later phases).

7. **Validation & Regression Checks**
   - Test matrix:
     - Import mixed M3U (files + streams) and verify playlist order, playback switching, absence of duplicates.
     - Double-click transitions between local files and streams ensure only one backend active.
     - Buffering indicator and metadata updates propagate to UI without race conditions.
     - Persisted favourites remain intact but do not auto-populate playlist.
   - Confirm no unexpected `AudioPlayer` crashes when encountering HTTP URLs in playlist (guarded via coordinator routing).

## Notes & Open Questions
- Decide whether to cache ICY-derived metadata back into the playlist row for the active stream (for UI parity).
- Consider adding an explicit “Add to Favourites” command in UI to bridge playlist streams into `RadioStationLibrary`.

