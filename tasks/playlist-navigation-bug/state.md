# State

- Added `currentPlaylistIndex` tracking and new `PlaylistAdvanceAction` flow inside `AudioPlayer`
- `AudioPlayer.nextTrack/previousTrack` now return actions (local playback handled internally, stream handoff via coordinator)
- `PlaybackCoordinator` consumes the new actions, updates unified state without replay loops, and owns stream/local switching
- Auto-advance from `AudioPlayer` notifies coordinator for both local and stream tracks via `externalPlaybackHandler`
- Need to verify shuffle, repeat, and start-of-playlist behaviors plus mixed playlist interactions
