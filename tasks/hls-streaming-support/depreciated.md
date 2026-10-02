# Depreciated: HLS Streaming Support

Updated: 2026-10-02

> Code removed by this task, and research approaches the plan superseded.

## Code

None removed yet. The optional P6.3b deletion of the two unused `StreamPlayer` DEBUG seams would be recorded here.

## Research approaches superseded by `plan.md`

| Research proposed | Plan uses instead |
|-------------------|-------------------|
| `M3U8Parser` and `HLSSegmentFeeder` in `Audio/Streaming/`, with no `AudioFileStreamParser` change | New `Audio/HLS/` folder; `AudioFileStreamParser.reset()` with a post-reset format/cookie compare |
| Encrypted, fMP4 and no-audio-variant playlists mapped to `.decodeError` or `.playlistResolutionFailed` | New non-reconnectable `.unsupportedFormat` and `.streamFinished` cases |
| Content-Type promotion of non-`.m3u8` URLs on first response (Open Question 1) | v1 routes only `.m3u8`/`.m3u` through `classifyM3UDialect`; promotion is deferred |
| Playlist refresh in Swift `Task`s capturing `[weak self]` | `DispatchSourceTimer`, cancelled in `feeder.cancel()`, to avoid `Task.sleep` leaks |
