# Research

## Scope
- Investigated how the eject button populates playlist and updates UI metadata
- Reviewed playback navigation workflow for mixed playlists (local + streams)
- Focused on `PlaybackCoordinator`, `AudioPlayer`, `WinampMainWindow`, `WinampPlaylistWindow`

## BUG 1: Eject metadata gap
- `WinampMainWindow.openFileDialog()` and playlist window use `PlaylistWindowActions.presentAddFilesPanel(audioPlayer:)`
- `presentAddFilesPanel` iterates selected URLs and calls `audioPlayer.addTrack(url:)`
- `AudioPlayer.addTrack` autoplays first selection only when `currentTrack == nil`, but playback stays internal to `AudioPlayer`
- `PlaybackCoordinator` owns `displayTitle` used by main window track bar; it is only updated through `play(track:)`, `play(url:)`, or navigation helpers
- No call informs `PlaybackCoordinator` when autoplay happens inside `AudioPlayer`, leaving `currentSource/title` untouched and UI displaying fallback "MacAmp"
- Metadata appears after clicking playlist row because `WinampPlaylistWindow` invokes `PlaybackCoordinator.play(track:)`, which sets coordinator state

## BUG 2: Navigation across streams
- `PlaybackCoordinator.next/previous` call `audioPlayer.nextTrack()`/`previousTrack()`
- `AudioPlayer.playTrack` still guards out streams (`guard !track.isStream`)
- Updated implementation introduces `PlaylistAdvanceAction`; `.requestCoordinatorPlayback(track)` is returned for streams while preserving playlist index bookkeeping
- Coordinator's `handlePlaylistAdvance` routes streams through `play(track:)`, ensuring stop -> stream playback path and state sync
- Shuffle branch also emits `.requestCoordinatorPlayback` for streams, maintaining randomness without replaying local track
- Repeat handling loops to index 0, again delegating streams back via coordinator
- End-of-playlist sets `.none` with `trackHasEnded = true`, so coordinator does nothing (player stops)

## Edge Observations
- `audioPlayer.updatePlaylistPosition(with:)` invoked at start of `PlaybackCoordinator.play(track:)`, keeping indices aligned for subsequent navigation
- `audioPlayer.stop()` called before stream playback; guard ensures local player quiet but does not clear playlist indices
- No existing path updates coordinator display for autoplay triggered by `addTrack`, confirming BUG 1 root cause
