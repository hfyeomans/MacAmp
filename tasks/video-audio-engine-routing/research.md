# Research: Video Audio Engine Routing

> **Purpose:** Research MTAudioProcessingTap and AVAudioEngine integration for routing video playback audio through the engine graph.

**Status:** Pending research/planning.

---

## Context

Video currently uses AVPlayer directly — audio bypasses the AVAudioEngine graph. MTAudioProcessingTap works with local file AVPlayerItems (unlike streaming items where it failed for T5 Phase 2). This would unify ALL audio through the engine, enabling EQ/visualization for video playback.

---
