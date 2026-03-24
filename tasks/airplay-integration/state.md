# State: AirPlay Integration

> **Purpose:** Tracks the current state of the AirPlay integration task.

**Date:** 2026-02-07
**Sprint:** S2 (MEDIUM)
**Status:** Plan Updated — Oracle Reviewed (8/10) — Ready for user approval + commit + branch
**Last Updated:** 2026-03-23

---

## Current Phase: Planning (final review)

### Completed
- [x] Gemini research on AirPlay APIs (2025-10-30)
- [x] Oracle review #1 — 5 critical corrections (2025-10-30)
- [x] Oracle review #2 — Logo overlay validation (2025-10-30)
- [x] Webamp codebase analysis — about link overlay pattern
- [x] MacAmp codebase analysis — title bar architecture, sprite system, coordinates
- [x] Entitlements verification (network.client + audio-output already exist)
- [x] Info.plist verification (no changes needed)
- [x] Consolidated research from tasks/airplay/ and tasks/winamp-airplay-overlay/
- [x] Combined plan created
- [x] Oracle review #3 (gpt-5.3-codex, xhigh) — Feasibility 8.5/10
- [x] Plan updated for current codebase (2026-03-23) — three-layer alignment, coordinator-level Now Playing
- [x] Oracle review #4 (gpt-5.4, xhigh) — 7/10, 7 corrections applied
- [x] Oracle review #5 (gpt-5.4, xhigh) — 8/10, 4 spec gaps fixed
- [x] Identified time display hit area bug (prerequisite for bolt trigger)
- [x] Dual-trigger approach: bolt primary + WA logo secondary
- [x] Full codebase research via sub-agents (AudioPlayer, PlaybackCoordinator, StreamPlayer, WinampMainWindow, layouts)
- [x] Todos rewritten from updated plan

- [x] Oracle review #6 (gpt-5.4, xhigh) — 8/10, 3 refinements applied (frame sizing, z-order, buffering state)

### In Progress
- [ ] User approval of plan → commit → create feature branch

### Pending
- [ ] Commit plan + create feature branch
- [ ] Phase 0: Fix time display hit area bug (full + shade)
- [ ] Phase 1: Core AirPlay (dual triggers + engine observer)
- [ ] Phase 2: Now Playing + remote commands
- [ ] Phase 3: Discoverability polish
- [ ] Manual testing with AirPlay devices
- [ ] PR creation

---

## Key Decisions Made

| Decision | Rationale | Date |
|---|---|---|
| Use AVRoutePickerView only | Custom device APIs don't exist on macOS (Oracle-confirmed) | 2025-10-30 |
| Import AVKit not AVFoundation | Oracle correction — wrong framework | 2025-10-30 |
| No Info.plist or entitlement changes | Already has network.client + audio-output | 2026-02-07 |
| Dual-trigger: bolt (primary) + logo (secondary) | Bolt is skin-independent + works in shade; logo matches webamp pattern | 2026-03-23 |
| Engine observer in AudioEngineController | Mechanism layer owns engine; will/did callbacks for AudioPlayer coordination | 2026-03-23 |
| Now Playing in PlaybackCoordinator | Bridge layer has unified state across both backends | 2026-03-23 |
| Fix time display hit area first | `.contentShape()` after `.at()` bug blocks bolt trigger | 2026-03-23 |
| All remote handlers via `Task { @MainActor }` | All model classes are @MainActor; handlers fire on arbitrary thread | 2026-03-23 |
| Explicit `playbackState` on macOS | Required by MPNowPlayingInfoCenter.h for remote control to work | 2026-03-23 |
| No periodic Now Playing timer | Apple auto-extrapolates elapsed time from rate | 2026-03-23 |

---

## Architecture

### Audio Pipeline (No Changes to Graph)
```
AVAudioPlayerNode → AVAudioUnitEQ → mainMixerNode → outputNode → [AirPlay/Built-in]
```
- EQ preserved before routing
- Engine config change observer handles route changes
- Stream bridge (AVAudioSourceNode) reconnected on config change

### Entitlements (Already Sufficient)
- `com.apple.security.network.client`
- `com.apple.security.device.audio-output`

### UI Triggers
- Primary: top-left bolt icon (~3, 1) — 12x12 — in titlebar, both modes
- Secondary: bottom-right WA logo (~249, 87) — 26x20 — in body, full mode only

---

## Prior Task Context

Consolidates:
- `tasks/airplay/` — Full AirPlay research, Oracle review, implementation plan
- `tasks/winamp-airplay-overlay/` — AVRoutePickerView overlay research, webamp pattern analysis
