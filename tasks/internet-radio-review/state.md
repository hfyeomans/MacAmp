## Status

- Research complete for target files (`AudioPlayer`, `StreamPlayer`, `PlaybackCoordinator`, main and playlist windows, app bootstrap).
- Review pass finished; findings collected for final report (no code changes made).
- Key issues spotted: (1) playlist ADD flow overwrites `externalPlaybackHandler`, replaying tracks when metadata refreshes and bypassing coordinator state handling; (2) `AudioPlayer.stop()` leaves `currentTrack` populated, so stream playback keeps local progress UI.
- Ready to deliver review summary with ✅/🛑/⚠️/🧹 sections.
