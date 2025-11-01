
---

## ⚠️ ORACLE CORRECTIONS - Critical Changes to Plan

**Gemini Accuracy:** 60% - Conceptually correct, technically wrong
**Oracle Review Date:** 2025-10-30

### Critical Issues Fixed:

1. **❌ Wrong Import:** AVFoundation → **✅ AVKit**
2. **❌ Custom UI Impossible:** No APIs exist for programmatic device selection
3. **❌ Info.plist Not Needed:** NSLocalNetworkUsageDescription is iOS-only
4. **✅ CRITICAL Addition:** Must handle AVAudioEngineConfigurationChange
5. **❌ Limited Customization:** AVRoutePickerView can't be styled on macOS

### Revised Scope:

**Phase 1 ONLY: AVRoutePickerView**
- System picker (can't customize appearance)
- Add engine configuration observer (CRITICAL)
- Test with real AirPlay device
- Estimated: 2 hours

**Phase 2 OPTIONAL: Now Playing**
- MPNowPlayingInfoCenter integration
- Verify MediaPlayer works on macOS
- Estimated: 2 hours

**Phase 3 REMOVED: Custom UI**
- Not possible - APIs don't exist
- Gemini was wrong about outputNode.setDeviceID()
- Must use system picker only

**Total Time: 2-4 hours** (not 7+)

---

# AirPlay Integration - Implementation Plan

**Date:** 2025-10-30
**Objective:** Add AirPlay device discovery and audio routing to MacAmp
**Approach:** AVRoutePickerView (System UI) + Engine Configuration Handling

**⚠️ ORACLE REVIEWED:** Custom UI not possible - system picker only option

---

## Success Criteria

### MVP (Phase 1)
- ✅ AirPlay picker button visible in UI
- ✅ User can select AirPlay devices
- ✅ Audio routes to selected device
- ✅ EQ processing maintained
- ✅ Device selection persists

### Full Integration (Phase 2)
- ✅ "Now Playing" info in Control Center
- ✅ Keyboard media controls work
- ✅ Track artwork displays
- ✅ Progress bar updates

### Custom UI (Phase 3 - Optional)
- ✅ Winamp-style device menu
- ✅ Device list with icons
- ✅ Sprite-based UI elements
- ✅ Integrated into main window

---

## Phase 1: MVP with AVRoutePickerView (1 hour)

### 1.1 Add Required Entitlements and Permissions

**File:** `MacAmpApp/Info.plist`

**Add local network usage description:**

```xml
<key>NSLocalNetworkUsageDescription</key>
<string>MacAmp needs to access the local network to discover and connect to AirPlay speakers.</string>
```

**Verify entitlement exists:**

Check `MacAmpApp/MacAmp.entitlements` has:
```xml
<key>com.apple.security.network.client</key>
<true/>
```

**If missing, add in Xcode:**
1. Select MacAmpApp target
2. Signing & Capabilities
3. + Capability → "Outgoing Connections (Client)"

### 1.2 Create AVRoutePickerView Wrapper

**File:** `MacAmpApp/Views/Components/AirPlayPickerView.swift` (new)

```swift
import SwiftUI
import AVFoundation
import AppKit

/// SwiftUI wrapper for AVRoutePickerView (system AirPlay picker)
struct AirPlayPickerView: NSViewRepresentable {

    func makeNSView(context: Context) -> AVRoutePickerView {
        let picker = AVRoutePickerView()

        // Enable device detection
        picker.isRouteDetectionEnabled = true

        // Style the button
        picker.routePickerButtonStyle = .system

        // Optional: Customize colors to match skin
        // picker.routePickerButtonBorderColor = .white
        // picker.routePickerButtonColor = .white

        return picker
    }

    func updateNSView(_ nsView: AVRoutePickerView, context: Context) {
        // No updates needed - picker is self-managing
    }
}
```

### 1.3 Integrate into WinampMainWindow

**File:** `MacAmpApp/Views/WinampMainWindow.swift`

**Add AirPlay button to main window:**

```swift
// In Coords struct (add coordinate for AirPlay button)
static let airPlayButton = CGPoint(x: 107, y: 40) // Near volume slider

// Add method to build AirPlay button
@ViewBuilder
private func buildAirPlayButton() -> some View {
    AirPlayPickerView()
        .frame(width: 20, height: 20)
        .at(Coords.airPlayButton)
}

// Call in buildFullWindow()
// Near volume/balance sliders:
buildVolumeSlider()
buildBalanceSlider()
buildAirPlayButton()  // Add this
```

**Alternative Positioning:**
- Near clutter bar buttons
- Above/below volume slider
- In titlebar area
- As separate floating button

### 1.4 Test AirPlay Functionality

**Manual Test:**
1. Build and run app
2. Look for AirPlay icon (system icon)
3. Click icon → device list appears
4. Select AirPlay device
5. Play music → should hear on AirPlay speaker
6. Verify EQ still works (adjust bands)
7. Switch back to built-in speakers

**Edge Cases:**
- Device disconnection during playback
- Network interruption
- Multiple devices selected (multi-room)
- Device battery low

---

## Phase 2: System Media Integration (2 hours)

### 2.1 Add MediaPlayer Framework

**File:** `MacAmpApp/Audio/AudioPlayer.swift`

**Add import:**
```swift
import MediaPlayer
```

### 2.2 Implement Now Playing Info

**File:** `MacAmpApp/Audio/AudioPlayer.swift`

**Add method to update Now Playing:**

```swift
@MainActor
private func updateNowPlayingInfo() {
    guard let track = currentTrack else {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        return
    }

    var nowPlayingInfo = [String: Any]()

    // Track metadata
    nowPlayingInfo[MPMediaItemPropertyTitle] = track.title
    nowPlayingInfo[MPMediaItemPropertyArtist] = track.artist ?? "Unknown Artist"
    nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = track.album ?? ""

    // Playback info
    nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = track.duration
    nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
    nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0

    // Optional: Album artwork
    if let artwork = track.artwork {
        let mediaArtwork = MPMediaItemArtwork(boundsSize: artwork.size) { _ in artwork }
        nowPlayingInfo[MPMediaItemPropertyArtwork] = mediaArtwork
    }

    MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
}
```

**Call updateNowPlayingInfo() whenever:**
- Track changes
- Playback starts/stops
- Time updates (every second)

### 2.3 Implement Remote Command Center

**File:** `MacAmpApp/Audio/AudioPlayer.swift`

**Add method to setup remote commands:**

```swift
@MainActor
private func setupRemoteCommands() {
    let commandCenter = MPRemoteCommandCenter.shared()

    // Play command
    commandCenter.playCommand.isEnabled = true
    commandCenter.playCommand.addTarget { [weak self] _ in
        self?.play()
        return .success
    }

    // Pause command
    commandCenter.pauseCommand.isEnabled = true
    commandCenter.pauseCommand.addTarget { [weak self] _ in
        self?.pause()
        return .success
    }

    // Toggle play/pause
    commandCenter.togglePlayPauseCommand.isEnabled = true
    commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
        self?.togglePlayPause()
        return .success
    }

    // Next track
    commandCenter.nextTrackCommand.isEnabled = true
    commandCenter.nextTrackCommand.addTarget { [weak self] _ in
        self?.nextTrack()
        return .success
    }

    // Previous track
    commandCenter.previousTrackCommand.isEnabled = true
    commandCenter.previousTrackCommand.addTarget { [weak self] _ in
        self?.previousTrack()
        return .success
    }

    // Seek command (optional)
    commandCenter.changePlaybackPositionCommand.isEnabled = true
    commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
        if let event = event as? MPChangePlaybackPositionCommandEvent {
            self?.seekToPercent(event.positionTime / (self?.currentTrack?.duration ?? 1.0))
            return .success
        }
        return .commandFailed
    }
}
```

**Call in init():**
```swift
init() {
    // ... existing initialization
    setupRemoteCommands()
}
```

---

## Phase 3: Winamp Logo Overlay (1-2 hours) - Oracle-Approved Alternative

### Oracle Validation: ✅ FEASIBLE

**User's Creative Idea:** Position AirPlay picker over Winamp logo (like webamp's "about" link)
**Oracle Confirmation:** "Drop transparent AVRoutePickerView over logo - this works!"

**Webamp Pattern:**
```tsx
// index.tsx Line 129-134
<a id="about" href="https://webamp.org/about" title="About" />

// CSS positions over logo
#about { position: absolute; top: 91px; left: 253px; height: 15px; width: 13px; }
```

**MacAmp Implementation:**
- Transparent AVRoutePickerView positioned over logo
- alphaValue = 0.01 (invisible but clickable)
- User clicks logo area → AirPlay menu appears
- Logo sprite provides the visual

**Note:** Logo position is skin-dependent - need to research GEN.BMP or skin metadata

### 3.1 Create Transparent Route Picker (Oracle's Code)

**File:** `MacAmpApp/Views/Components/AirPlayRoutePicker.swift` (new)

```swift
import SwiftUI
import AVKit

struct AirPlayRoutePicker: NSViewRepresentable {
    func makeNSView(context: Context) -> AVRoutePickerView {
        let picker = AVRoutePickerView(frame: .zero)
        picker.wantsLayer = true
        picker.layer?.backgroundColor = NSColor.clear.cgColor
        picker.alphaValue = 0.01 // Invisible but hit-testable
        picker.translatesAutoresizingMaskIntoConstraints = false
        return picker
    }

    func updateNSView(_ nsView: AVRoutePickerView, context: Context) {
        // No updates needed
    }
}
```

### 3.2 Position Over Winamp Logo

**File:** `MacAmpApp/Views/WinampMainWindow.swift`

**Add to buildFullWindow() or body ZStack:**

```swift
// Position transparent AirPlay picker over Winamp logo
AirPlayRoutePicker()
    .frame(width: 24, height: 24) // Accessibility minimum
    .contentShape(Rectangle())
    .accessibilityLabel("Open AirPlay devices")
    .at(CGPoint(x: 253, y: 91)) // Webamp logo position - adjust for skin
```

**Note:** Coordinates (253, 91) from webamp - verify against MacAmp logo position

### 3.3 Handle Skin-Dependent Logo Position

**Research needed:**
- Logo position varies by skin (GEN.BMP or skin metadata)
- Webamp reference: Check how they handle dynamic positioning
- May need SkinManager integration to get logo bounds per skin

**Defer to implementation:** Start with fixed coordinates, refine if needed

---

## ❌ Phase 3A: Custom Device Menu - REMOVED (Oracle: Impossible)

### 3.1 Create AirPlayManager ViewModel

**File:** `MacAmpApp/ViewModels/AirPlayManager.swift` (new)

```swift
import AVFoundation
import Observation
import AppKit

@MainActor
@Observable
final class AirPlayManager {
    // MARK: - Properties

    var availableDevices: [AVAudioDevice] = []
    var selectedDevice: AVAudioDevice?
    var isAirPlayActive: Bool = false

    private let audioEngine: AVAudioEngine
    private let routeDetector = AVRouteDetector()
    private var observers: [NSObjectProtocol] = []

    // MARK: - Initialization

    init(audioEngine: AVAudioEngine) {
        self.audioEngine = audioEngine
        setupRouteDetection()
        refreshDevices()
    }

    // MARK: - Public Methods

    func refreshDevices() {
        availableDevices = AVAudioDevice.outputDevices

        // Update selected device
        if let currentID = audioEngine.outputNode.audioDeviceID {
            selectedDevice = availableDevices.first { $0.deviceID == currentID }
            isAirPlayActive = (selectedDevice?.transportType == .airPlay)
        }
    }

    func selectDevice(_ device: AVAudioDevice) throws {
        try audioEngine.outputNode.setDeviceID(device.deviceID)
        selectedDevice = device
        isAirPlayActive = (device.transportType == .airPlay)

        // Persist selection
        UserDefaults.standard.set(device.deviceID, forKey: "lastAirPlayDeviceID")
    }

    func restoreLastDevice() {
        guard let lastDeviceID = UserDefaults.standard.object(forKey: "lastAirPlayDeviceID") as? AudioDeviceID else {
            return
        }

        if let device = availableDevices.first(where: { $0.deviceID == lastDeviceID }) {
            try? selectDevice(device)
        }
    }

    // MARK: - Private Methods

    private func setupRouteDetection() {
        routeDetector.isRouteDetectionEnabled = true

        // Observe route changes
        let routeObserver = NotificationCenter.default.addObserver(
            forName: .AVRouteDetectorMultipleRoutesDetectedDidChange,
            object: routeDetector,
            queue: .main
        ) { [weak self] _ in
            self?.refreshDevices()
        }
        observers.append(routeObserver)

        // Observe engine configuration changes
        let configObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: audioEngine,
            queue: .main
        ) { [weak self] _ in
            self?.handleEngineConfigurationChange()
        }
        observers.append(configObserver)
    }

    private func handleEngineConfigurationChange() {
        refreshDevices()

        // Check if device disconnected
        if let selected = selectedDevice,
           !availableDevices.contains(where: { $0.deviceID == selected.deviceID }) {
            // Fall back to default device
            if let defaultDevice = AVAudioDevice.defaultOutputDevice {
                try? selectDevice(defaultDevice)
            }
        }
    }

    deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
    }
}
```

### 3.2 Create Custom Device Selection Menu

**File:** `MacAmpApp/Views/Components/AirPlayMenu.swift` (new)

```swift
import SwiftUI
import AVFoundation

struct AirPlayDeviceMenu: View {
    @Environment(AirPlayManager.self) var airPlayManager

    var body: some View {
        Menu {
            ForEach(airPlayManager.availableDevices, id: \.deviceID) { device in
                Button(action: {
                    try? airPlayManager.selectDevice(device)
                }) {
                    HStack {
                        // Device type icon
                        Image(systemName: deviceIcon(for: device))
                            .frame(width: 20)

                        // Device name
                        Text(device.deviceName)

                        Spacer()

                        // Checkmark if selected
                        if airPlayManager.selectedDevice?.deviceID == device.deviceID {
                            Image(systemName: "checkmark")
                                .foregroundColor(.accentColor)
                        }
                    }
                }
            }
        } label: {
            // AirPlay icon (can replace with Winamp sprite)
            Image(systemName: "airplayaudio")
                .imageScale(.large)
                .foregroundColor(airPlayManager.isAirPlayActive ? .blue : .primary)
        }
        .onAppear {
            airPlayManager.refreshDevices()
        }
    }

    private func deviceIcon(for device: AVAudioDevice) -> String {
        switch device.transportType {
        case .airPlay:
            return "airplayaudio"
        case .bluetooth:
            return "bluetoothspeaker.fill"
        case .builtIn:
            return "hifispeaker.fill"
        default:
            if device.isDefaultDevice {
                return "speaker.wave.3.fill"
            }
            return "speaker.wave.2.fill"
        }
    }
}
```

### 3.3 Inject AirPlayManager

**File:** `MacAmpApp/MacAmpApp.swift`

```swift
@main
struct MacAmpApp: App {
    @State private var skinManager = SkinManager()
    @State private var audioPlayer = AudioPlayer()
    @State private var dockingController = DockingController()
    @State private var settings = AppSettings.instance()
    @State private var airPlayManager: AirPlayManager?  // Add this

    var body: some Scene {
        WindowGroup {
            UnifiedDockView()
                .environment(skinManager)
                .environment(audioPlayer)
                .environment(dockingController)
                .environment(settings)
                .environment(airPlayManager ?? AirPlayManager(audioEngine: audioPlayer.audioEngine))
                .onAppear {
                    if airPlayManager == nil {
                        airPlayManager = AirPlayManager(audioEngine: audioPlayer.audioEngine)
                    }
                }
        }
        // ...
    }
}
```

---

## Implementation Options

### Option A: System Picker (Recommended for MVP)

**Pros:**
- ✅ 30 minutes implementation
- ✅ Zero maintenance
- ✅ Apple handles all edge cases
- ✅ Multi-room support included
- ✅ Familiar to users

**Cons:**
- ⚠️ Doesn't match Winamp aesthetic
- ⚠️ Can't customize UI

**Where to Add:**
- Near volume/balance sliders
- Or in titlebar area
- Or as floating button overlay

### Option B: Custom Menu (Future)

**Pros:**
- ✅ Matches Winamp style
- ✅ Can use sprite-based UI
- ✅ Full control over UX
- ✅ Can show device details

**Cons:**
- ⚠️ 4+ hours implementation
- ⚠️ Must handle edge cases
- ⚠️ More testing needed

**Defer to Phase 3** - Get AirPlay working first!

---

## Integration Points

### Where AirPlay Button Should Go

**Option 1: Near Volume Slider (Recommended)**
- Position: x: 107, y: 40 (below volume slider)
- Makes sense contextually (audio output control)
- Doesn't interfere with existing UI

**Option 2: In Clutter Bar**
- Could replace or augment V button
- Matches classic Winamp positioning
- Requires sprite integration

**Option 3: Titlebar Area**
- Upper-right corner
- Always visible
- Compact

**Option 4: As Menu Item**
- Windows menu → "AirPlay Devices"
- Keyboard shortcut: Cmd+Shift+A
- Less discoverable

**Recommendation:** Start with Option 1 (near volume), can move later

---

## Technical Architecture

### No Changes to AudioPlayer Required!

**Critical Finding:** AVAudioEngine already supports AirPlay

**Current AudioPlayer.swift (Lines 94-96):**
```swift
@MainActor
@Observable
class AudioPlayer {
    private let audioEngine: AVAudioEngine
    private let playerNode: AVAudioPlayerNode
    private let eqNode: AVAudioUnitEQ

    // Graph: playerNode → eqNode → mainMixerNode → outputNode
}
```

**This architecture is PERFECT for AirPlay:**
- outputNode routes to any audio device
- EQ is applied before outputNode
- No graph changes needed
- Just expose device selection UI

### Audio Flow Remains Unchanged

```
Audio File
    ↓
AVAudioPlayerNode
    ↓
AVAudioUnitEQ (10-band EQ) ← Already working
    ↓
mainMixerNode
    ↓
outputNode
    ↓
┌─────────────────────────────┐
│  System Audio Routing       │
│  (User selects via picker)  │
└─────────────────────────────┘
    ↓
[Built-in Speakers] OR [AirPlay Device]
```

**Key Point:** We just add UI for device selection. Audio engine handles the rest!

---

## Rollout Strategy

### Day 1: MVP Implementation

**Morning (1 hour):**
1. Add NSLocalNetworkUsageDescription to Info.plist
2. Verify network client entitlement
3. Create AirPlayPickerView wrapper
4. Add to WinampMainWindow
5. Build and test

**Afternoon (1 hour):**
1. Test with real AirPlay device
2. Verify EQ works
3. Test edge cases (disconnect, etc.)
4. Document any issues

### Day 2: System Integration (Optional)

**Morning (2 hours):**
1. Add MediaPlayer import
2. Implement updateNowPlayingInfo()
3. Implement setupRemoteCommands()
4. Test Control Center integration

### Day 3+: Custom UI (Optional)

**When ready for polish:**
1. Create AirPlayManager ViewModel
2. Build custom device menu
3. Add Winamp-style sprites
4. Replace system picker

---

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Device discovery fails | Low | High | Check entitlements, test permission dialog |
| Audio doesn't route | Low | High | Verify AVAudioEngine setup, test with multiple devices |
| EQ breaks on AirPlay | Very Low | High | Already tested - EQ is before outputNode |
| UI doesn't fit aesthetic | Medium | Low | Start with system picker, replace with custom later |
| Latency issues | Low | Medium | AirPlay 2 handles this, monitor user feedback |
| Device disconnection | Medium | Medium | Handle gracefully, fall back to built-in |

---

## Testing Strategy

### Phase 1 Testing

**Required Equipment:**
- AirPlay 2 compatible device (HomePod, Apple TV, AirPlay speaker)
- Same Wi-Fi network as Mac

**Test Cases:**
1. Device appears in picker
2. Can select device
3. Audio plays on selected device
4. EQ adjustments audible on AirPlay
5. Can switch back to built-in speakers
6. Volume control works
7. Balance control works (if AirPlay supports stereo)

### Phase 2 Testing

**Control Center Integration:**
1. Play track → Control Center shows "Now Playing"
2. Track info correct (title, artist, artwork)
3. Progress bar updates
4. Keyboard play/pause works
5. Keyboard next/previous works

### Edge Case Testing

1. **Device Disconnection:**
   - Unplug AirPlay device during playback
   - App should fall back to built-in speakers
   - No crash or audio interruption

2. **Network Issues:**
   - Disable Wi-Fi during playback
   - AirPlay should disconnect gracefully
   - App continues playing on built-in

3. **Multi-Room:**
   - Select 2+ AirPlay devices
   - Audio should play on all
   - EQ should apply to all
   - Synchronized playback

---

## Future Enhancements

### Post-MVP Features

1. **Device Status Indicators**
   - Show battery level (if available)
   - Show signal strength
   - Show device type icon

2. **Keyboard Shortcuts**
   - Cmd+Shift+A: Open AirPlay menu
   - Quick device switching

3. **Device Presets**
   - Remember favorite devices
   - Quick-select from menu
   - Device groups (e.g., "Living Room", "Whole House")

4. **Visual Feedback**
   - Animated AirPlay icon when active
   - Device name in status bar
   - Connection status indicator

5. **Advanced Routing**
   - Per-window routing (if magnetic docking implemented)
   - Independent device selection for EQ preview
   - A/B comparison between devices

---

## Dependencies

### Framework Requirements
- ✅ AVFoundation (already using)
- 📦 MediaPlayer (need to add for Phase 2)

### Entitlements
- ✅ com.apple.security.network.client (verify exists)
- ✅ com.apple.security.device.audio-output (already have)

### Info.plist
- ❌ NSLocalNetworkUsageDescription (need to add)

### System Requirements
- macOS 15+ (Sequoia) - ✅ Already target
- Swift 6 - ✅ Already using
- Xcode 16+ - ✅ Already have

---

## Success Metrics

### MVP Success
- [ ] AirPlay button visible and clickable
- [ ] Device list populates
- [ ] Can select device and audio routes correctly
- [ ] EQ processing maintained
- [ ] No crashes or audio glitches
- [ ] Permission dialog shows correct text

### Full Integration Success
- [ ] "Now Playing" shows in Control Center
- [ ] Keyboard controls work
- [ ] Artwork displays
- [ ] Progress updates in real-time

### User Experience Success
- [ ] Intuitive to use
- [ ] Reliable device switching
- [ ] Graceful error handling
- [ ] Clear device status indication

---

## References

- Research: `tasks/airplay/research.md` (Gemini findings)
- Apple Docs: AVFoundation/AVRoutePickerView
- Apple Docs: MediaPlayer/MPNowPlayingInfoCenter
- Current Audio: `MacAmpApp/Audio/AudioPlayer.swift`
- Entitlements: `MacAmpApp/MacAmp.entitlements`
