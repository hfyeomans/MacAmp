# State: Video Audio Engine Routing

> **Purpose:** Route video playback audio through AVAudioEngine for EQ and visualization support
> **Created:** 2026-03-14
> **Sprint:** S3 (deferred from S2 on 2026-03-22)
> **Status:** PLANNED — Gemini deep research pending

---

## Current Status

**Phase:** Research (initial complete, deep research pending)
**Status:** PLANNED — Deferred to S3
**Last Updated:** 2026-03-22

## Deferral Decision (2026-03-22)

**Moved from S2 to S3** based on Oracle review and risk assessment:

1. **A/V sync risk is the key unknown.** MTAudioProcessingTap + ring buffer introduces an asynchronous boundary between AVPlayer's video clock and Core Audio's audio clock. Latency must stay under ~30ms to avoid perceptible desync. Needs measurement and compensation strategy.

2. **AirPlay (S2) provides shared foundation.** The engine configuration change handler (`AVAudioEngineConfigurationChange` notification) is needed by both AirPlay and video routing. Implementing AirPlay first in S2 means video routing in S3 gets this for free.

3. **No file-move conflicts.** This task doesn't touch any files that are targets of the post-S3 Structure Sprint. `VideoPlaybackController.swift` stays in `Audio/`. No XcodeGen or project.yml changes needed beyond the initial implementation.

4. **Gemini deep research recommended first.** A/V sync strategies (masterClock, AVSynchronizedLayer, pre-roll) need investigation before committing to implementation.

## Sprint Structure Impact

Moving this from S2 to S3 has no dependency conflicts:
- No other S2 task depends on video-audio-engine-routing
- The post-S2 decomposition tasks don't touch VideoPlaybackController
- The post-S3 Structure Sprint moves files but doesn't change audio routing

S3 updated lineup:
- `mainwindow-visualizer-isolation` (Small)
- `stream-pause-tail` (Small)
- `video-audio-engine-routing` (Medium-High) ← moved here
- `hls-streaming-support` (Large)
- `ogg-vorbis-support` (Medium)

---
