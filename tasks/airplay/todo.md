# AirPlay Integration - Implementation Checklist

**Date:** 2025-10-30
**Status:** Oracle-Reviewed - Scope Corrected - Ready for Implementation

---

## ⚠️ Oracle Corrections Applied

**Gemini Research:** 60% accurate
**Oracle Review:** ✅ Complete - 5 critical issues fixed
**Scope Changed:** Custom UI removed (APIs don't exist)

### Key Changes:
1. ✅ AVKit framework (not AVFoundation)
2. ❌ Phase 3 removed (custom UI impossible)
3. ❌ NSLocalNetworkUsageDescription not needed
4. ✅ Added critical engine restart logic
5. ✅ Entitlements already sufficient

---

## Progress Summary

**Research:** ✅ Complete (Gemini + Oracle corrections)
**Planning:** ✅ Complete (Oracle-reviewed)
**Oracle Review:** ✅ Complete - All issues fixed
**Entitlements:** ✅ Verified - No changes needed
**Implementation:** ⏸️ Ready to begin

**Revised Total Time:** 2-4 hours (not 7+)
- Phase 1 (AVRoutePickerView + Engine Restart): 2 hours
- Phase 2 (Now Playing - Optional): 2 hours
- Phase 3: REMOVED (not possible)

---

## Prerequisites ✅ VERIFIED

### ✅ Entitlements Check (COMPLETE)
- [x] ✅ `com.apple.security.network.client` EXISTS
  - File: `MacAmpApp/MacAmp.entitlements` Line 32
  - Status: Set to `<true/>`
  - **No changes needed** ✅

- [x] ✅ `com.apple.security.device.audio-output` EXISTS
  - File: `MacAmpApp/MacAmp.entitlements` Line 22
  - Status: Set to `<true/>`
  - **No changes needed** ✅

### ✅ Architecture Verification (COMPLETE)
- [x] ✅ AudioPlayer uses AVAudioEngine
  - File: `MacAmpApp/Audio/AudioPlayer.swift`
  - Confirmed: AVAudioEngine, AVAudioPlayerNode, AVAudioUnitEQ
  - Graph: playerNode → eqNode → mainMixerNode → outputNode ✅

### ✅ No Info.plist Changes Needed
- [x] ✅ Oracle confirmed: NSLocalNetworkUsageDescription NOT needed on macOS
  - Gemini was wrong (iOS-only key)
  - **Don't add anything to Info.plist** ✅

---

## Phase 1: AVRoutePickerView + Engine Restart (2 hours)

### Step 1: Verify Prerequisites ✅ ALREADY COMPLETE

- [x] ✅ **Entitlements verified** - No changes needed
  - network.client already exists (Line 32)
  - audio-output already exists (Line 22)

- [x] ✅ **Info.plist verified** - No changes needed
  - Oracle: NSLocalNetworkUsageDescription NOT needed on macOS
  - Gemini was wrong

### Step 2: Create AirPlayPickerView Component (Oracle-Corrected)

- [ ] **Create new Swift file**
  - [ ] Create: `MacAmpApp/Views/Components/AirPlayPickerView.swift`
  - [ ] Import: SwiftUI, **AVKit** (✅ NOT AVFoundation!), AppKit
  - [ ] Define struct conforming to NSViewRepresentable

- [ ] **Implement makeNSView (Minimal - Oracle says properties don't exist)**
  - [ ] Create AVRoutePickerView instance
  - [ ] Return picker immediately
  - [ ] ❌ DON'T set isRouteDetectionEnabled (doesn't exist on macOS)
  - [ ] ❌ DON'T set routePickerButtonStyle (doesn't exist on macOS)
  - [ ] ❌ DON'T customize colors (not possible on macOS)

- [ ] **Code should be ~10 lines total:**
  ```swift
  import SwiftUI
  import AVKit  // ✅ CORRECT

  struct AirPlayPickerView: NSViewRepresentable {
      func makeNSView(context: Context) -> AVRoutePickerView {
          return AVRoutePickerView()
      }
      func updateNSView(_ nsView: AVRoutePickerView, context: Context) {}
  }
  ```

- [ ] **Test component compiles**
  - [ ] Build project
  - [ ] Fix any errors

### Step 3: Integrate into WinampMainWindow

- [ ] **Add AirPlay button coordinate**
  - [ ] Open `MacAmpApp/Views/WinampMainWindow.swift`
  - [ ] Add to Coords struct (Lines 75-81):
    ```swift
    static let airPlayButton = CGPoint(x: 107, y: 40)
    ```
  - [ ] Or choose different position

- [ ] **Create buildAirPlayButton method**
  - [ ] Add new method after buildBalanceSlider()
  - [ ] Return AirPlayPickerView with frame
  - [ ] Use `.at()` modifier for positioning
  - [ ] Pattern: Follow existing builder methods

- [ ] **Call in buildFullWindow**
  - [ ] Add call after buildBalanceSlider()
  - [ ] Verify doesn't overlap other elements

### Step 4: Add Engine Configuration Observer (CRITICAL - Oracle Required)

- [ ] **Add observer setup method to AudioPlayer.swift**
  - [ ] Create `setupEngineConfigurationObserver()` method
  - [ ] Observe AVAudioEngineConfigurationChange notification
  - [ ] Pass audioEngine as object parameter
  - [ ] Use .main queue for @MainActor safety
  - [ ] Store observer reference for cleanup

- [ ] **Implement engine restart handler**
  - [ ] Create `handleEngineConfigurationChange()` method
  - [ ] Mark `@MainActor`
  - [ ] Check if currently playing
  - [ ] If playing: Save currentTime and currentTrack
  - [ ] Stop engine: `audioEngine.stop()`
  - [ ] Start engine: `try? audioEngine.start()`
  - [ ] If was playing: Rewire graph and resume from saved time
  - [ ] If not playing: Just restart engine for next playback

- [ ] **Call setup in AudioPlayer init()**
  - [ ] Add `setupEngineConfigurationObserver()` call
  - [ ] Verify called once on initialization

- [ ] **Critical Code (~30 lines):**
  ```swift
  // In AudioPlayer.swift

  private func setupEngineConfigurationObserver() {
      NotificationCenter.default.addObserver(
          forName: .AVAudioEngineConfigurationChange,
          object: audioEngine,
          queue: .main
      ) { [weak self] _ in
          self?.handleEngineConfigurationChange()
      }
  }

  private func handleEngineConfigurationChange() {
      // Route changed (e.g., AirPlay connect/disconnect)
      // Engine stops - MUST restart!

      if isPlaying {
          let savedTime = currentTime
          audioEngine.stop()
          try? audioEngine.start()
          seekToPercent(savedTime / (currentTrack?.duration ?? 1.0), resume: true)
      } else {
          try? audioEngine.start()
      }
  }
  ```

- [ ] **Test engine restart works**
  - [ ] Add debug print to handleEngineConfigurationChange
  - [ ] Trigger by changing output device in System Settings
  - [ ] Verify method is called
  - [ ] Verify playback continues

### Step 5: Build and Test

- [ ] **Build project**
  - [ ] Fix any compilation errors
  - [ ] Ensure Swift 6 concurrency compliant

- [ ] **Launch app**
  - [ ] Verify AirPlay button appears
  - [ ] Check button positioning
  - [ ] Look for system AirPlay icon

- [ ] **Test permission dialog**
  - [ ] Click AirPlay button (first time)
  - [ ] Verify permission dialog appears
  - [ ] Check dialog shows correct description
  - [ ] Grant permission

- [ ] **Test device discovery**
  - [ ] Click AirPlay button
  - [ ] Verify device list appears
  - [ ] Check your AirPlay device is listed
  - [ ] Check "This Mac" (built-in) is listed

- [ ] **Test audio routing**
  - [ ] Select AirPlay device
  - [ ] Play music
  - [ ] Verify audio plays on AirPlay speaker
  - [ ] Verify no audio on Mac speakers

- [ ] **Test EQ processing**
  - [ ] Open equalizer window
  - [ ] Adjust EQ bands while playing
  - [ ] Verify EQ changes audible on AirPlay
  - [ ] **CRITICAL:** Confirm EQ is maintained

- [ ] **Test device switching**
  - [ ] Switch back to "This Mac"
  - [ ] Verify audio on built-in speakers
  - [ ] Switch to AirPlay again
  - [ ] Verify seamless transition

### Step 5: Edge Case Testing

- [ ] **Device disconnection**
  - [ ] Play music on AirPlay device
  - [ ] Unplug/power off AirPlay device
  - [ ] Verify app doesn't crash
  - [ ] Verify falls back to built-in speakers

- [ ] **Network interruption**
  - [ ] Play on AirPlay
  - [ ] Disable Wi-Fi on Mac
  - [ ] Verify graceful handling
  - [ ] Re-enable Wi-Fi
  - [ ] Verify can reconnect

- [ ] **Multi-room audio (if available)**
  - [ ] Select 2+ AirPlay devices
  - [ ] Verify audio plays on both
  - [ ] Verify synchronized playback
  - [ ] Verify EQ applied to both

---

## Phase 2: System Media Integration (2 hours)

### Step 1: Add MediaPlayer Framework

- [ ] **Import MediaPlayer**
  - [ ] Open `MacAmpApp/Audio/AudioPlayer.swift`
  - [ ] Add: `import MediaPlayer`
  - [ ] Verify builds

### Step 2: Implement Now Playing Info

- [ ] **Create updateNowPlayingInfo method**
  - [ ] Mark `@MainActor`
  - [ ] Get current track
  - [ ] Create nowPlayingInfo dictionary
  - [ ] Set title, artist, album
  - [ ] Set duration and elapsed time
  - [ ] Set playback rate (1.0 or 0.0)
  - [ ] Optional: Add artwork
  - [ ] Update MPNowPlayingInfoCenter

- [ ] **Call on track changes**
  - [ ] Find track change location
  - [ ] Add updateNowPlayingInfo() call

- [ ] **Call on play/pause**
  - [ ] In play() method
  - [ ] In pause() method
  - [ ] In stop() method

- [ ] **Call on time updates**
  - [ ] Every second during playback
  - [ ] Update elapsed time only

### Step 3: Implement Remote Commands

- [ ] **Create setupRemoteCommands method**
  - [ ] Mark `@MainActor`
  - [ ] Get MPRemoteCommandCenter.shared()

- [ ] **Implement play command**
  - [ ] Enable command
  - [ ] Add target handler
  - [ ] Call self.play()
  - [ ] Return .success

- [ ] **Implement pause command**
  - [ ] Enable command
  - [ ] Add target handler
  - [ ] Call self.pause()
  - [ ] Return .success

- [ ] **Implement toggle play/pause**
  - [ ] Enable command
  - [ ] Add target handler
  - [ ] Call self.togglePlayPause()
  - [ ] Return .success

- [ ] **Implement next track**
  - [ ] Enable command
  - [ ] Add target handler
  - [ ] Call self.nextTrack()
  - [ ] Return .success

- [ ] **Implement previous track**
  - [ ] Enable command
  - [ ] Add target handler
  - [ ] Call self.previousTrack()
  - [ ] Return .success

- [ ] **Implement seek command (optional)**
  - [ ] Enable changePlaybackPositionCommand
  - [ ] Cast event to MPChangePlaybackPositionCommandEvent
  - [ ] Calculate seek percentage
  - [ ] Call self.seekToPercent()
  - [ ] Return .success

- [ ] **Call setupRemoteCommands in init**
  - [ ] Add call in AudioPlayer init()
  - [ ] Verify commands don't interfere with UI

### Step 4: Test System Integration

- [ ] **Control Center**
  - [ ] Play track
  - [ ] Open Control Center
  - [ ] Verify "Now Playing" shows MacAmp
  - [ ] Check track title correct
  - [ ] Check artist correct
  - [ ] Check artwork displays (if added)
  - [ ] Check progress bar updates

- [ ] **Keyboard Controls**
  - [ ] Press media play/pause key
  - [ ] Verify app responds
  - [ ] Press next track key
  - [ ] Verify skips to next
  - [ ] Press previous track key
  - [ ] Verify goes to previous

- [ ] **Menu Bar**
  - [ ] Check macOS menu bar music controls
  - [ ] Verify shows current track
  - [ ] Test controls from menu bar

---

## ❌ Phase 3A: Custom Device Menu - CANCELLED (Oracle: APIs Don't Exist)

**Gemini Claimed:** Could build custom device selection menu
**Oracle Found:** APIs don't exist on macOS - NOT POSSIBLE

**What Doesn't Work:**
- `audioEngine.outputNode.setDeviceID()` - Method doesn't exist
- Custom device list menu - Can't enumerate AirPlay devices

**Decision:** Removed - APIs don't exist

---

## ✅ Phase 3B: Winamp Logo Overlay (Oracle-Approved Alternative)

**Oracle Confirmed:** CAN position AVRoutePickerView over Winamp logo! ✅

**Approach (Like webamp.org "about" link):**
- Position transparent AVRoutePickerView over Winamp logo
- User clicks logo → AirPlay menu appears
- Logo sprite is the visual (picker is invisible)
- Matches webamp pattern

**Webamp Reference:**
```tsx
// index.tsx Line 129-134
<a id="about" href="https://webamp.org/about" title="About" />

// CSS Line 394-399
#about {
  position: absolute;
  top: 91px;
  left: 253px;
  height: 15px;
  width: 13px;
}
```

### Implementation Tasks (1-2 hours)

- [ ] **Find Winamp logo coordinates in MacAmp**
  - [ ] Check WinampMainWindow.swift for logo sprite position
  - [ ] Identify logo size (width × height)
  - [ ] Note: Logo is part of MAIN_TITLE_BAR sprite

- [ ] **Create transparent AVRoutePickerView overlay**
  - [ ] Use Oracle's code example (see ORACLE_REVIEW.md)
  - [ ] Set alphaValue = 0.01 (invisible but clickable)
  - [ ] Clear background color
  - [ ] Enable hit testing

- [ ] **Position over logo**
  - [ ] Use .at() modifier with logo coordinates
  - [ ] Frame size: 24×24 (accessibility minimum per Oracle)
  - [ ] Ensure doesn't overlap other clickable elements
  - [ ] Test click area activates picker

- [ ] **Oracle's Code Pattern:**
  ```swift
  // Create transparent picker
  struct AirPlayRoutePicker: NSViewRepresentable {
      func makeNSView(context: Context) -> AVRoutePickerView {
          let picker = AVRoutePickerView(frame: .zero)
          picker.wantsLayer = true
          picker.layer?.backgroundColor = NSColor.clear.cgColor
          picker.alphaValue = 0.01 // Invisible but clickable
          return picker
      }
      func updateNSView(_ nsView: AVRoutePickerView, context: Context) {}
  }

  // In WinampMainWindow - position over logo
  AirPlayRoutePicker()
      .frame(width: 24, height: 24)
      .contentShape(Rectangle())
      .accessibilityLabel("Open AirPlay devices")
      .at(logoCoordinates) // Match logo position
  ```

- [ ] **Test logo click activates AirPlay**
  - [ ] Click Winamp logo
  - [ ] Verify AirPlay menu appears
  - [ ] Select device
  - [ ] Verify audio routes

- [ ] **Adjust positioning if needed**
  - [ ] Fine-tune coordinates for perfect overlay
  - [ ] Ensure works in both full and shade modes
  - [ ] Test with different skins

---

## ~~Phase 3A: Custom Device Menu~~ - CANCELLED

### Step 1: Create AirPlayManager

- [ ] **Create ViewModel file**
  - [ ] Create: `MacAmpApp/ViewModels/AirPlayManager.swift`
  - [ ] Mark class `@MainActor @Observable`

- [ ] **Add properties**
  - [ ] `var availableDevices: [AVAudioDevice] = []`
  - [ ] `var selectedDevice: AVAudioDevice?`
  - [ ] `var isAirPlayActive: Bool = false`
  - [ ] `private let audioEngine: AVAudioEngine`
  - [ ] `private let routeDetector = AVRouteDetector()`
  - [ ] `private var observers: [NSObjectProtocol] = []`

- [ ] **Implement init**
  - [ ] Take audioEngine parameter
  - [ ] Call setupRouteDetection()
  - [ ] Call refreshDevices()

- [ ] **Implement refreshDevices**
  - [ ] Get AVAudioDevice.outputDevices
  - [ ] Update availableDevices
  - [ ] Update selectedDevice from engine
  - [ ] Update isAirPlayActive flag

- [ ] **Implement selectDevice**
  - [ ] Try audioEngine.outputNode.setDeviceID()
  - [ ] Update selectedDevice
  - [ ] Update isAirPlayActive
  - [ ] Persist to UserDefaults
  - [ ] Handle errors

- [ ] **Implement setupRouteDetection**
  - [ ] Enable routeDetector
  - [ ] Observe AVRouteDetectorMultipleRoutesDetectedDidChange
  - [ ] Observe AVAudioEngineConfigurationChange
  - [ ] Store observers for cleanup

- [ ] **Implement deinit**
  - [ ] Remove all observers

### Step 2: Create Custom Menu UI

- [ ] **Create view file**
  - [ ] Create: `MacAmpApp/Views/Components/AirPlayMenu.swift`
  - [ ] Add @Environment(AirPlayManager.self)

- [ ] **Build Menu structure**
  - [ ] Use Menu { } label: { }
  - [ ] ForEach over availableDevices
  - [ ] Create Button for each device

- [ ] **Add device info display**
  - [ ] Device icon (airplay, bluetooth, speaker)
  - [ ] Device name
  - [ ] Checkmark if selected

- [ ] **Add action handlers**
  - [ ] Button calls airPlayManager.selectDevice()
  - [ ] Handle errors

- [ ] **Add onAppear**
  - [ ] Call refreshDevices()

### Step 3: Inject AirPlayManager

- [ ] **Update MacAmpApp.swift**
  - [ ] Add `@State private var airPlayManager: AirPlayManager?`
  - [ ] Create instance with audioPlayer.audioEngine
  - [ ] Inject via `.environment()`

### Step 4: Replace System Picker

- [ ] **Update WinampMainWindow**
  - [ ] Remove AirPlayPickerView
  - [ ] Add AirPlayMenu
  - [ ] Adjust positioning
  - [ ] Update styling

### Step 5: Test Custom UI

- [ ] All Phase 1 tests
- [ ] Device list accuracy
- [ ] Real-time updates
- [ ] Connection state
- [ ] Disconnection handling

---

## Documentation Tasks

### Code Documentation
- [ ] Add doc comments to AirPlayPickerView
- [ ] Add doc comments to AirPlayManager (if created)
- [ ] Document Info.plist change
- [ ] Document entitlement requirement

### User Documentation
- [ ] Update README.md with AirPlay feature
- [ ] Add usage instructions
- [ ] Document AirPlay button location
- [ ] Add keyboard shortcuts (if added)

### Task Documentation
- [ ] Update state.md with implementation status
- [ ] Mark todo.md items complete
- [ ] Document any deviations from plan
- [ ] Note any issues discovered

---

## Testing Checklist

### Functional Testing
- [ ] AirPlay button appears
- [ ] Can click button
- [ ] Device list populates
- [ ] Can select device
- [ ] Audio routes correctly
- [ ] EQ maintains processing
- [ ] Can switch devices
- [ ] Can return to built-in

### Integration Testing
- [ ] Works with all skins
- [ ] Works in double-size mode
- [ ] Works with shade mode
- [ ] Works with all 3 windows
- [ ] Doesn't interfere with existing controls

### Edge Case Testing
- [ ] Device disconnection during playback
- [ ] Network interruption
- [ ] Permission denied
- [ ] No devices available
- [ ] Multi-room selection (if available)
- [ ] Rapid device switching

### System Integration Testing (Phase 2)
- [ ] Control Center shows track info
- [ ] Keyboard play/pause works
- [ ] Next/previous from keyboard
- [ ] Menu bar controls work
- [ ] Artwork displays correctly
- [ ] Progress bar updates

---

## Completion Criteria

### Phase 1 Complete When:
- [x] Info.plist has local network description
- [x] Entitlements verified
- [x] AirPlayPickerView created
- [x] Button integrated into UI
- [x] All functional tests pass
- [x] Edge cases handled
- [x] Documentation updated

### Phase 2 Complete When:
- [x] MediaPlayer framework added
- [x] Now Playing info updates
- [x] Remote commands respond
- [x] Control Center integration works
- [x] All system integration tests pass

### Phase 3 Complete When:
- [x] AirPlayManager created
- [x] Custom menu UI built
- [x] All Phase 1 functionality preserved
- [x] Device status indicators added
- [x] Winamp aesthetic maintained

---

## Potential Issues & Solutions

### Issue: Permission Denied
**Solution:** Check Info.plist has NSLocalNetworkUsageDescription

### Issue: No Devices Found
**Solution:** Verify AirPlay device on same Wi-Fi network

### Issue: Audio Doesn't Route
**Solution:** Check audioEngine.outputNode is accessible, verify device ID

### Issue: EQ Stops Working
**Solution:** Impossible - EQ is before outputNode (but verify in testing)

### Issue: Device List Empty
**Solution:** Check entitlements, check permission granted

### Issue: Crashes on Device Switch
**Solution:** Wrap setDeviceID in try-catch, handle errors gracefully

---

## Files to Create

1. `MacAmpApp/Views/Components/AirPlayPickerView.swift` - Phase 1
2. `MacAmpApp/ViewModels/AirPlayManager.swift` - Phase 3
3. `MacAmpApp/Views/Components/AirPlayMenu.swift` - Phase 3

## Files to Modify

1. `MacAmpApp/Info.plist` - Add NSLocalNetworkUsageDescription
2. `MacAmpApp/MacAmp.entitlements` - Verify network.client
3. `MacAmpApp/Views/WinampMainWindow.swift` - Add AirPlay button
4. `MacAmpApp/Audio/AudioPlayer.swift` - Phase 2 (Now Playing integration)
5. `MacAmpApp/MacAmpApp.swift` - Phase 3 (Inject AirPlayManager)
6. `README.md` - Document AirPlay feature

---

## Current Status

**Completed:**
- ✅ Research (Gemini)
- ✅ Planning (implementation strategy)
- ✅ State tracking (prerequisites identified)
- ✅ TODO checklist (this file)

**Pending:**
- ⏸️ Oracle review of research and plan
- ⏸️ User approval to proceed
- ⏸️ Implementation

**Blocked:**
- None identified

---

**Ready for Oracle review and user approval!**
