# TODO: AirPlay Integration

> **Purpose:** Implementation checklist derived from plan.md. Each item is actionable.

**Date:** 2026-02-07 (original), **Updated:** 2026-03-23
**Status:** Pending Implementation

---

## Prerequisites (DONE)

- [x] Verify `com.apple.security.network.client` entitlement exists
- [x] Verify `com.apple.security.device.audio-output` entitlement exists
- [x] Confirm no Info.plist changes needed
- [x] Research logo coordinates (webamp: 253, 91)
- [x] Identify dual-trigger approach (bolt primary + logo secondary)
- [x] Identify time display hit area bug (prerequisite for bolt trigger)
- [x] Oracle plan review — Round 1: 7/10, Round 2: 8/10, Round 3: 8/10 (3 refinements)

---

## Phase 0: Fix Time Display Hit Area Bug

### MainWindowFullLayer (full mode)
- [ ] Add `.frame(width: 56, height: 13)` after ZStack to set full MM:SS bounds
- [ ] Move `.contentShape(Rectangle())` and `.onTapGesture` BEFORE `.at(Layout.timeDisplay)`
- [ ] Verify: clicking time digits toggles elapsed/remaining (all 4 digits)
- [ ] Verify: clicking bolt icon area does NOT toggle time display

### MainWindowShadeLayer (shade mode)
- [ ] Add `.frame(width: 56, height: 13)` after ZStack to set full MM:SS bounds
- [ ] Move `.contentShape(Rectangle())` and `.onTapGesture` BEFORE `.at(Layout.timeDisplay).scaleEffect(0.7).at(...)`
- [ ] Verify: clicking shade time digits toggles elapsed/remaining
- [ ] Verify: clicking shade bolt area does NOT toggle time display

### Build & Test
- [ ] XcodeBuildMCP build — no compiler errors
- [ ] XcodeBuildMCP test — all tests pass

---

## Phase 1: Core AirPlay + Engine Restart

### Create AirPlayRoutePicker Component
- [ ] Create `MacAmpApp/Views/Components/AirPlayRoutePicker.swift`
- [ ] Import SwiftUI and AVKit (NOT AVFoundation)
- [ ] Implement NSViewRepresentable wrapping AVRoutePickerView
- [ ] Set `isRoutePickerButtonBordered = false`
- [ ] Set `alphaValue = 0.01` (invisible but hit-testable)
- [ ] Set `setRoutePickerButtonColor(.clear, for: .normal)`
- [ ] Set `toolTip = "AirPlay"`
- [ ] Verify compiles

### Add Layout Constants
- [ ] Add `airPlayBolt` coordinate to `WinampMainWindowLayout.swift` (~3, 1)
- [ ] Add `airPlayBoltSize` to `WinampMainWindowLayout.swift` (12x12)
- [ ] Add `airPlayLogo` coordinate to `WinampMainWindowLayout.swift` (~249, 87)
- [ ] Add `airPlayLogoSize` to `WinampMainWindowLayout.swift` (26x20)

### Position Primary Trigger (bolt icon — both modes)
- [ ] Add AirPlayRoutePicker overlay as LAST child of ZStack in `WinampMainWindow.swift`
- [ ] Must be LAST = highest z-order (above drag handle AND shade/full layers)
- [ ] Frame: `Layout.airPlayBoltSize`, position: `Layout.airPlayBolt`
- [ ] Verify doesn't interfere with titlebar drag (small 12x12 area)
- [ ] Verify works in full mode
- [ ] Verify works in shade mode

### Position Secondary Trigger (WA logo — full mode only)
- [ ] Add AirPlayRoutePicker overlay to Group in `MainWindowFullLayer.swift`
- [ ] Frame: `Layout.airPlayLogoSize`, position: `Layout.airPlayLogo`
- [ ] Verify auto-hides in shade mode (MainWindowFullLayer not rendered)
- [ ] Verify doesn't overlap repeat button (211, 89) or other controls

### Add Engine Configuration Observer (CRITICAL)
- [ ] Add `AVAudioEngine.configurationChangeNotification` observer in `AudioEngineController.swift`
- [ ] Dispatch to `@MainActor` via `Task` (fires on arbitrary queue)
- [ ] Add `onWillReconfigure` callback property
- [ ] Add `onDidReconfigure` callback property
- [ ] Implement `handleEngineConfigurationChange()`:
  - [ ] Fire `onWillReconfigure()`
  - [ ] Save engine running state
  - [ ] Stop engine
  - [ ] If stream bridge active: disconnect/reconnect source node path
  - [ ] If local file playing: reconnect player node path
  - [ ] Restart engine (`try engine.start()`)
  - [ ] Fire `onDidReconfigure()`

### Wire Engine Reconfiguration in AudioPlayer
- [ ] Wire `engine.onWillReconfigure` in AudioPlayer init
  - [ ] Set `seekGuardActive = true`
  - [ ] Set `isHandlingCompletion = true`
  - [ ] Save `currentTime` for resume
- [ ] Wire `engine.onDidReconfigure` in AudioPlayer init
  - [ ] Re-apply volume and balance
  - [ ] If was playing local: seek to saved position, resume
  - [ ] Fire `onEngineReconfigured` callback
  - [ ] Clear `seekGuardActive` after 100ms delay
  - [ ] Clear `isHandlingCompletion` after 200ms delay
- [ ] Add `onEngineReconfigured` callback property on AudioPlayer

### Wire Stream Workgroup Refresh in PlaybackCoordinator
- [ ] Wire `audioPlayer.onEngineReconfigured` in PlaybackCoordinator init
- [ ] If stream bridge active: call `streamPlayer.setAudioWorkgroup(audioPlayer.audioWorkgroup)`

### Build & Test Phase 1
- [ ] XcodeBuildMCP build with Thread Sanitizer — no warnings
- [ ] XcodeBuildMCP test — all tests pass
- [ ] Launch app — no visible change to bolt or logo areas
- [ ] Click top-left bolt — AirPlay picker appears
- [ ] Click bottom-right WA logo — AirPlay picker appears
- [ ] Test with real AirPlay device (local file playback)
- [ ] Verify EQ processing maintained on AirPlay
- [ ] Switch back to built-in speakers
- [ ] Test engine restart: switch output while playing
- [ ] Test stream playback over AirPlay
- [ ] Test AirPlay in shade mode (bolt trigger)
- [ ] Edge case: AirPlay device disconnection
- [ ] Edge case: switch output while paused, then resume

### Oracle Review Phase 1
- [ ] Submit Phase 1 implementation to Oracle for code review

---

## Phase 2: Now Playing Integration

### MPNowPlayingInfoCenter
- [ ] Add `import MediaPlayer` to PlaybackCoordinator.swift
- [ ] Implement `updateNowPlayingInfo()` method
  - [ ] Set title (`displayTitle`)
  - [ ] Set artist (`displayArtist`)
  - [ ] Set elapsed time (`displayTime`)
  - [ ] Set duration (`displayDuration`, 0 for streams)
  - [ ] Set playback rate (1.0 / 0.0)
  - [ ] Set explicit `playbackState` (.playing / .paused / .stopped) — REQUIRED on macOS
- [ ] Implement `clearNowPlayingInfo()` method
  - [ ] Set `nowPlayingInfo = nil`
  - [ ] Set `playbackState = .stopped`
- [ ] Call `updateNowPlayingInfo()` at all 9 transition points:
  - [ ] `play(track:)`
  - [ ] `play(station:)`
  - [ ] `pause()`
  - [ ] `stop()` (via `clearNowPlayingInfo()`)
  - [ ] `resume()`
  - [ ] `handlePlaylistAdvance(action:)`
  - [ ] `updateTrackMetadata(_:)`
  - [ ] StreamPlayer `onStateChange` callback
  - [ ] StreamPlayer `onMetadataChanged` callback (NEW)

### MPRemoteCommandCenter
- [ ] Implement `setupRemoteCommands()` in PlaybackCoordinator
- [ ] All handlers dispatch via `Task { @MainActor }`:
  - [ ] play → `resume()`
  - [ ] pause → `pause()`
  - [ ] togglePlayPause → `togglePlayPause()`
  - [ ] nextTrack → `next()`
  - [ ] previousTrack → `previous()`
  - [ ] changePlaybackPosition → `audioPlayer.seek(to:)`
- [ ] Disable seek command when `currentSource == .radioStation`
- [ ] Re-enable seek command when switching to local playback
- [ ] Evaluate command enablement during testing: skip forward/backward, seek, repeat, shuffle — MacAmp has UI for these already, decide which to wire vs disable based on Control Center space
- [ ] Call `setupRemoteCommands()` from init

### Stream Metadata Callback
- [ ] Add `onMetadataChanged` callback to StreamPlayer
- [ ] Fire from ICY metadata handler (alongside streamTitle/streamArtist updates)
- [ ] Wire in PlaybackCoordinator init → calls `updateNowPlayingInfo()`

### Build & Test Phase 2
- [ ] XcodeBuildMCP build with Thread Sanitizer — no warnings
- [ ] XcodeBuildMCP test — all tests pass
- [ ] Play local file — Control Center shows title/artist/progress
- [ ] Play internet radio — Control Center shows stream title
- [ ] Keyboard play/pause — works
- [ ] Keyboard next/previous — advances playlist
- [ ] Seek via Control Center — works for local files
- [ ] Seek disabled for streams
- [ ] ICY metadata change — Control Center updates
- [ ] Switch local → stream → local — Now Playing updates each time
- [ ] Stop playback — Now Playing clears
- [ ] Test with AirPlay active

### Oracle Review Phase 2
- [ ] Submit Phase 2 implementation to Oracle for code review

---

## Phase 3: Discoverability & UX Polish

### Options Menu Hint
- [ ] Add disabled `NSMenuItem` to `MainWindowOptionsMenuPresenter`
- [ ] Text: "AirPlay: click bolt icon" (or similar)
- [ ] `isEnabled = false` — informational only

### Verification
- [ ] Tooltip shows "AirPlay" on bolt hover (full mode)
- [ ] Tooltip shows "AirPlay" on bolt hover (shade mode)
- [ ] Tooltip shows "AirPlay" on WA logo hover (full mode)
- [ ] Options menu includes AirPlay hint
- [ ] Double-size mode — both triggers work
- [ ] Test with 3+ different skins — bolt position consistent
- [ ] Test with 3+ different skins — WA logo overlay reasonable

---

## Documentation & Closeout

- [ ] Update state.md with final status
- [ ] Create docs-update-needed.md for architecture docs
- [ ] Check for deprecated code → depreciated.md
- [ ] Check for placeholders → placeholder.md
- [ ] Update shared _context/state.md and tasks_index.md
- [ ] Final Oracle review of complete implementation
- [ ] Create PR
