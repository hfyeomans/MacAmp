# TODO: AirPlay Integration

> **Purpose:** Implementation checklist for the AirPlay integration feature. Each item is actionable and maps to the plan.

**Date:** 2026-02-07
**Status:** Pending Implementation

---

## Phase 1: Core AirPlay + Engine Restart (REQUIRED)

### Prerequisites (DONE)
- [x] Verify `com.apple.security.network.client` entitlement exists
- [x] Verify `com.apple.security.device.audio-output` entitlement exists
- [x] Confirm no Info.plist changes needed
- [x] Research logo coordinates (webamp: 253, 91)

### Create AirPlayRoutePicker Component
- [ ] Create `MacAmpApp/Views/Components/AirPlayRoutePicker.swift`
- [ ] Import SwiftUI and AVKit
- [ ] Implement NSViewRepresentable with transparent AVRoutePickerView
- [ ] Set alphaValue = 0.01 (invisible but hit-testable)
- [ ] Set clear background
- [ ] Add accessibility label
- [ ] Verify compiles

### Position Over Winamp Logo
- [ ] Open `MacAmpApp/Views/WinampMainWindow.swift`
- [ ] Add AirPlay logo coordinate to Coords struct or inline
- [ ] Add AirPlayRoutePicker overlay to main ZStack
- [ ] Use `.at(CGPoint(x: 253, y: 91))` positioning
- [ ] Set frame to 24x24 (accessibility minimum)
- [ ] Add `.contentShape(Rectangle())` for hit testing
- [ ] Verify doesn't overlap other controls
- [ ] Visual test: confirm overlay aligns with logo

### Add Engine Configuration Observer (CRITICAL)
- [ ] Open `MacAmpApp/Audio/AudioPlayer.swift`
- [ ] Add `setupEngineConfigurationObserver()` method
- [ ] Observe `.AVAudioEngineConfigurationChange` notification
- [ ] Implement `handleEngineConfigurationChange()` method
- [ ] Save playback state when triggered (currentTime, isPlaying)
- [ ] Stop and restart engine
- [ ] Resume playback from saved position if was playing
- [ ] Call setup method in init/setup
- [ ] Use `[weak self]` to prevent retain cycles

### Build & Test
- [ ] Build with Thread Sanitizer enabled
- [ ] Launch app - verify no visible change to logo
- [ ] Click logo area - verify AirPlay picker popover appears
- [ ] Test with real AirPlay device
- [ ] Verify audio routes to AirPlay device
- [ ] Verify EQ still works on AirPlay
- [ ] Switch back to built-in speakers
- [ ] Test engine restart: switch output while playing
- [ ] Edge case: device disconnection during playback
- [ ] Edge case: network interruption

---

## Phase 2: Now Playing Integration (OPTIONAL)

### MPNowPlayingInfoCenter
- [ ] Add `import MediaPlayer` to AudioPlayer.swift
- [ ] Create `updateNowPlayingInfo()` method
- [ ] Set track title, artist, album
- [ ] Set duration and elapsed time
- [ ] Set playback rate (1.0 / 0.0)
- [ ] Optional: set album artwork
- [ ] Call on track change
- [ ] Call on play/pause/stop
- [ ] Call on time updates (every second)

### MPRemoteCommandCenter
- [ ] Create `setupRemoteCommands()` method
- [ ] Implement play command handler
- [ ] Implement pause command handler
- [ ] Implement toggle play/pause handler
- [ ] Implement next track handler
- [ ] Implement previous track handler
- [ ] Optional: implement seek handler
- [ ] Call in init

### Test System Integration
- [ ] Play track - check Control Center
- [ ] Verify track info displays correctly
- [ ] Test keyboard play/pause
- [ ] Test keyboard next/previous
- [ ] Verify progress bar updates
- [ ] Test with AirPlay active

---

## Phase 3: UX Polish (OPTIONAL)

- [ ] Handle shade mode (logo not visible at 275x14)
- [ ] Handle double-size mode (coordinates may need scaling)
- [ ] Consider tooltip on logo hover for discoverability
- [ ] Consider keyboard shortcut (Cmd+Shift+A)
- [ ] Test with multiple skins (verify logo position)
- [ ] Consider adding visual AirPlay status indicator somewhere

---

## Documentation
- [ ] Update state.md with implementation status
- [ ] Document any deviations from plan
- [ ] Note any issues discovered during implementation
- [ ] Update task to done when complete
