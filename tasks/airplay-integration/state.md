# State: AirPlay Integration

> **Purpose:** Tracks the current state of the AirPlay integration task, including what's been completed, what's in progress, and what's blocked.

**Date:** 2026-02-07
**Status:** Research Complete - Oracle Reviewed (8.5/10) - Awaiting User Approval

---

## Current Phase: Research & Planning

### Completed
- [x] Gemini research on AirPlay APIs (2025-10-30)
- [x] Oracle review #1 - 5 critical corrections (2025-10-30)
- [x] Oracle review #2 - Logo overlay validation (2025-10-30)
- [x] Webamp codebase analysis - about link overlay pattern
- [x] MacAmp codebase analysis - title bar architecture, sprite system, coordinates
- [x] Entitlements verification (network.client already exists)
- [x] Info.plist verification (no changes needed)
- [x] Consolidated research from tasks/airplay/ and tasks/winamp-airplay-overlay/
- [x] Combined plan created
- [x] Oracle review #3 (gpt-5.3-codex, xhigh) - Feasibility 8.5/10, 5 corrections applied

### In Progress
- None

### Pending
- [ ] User approval of plan
- [ ] Phase 1 implementation (AirPlayRoutePicker + engine observer)
- [ ] Phase 1 testing with real AirPlay device
- [ ] Phase 2 implementation (Now Playing integration)
- [ ] Phase 3 implementation (UX polish)

### Blocked
- None

---

## Key Decisions Made

| Decision | Rationale | Date |
|---|---|---|
| Use AVRoutePickerView only | Custom device APIs don't exist on macOS | 2025-10-30 |
| Import AVKit not AVFoundation | Oracle correction - wrong framework | 2025-10-30 |
| No Info.plist changes | NSLocalNetworkUsageDescription valid on macOS but not needed for AVRoutePickerView | 2026-02-07 |
| Transparent overlay on logo | Matches webamp pattern, maintains aesthetic | 2025-10-30 |
| Engine config observer required | Audio goes silent without it on route change | 2025-10-30 |
| Logo position at (253, 91) | Webamp reference, body area not title bar | 2026-02-07 |

---

## Architecture Verified

### Audio Pipeline (No Changes Needed)
```
AVAudioPlayerNode -> AVAudioUnitEQ -> mainMixerNode -> outputNode -> [AirPlay/Built-in]
```
- EQ preserved before routing
- AVAudioEngine supports AirPlay natively
- Only addition: engine config change observer

### Entitlements (Already Sufficient)
- `com.apple.security.network.client` - Line 32
- `com.apple.security.device.audio-output` - Line 22

### UI Architecture
- Main window: 275x116 pixels
- Title bar: 275x14 at (0, 0) - wrapped in drag handle
- Logo area: approximately (253, 91) - in body, not title bar
- Existing buttons at y:3 (minimize, shade, close) and y:25+ (clutter bar)

---

## Prior Task Context

This task consolidates:
- `tasks/airplay/` - Full AirPlay research, Oracle review, implementation plan
- `tasks/winamp-airplay-overlay/` - AVRoutePickerView overlay research, webamp pattern analysis

Both prior tasks remain as historical reference.
