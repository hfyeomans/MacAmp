# Clutter Bar O and I Buttons - Implementation Plan

**Date:** 2025-11-02
**Feature:** Options Menu (O Button) and Track Info Dialog (I Button)
**Priority:** P2 (Quick Win)
**Estimated Time:** 6.5 hours (with 20% contingency)
**Pattern Source:** tasks/done/double-size-button/

---

## 🎯 Implementation Strategy

**Approach:** Follow proven double-size-button pattern exactly
- Implement O button first (simpler, menu-driven)
- Then I button (more complex, requires new UI)
- Test both together for interactions
- Both buttons use existing scaffolding in WinampMainWindow.swift

**Why This Order:**
1. O button builds confidence (2 hours, low complexity)
2. I button reuses patterns from O (3 hours, medium complexity)
3. Testing combined functionality validates architecture

---

## 📊 Overview

### O Button (Options Menu) - 2 Hours

**Functionality:** Opens context menu with player options
- Time display mode toggle (elapsed ⇄ remaining)
- Double-size mode toggle (already exists)
- Repeat mode toggle (already exists)
- Shuffle toggle (already exists)

**Components:**
- State: `AppSettings.timeDisplayMode` (new enum)
- UI: NSMenu via AppKit bridge
- Integration: Existing button scaffolding

---

### I Button (Track Info Dialog) - 3 Hours

**Functionality:** Shows current track metadata in modal dialog
- Track title, artist, album
- Duration, file format
- Technical details (bitrate, sample rate)
- Read-only display (edit deferred to P3)

**Components:**
- State: `AppSettings.showTrackInfoDialog` (new Bool)
- UI: TrackInfoView.swift (new SwiftUI view)
- Data: PlaybackCoordinator.currentTrack
- Integration: Sheet presentation

---

## 🏗️ Phase Breakdown

---

### PHASE 1: O Button Foundation (30 minutes)

**Objective:** Add time display mode state management

#### 1.1 Define TimeDisplayMode Enum

**File:** `MacAmpApp/Models/AppSettings.swift`

**Add after line 21 (where isDoubleSizeMode is defined):**

```swift
enum TimeDisplayMode: String, Codable {
    case elapsed = "elapsed"
    case remaining = "remaining"
}
```

#### 1.2 Add State Property

**File:** `MacAmpApp/Models/AppSettings.swift`

**Add after isAlwaysOnTop property:**

```swift
var timeDisplayMode: TimeDisplayMode = .elapsed {
    didSet {
        UserDefaults.standard.set(timeDisplayMode.rawValue, forKey: "timeDisplayMode")
    }
}

init() {
    // Load time display mode from UserDefaults
    if let saved = UserDefaults.standard.string(forKey: "timeDisplayMode"),
       let mode = TimeDisplayMode(rawValue: saved) {
        self.timeDisplayMode = mode
    }
}
```

**Pattern:** Exact same as isDoubleSizeMode with didSet persistence

---

#### 1.3 Add Toggle Method

**File:** `MacAmpApp/Models/AppSettings.swift`

```swift
func toggleTimeDisplayMode() {
    timeDisplayMode = (timeDisplayMode == .elapsed) ? .remaining : .elapsed
}
```

---

### PHASE 2: O Button Menu Implementation (1 hour)

**Objective:** Create and wire up context menu

#### 2.1 Create Menu Helper

**File:** `MacAmpApp/Views/WinampMainWindow.swift`

**Add new method after buildClutterBarButtons():**

```swift
@MainActor
private func showOptionsMenu(from sourceView: NSView) {
    let menu = NSMenu(title: "Options")

    // Time Display Modes
    let elapsedItem = NSMenuItem(
        title: "Time elapsed",
        action: #selector(toggleTimeDisplay),
        keyEquivalent: ""
    )
    elapsedItem.state = settings.timeDisplayMode == .elapsed ? .on : .off
    elapsedItem.target = self
    menu.addItem(elapsedItem)

    let remainingItem = NSMenuItem(
        title: "Time remaining",
        action: #selector(toggleTimeDisplay),
        keyEquivalent: ""
    )
    remainingItem.state = settings.timeDisplayMode == .remaining ? .on : .off
    remainingItem.target = self
    menu.addItem(remainingItem)

    menu.addItem(NSMenuItem.separator())

    // Double Size
    let doubleSizeItem = NSMenuItem(
        title: "Double Size",
        action: #selector(toggleDoubleSize),
        keyEquivalent: "d"
    )
    doubleSizeItem.keyEquivalentModifierMask = [.command]
    doubleSizeItem.state = settings.isDoubleSizeMode ? .on : .off
    doubleSizeItem.target = self
    menu.addItem(doubleSizeItem)

    menu.addItem(NSMenuItem.separator())

    // Repeat
    let repeatItem = NSMenuItem(
        title: "Repeat",
        action: #selector(toggleRepeat),
        keyEquivalent: "r"
    )
    repeatItem.state = audioPlayer.repeatEnabled ? .on : .off
    repeatItem.target = self
    menu.addItem(repeatItem)

    // Shuffle
    let shuffleItem = NSMenuItem(
        title: "Shuffle",
        action: #selector(toggleShuffle),
        keyEquivalent: "s"
    )
    shuffleItem.state = audioPlayer.shuffleEnabled ? .on : .off
    shuffleItem.target = self
    menu.addItem(shuffleItem)

    // Show menu below button
    let menuOrigin = NSPoint(x: sourceView.frame.minX, y: sourceView.frame.minY)
    menu.popUp(positioning: nil, at: menuOrigin, in: sourceView.superview)
}

@objc private func toggleTimeDisplay() {
    settings.toggleTimeDisplayMode()
}

@objc private func toggleDoubleSize() {
    settings.isDoubleSizeMode.toggle()
}

@objc private func toggleRepeat() {
    audioPlayer.repeatEnabled.toggle()
}

@objc private func toggleShuffle() {
    audioPlayer.shuffleEnabled.toggle()
}
```

---

#### 2.2 Update O Button

**File:** `MacAmpApp/Views/WinampMainWindow.swift`

**Replace O button scaffolding (around line 530):**

```swift
// O button (Options) - NOW FUNCTIONAL ✅
Button {
    // Capture button view for menu positioning
    if let window = NSApp.keyWindow,
       let contentView = window.contentView {
        showOptionsMenu(from: contentView)
    }
} label: {
    SimpleSpriteImage("MAIN_CLUTTER_BAR_BUTTON_O", width: 8, height: 8)
}
.buttonStyle(PlainButtonStyle())
.accessibilityLabel("Options menu")
```

**Remove:** `.disabled(true)` and `.accessibilityHidden(true)`

---

### PHASE 3: O Button Keyboard Shortcut (15 minutes)

**Objective:** Add Ctrl+T for time toggle

#### 3.1 Add Command to AppCommands

**File:** `MacAmpApp/AppCommands.swift`

**Add after Ctrl+D command:**

```swift
Button("Time: \(settings.timeDisplayMode == .elapsed ? "Elapsed" : "Remaining")") {
    settings.toggleTimeDisplayMode()
}
.keyboardShortcut("t", modifiers: [.control])
```

---

### PHASE 4: O Button Testing (15 minutes)

**Test Checklist:**
- [ ] Click O button → menu appears below button
- [ ] Time elapsed selected by default
- [ ] Click elapsed/remaining → toggles mode
- [ ] Double Size shows checkmark if active
- [ ] Repeat shows checkmark if active
- [ ] Shuffle shows checkmark if active
- [ ] Ctrl+T toggles time mode
- [ ] Ctrl+D, R, S shortcuts work from menu
- [ ] Menu dismisses after selection
- [ ] Click outside menu to dismiss
- [ ] O button sprite shows selected state while menu open (if possible)

---

### PHASE 5: I Button Foundation (30 minutes)

**Objective:** Add dialog state and view scaffold

#### 5.1 Add Dialog State

**File:** `MacAmpApp/Models/AppSettings.swift`

**Add after timeDisplayMode:**

```swift
var showTrackInfoDialog: Bool = false
```

---

#### 5.2 Create TrackInfoView

**File:** `MacAmpApp/Views/Components/TrackInfoView.swift` (NEW)

```swift
import SwiftUI

@MainActor
struct TrackInfoView: View {
    @EnvironmentObject var audioPlayer: AudioPlayer
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 20) {
            // Header
            Text("Track Information")
                .font(.headline)
                .padding(.top)

            if let track = audioPlayer.currentTrack {
                // Track Details
                VStack(alignment: .leading, spacing: 12) {
                    InfoRow(label: "Title", value: track.title)

                    if let artist = track.artist {
                        InfoRow(label: "Artist", value: artist)
                    }

                    InfoRow(label: "Duration", value: formatDuration(track.duration))

                    // Technical Details (from AudioPlayer properties)
                    Divider()

                    if let bitrate = audioPlayer.bitrate {
                        InfoRow(label: "Bitrate", value: "\(bitrate) kbps")
                    }

                    if let sampleRate = audioPlayer.sampleRate {
                        InfoRow(label: "Sample Rate", value: "\(sampleRate) Hz")
                    }

                    if let channels = audioPlayer.channelCount {
                        InfoRow(label: "Channels", value: channels == 2 ? "Stereo" : "Mono")
                    }
                }
                .padding()
            } else {
                Text("No track currently playing")
                    .foregroundColor(.secondary)
                    .padding()
            }

            // Close Button
            Button("Close") {
                dismiss()
            }
            .keyboardShortcut(.defaultAction)
            .padding(.bottom)
        }
        .frame(width: 400)
        .frame(minHeight: 300)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label + ":")
                .foregroundColor(.secondary)
                .frame(width: 100, alignment: .trailing)

            Text(value)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview {
    TrackInfoView()
        .environmentObject(AudioPlayer())
}
```

---

### PHASE 6: I Button Integration (45 minutes)

**Objective:** Wire up dialog presentation

#### 6.1 Update I Button

**File:** `MacAmpApp/Views/WinampMainWindow.swift`

**Replace I button scaffolding (around line 545):**

```swift
// I button (Info) - NOW FUNCTIONAL ✅
Button {
    settings.showTrackInfoDialog = true
} label: {
    SimpleSpriteImage(
        settings.showTrackInfoDialog ? "MAIN_CLUTTER_BAR_BUTTON_I_SELECTED" : "MAIN_CLUTTER_BAR_BUTTON_I",
        width: 8,
        height: 7
    )
}
.buttonStyle(PlainButtonStyle())
.accessibilityLabel("Track information")
```

**Remove:** `.disabled(true)` and `.accessibilityHidden(true)`

---

#### 6.2 Add Sheet Presentation

**File:** `MacAmpApp/Views/WinampMainWindow.swift`

**Add sheet modifier to main VStack (around line 170):**

```swift
.sheet(isPresented: Binding(
    get: { settings.showTrackInfoDialog },
    set: { settings.showTrackInfoDialog = $0 }
)) {
    TrackInfoView()
        .environmentObject(playbackCoordinator)
}
```

---

### PHASE 7: I Button Keyboard Shortcut (15 minutes)

**Objective:** Add Ctrl+I for track info

#### 7.1 Add Command to AppCommands

**File:** `MacAmpApp/AppCommands.swift`

**Add after Ctrl+T command:**

```swift
Button("Track Information") {
    settings.showTrackInfoDialog = true
}
.keyboardShortcut("i", modifiers: [.control])
```

---

### PHASE 8: I Button Testing (30 minutes)

**Test Checklist:**
- [ ] Click I button → dialog appears
- [ ] Dialog shows current track info (if playing)
- [ ] Dialog shows "No track" message (if nothing playing)
- [ ] All metadata fields display correctly:
  - Title
  - Artist (if available)
  - Album (if available)
  - Duration (MM:SS format)
  - File format (MP3, FLAC, etc.)
- [ ] Technical details show (if available):
  - Bitrate
  - Sample Rate
  - Channels
- [ ] Close button works
- [ ] Esc key closes dialog
- [ ] Click outside dialog to dismiss
- [ ] Ctrl+I opens dialog
- [ ] I button sprite shows selected state while dialog open
- [ ] Dialog doesn't break playback
- [ ] Works in double-size mode
- [ ] Works with all 3 skins (Base, Plastic, Green Dimension)

---

### PHASE 9: Time Display Migration (60 minutes)

**Objective:** Migrate showRemainingTime from local state to AppSettings.timeDisplayMode

#### 9.1 Remove Local State

**File:** `MacAmpApp/Views/WinampMainWindow.swift`

**Find and remove (around line 19):**

```swift
@State private var showRemainingTime = false
```

#### 9.2 Update Time Display Gesture

**File:** `MacAmpApp/Views/WinampMainWindow.swift`

**Find the time display onTapGesture (around line 344):**

```swift
.onTapGesture {
    showRemainingTime.toggle()
}
```

**Replace with:**

```swift
.onTapGesture {
    settings.timeDisplayMode = (settings.timeDisplayMode == .elapsed) ? .remaining : .elapsed
}
```

#### 9.3 Update Time Calculation Logic

**File:** `MacAmpApp/Views/WinampMainWindow.swift`

**Find references to `showRemainingTime` in time display logic and replace with:**

```swift
settings.timeDisplayMode == .remaining
```

#### 9.4 Test Migration

- [ ] Build project → verify no errors
- [ ] Run app
- [ ] Click on time display → should toggle mode
- [ ] Verify time changes between elapsed and remaining
- [ ] Verify persistence across app restarts
- [ ] Verify O button menu reflects correct state

**Phase 9 Milestone:** ✅ Time display migration complete

---

### PHASE 10: Integration Testing (30 minutes)

**Combined Functionality:**
- [ ] O and I buttons work independently
- [ ] Can open menu while dialog is open
- [ ] Can open dialog while menu is open
- [ ] Both work with D/A buttons
- [ ] All keyboard shortcuts non-conflicting:
  - Ctrl+D: Double-size ✅
  - Ctrl+A: Always on top ✅
  - Ctrl+T: Time display toggle ✅ NEW
  - Ctrl+I: Track info ✅ NEW
  - R: Repeat ✅
  - S: Shuffle ✅
- [ ] State persists across app restarts:
  - Time display mode
  - (Dialog state is transient, doesn't persist)
- [ ] Works in double-size mode
- [ ] All 5 clutter buttons aligned correctly
- [ ] Sprite rendering correct for all skins

---

## 📁 Files Modified/Created

### Files to Modify (3 files)

1. **MacAmpApp/Models/AppSettings.swift** (+60 lines)
   - Add TimeDisplayMode enum
   - Add timeDisplayMode property with didSet
   - Add showTrackInfoDialog property (transient, no didSet)
   - Add toggleTimeDisplayMode() method

2. **MacAmpApp/Views/WinampMainWindow.swift** (+120 lines, -2 lines)
   - Add showOptionsMenu(from:) method
   - Add @objc action methods (4 total)
   - Update O button (remove disabled, add action, use SimpleSpriteImage)
   - Update I button (remove disabled, add action, use SimpleSpriteImage)
   - Add .sheet() modifier for track info dialog
   - **MIGRATION:** Remove @State private var showRemainingTime
   - **MIGRATION:** Update onTapGesture to use settings.timeDisplayMode

3. **MacAmpApp/AppCommands.swift** (+14 lines)
   - Add Ctrl+T command for time toggle
   - Add Ctrl+I command for track info

### Files to Create (1 file)

4. **MacAmpApp/Views/Components/TrackInfoView.swift** (NEW, ~100 lines)
   - TrackInfoView main component
   - Uses AudioPlayer (not PlaybackCoordinator)
   - Track model: url, title, artist, duration (no album/fileFormat/metadata)
   - Metadata from AudioPlayer properties: bitrate, sampleRate, channelCount
   - InfoRow helper component
   - Duration formatting helper
   - Preview provider

### Files Unchanged (Reference Only)

- MacAmpApp/Models/SkinSprites.swift ✅ (sprites already defined)
- MacAmpApp/Utilities/SpriteResolver.swift ✅ (no changes needed)
- MacAmpApp/Views/Components/SimpleSpriteImage.swift ✅ (no changes needed)

**Total Code Changes:** ~294 lines added, 2 lines removed (disabled/hidden flags)

---

## 🎯 Acceptance Criteria

### O Button (Options Menu)

**Must Pass:**
- [x] Menu appears on click
- [x] Menu positioned below button
- [x] Time toggle works (elapsed ⇄ remaining)
- [x] Double-size toggle shows in menu
- [x] Repeat toggle shows in menu
- [x] Shuffle toggle shows in menu
- [x] Checkmarks reflect current state
- [x] Ctrl+T keyboard shortcut works
- [x] Menu hotkeys work (Ctrl+D, R, S)
- [x] State persists across restarts

**Should Pass:**
- [x] Menu dismisses after selection
- [x] Click outside to dismiss
- [x] O button visual feedback (selected sprite)

---

### I Button (Track Info Dialog)

**Must Pass:**
- [x] Dialog opens on click
- [x] Shows current track metadata
- [x] Displays: title, artist, album, duration, format
- [x] Shows technical details (bitrate, sample rate, channels)
- [x] "No track" message when nothing playing
- [x] Close button works
- [x] Esc key dismisses dialog
- [x] Ctrl+I keyboard shortcut works
- [x] I button visual feedback (selected sprite while open)

**Should Pass:**
- [x] Click outside dialog to dismiss
- [x] Dialog doesn't pause playback
- [x] Works in double-size mode

---

### Integration

**Must Pass:**
- [x] O and I buttons independent
- [x] No keyboard shortcut conflicts
- [x] Works with D/A buttons
- [x] All 5 clutter buttons aligned
- [x] Sprite rendering in all skins
- [x] State persistence correct

---

## ⚠️ Known Limitations & Deferred Features

### Deferred to Future (P3)

1. **Skins Submenu (O Button)**
   - Shows available skins
   - Switch skin from menu
   - Reason: Skin switching architecture not ready

2. **EQ Preset Menu (O Button)**
   - Show EQ presets
   - Switch preset from menu
   - Reason: EQ presets not implemented yet

3. **ID3 Tag Editing (I Button)**
   - Edit title, artist, album
   - Save changes to file
   - Reason: Write access + validation complex

4. **Album Artwork (I Button)**
   - Show album cover thumbnail
   - Reason: Image extraction + display complex

5. **Lyrics Display (I Button)**
   - Show synced lyrics if available
   - Reason: Lyrics parsing not implemented

6. **Next/Previous in Dialog (I Button)**
   - Navigate tracks without closing dialog
   - Reason: Adds complexity, low value

---

## 🚧 Potential Issues & Mitigations

### Issue 1: Time Display Not Visible

**Problem:** We're adding time toggle but main window might not show time

**Investigation Needed:**
- Find where time is displayed in WinampMainWindow
- Verify elapsed/remaining logic exists
- May need to implement time display first

**Mitigation:**
- Phase 1 starts with investigation
- If time display missing, defer time toggle
- Focus on I button (independent feature)

---

### Issue 2: Menu Positioning

**Problem:** NSMenu.popUp() might not position correctly

**Investigation Needed:**
- Test menu positioning with different window sizes
- Verify menu appears below button (not above/beside)

**Mitigation:**
- Use sourceView.frame for positioning
- Adjust menuOrigin calculation if needed
- Fallback: Use SwiftUI Menu (native positioning)

---

### Issue 3: Metadata Access

**Problem:** PlaybackCoordinator.currentTrack might not expose all metadata

**Investigation Needed:**
- Verify AudioTrack struct has all fields
- Check if AudioMetadata is populated
- Confirm bitrate/sample rate available

**Mitigation:**
- Display only available fields
- Gracefully handle missing data
- Show "N/A" for unavailable metadata

---

### Issue 4: Dialog Presentation Layer

**Problem:** Sheet might not present from UnifiedDockView correctly

**Investigation Needed:**
- Test sheet presentation in unified window
- Verify dismiss gesture works
- Check double-size mode interaction

**Mitigation:**
- Use .sheet() modifier (simplest approach)
- If sheet fails, try .popover()
- If both fail, use custom overlay

---

## 📊 Time Tracking

| Phase | Description | Estimated | Actual | Notes |
|-------|-------------|-----------|--------|-------|
| 1 | O Button Foundation | 30 min | | State management |
| 2 | O Button Menu | 60 min | | NSMenu implementation |
| 3 | O Button Shortcut | 15 min | | Ctrl+T command |
| 4 | O Button Testing | 15 min | | Manual verification |
| 5 | I Button Foundation | 30 min | | State + view scaffold |
| 6 | I Button Integration | 45 min | | Dialog presentation |
| 7 | I Button Shortcut | 15 min | | Ctrl+I command |
| 8 | I Button Testing | 30 min | | Manual verification |
| 9 | Time Display Migration | 60 min | | showRemainingTime → timeDisplayMode |
| 10 | Integration Testing | 30 min | | Combined testing |
| **TOTAL** | | **5.5 hours** | | |
| **+20% Contingency** | | **6.6 hours** | | |
| **Rounded** | | **7 hours** | | |

---

## 🎓 Success Patterns from D/A Buttons

### Pattern 1: didSet Persistence ✅

**Proven:**
```swift
var someState: Bool = false {
    didSet {
        UserDefaults.standard.set(someState, forKey: "someState")
    }
}
```

**Why:** @AppStorage breaks @Observable reactivity

---

### Pattern 2: Sprite Selection ✅

**Proven:**
```swift
spriteImage(
    isActive: settings.someState,
    normal: .normalSprite,
    selected: .selectedSprite
)
```

**Why:** Normal and selected coordinates must differ

---

### Pattern 3: Button Scaffolding ✅

**Proven:**
```swift
Button {
    settings.someState.toggle()
} label: {
    spriteImage(...)
}
.buttonStyle(PlainButtonStyle())
.accessibilityLabel("Description")
```

**Why:** Removes system button chrome, works with skin sprites

---

### Pattern 4: Keyboard Shortcuts ✅

**Proven:**
```swift
// AppCommands.swift
Button("Action") {
    settings.someState.toggle()
}
.keyboardShortcut("x", modifiers: [.command])
```

**Why:** Centralized shortcut management, works globally

---

## 📋 Pre-Implementation Checklist

### Before Starting

- [ ] Read this plan completely
- [ ] Review research.md for context
- [ ] Study double-size-button implementation
- [ ] Verify Xcode project builds
- [ ] Create feature branch: `feature/clutter-bar-oi-buttons`
- [ ] Backup current WinampMainWindow.swift

### Phase Prerequisites

**Phase 1 (O Button Foundation):**
- [ ] Locate time display in WinampMainWindow
- [ ] Verify time elapsed/remaining logic exists
- [ ] Confirm AppSettings extension point

**Phase 5 (I Button Foundation):**
- [ ] Verify PlaybackCoordinator.currentTrack structure
- [ ] Check AudioMetadata fields available
- [ ] Test metadata with sample tracks

---

## 🎯 Post-Implementation

### After Completion

1. **Testing**
   - Run full test suite
   - Manual test all acceptance criteria
   - Test with 3+ different skins
   - Test in double-size mode

2. **Documentation**
   - Update COMPLETION_SUMMARY.md
   - Create FEATURE_DOCUMENTATION.md
   - Update README.md with new features
   - Document keyboard shortcuts

3. **Code Review**
   - Self-review against patterns
   - Check for dead code
   - Remove debug prints
   - Verify Swift 6 concurrency compliance

4. **Merge**
   - Squash commits if needed
   - Write detailed commit message
   - Create PR with screenshots
   - Tag as P2 quick win

---

## 🚀 Future Enhancements (Out of Scope)

### P3 Priority (Post-1.0)

1. **Skins Menu** (O Button)
   - Scan skins directory
   - Preview thumbnails
   - Switch skin from menu

2. **EQ Presets Menu** (O Button)
   - Load preset from menu
   - Save current as preset
   - Import/export presets

3. **Preferences Dialog** (O Button)
   - Full settings UI
   - Advanced options
   - Plugin management

4. **Editable Track Info** (I Button)
   - Edit ID3 tags
   - Write changes to file
   - Batch edit multiple tracks

5. **Extended Metadata** (I Button)
   - Album artwork
   - Lyrics display
   - ReplayGain values
   - File path/size

---

**Plan Status:** ✅ COMPLETE
**Ready for Implementation:** ✅ YES
**Next Step:** Create state.md and todo.md
**Estimated Total Time:** 6 hours
