# State: AirPlay Integration

> **Purpose:** Tracks the current state of the AirPlay integration task.

**Date:** 2026-02-07
**Sprint:** S2 (MEDIUM)
**Status:** COMPLETE — PR #69 merged (2026-03-24)
**Last Updated:** 2026-03-24

---

## Current Phase: Reassessing scope after Phase 1 failure

### Completed
- [x] Gemini research on AirPlay APIs (2025-10-30)
- [x] Oracle reviews #1-6 (2025-10-30 through 2026-03-23)
- [x] Webamp + MacAmp codebase analysis
- [x] Entitlements verification (network.client + audio-output already exist)
- [x] Consolidated research from prior tasks
- [x] Plan created with dual-trigger approach (Oracle 8/10)
- [x] Phase 0: Fix time display hit area bug (full + shade modes)
- [x] Phase 0: Digit positioning refinement
- [x] Phase 0: Black mask removal (documented in depreciated.md)
- [x] Phase 1 ATTEMPTED: AVRoutePickerView dual triggers + engine observer
- [x] Phase 1 FAILED: AVRoutePickerView doesn't route AVAudioEngine audio on macOS
- [x] Gemini deep research: AVRoutePickerView failure analysis, HAL routing, AVPlayer rewrite, per-app routing

### Blocked
- [x] Phase 1 AirPlay triggers — AVRoutePickerView is designed for AVPlayer per-app routing, NOT system-wide output switching for AVAudioEngine

### Still Viable (Future Work)
- [ ] Engine config observer (needed when users switch output via macOS Control Center — deferred)

### Complete
- [x] Phase 2: Now Playing + remote commands — Oracle 9/10, manual testing passed
  - MPNowPlayingInfoCenter with explicit playbackState
  - MPRemoteCommandCenter with @MainActor dispatch
  - 10 trigger points, smart command enablement, lifecycle cleanup
  - Keyboard media keys, Bluetooth headphones, Control Center transport all verified

### Defunct
- Phase 1: AirPlay triggers (AVRoutePickerView + dual overlays) — ABANDONED
- Phase 3: Discoverability UX (no in-app AirPlay button to discover) — ABANDONED

---

## Critical Finding: AVRoutePickerView + AVAudioEngine Incompatibility

**Date:** 2026-03-24
**Source:** Phase 1 implementation testing + Gemini deep research

### The Problem

`AVRoutePickerView` on macOS is designed to route a specific `AVPlayer` instance's audio over AirPlay 2. It is NOT a generic "change system output" button.

| Test | Result | Why |
|---|---|---|
| AVRoutePickerView alone (no player) | UI only, no routing | Picker requires `.player` property to know what to route |
| AVRoutePickerView + empty AVPlayer | TV connects, system default unchanged | Establishes per-app route for that AVPlayer only |
| AVRoutePickerView + silent AVPlayer | FigFilePlayer errors | AVPlayer optimizes out silent/empty tracks |
| AirPlay devices in HAL | Not visible | AirPlay devices hidden from Core Audio HAL until system-wide route established |
| Engine config notification | Never fires | System default never changed, so AVAudioEngine sees no hardware change |

### Root Cause

- **iOS:** `AVAudioSession` is global per app. Route changes affect everything including `AVAudioEngine`.
- **macOS:** No global `AVAudioSession`. `AVPlayer` routing is isolated per-instance. `AVAudioEngine` routing is tied to Core Audio HAL (hardware devices). They are completely separate worlds.

### Paths Evaluated

| Path | Viable? | Trade-off |
|---|---|---|
| System-wide AirPlay (Control Center) | YES | Users switch via macOS UI, not in-app. Engine config observer handles restart. EQ/visualizer preserved. |
| AVPlayer rewrite | NO (too costly) | Lose 10-band EQ, lose custom StreamDecodePipeline, lose ICY metadata, rewrite visualizer |
| AVSampleBufferAudioRenderer | NO (too costly) | Massive rewrite, poor EQ compatibility |
| Core Audio HAL device selection | PARTIAL | AirPlay 1 only, no AirPlay 2 multi-room, fragile, custom UI needed |
| Custom virtual audio driver | NO (out of scope) | Airfoil-level complexity |

### Decision

**Accept system-wide AirPlay routing.** Users switch output via macOS Control Center. MacAmp handles the engine config change notification to restart seamlessly. EQ, visualizer, and custom streaming pipeline are all preserved.

No in-app AirPlay trigger button. The bolt icon and WA logo overlays are not needed.

---

## Key Decisions Made

| Decision | Rationale | Date |
|---|---|---|
| AVRoutePickerView approach | ABANDONED — doesn't work with AVAudioEngine on macOS | 2026-03-24 |
| System-wide AirPlay via Control Center | Only viable path that preserves EQ + visualizer + streaming | 2026-03-24 |
| Engine config observer still needed | Handles route changes from macOS Control Center | 2026-03-24 |
| Now Playing in PlaybackCoordinator | Bridge layer, independent of AirPlay trigger method | 2026-03-23 |
| Phase 0 time display bugfix | Shipped — `.contentShape()` before `.at()`, explicit frame | 2026-03-24 |

---

## Architecture (Revised)

### Audio Pipeline (No Changes to Graph)
```
AVAudioPlayerNode → AVAudioUnitEQ → mainMixerNode → outputNode → [System Default Output]
```
- When user switches to AirPlay via macOS Control Center, system default changes
- AVAudioEngine fires configurationChangeNotification
- Engine restarts with new output format
- EQ, visualizer, stream bridge all preserved through restart

### What's Still Needed (Future Work)
1. **Engine config observer** — handle route changes when users switch output via macOS Control Center (deferred)

### Completed
2. ~~**Now Playing**~~ — DONE. MPNowPlayingInfoCenter + MPRemoteCommandCenter in PlaybackCoordinator (Oracle 9/10)
3. **No in-app AirPlay UI** — users use macOS Control Center (accepted limitation)

---

## Prior Task Context

Consolidates:
- `tasks/airplay/` — Original AirPlay research
- `tasks/winamp-airplay-overlay/` — AVRoutePickerView overlay research (approach abandoned)
- `research-gemini-avroutepicker-failure.md` — Why AVRoutePickerView fails with AVAudioEngine
- `research-gemini-airplay-hal.md` — AirPlay devices hidden from Core Audio HAL
- `research-avplayer-rewrite.md` — AVPlayer rewrite evaluation (rejected)
- `research-per-app-routing.md` — Per-app routing options evaluation
