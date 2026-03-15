# Audio Pipeline Duplicate Investigation

## Scope

- `configureFramer`
- `activateStreamBridge`
- `deactivateStreamBridge`
- Side effects reachable from multiple actor, queue, callback, or lifecycle contexts

## Initial Inventory

- Risky symbols are concentrated in:
  - `MacAmpApp/Audio/AudioPlayer.swift`
  - `MacAmpApp/Audio/PlaybackCoordinator.swift`
  - `MacAmpApp/Audio/Streaming/StreamDecodePipeline.swift`
- `configureFramer` appears in `StreamDecodePipeline` and is intentionally documented as queue-confined.
- `activateStreamBridge` and `deactivateStreamBridge` are defined in `AudioPlayer` and called from `PlaybackCoordinator`, plus `deactivateStreamBridge` is also called from `AudioPlayer` lifecycle/internal paths.

## Investigation Method

- Use `rg` for inventory and call-site counts.
- Use `ast-grep` as the primary syntax-aware matcher for lifecycle, task, and direct-call structure.
- Use a dedicated explorer sub-agent for duplicate-path analysis.
- Judge behavioral duplication before text duplication.

## Findings

### Confirmed duplicate

- Local file autoplay has two live owners.
- `AudioPlayer.addTrack(url:)` auto-plays the first track when `currentTrack == nil`.
- `PlaylistWindowActions.presentAddFilesPanel(...)` adds files through `audioPlayer.addTrack(url:)`, then if the playlist had been empty also calls `await coordinator.play(track: firstTrack)`.
- This re-enters local playback initialization for the same track.

### Likely duplicate-path risks

- Bridge teardown ownership is split.
- `PlaybackCoordinator` proactively calls `audioPlayer.deactivateStreamBridge()` in multiple source-switch and stop paths.
- `AudioPlayer.rewireForCurrentFile()` also tears down the bridge for direct local playback paths.
- `PlaybackCoordinator` additionally wires `streamPlayer.onStreamTerminated` to bridge teardown.
- Current ordering and `isBridgeActive` guards prevent same-event double execution, but ownership is still distributed.

- Coordinator bypasses exist for local file starts.
- `AppCommands.presentOpenPanel()` and `PlaylistWindowActions.handleSelectedURLs(...)` call `audioPlayer.addTrack(url:)` directly.
- That allows local playback to begin outside the unified playback owner.

### Intentional repetition / false positives

- `configureFramer(metaInterval:)` has a single behavioral owner on the decode queue.
- `StreamDecodePipeline.handleHTTPResponse(...)` explicitly documents why it must not configure the framer again on `@MainActor`.
- `activateStreamBridge(...)` currently has one real activation path: `PlaybackCoordinator`'s `streamPlayer.onFormatReady` callback.
- The two `formatReadyFired` flags are layered idempotence guards, not competing implementations.
