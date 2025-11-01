# Internet Radio Architecture — Research Notes

## Code Paths Reviewed
- `MacAmpApp/Audio/AudioPlayer.swift#L68`
- `MacAmpApp/Audio/PlaybackCoordinator.swift#L15`
- `MacAmpApp/Audio/StreamPlayer.swift#L26`
- `MacAmpApp/Models/RadioStation.swift#L3`
- `MacAmpApp/Models/RadioStationLibrary.swift#L6`
- `MacAmpApp/Models/M3UEntry.swift#L3`
- `MacAmpApp/Models/M3UParser.swift#L3`
- `MacAmpApp/Views/WinampPlaylistWindow.swift#L1`

## Key Observations
- `Track` (playlist element) assumes on-disk media: stores `url`, `title`, `artist`, `duration`, and equality/metadata workflows in `AudioPlayer` call `AVAudioFile` (`AudioPlayer.swift#L214`). Remote HTTP URLs fail this pipeline.
- `AudioPlayer` maintains the canonical playlist (`AudioPlayer.playlist`) and double-click playback in the playlist UI invokes `audioPlayer.playTrack(track:)` directly (`WinampPlaylistWindow.swift#L421`), bypassing `PlaybackCoordinator`. As a result, the stream backend is never used for playlist-triggered items.
- `PlaybackCoordinator` currently only mediates ad-hoc playback decisions based on `URL.isFileURL` or explicit `RadioStation` requests (`PlaybackCoordinator.swift#L62`). It instantiates a synthetic `RadioStation` when asked to play a non-file URL (`PlaybackCoordinator.swift#L69`), but there is no path for the playlist UI to reach this logic.
- The M3U loader splits responsibilities: local file entries go straight to `AudioPlayer.addTrack`, while remote entries create `RadioStation` instances persisted via `RadioStationLibrary` (`WinampPlaylistWindow.swift#L61`). This diverges from Winamp behaviour where all entries populate the active playlist.
- `RadioStationLibrary` is a persisted favourites list stored in `UserDefaults` and used by the playlist window for "Add URL" and M3U imports (`RadioStationLibrary.swift#L6`, `WinampPlaylistWindow.swift#L94`).
- `StreamPlayer` manages AVPlayer playback, buffering, and ICY metadata, but its `currentStation` type is `RadioStation` rather than a generalised stream descriptor (`StreamPlayer.swift#L27`), reinforcing the RadioStation-centric model.
- UI state such as display titles currently derives from `AudioPlayer.currentTitle` with no visibility into stream buffering — playlist window displays metadata only through `AudioPlayer`'s state.

## User Behaviour Gap
- Real Winamp playlists interleave file paths and HTTP stream URLs as ephemeral items. Current implementation persists streams separately and excludes them from the playlist UI, preventing quick playback and deviating from expected workflow.

## Risks & Constraints
- Enabling HTTP URLs inside `AudioPlayer.playlist` requires segregated playback logic: the `AudioPlayer` pipeline cannot open network URLs, so fallback to `PlaybackCoordinator`/`StreamPlayer` is necessary when interacting with playlist entries.
- Metadata handling differs: streams rely on ICY updates (`StreamPlayer.swift#L67`), whereas files use AVAsset metadata. Playlist UI and transport controls need unified presentation to avoid regression when switching between track types.
- Persisting `RadioStation` entries in favourites while also allowing ephemeral playlist streams means the model layer must distinguish between transient `Track` instances and curated `RadioStation` records.

