# State: Video Multichannel Output (S4-4)

Updated: 2026-10-02

**Status:** QUEUED. Research seeded; experiments not started.

**Issue:** [#88](https://github.com/hfyeomans/MacAmp/issues/88)

## Purpose

Play 5.1 and other multichannel or spatial video audio as multichannel (as Apple Music and TV do) while MacAmp's balance still controls the left vs right speakers.

## Gating

- Predecessors are met: S3-2 `avplayer-native-video-dsp` (PR #89) added the preferred-format tap this task extends, and D-TARGET27 (PR #87) made `MTAudioProcessingTapCreateWithPreferredFormat` (macOS 27) available.
- Unblocked, but it keeps its roadmap position after S4-3 `airplay-route-picker`.

## Starting point

- `VideoTap.preferredProcessingFormat` pins stereo Float32 non-interleaved at the source rate (`MacAmpApp/Audio/VideoDSP/VideoTap.swift:220-227`), so the system upmixes mono and downmixes multichannel before the tap.
- This task pins the source layout instead and makes balance layout-aware (recommended design in `research.md`), keeping the source-rate pin that fixed AirPlay 2 pumping.

## Next step

Run experiments 1-4 and the passthrough check in `research.md`, then write `plan.md`.
