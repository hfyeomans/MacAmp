# AirPlay Integration Research

**Date:** 2025-10-30
**Objective:** Add AirPlay device discovery and audio routing to MacAmp
**Research Sources:**
- Gemini (Xcode 26 documentation analysis)
- Oracle (Codex) code review and corrections

---

## ⚠️ Oracle Review - Critical Corrections Applied

**Gemini Accuracy:** 60% (conceptually correct, technically wrong)
**Oracle Corrections:** 5 critical issues fixed
**Revised Scope:** AVRoutePickerView ONLY (custom UI not feasible)

---

## Executive Summary

AirPlay integration for MacAmp is **feasible** with existing AVAudioEngine architecture.

**ONLY ONE Implementation Path:**
1. **AVRoutePickerView (System UI)** - ONLY viable option

**Custom UI NOT POSSIBLE** - APIs don't exist on macOS ❌

**Key Findings:**
- ✅ AVAudioEngine natively supports AirPlay routing
- ✅ EQ processing is maintained
- ✅ AVRoutePickerView is in AVKit framework
- ❌ Custom device selection APIs don't exist (Gemini was wrong)
- ⚠️ **CRITICAL:** Must handle AVAudioEngineConfigurationChange or playback fails

---

## 1. AirPlay APIs and Architecture

### Modern Swift 6 / SwiftUI APIs for AirPlay 2

**Primary Framework:** AVFoundation (no separate "AirPlay 2 API")

**Key Classes:**

| Class | Purpose | Usage |
|-------|---------|-------|
| `AVRoutePickerView` | System UI for route selection | Easiest - handles everything |
| `AVRouteDetector` | Detect multiple audio routes | For custom UI |
| `AVAudioEngine` | Audio processing graph | ✅ Already using this |
| `AVAudioDevice` | Represents output device | For custom device selection |

### AVRoutePickerView vs Custom UI

**AVRoutePickerView (Recommended for MVP):**

**Pros:**
- ✅ Zero-effort UI implementation
- ✅ Automatically stays up-to-date with system changes
- ✅ Handles all connection logic
- ✅ Familiar user experience (system standard)
- ✅ Multi-room audio support included
- ✅ Device discovery automatic
- ✅ Connection state management automatic

**Cons:**
- ⚠️ NSView (requires NSViewRepresentable wrapper)
- ⚠️ UI not customizable (doesn't match Winamp aesthetic)
- ⚠️ Can't integrate into custom menu system

**Custom UI (Future Enhancement):**

**Pros:**
- ✅ Full control over UI (can match Winamp style)
- ✅ Can integrate into custom menu system
- ✅ Can show device details (battery, signal strength)
- ✅ Matches clutter bar aesthetic

**Cons:**
- ⚠️ Significantly more work
- ⚠️ Must handle device discovery manually
- ⚠️ Must handle connection state
- ⚠️ Must update UI on device changes
- ⚠️ More fragile (could break with macOS updates)
- ⚠️ Must test edge cases (disconnection, errors)

### AVAudioSession.routeOverride

**Important:** `AVAudioSession` is iOS/iPadOS only!

**On macOS:**
- ❌ Do NOT use AVAudioSession
- ✅ Use AVAudioEngine.outputNode.setDeviceID() instead
- ✅ Or let AVRoutePickerView handle routing

### Relationship Between AVAudioEngine and AirPlay

**How It Works:**

```
AVAudioEngine Architecture:
┌─────────────────────────────────────────────────────────────┐
│  AVAudioPlayerNode (your audio files)                       │
│         ↓                                                    │
│  AVAudioUnitEQ (10-band EQ) ✅ PRESERVED                    │
│         ↓                                                    │
│  mainMixerNode (mixing)                                      │
│         ↓                                                    │
│  outputNode → Current Audio Device                          │
│                      ↓                                       │
│              ┌──────────────────┐                           │
│              │ System Routes To │                           │
│              └──────────────────┘                           │
│                 /              \                             │
│        Built-in Speakers    AirPlay Device                  │
└─────────────────────────────────────────────────────────────┘
```

**Key Points:**
- AVAudioEngine.outputNode outputs to system's default audio device
- When user selects AirPlay, system changes default device
- Engine automatically follows the change
- **EQ processing happens BEFORE routing** ✅
- All audio effects are maintained

**Programmatic Routing (Custom UI):**

```swift
// Get available devices
let devices = AVAudioDevice.outputDevices

// Find AirPlay device
let airplayDevice = devices.first { device in
    device.transportType == .airPlay // Check if it's AirPlay
}

// Set output device
try audioEngine.outputNode.setDeviceID(airplayDevice.deviceID)

// Engine re-routes all audio (including EQ) to new device
```

### MPRemoteCommandCenter and MPNowPlayingInfoCenter

**Purpose:** System media integration (Control Center, menu bar, keyboard controls)

**Not for routing, but ESSENTIAL for media app experience!**

**MPNowPlayingInfoCenter:**
- Displays "Now Playing" info in Control Center
- Shows track title, artist, album, artwork
- Updates progress bar
- Required for professional media app

**MPRemoteCommandCenter:**
- Responds to play/pause from keyboard
- Responds to next/previous from headphones
- Responds to Control Center controls
- Makes app feel native

**Recommendation:** Implement these along with AirPlay for complete system integration

---

## 2. Device Discovery and Selection

### Discovering Devices

**With AVRoutePickerView (Simple):**
```swift
let picker = AVRoutePickerView()
picker.isRouteDetectionEnabled = true
// That's it! Picker handles discovery automatically
```

**Custom UI (Complex):**
```swift
// 1. Create detector
let routeDetector = AVRouteDetector()
routeDetector.isRouteDetectionEnabled = true

// 2. Check if multiple routes available
if routeDetector.multipleRoutesDetected {
    // Show custom UI
}

// 3. Get device list
let devices = AVAudioDevice.outputDevices

// 4. Filter for AirPlay
let airplayDevices = devices.filter { device in
    device.transportType == .airPlay
}
```

### Presenting Device Selection UI

**Option A: System Picker (Recommended)**

```swift
// SwiftUI integration
struct AirPlayButton: View {
    var body: some View {
        AirPlayPickerView() // NSViewRepresentable wrapper
            .frame(width: 40, height: 40)
    }
}
```

**Option B: Custom Menu**

```swift
@Observable
class AirPlayManager {
    var devices: [AVAudioDevice] = []
    var selectedDevice: AVAudioDevice?

    func refreshDevices() {
        devices = AVAudioDevice.outputDevices.filter {
            $0.transportType == .airPlay || $0.isDefaultDevice
        }
    }

    func selectDevice(_ device: AVAudioDevice, engine: AVAudioEngine) throws {
        try engine.outputNode.setDeviceID(device.deviceID)
        selectedDevice = device
    }
}

struct AirPlayMenu: View {
    @State var manager: AirPlayManager
    let audioEngine: AVAudioEngine

    var body: some View {
        Menu {
            ForEach(manager.devices, id: \.deviceID) { device in
                Button(action: {
                    try? manager.selectDevice(device, engine: audioEngine)
                }) {
                    HStack {
                        Text(device.deviceName)
                        if manager.selectedDevice?.deviceID == device.deviceID {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Image(systemName: "airplayaudio")
        }
        .onAppear {
            manager.refreshDevices()
        }
    }
}
```

### Notifications for Device Changes

**AVRoutePickerView:** Handles automatically ✅

**Custom UI:** Must observe notifications

```swift
// 1. When available routes change
NotificationCenter.default.addObserver(
    forName: .AVRouteDetectorMultipleRoutesDetectedDidChange,
    object: routeDetector,
    queue: .main
) { _ in
    manager.refreshDevices()
}

// 2. When engine configuration changes
NotificationCenter.default.addObserver(
    forName: .AVAudioEngineConfigurationChange,
    object: audioEngine,
    queue: .main
) { _ in
    // Update selected device
    manager.updateCurrentDevice()
}

// 3. When system audio device changes
NotificationCenter.default.addObserver(
    forName: NSNotification.Name(rawValue: "com.apple.audio.default.device.changed"),
    object: nil,
    queue: .main
) { _ in
    manager.refreshDevices()
}
```

### Handling Connection/Disconnection

**Graceful Fallback Strategy:**

```swift
func handleDeviceDisconnection() {
    // Check if current device is still available
    let availableIDs = AVAudioDevice.outputDevices.map { $0.deviceID }

    if let currentID = audioEngine.outputNode.audioDeviceID,
       !availableIDs.contains(currentID) {
        // Device disconnected - fall back to default
        if let defaultDevice = AVAudioDevice.defaultOutputDevice {
            try? audioEngine.outputNode.setDeviceID(defaultDevice.deviceID)
        }
    }
}
```

### Multi-Room Audio Support

**AirPlay 2 multi-room is handled at SYSTEM LEVEL:**

- User selects multiple speakers from AVRoutePickerView
- macOS creates aggregate audio device
- Your app outputs to single destination
- System distributes audio to all selected speakers
- **No special code needed** - just works! ✅

---

## 3. Audio Routing Architecture

### Routing AVAudioEngine Output

**Current MacAmp Architecture:**

```
AudioPlayer.swift (Lines 94-96):
┌──────────────────────────────────────────────────┐
│  AVAudioPlayerNode                               │
│         ↓                                        │
│  AVAudioUnitEQ (10-band EQ)                     │
│         ↓                                        │
│  audioEngine.mainMixerNode                       │
│         ↓                                        │
│  audioEngine.outputNode                          │
│         ↓                                        │
│  System Audio Output (Default Device)           │
└──────────────────────────────────────────────────┘
```

**With AirPlay Routing:**

```
┌──────────────────────────────────────────────────┐
│  AVAudioPlayerNode                               │
│         ↓                                        │
│  AVAudioUnitEQ (10-band EQ) ✅ PRESERVED         │
│         ↓                                        │
│  audioEngine.mainMixerNode                       │
│         ↓                                        │
│  audioEngine.outputNode                          │
│         ↓                                        │
│  Programmatically Selected Device:               │
│     - Built-in Speakers (default)                │
│     - AirPlay Device (user selected)            │
│     - Bluetooth Speaker                          │
│     - External DAC                               │
└──────────────────────────────────────────────────┘
```

### Native Support - No Bridging Required

**✅ AVAudioEngine natively supports AirPlay!**

- No bridging code needed
- No protocol translation
- Engine is device-agnostic
- macOS handles AirPlay 2 protocol
- Just change outputNode.audioDeviceID

### AVPlayer vs AVAudioEngine

**AVPlayer:**
- High-level, simpler API
- Built-in AirPlay support (easier)
- ❌ Can't insert custom audio units (EQ)
- ❌ Would require major rewrite

**AVAudioEngine (Current):**
- Low-level audio graph
- Full control over processing
- ✅ Supports custom EQ
- ✅ Supports AirPlay routing
- ✅ **Correct choice for MacAmp** - no changes needed!

### Maintaining EQ Processing

**CRITICAL FINDING:** EQ is 100% maintained! ✅

**Why:**
- AVAudioUnitEQ is part of engine graph
- EQ processes audio BEFORE outputNode
- outputNode just routes the processed signal
- AirPlay receives fully EQ'd audio
- No special handling needed

**Processing Order:**
1. Audio file → AVAudioPlayerNode
2. **EQ applied** → AVAudioUnitEQ
3. Mixed → mainMixerNode
4. **THEN routed** → outputNode → AirPlay device

### Latency Considerations

**AirPlay 2 Latency:**
- Typical: ~2 seconds network latency
- Variable based on network conditions
- System compensates automatically

**Good News for MacAmp:**
- ✅ AVAudioEngine handles latency compensation
- ✅ Audio server ensures sync across devices
- ✅ playerNode.play() schedules audio correctly
- ✅ Multi-room audio stays synchronized
- ❌ **No manual latency management needed!**

**For Music Playback (Our Use Case):**
- Latency is acceptable
- User isn't expecting real-time (like gaming)
- Buffering compensates for network jitter

---

## 4. SwiftUI Integration

### AVRoutePickerView in SwiftUI

**NSViewRepresentable Wrapper (Simple Implementation):**

```swift
import SwiftUI
import AVFoundation
import AppKit

struct AirPlayPickerView: NSViewRepresentable {
    func makeNSView(context: Context) -> AVRoutePickerView {
        let picker = AVRoutePickerView()
        picker.isRouteDetectionEnabled = true

        // Optional: Customize button style
        picker.routePickerButtonStyle = .system  // or .plain, .custom

        // Optional: Set button tint color
        picker.routePickerButtonBorderColor = .white

        return picker
    }

    func updateNSView(_ nsView: AVRoutePickerView, context: Context) {
        // No update logic needed for simple case
    }
}
```

**Usage in SwiftUI:**

```swift
struct PlayerControlsView: View {
    var body: some View {
        HStack {
            // Transport controls...

            // AirPlay picker button
            AirPlayPickerView()
                .frame(width: 40, height: 40)
        }
    }
}
```

### Custom Menu System (Advanced)

**ViewModel for Device Management:**

```swift
import AVFoundation
import Observation

@MainActor
@Observable
class AirPlayViewModel {
    var devices: [AVAudioDevice] = []
    var currentDevice: AVAudioDevice?

    private let audioEngine: AVAudioEngine
    private let routeDetector = AVRouteDetector()
    private var observers: [NSObjectProtocol] = []

    init(audioEngine: AVAudioEngine) {
        self.audioEngine = audioEngine
        setupNotifications()
        refreshDevices()
    }

    func refreshDevices() {
        // Get all output devices
        devices = AVAudioDevice.outputDevices

        // Update current device
        if let currentID = audioEngine.outputNode.audioDeviceID {
            currentDevice = devices.first { $0.deviceID == currentID }
        }
    }

    func selectDevice(_ device: AVAudioDevice) {
        do {
            try audioEngine.outputNode.setDeviceID(device.deviceID)
            currentDevice = device
        } catch {
            print("Failed to set output device: \(error)")
        }
    }

    private func setupNotifications() {
        // Enable route detection
        routeDetector.isRouteDetectionEnabled = true

        // Observe route changes
        let observer = NotificationCenter.default.addObserver(
            forName: .AVRouteDetectorMultipleRoutesDetectedDidChange,
            object: routeDetector,
            queue: .main
        ) { [weak self] _ in
            self?.refreshDevices()
        }
        observers.append(observer)

        // Observe engine configuration changes
        let configObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: audioEngine,
            queue: .main
        ) { [weak self] _ in
            self?.refreshDevices()
        }
        observers.append(configObserver)
    }

    deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
    }
}
```

**SwiftUI Custom Menu:**

```swift
struct CustomAirPlayMenu: View {
    @State var viewModel: AirPlayViewModel

    var body: some View {
        Menu {
            ForEach(viewModel.devices, id: \.deviceID) { device in
                Button(action: {
                    viewModel.selectDevice(device)
                }) {
                    HStack {
                        // Device icon
                        Image(systemName: deviceIcon(for: device))

                        // Device name
                        Text(device.deviceName)

                        // Checkmark if selected
                        if viewModel.currentDevice?.deviceID == device.deviceID {
                            Spacer()
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Image(systemName: "airplayaudio")
                .imageScale(.large)
        }
        .onAppear {
            viewModel.refreshDevices()
        }
    }

    private func deviceIcon(for device: AVAudioDevice) -> String {
        switch device.transportType {
        case .airPlay:
            return "airplayaudio"
        case .bluetooth:
            return "bluetoothspeaker"
        case .builtIn:
            return "hifispeaker"
        default:
            return "speaker.wave.2"
        }
    }
}
```

### Showing Currently Selected Device

**With AVRoutePickerView:**
- Button shows AirPlay icon
- User clicks → system menu appears
- Selected device shown with checkmark
- **Handled automatically** ✅

**With Custom Menu:**
- Store selectedDevice in ViewModel
- Update on device change notifications
- Show checkmark next to selected device
- Display device name in UI if desired

### Reactive Updates

**SwiftUI @Observable Pattern:**

```swift
@Observable
class AirPlayManager {
    var selectedDeviceName: String = "Built-in"
    var isAirPlayActive: Bool = false

    func updateDeviceInfo() {
        guard let currentID = audioEngine.outputNode.audioDeviceID,
              let device = AVAudioDevice.outputDevices.first(where: { $0.deviceID == currentID }) else {
            selectedDeviceName = "Unknown"
            return
        }

        selectedDeviceName = device.deviceName
        isAirPlayActive = (device.transportType == .airPlay)
    }
}

// SwiftUI view automatically updates when these properties change
```

---

## 5. Entitlements and Permissions

### Required Entitlements

**Network Access (REQUIRED):**

**Capability:** Outgoing Connections (Client)
**Entitlement Key:** `com.apple.security.network.client`

**How to Add:**
1. Open Xcode
2. Select MacAmpApp target
3. Signing & Capabilities tab
4. Click "+ Capability"
5. Add "Outgoing Connections (Client)"

**Result in MacAmp.entitlements:**
```xml
<key>com.apple.security.network.client</key>
<true/>
```

### Info.plist Keys (REQUIRED)

**Local Network Usage Description:**

**Key:** `NSLocalNetworkUsageDescription`
**Value:** "MacAmp needs to access the local network to discover and connect to AirPlay speakers."

**Why Required:**
- macOS privacy protection for local network access
- User sees permission dialog on first network scan
- Without this: Device discovery fails silently
- Required since macOS 11 Big Sur

**How to Add:**
```xml
<!-- In Info.plist -->
<key>NSLocalNetworkUsageDescription</key>
<string>MacAmp needs to access the local network to discover and connect to AirPlay speakers.</string>
```

### Privacy Permissions

**User Permission Flow:**
1. First time app scans for AirPlay devices
2. macOS shows system dialog:
   > "MacAmp would like to find and connect to devices on your local network"
   > [Your NSLocalNetworkUsageDescription text]
   > [Don't Allow] [OK]
3. User must click OK
4. Permission stored, won't ask again

**No Other Special Permissions:**
- ✅ Audio output: Already have `com.apple.security.device.audio-output`
- ✅ Network client: Need to add `com.apple.security.network.client`
- ✅ File access: Already configured
- ❌ No camera/microphone needed
- ❌ No Bluetooth permission needed (AirPlay uses Wi-Fi)

### Current MacAmp Entitlements

**Check existing entitlements:**

```xml
<!-- MacAmpApp/MacAmp.entitlements (current) -->
<dict>
    <key>com.apple.security.device.audio-output</key>
    <true/>
    <key>com.apple.security.files.user-selected.read-write</key>
    <true/>
    <key>com.apple.security.network.client</key>
    <true/>  <!-- ✅ Already have this! -->
    <key>com.apple.security.files.downloads.read-write</key>
    <true/>
</dict>
```

**Finding:** You likely ALREADY have `com.apple.security.network.client` ✅

**Still Need to Add:**
- `NSLocalNetworkUsageDescription` to Info.plist

---

## 6. Xcode 26 / macOS 26 (Tahoe) New Features

### macOS 15 Sequoia Status

**No fundamental AirPlay changes for macOS 15:**
- AVRoutePickerView remains standard approach
- AVAudioEngine routing unchanged
- AirPlay 2 multi-room support continues

**Refinements:**
- Improved AirPlay 2 stability
- Better device discovery performance
- Enhanced multi-room synchronization

### Swift 6 Concurrency Considerations

**MacAmp is already Swift 6 compliant** ✅

**For AirPlay implementation:**

```swift
// AudioPlayer already @MainActor - good!
@MainActor
@Observable
class AudioPlayer {
    private let audioEngine: AVAudioEngine

    // AirPlay device selection (thread-safe)
    func selectAirPlayDevice(_ deviceID: AudioDeviceID) async throws {
        // AVAudioEngine methods are thread-safe
        try audioEngine.outputNode.setDeviceID(deviceID)
    }
}

// Custom ViewModel also @MainActor
@MainActor
@Observable
class AirPlayViewModel {
    // All UI updates on main thread
    var devices: [AVAudioDevice] = []

    // Notifications delivered to .main queue
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: audioEngine,
            queue: .main  // ✅ Main thread
        ) { _ in
            self.refreshDevices()
        }
    }
}
```

### macOS 26 Tahoe (Speculative)

**Note:** macOS 26 is not public, so this is based on trends

**Expected:**
- ✅ AVRoutePickerView will continue to work
- ✅ AVAudioEngine routing API stable
- ✅ AirPlay 2 backward compatible
- ⏸️ Possible: More declarative SwiftUI audio APIs (future)
- ⏸️ Possible: Enhanced device metadata APIs
- ❌ No breaking changes expected

**Swift 6 Impact:**
- Stricter concurrency checking
- `@MainActor` requirements more enforced
- Your current architecture is compliant ✅

### Future Trends (Speculative)

**Declarative APIs:**
- Apple may introduce SwiftUI-native audio routing
- Possibly a view modifier: `.audioOutput(device)`
- Not on horizon yet - use current APIs

**Enhanced AudioDevice Control:**
- More granular device capabilities
- Latency profiles for pro-audio apps
- Not needed for music playback app

**No Major Breaking Changes Expected:**
- AVAudioEngine is mature and stable
- Apple maintains backward compatibility
- Safe to implement with current APIs

---

## Integration Strategy Comparison

### Option A: AVRoutePickerView (Simple)

**Effort:** 30 minutes
**Code:** ~15 lines (NSViewRepresentable wrapper)
**Maintenance:** Zero (Apple handles updates)
**UX:** System standard (familiar to users)
**Aesthetics:** ⚠️ Doesn't match Winamp retro style

**Recommended for:** MVP, quick AirPlay support

### Option B: Custom Menu (Complex)

**Effort:** 3-4 hours
**Code:** ~200 lines (ViewModel + View + Notifications)
**Maintenance:** Medium (handle edge cases, test devices)
**UX:** Custom (can match Winamp style)
**Aesthetics:** ✅ Can use Winamp sprites/styling

**Recommended for:** After MVP, for polished release

### Option C: Hybrid Approach

**Phase 1 (Now):**
- Implement AVRoutePickerView
- Get AirPlay working quickly
- Test with real devices
- Validate architecture

**Phase 2 (Later):**
- Replace with custom menu
- Match Winamp aesthetic
- Add device details (battery, signal)
- Integrate with sprite-based UI

---

## Recommended Implementation Path

### Phase 1: MVP (AVRoutePickerView)

1. Add `NSLocalNetworkUsageDescription` to Info.plist
2. Verify `com.apple.security.network.client` entitlement
3. Create `AirPlayPickerView` NSViewRepresentable
4. Add to WinampMainWindow (near volume/balance controls)
5. Test with AirPlay device
6. Verify EQ still works

**Estimated:** 1 hour

### Phase 2: System Media Integration

1. Implement MPNowPlayingInfoCenter
2. Update "Now Playing" info on track change
3. Add MPRemoteCommandCenter handlers
4. Test Control Center integration

**Estimated:** 2 hours

### Phase 3: Custom Menu (Optional)

1. Create AirPlayViewModel
2. Build custom device selection menu
3. Add Winamp-style sprites
4. Implement graceful disconnect handling
5. Add to clutter bar or menu system

**Estimated:** 4 hours

---

## Technical Requirements Summary

### Entitlements Needed

1. ✅ `com.apple.security.network.client` (likely already have)
2. ✅ `com.apple.security.device.audio-output` (already have)

### Info.plist Keys Needed

1. ❌ `NSLocalNetworkUsageDescription` (need to add)

### Framework Imports

```swift
import AVFoundation  // Already importing
import MediaPlayer   // Need to add (for Now Playing)
```

### No Code Changes to AudioPlayer Required!

**Critical:** AVAudioEngine already supports AirPlay routing
- No changes to audio graph
- No changes to EQ node
- Just expose device selection UI

---

## Architecture Decision

### Recommended: Start with AVRoutePickerView

**Rationale:**
- ✅ Minimal risk (Apple-maintained)
- ✅ Quick implementation (30 min)
- ✅ Fully functional AirPlay 2
- ✅ Multi-room support included
- ✅ Validates architecture before custom UI
- ✅ Can replace with custom UI later

**Implementation Complexity:**
- 🟢 **Simple:** AVRoutePickerView (recommended for MVP)
- 🟡 **Medium:** Custom menu with AVRouteDetector
- 🔴 **Complex:** Full device manager with state sync

---

## Research Sources

- Gemini analysis of Xcode 26 documentation
- AVFoundation framework documentation
- macOS audio routing architecture
- AirPlay 2 technical specifications
- Swift 6 concurrency patterns

---

## Next Steps

See `plan.md` for detailed implementation strategy.

---

# ⚠️ ORACLE CORRECTIONS - READ THIS FIRST

**Date:** 2025-10-30
**Source:** Oracle (Codex) review of Gemini research

## Critical Corrections to Gemini's Findings

### Issue #1: Wrong Framework ❌

**Gemini Said:** Import AVFoundation for AVRoutePickerView
**Oracle Correction:** Import AVKit

```swift
// ❌ WRONG:
import AVFoundation
let picker = AVRoutePickerView()

// ✅ CORRECT:
import AVKit
let picker = AVRoutePickerView()
```

### Issue #2: Custom UI APIs Don't Exist ❌

**Gemini Said:** Use `audioEngine.outputNode.setDeviceID()` for custom device selection
**Oracle Correction:** This API doesn't exist!

```swift
// ❌ WRONG - This method doesn't exist:
try audioEngine.outputNode.setDeviceID(device.deviceID)
```

**Reality:**
- AVAudioOutputNode has NO public setDeviceID method
- AVRouteDetector only reports "multiple routes detected"
- AVAudioDevice shows local Core Audio devices, NOT AirPlay endpoints
- **Custom device selection is NOT possible with public APIs**

**Impact:** Phase 3 (Custom UI) is IMPOSSIBLE - remove from plan

### Issue #3: NSLocalNetworkUsageDescription Not Needed ❌

**Gemini Said:** Required for AirPlay on macOS
**Oracle Correction:** This is iOS-only, macOS ignores it

```xml
<!-- ❌ NOT NEEDED on macOS -->
<key>NSLocalNetworkUsageDescription</key>
<string>...</string>
```

**Reality:**
- macOS sandboxed apps don't show local network prompts
- Air Play works without this key
- Don't add to Info.plist

### Issue #4: Missing Critical Engine Restart Logic ❌

**Gemini Said:** AVAudioEngine automatically handles route changes
**Oracle Correction:** Engine STOPS on route change - MUST restart!

**CRITICAL MISSING CODE:**

```swift
// In AudioPlayer.swift - REQUIRED for AirPlay to work!
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
    // Hardware sample rate changed (e.g., switching to AirPlay)
    // Engine stops - MUST restart or audio goes silent
    
    if isPlaying {
        let savedTime = currentTime
        let savedTrack = currentTrack
        
        // Restart engine
        audioEngine.stop()
        try? audioEngine.start()
        
        // Resume playback from saved position
        if let track = savedTrack {
            // Rewire audio graph for current file
            rewireForCurrentFile()
            seekToPercent(savedTime / track.duration, resume: true)
        }
    } else {
        // Not playing - just restart engine for next playback
        audioEngine.stop()
        try? audioEngine.start()
    }
}
```

**Why Critical:**
- Without this: Audio goes silent when switching to AirPlay
- User thinks AirPlay is broken
- Must restart engine after configuration change

### Issue #5: AVRoutePickerView Customization Limited ❌

**Gemini Said:** Can customize button style, colors, etc.
**Oracle Correction:** macOS AVRoutePickerView has minimal customization

**Reality:**
```swift
// Minimal working implementation:
func makeNSView(context: Context) -> AVRoutePickerView {
    return AVRoutePickerView()
    // That's it! Most properties don't exist on macOS
}
```

**Can't customize:**
- Button style
- Colors
- Size (much)
- Appearance

**Can only:**
- Set frame size
- Position it

---

## Corrected Implementation Plan

### ✅ PHASE 1: AVRoutePickerView (ONLY OPTION)

**What Works:**
1. Create NSViewRepresentable wrapper
2. Import AVKit (not AVFoundation)
3. Create minimal AVRoutePickerView
4. Add to UI
5. **Add engine configuration observer** (CRITICAL)
6. Test with AirPlay device

**Estimated Time:** 2 hours (including engine restart logic)

### ✅ PHASE 2: Now Playing Integration (OPTIONAL)

**What Works:**
1. Add MediaPlayer import
2. Implement MPNowPlayingInfoCenter updates
3. Implement MPRemoteCommandCenter handlers
4. Test Control Center integration

**Note:** Verify MediaPlayer works on macOS (Oracle suggests checking)

**Estimated Time:** 2 hours

### ❌ PHASE 3: Custom UI (IMPOSSIBLE - REMOVE)

**What Doesn't Work:**
- AVRouteDetector doesn't expose AirPlay devices
- AVAudioDevice doesn't include AirPlay endpoints
- No outputNode.setDeviceID() API exists
- Can't build custom device selection menu

**Reality:** Must use system picker, no custom UI possible

---

## Corrected Technical Requirements

### Entitlements

**Probably Already Have:**
- ✅ `com.apple.security.network.client` (check entitlements file)

**Don't Need:**
- ❌ No special AirPlay entitlement
- ❌ NSLocalNetworkUsageDescription (iOS-only)

### Info.plist

**DON'T ADD:**
- ❌ NSLocalNetworkUsageDescription (Gemini was wrong)

**No Info.plist changes needed!**

### Framework Imports

**Phase 1:**
```swift
import AVKit  // ✅ For AVRoutePickerView
```

**Phase 2:**
```swift
import MediaPlayer  // For Now Playing (verify works on macOS)
```

---

## Critical Implementation Notes

### 1. AVRoutePickerView Minimal Usage

```swift
import SwiftUI
import AVKit  // ✅ CORRECT import

struct AirPlayPickerView: NSViewRepresentable {
    func makeNSView(context: Context) -> AVRoutePickerView {
        return AVRoutePickerView()
    }

    func updateNSView(_ nsView: AVRoutePickerView, context: Context) {}
}
```

### 2. Engine Configuration Observer (CRITICAL)

**MUST ADD to AudioPlayer.swift:**

```swift
// Call in init()
setupEngineConfigurationObserver()

// Observer method
private func setupEngineConfigurationObserver() {
    NotificationCenter.default.addObserver(
        forName: .AVAudioEngineConfigurationChange,
        object: audioEngine,
        queue: .main
    ) { [weak self] _ in
        self?.restartEngineAfterRouteChange()
    }
}

// Restart method
private func restartEngineAfterRouteChange() {
    guard isPlaying else {
        // Not playing - just restart engine
        try? audioEngine.start()
        return
    }

    // Save state
    let time = currentTime
    let duration = currentTrack?.duration ?? 1.0

    // Restart engine
    audioEngine.stop()
    try? audioEngine.start()

    // Resume playback
    seekToPercent(time / duration, resume: true)
}
```

### 3. Simplified Scope

**What We Can Do:**
- ✅ Add system AirPlay picker button
- ✅ Audio routes to selected device
- ✅ EQ processing maintained
- ✅ Handle engine restarts
- ✅ Add Now Playing integration

**What We CAN'T Do:**
- ❌ Custom Winamp-style device menu
- ❌ Programmatic device selection
- ❌ Show device list in custom UI
- ❌ Device status indicators
- ❌ Custom styling of picker

---

## Revised Effort Estimate

**Phase 1 (AVRoutePickerView + Engine Restart):**
- Time: 2 hours
- Complexity: LOW
- Risk: LOW
- Feasibility: ✅ HIGH

**Phase 2 (Now Playing Integration):**
- Time: 2 hours
- Complexity: LOW
- Risk: MEDIUM (verify MediaPlayer on macOS)
- Feasibility: ✅ MEDIUM-HIGH

**Phase 3 (Custom UI):**
- Time: N/A
- Complexity: N/A
- Risk: N/A
- Feasibility: ❌ IMPOSSIBLE

**Total Realistic Time:** 2-4 hours (not 7+)

---

## Oracle Final Recommendations

1. ✅ Use AVRoutePickerView (system picker only)
2. ✅ Import AVKit (not AVFoundation)
3. ✅ Add engine configuration observer (CRITICAL)
4. ✅ Don't add NSLocalNetworkUsageDescription
5. ✅ Don't attempt custom UI
6. ✅ Test with real AirPlay device
7. ✅ Focus on Phase 1, defer Phase 2

**Verdict:** Simple, achievable feature with correct understanding!

---

**NOTE:** All sections below from Gemini research should be read with these corrections in mind.
Many code examples are INCORRECT (wrong imports, non-existent APIs).
Refer to Oracle corrections above for accurate implementation.


---

## Phase 3B: Winamp Logo Overlay (Oracle-Approved)

### User's Creative Solution

**Instead of separate button:** Position AirPlay picker over Winamp logo
**Pattern from webamp:** Clickable "about" link overlays logo → opens webamp.org
**MacAmp adaptation:** Clickable overlay on logo → opens AirPlay picker

### Webamp Implementation Reference

**File:** `webamp_clone/packages/webamp/js/components/MainWindow/index.tsx`
**Lines:** 129-134

```tsx
<a
  id="about"
  target="_blank"
  href="https://webamp.org/about"
  title="About"
/>
```

**CSS:** `webamp_clone/packages/webamp/css/main-window.css` Lines 394-399

```css
#webamp #about {
  position: absolute;
  top: 91px;
  left: 253px;
  height: 15px;
  width: 13px;
}
```

**How it works:**
- Invisible clickable <a> element
- Positioned over Winamp logo via CSS
- User clicks logo → Opens webamp.org
- Logo sprite provides visual, link provides functionality

### Oracle's SwiftUI Solution

**Oracle Confirmed:** Can position transparent AVRoutePickerView over logo ✅

**Implementation Pattern:**

```swift
// 1. Create transparent picker
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

    func updateNSView(_ nsView: AVRoutePickerView, context: Context) {}
}

// 2. Position over logo in WinampMainWindow
AirPlayRoutePicker()
    .frame(width: 24, height: 24) // Accessibility minimum
    .contentShape(Rectangle())
    .accessibilityLabel("Open AirPlay devices")
    .at(CGPoint(x: 253, y: 91)) // Webamp reference - verify for MacAmp
```

**Key Points (Oracle):**
- User MUST click actual AVRoutePickerView (can't trigger programmatically)
- Make picker transparent (alphaValue = 0.01)
- Position exactly over logo hotspot
- Frame size: 24×24 minimum for accessibility
- Logo sprite provides visual, picker provides functionality

### Skin-Dependent Logo Position

**Important:** Logo position varies by skin

**Webamp reference:** Logo coordinates in webamp:
- Classic skin: (253, 91) size 13×15

**MacAmp needs:**
- Research logo position in MAIN_TITLE_BAR sprite
- Or research GEN.BMP (if skins define logo position)
- May need dynamic positioning based on current skin
- Start with fixed coords, refine if needed

**Future enhancement:** Query skin metadata for logo bounds

### Advantages of Logo Overlay

**UX:**
- ✅ Hidden integration (no visible AirPlay icon)
- ✅ Winamp aesthetic maintained
- ✅ Clever use of existing visual element
- ✅ Matches webamp "about" pattern

**Technical:**
- ✅ Simple implementation (~20 lines)
- ✅ Oracle-validated approach
- ✅ Works with AVKit APIs
- ✅ No custom device enumeration needed

**Considerations:**
- ⚠️ Logo position varies by skin
- ⚠️ User might not discover feature (not obvious)
- ⚠️ No visual indication of AirPlay status
- ⚠️ Consider adding tooltip or subtle hint

---

## Revised Phase Comparison

### Phase 1: Standard Placement
- Visible system AirPlay icon
- Near volume/balance sliders
- Obvious to users
- Effort: 2 hours

### Phase 3B: Logo Overlay (Recommended)
- Hidden integration
- Click Winamp logo for AirPlay
- Maintains Winamp aesthetic
- Effort: 2 hours (with positioning research)

### Both (Hybrid Approach)
- Start with standard placement (Phase 1)
- Test functionality
- Add logo overlay (Phase 3B)
- Keep or remove standard placement
- Effort: 3 hours total

---

**Oracle Verdict on Logo Overlay:** ✅ Feasible and elegant solution!

