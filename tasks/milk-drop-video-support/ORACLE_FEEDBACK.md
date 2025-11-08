# Oracle Validation Feedback (B- Grade)

**Date**: 2025-11-08  
**Model**: gpt-5-codex  
**Reasoning**: High  
**Grade**: B-  
**Status**: NO-GO until critical issues resolved

---

## Critical Issues (Showstoppers)

### Issue #1: No NSWindow Infrastructure ⚠️ CRITICAL

**Problem**: Plan says "two independent windows" but code still mounts views inside `WinampMainWindow`.

**Current Plan (WRONG)**:
```swift
// In WinampMainWindow.swift body:
if appSettings.showVideoWindow {
    VideoWindowView()  // ❌ Still inside single NSWindow!
}
```

**What We Actually Need**:
```swift
// Separate WindowGroup scenes in App.swift:
WindowGroup("Video", id: "video-window") {
    VideoWindowView()
        .environment(appSettings)
}

WindowGroup("Milkdrop", id: "milkdrop-window") {
    MilkdropWindowView()
        .environment(appSettings)
}

// Or NSWindow approach with NSWindowController
```

**Fix Required**: Add NSWindow infrastructure milestone BEFORE Day 3

---

### Issue #2: VIDEO.bmp Parsing Too Rigid ⚠️ CRITICAL

**Problem**: Assumes fixed 233x119 sprite layout - breaks with different skins.

**Current Plan (FRAGILE)**:
```swift
titlebarActive = videoBmp.cropping(to: CGRect(x: 0, y: 0, width: 233, height: 14))
// ❌ Hardcoded dimensions!
```

**What We Need**:
- Dynamic sprite region detection
- Or metadata file (like PLEDIT.txt for playlist)
- Or multiple known layouts with fallback

**Fix Required**: Robust sprite parsing strategy

---

### Issue #3: AppSettings Loading Missing ⚠️ CRITICAL

**Problem**: New properties only have `didSet` (save), no loading logic!

**Current Plan (INCOMPLETE)**:
```swift
var videoWindowFrame: CGRect? {
    didSet { /* saves to UserDefaults */ }
    // ❌ NO get/init logic!
}
```

**What We Need**:
```swift
// In AppSettings init:
self.videoWindowFrame = {
    if let str = UserDefaults.standard.string(forKey: "videoWindowFrame") {
        return NSRectFromCGRect(NSRectFromString(str))
    }
    return nil
}()
```

**Fix Required**: Add complete load/save cycle for all properties

---

## Recommendations

### Rec #1: Add Aux Window Host Milestone

**Insert Before Day 3**: Days 2-3 should create window infrastructure

**Tasks**:
- Research SwiftUI WindowGroup vs NSWindow approach
- Create window hosting architecture
- Test multiple windows can open simultaneously
- Ensure proper lifecycle management

### Rec #2: Per-Window File Organization

**Current**: `Views/Windows/` (flat dump)

**Better**:
```
Views/
├── VideoWindow/
│   ├── VideoWindowView.swift
│   ├── VideoWindowChromeView.swift
│   ├── VideoWindowTitlebar.swift
│   ├── VideoWindowControlBar.swift
│   └── AVPlayerViewRepresentable.swift
└── MilkdropWindow/
    ├── MilkdropWindowView.swift
    ├── ButterchurnWebView.swift
    └── PresetSelectorMenu.swift
```

### Rec #3: Split Large Commits

**Example**: "extend AudioPlayer with video support" should be:
1. `feat: Add MediaType enum to AudioPlayer`
2. `feat: Add video file detection logic`
3. `feat: Add AVPlayer property to AudioPlayer`
4. `feat: Implement loadVideoFile method`

### Rec #4: Add Automated Tests

**Need actual test implementations**:
```swift
// Not just aspirational!
func testMediaTypeDetection() {
    XCTAssertEqual(detectMediaType(URL("test.mp4")), .video)
    XCTAssertEqual(detectMediaType(URL("test.mp3")), .audio)
}

func testVideoWindowPersistence() {
    let frame = CGRect(x: 100, y: 200, width: 300, height: 200)
    appSettings.videoWindowFrame = frame
    // Reload AppSettings
    XCTAssertEqual(appSettings.videoWindowFrame, frame)
}
```

---

## Timeline Validation

**Oracle Assessment**: 10 days is OPTIMISTIC

**Recommended**: **12 days** with buffers

**Breakdown**:
- Days 1-3: Foundation + NSWindow infrastructure (was 1-2)
- Days 4-5: VIDEO.bmp parsing (was Day 3)
- Days 6-7: Video chrome + AVPlayer (was Days 4-5)
- Day 8: Video polish (was Day 6)
- Days 9-10: Milkdrop foundation + Butterchurn (was Days 7-8)
- Day 11: FFT bridge (was Day 9)
- Day 12: Final polish + testing (was Day 10)

**High-Risk Tasks Identified**:
- Day 3: NSWindow infrastructure (new, untested)
- Days 4-5: VIDEO.bmp parsing (complex, variable layouts)
- Day 11: FFT bridge (performance-sensitive)

---

## New Risks to Add

### Risk: NSWindow Lifecycle Management
**Description**: Creating independent NSWindows requires lifecycle management  
**Mitigation**: Research WindowGroup vs NSWindowController approaches

### Risk: AVPlayer + Audio Engine Conflicts
**Description**: Video playback may conflict with existing audio pipeline  
**Mitigation**: Proper mode switching, test video+audio coexistence

### Risk: WKWebView Resource Loading
**Description**: Butterchurn bundle may have sandbox/permission issues  
**Mitigation**: Test resource loading early, use proper file access grants

### Risk: Multi-Window Docking/Focus
**Description**: Multiple NSWindows without magnetic docking may feel disjointed  
**Mitigation**: Document as known limitation, plan magnetic docking integration

---

## Swift 6 Compliance Issues

### Issue: CGRect Persistence Needs AppKit
```swift
// Need to import AppKit for NSRectFromString
import AppKit

// In AppSettings init:
if let str = UserDefaults.standard.string(forKey: "videoWindowFrame") {
    self.videoWindowFrame = NSRectFromString(str) as CGRect
}
```

### Issue: Timer Loop Actor Isolation
```swift
// Milkdrop FFT update loop needs proper actor isolation
@MainActor
class MilkdropUpdateManager: ObservableObject {
    private var timer: Timer?
    // Proper main-actor isolation
}
```

---

## Integration with Existing Code

**Oracle Assessment**: Extending AppSettings is fine, BUT:

**Need**:
- Complete init logic (not just didSet)
- Import AppKit for NSRectFromString
- Validation for loaded values (bounds checking)

**Consider**: Separate VideoSettings/MilkdropSettings if AppSettings gets too large

---

## Action Items (Before Implementation)

1. ✅ Fix NSWindow infrastructure (add to plan)
2. ✅ Improve VIDEO.bmp parsing (dynamic detection)
3. ✅ Add AppSettings loading logic
4. ✅ Reorganize file structure
5. ✅ Add real automated tests
6. ✅ Extend timeline to 12 days
7. ✅ Add new risks
8. ✅ Get Oracle approval on revised plan

---

**Status**: 🔴 NO-GO (Critical issues identified)  
**Next**: Fix critical issues, get Oracle re-approval  
**Timeline**: Add 1-2 days for plan revision
