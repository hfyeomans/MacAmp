# Oracle Code Review - AirPlay Task

**Date:** 2025-10-30
**Reviewer:** Oracle (Codex)
**Scope:** Complete AirPlay task (research, plan, state, todo)

---

## Critical Issues Found (5)

### 1. ❌ CRITICAL: Wrong Framework for AVRoutePickerView

**Gemini Said:** Import AVFoundation
**Oracle Says:** Import AVKit

**Issue:**
```swift
// ❌ WRONG (Gemini):
import AVFoundation
let picker = AVRoutePickerView()  // Doesn't exist in AVFoundation!

// ✅ CORRECT (Oracle):
import AVKit
let picker = AVRoutePickerView()  // Lives in AVKit on macOS
```

**Impact:** Code won't compile
**Fix:** Change import from AVFoundation to AVKit
**Files Affected:** plan.md, research.md, all code examples

---

### 2. ❌ CRITICAL: outputNode.setDeviceID() Doesn't Exist

**Gemini Said:** Can programmatically route with `audioEngine.outputNode.setDeviceID(deviceID)`
**Oracle Says:** This API doesn't exist - custom UI path is NOT feasible

**Issue:**
```swift
// ❌ WRONG (Gemini claims this works):
try audioEngine.outputNode.setDeviceID(airplayDevice.deviceID)

// Reality: AVAudioOutputNode has NO setDeviceID method!
```

**What This Means:**
- Phase 3 (Custom UI) is NOT possible with public APIs
- AVRouteDetector doesn't expose AirPlay devices
- AVAudioDevice only shows local Core Audio devices (not AirPlay endpoints)
- **MUST use AVRoutePickerView** (system UI only option)

**Impact:** Custom Winamp-style menu is NOT feasible
**Fix:** Remove all Phase 3 content, focus only on AVRoutePickerView
**Files Affected:** All files - remove custom UI sections

---

### 3. ❌ MEDIUM: NSLocalNetworkUsageDescription is iOS-Only

**Gemini Said:** Required on macOS for AirPlay
**Oracle Says:** This key is ignored on macOS - not needed

**Issue:**
```xml
<!-- ❌ NOT NEEDED on macOS -->
<key>NSLocalNetworkUsageDescription</key>
<string>...</string>
```

**Reality:**
- macOS sandboxed apps don't show iOS local-network prompts
- AirPlay works without this key
- This is iOS/iPadOS only

**Impact:** Unnecessary Info.plist change
**Fix:** Remove NSLocalNetworkUsageDescription from plan
**Files Affected:** plan.md, state.md, todo.md

---

### 4. ❌ CRITICAL: Missing AVAudioEngineConfigurationChange Handling

**Gemini Said:** AVAudioEngine automatically handles AirPlay routing
**Oracle Says:** Engine STOPS when route changes - must restart!

**Issue:**
```swift
// Current AudioPlayer.swift doesn't observe this:
NotificationCenter.default.addObserver(
    forName: .AVAudioEngineConfigurationChange,
    object: audioEngine,
    queue: .main
) { [weak self] _ in
    // MUST restart engine or playback silently fails!
    self?.handleEngineConfigurationChange()
}
```

**Why Critical:**
- Hardware sample rate changes when switching to AirPlay
- Engine stops processing
- Audio goes silent without restart
- User thinks AirPlay is broken

**Impact:** AirPlay won't work without this
**Fix:** Add configuration change observer to AudioPlayer
**Files Affected:** plan.md (add as required step)

---

### 5. ❌ MEDIUM: AVRoutePickerView Properties Don't Exist on macOS

**Gemini Said:**
```swift
picker.isRouteDetectionEnabled = true
picker.routePickerButtonStyle = .system
```

**Oracle Says:** These properties aren't available on macOS AVRoutePickerView

**Reality:**
- AppKit AVRoutePickerView has different API than UIKit version
- Properties available are limited
- Can't customize as much as Gemini suggested

**Impact:** Code examples won't compile
**Fix:** Use minimal AVRoutePickerView with no customization
**Files Affected:** plan.md, research.md code examples

---

## Oracle Recommendations

### 1. Focus ONLY on AVRoutePickerView (No Custom UI)

**Remove:**
- All Phase 3 (Custom UI) content
- All references to AVRouteDetector
- All references to outputNode.setDeviceID()
- All references to AVAudioDevice for AirPlay selection
- Custom menu UI code examples

**Reality:**
- System picker is ONLY viable option
- Custom device selection not possible with public APIs
- Phase 3 is speculative/impossible

### 2. Add Critical Engine Configuration Handling

**Add to plan.md:**
```swift
// In AudioPlayer.swift - REQUIRED!
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
    // Engine stopped due to route change (AirPlay connect/disconnect)
    // MUST restart or playback fails
    if isPlaying {
        let currentTime = self.currentTime
        audioEngine.stop()
        try? audioEngine.start()
        // Resume from current position
        seekToPercent(currentTime / (currentTrack?.duration ?? 1.0), resume: true)
    }
}
```

### 3. Remove macOS-Invalid Keys

**Remove from plan:**
- NSLocalNetworkUsageDescription (iOS-only)

**Keep:**
- com.apple.security.network.client (if exists - doesn't hurt)

### 4. Correct AVRoutePickerView Usage

**Minimal working wrapper:**
```swift
import SwiftUI
import AVKit  // ✅ Correct import

struct AirPlayPickerView: NSViewRepresentable {
    func makeNSView(context: Context) -> AVRoutePickerView {
        let picker = AVRoutePickerView()
        // That's it! No other properties needed/available
        return picker
    }

    func updateNSView(_ nsView: AVRoutePickerView, context: Context) {
        // No-op
    }
}
```

### 5. Set Realistic Expectations

**Phase 1 (MVP): AVRoutePickerView**
- Effort: 1 hour
- UI: System standard (can't customize)
- ✅ Feasible

**Phase 2 (Now Playing): MPNowPlayingInfoCenter**
- Effort: 2 hours
- ✅ Feasible
- Note: Verify MediaPlayer availability on macOS

**Phase 3 (Custom UI): REMOVE**
- ❌ Not feasible with public APIs
- Remove entirely from plan

---

## Oracle Final Assessment

**Gemini's Research:** 60% accurate
- ✅ Correct: AVAudioEngine supports AirPlay
- ✅ Correct: EQ processing maintained
- ✅ Correct: AVRoutePickerView is solution
- ❌ Wrong: Custom UI APIs don't exist
- ❌ Wrong: Framework imports
- ❌ Wrong: macOS Info.plist requirements
- ❌ Missing: Engine configuration change handling

**Must Fix Before Implementation:**
1. Change AVFoundation → AVKit
2. Remove all custom UI code/plans
3. Remove NSLocalNetworkUsageDescription
4. Add engine configuration change observer
5. Set realistic scope (system picker only)

**Revised Effort Estimate:**
- Phase 1: 1-2 hours (system picker + engine restart)
- Phase 2: 2 hours (Now Playing)
- Phase 3: N/A (not possible)
- **Total: 3-4 hours** (not 7+ as planned)

**Risk Level After Corrections:** LOW
- Simpler scope (just system picker)
- Well-established API (AVRoutePickerView)
- Critical engine restart handled
- No custom UI complexity

---

## Recommended Next Steps

1. ✅ Update all task files with Oracle corrections
2. ✅ Remove Phase 3 (custom UI) entirely
3. ✅ Add engine configuration change handling to plan
4. ✅ Correct all code examples (AVKit import)
5. ✅ Remove NSLocalNetworkUsageDescription
6. ⏸️ Present corrected task to user
7. ⏸️ Implement Phase 1 (simple, well-defined)

---

**Oracle Verdict:** Feasible after corrections. Focus on AVRoutePickerView only. Custom UI is not possible.
