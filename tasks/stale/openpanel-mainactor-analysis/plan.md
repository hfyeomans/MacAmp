# Plan

1. Summarize the modernization architecture’s guidance on actor isolation and UI/Audio threading, highlighting any constraints that affect the playlist ADD menu flow.
2. Trace the control path for `NSOpenPanel` completion → `PlaylistWindowActions.handleSelectedURLs` → `AudioPlayer.addTrack` to determine how skipping the `MainActor` hop could lead to both the concurrency regression and the intermittent `ExtAudioFileOpenURL` failure.
3. Formulate recommendations that restore correctness without conflicting with the target architecture, and list any clarifications needed (e.g., additional telemetry about the MP3 failures).
