# Depreciated: OGG Vorbis Support

Updated: 2026-10-02

> Code removed by this task, and research approaches the plan superseded.

## Code

None removed yet. C1 will remove the root `Package.swift`, `Package.resolved` and the `.swiftlint.yml` exclude (plan §6); record them here when it lands. The `ICYMetadata` → `StreamMetadata` rename (C6) is in place, not a deprecation.

## Research approaches superseded by `plan.md`

| Research proposed | Plan uses instead |
|-------------------|-------------------|
| `Cogg`/`Cvorbis` as targets in the root `Package.swift`, with licenses as `Package.swift` resources | A local `Vendor/COggVorbis` package wired through `project.yml`; `THIRD_PARTY_LICENSES.txt` in `project.yml` resources; root `Package.swift` deleted in C1 |
| A `StreamDecoder` protocol (`OggDecodeStrategy.swift`, `AudioConverterDecoder` conformance) and a 4-case `StreamFormatHint` {mp3, aacADTS, oggVorbis, unknown} | A fileprivate `StreamBackend` enum and `StreamFormatHint` {`.audioFileStream(AudioFileTypeID)`, `.ogg`, `.unknown`} |
| Local Vorbis through `AVAudioSourceNode` + ring buffer (Open Question 2) | Path A-revised: chained `scheduleBuffer` on the existing `AVAudioPlayerNode` (Oracle CRITICAL finding) |
| `VorbisDecoder` in `Audio/Streaming/`, `VorbisFileSource` in `Audio/`, and a branch in `AudioPlayer.detectMediaType` | Both under `Audio/Vorbis/`; `AudioPlayer` only swaps `engine.audioFile != nil` for `hasLoadedSource` |
