# Research - Oracle Validation (AudioPlayer Refactor)

## Sources Reviewed
- MacAmpApp/Audio/VideoPlaybackController.swift
- docs/AUDIOPLAYER_REFACTORING_2026_CORRECTED.md
- Audio engine file line counts (wc -l)

## Findings
- Audio Engine file count and lines:
  - AudioPlayer.swift (1043), EQPresetStore.swift (187), MetadataLoader.swift (171), PlaylistController.swift (273), VideoPlaybackController.swift (297), VisualizerPipeline.swift (525), StreamPlayer.swift (199), PlaybackCoordinator.swift (352)
  - Total: 3047 lines across 8 files (matches stated metric).
- Reduction metric present in doc: AudioPlayer 1,805 -> 1,043 lines (-42.2%).
- API naming in code: `EQPresetStore.savePreset(_ preset: EqfPreset, forTrackURL urlString: String)`; call site uses `savePreset(..., forTrackURL:)`.
  - Documentation diagram mentions `savePreset(:for:)`, which does not match current code signature.
- Sample rate statement in doc uses "sample rate from file format"; no 48kHz text found.
- VideoPlaybackController header comment explicitly classifies Layer as Mechanism and references "Mechanism layer".
