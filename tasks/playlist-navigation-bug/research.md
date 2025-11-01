# Research

## Context
- Playback navigation managed by `PlaybackCoordinator.next/previous` delegating to `AudioPlayer.nextTrack/previousTrack`
- `AudioPlayer.playTrack(track:)` guards against `track.isStream` and returns early without updating `currentTrack`
- `AudioPlayer.nextTrack()` executes shuffle/repeat logic then calls `playTrack` to perform playback and update `currentTrack`
- When `playTrack` bails on streams, `currentTrack` remains pointing to the previous local file, so navigation never advances across stream entries
- `PlaybackCoordinator.play(track:)` sets its own `currentTrack` reference and switches between `AudioPlayer` and `StreamPlayer`
- Shuffle/repeat flags live inside `AudioPlayer`

## Observations
- `AudioPlayer` currently owns playlist state, shuffle, repeat, and `currentTrack`
- Coordinator needs consistent playlist traversal that respects shuffle/repeat but can defer playback to either `AudioPlayer` or `StreamPlayer`
- Coordinator currently lacks a way to retrieve the next/previous track without forcing `AudioPlayer` to attempt playback
- `AudioPlayer.currentTrack` must track whichever playlist item is active (even if stream) so its navigation logic remains accurate
- Stream playback path should stop the local player but still advance playlist indices through the coordinator

