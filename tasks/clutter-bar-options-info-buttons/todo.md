# Clutter Bar O and I Buttons - Implementation Checklist

**Date:** 2025-11-02
**Estimated Time:** 6 hours
**Pattern:** tasks/done/double-size-button/
**Status:** Ready to implement

---

## 📋 Pre-Implementation Setup

### Prerequisites

- [ ] Read all task documentation completely
  - [ ] research.md (comprehensive analysis)
  - [ ] plan.md (9-phase implementation)
  - [ ] state.md (current status)
  - [ ] todo.md (this file)

- [ ] Study reference implementation
  - [ ] tasks/done/double-size-button/COMPLETION_SUMMARY.md
  - [ ] tasks/done/double-size-button/FEATURE_DOCUMENTATION.md
  - [ ] tasks/done/double-size-button/plan.md

- [ ] Verify development environment
  - [ ] Xcode project builds successfully
  - [ ] No existing build errors
  - [ ] Thread Sanitizer clean

- [ ] Create feature branch
  - [ ] `git checkout main`
  - [ ] `git pull origin main`
  - [ ] `git checkout -b feature/clutter-bar-oi-buttons`

- [ ] Backup critical files
  - [ ] `MacAmpApp/Views/WinampMainWindow.swift`
  - [ ] `MacAmpApp/Models/AppSettings.swift`

---

## 🎯 PHASE 1: O Button Foundation (30 minutes)

### 1.1 Define TimeDisplayMode Enum

**File:** `MacAmpApp/Models/AppSettings.swift`

- [ ] Open AppSettings.swift
- [ ] Locate `isDoubleSizeMode` property (around line 21)
- [ ] Add TimeDisplayMode enum BEFORE AppSettings class:

```swift
enum TimeDisplayMode: String, Codable {
    case elapsed = "elapsed"
    case remaining = "remaining"
}
```

- [ ] Save file
- [ ] Build project → verify no errors

---

### 1.2 Add State Property

**File:** `MacAmpApp/Models/AppSettings.swift`

- [ ] Locate `isAlwaysOnTop` property
- [ ] Add after isAlwaysOnTop:

```swift
var timeDisplayMode: TimeDisplayMode = .elapsed {
    didSet {
        UserDefaults.standard.set(timeDisplayMode.rawValue, forKey: "timeDisplayMode")
    }
}
```

- [ ] Locate `init()` method
- [ ] Add to init() after loading other UserDefaults:

```swift
// Load time display mode
if let saved = UserDefaults.standard.string(forKey: "timeDisplayMode"),
   let mode = TimeDisplayMode(rawValue: saved) {
    self.timeDisplayMode = mode
}
```

- [ ] Save file
- [ ] Build project → verify no errors

---

### 1.3 Add Toggle Method

**File:** `MacAmpApp/Models/AppSettings.swift`

- [ ] Add method after property declarations:

```swift
func toggleTimeDisplayMode() {
    timeDisplayMode = (timeDisplayMode == .elapsed) ? .remaining : .elapsed
}
```

- [ ] Save file
- [ ] Build project → verify no errors

---

### 1.4 Verify Time Display Location (Investigation)

- [ ] Open `MacAmpApp/Views/WinampMainWindow.swift`
- [ ] Search for "time" or "duration" display
- [ ] Locate where elapsed/remaining time is shown
- [ ] Document location for later integration
- [ ] If time display missing, note for future implementation

**Phase 1 Milestone:** ✅ State management ready

---

## 🎯 PHASE 2: O Button Menu Implementation (60 minutes)

### 2.1 Add Menu Helper Method

**File:** `MacAmpApp/Views/WinampMainWindow.swift`

- [ ] Locate `buildClutterBarButtons()` method (around line 520)
- [ ] Add new method AFTER buildClutterBarButtons():

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
    repeatItem.state = playback.repeatMode != .off ? .on : .off
    repeatItem.target = self
    menu.addItem(repeatItem)

    // Shuffle
    let shuffleItem = NSMenuItem(
        title: "Shuffle",
        action: #selector(toggleShuffle),
        keyEquivalent: "s"
    )
    shuffleItem.state = playback.shuffleEnabled ? .on : .off
    shuffleItem.target = self
    menu.addItem(shuffleItem)

    // Show menu below button
    let menuOrigin = NSPoint(x: sourceView.frame.minX, y: sourceView.frame.minY)
    menu.popUp(positioning: nil, at: menuOrigin, in: sourceView.superview)
}
```

- [ ] Save file
- [ ] Build project → verify no errors

---

### 2.2 Add @objc Action Methods

**File:** `MacAmpApp/Views/WinampMainWindow.swift`

- [ ] Add after showOptionsMenu() method:

```swift
@objc private func toggleTimeDisplay() {
    settings.toggleTimeDisplayMode()
}

@objc private func toggleDoubleSize() {
    settings.isDoubleSizeMode.toggle()
}

@objc private func toggleRepeat() {
    playback.cycleRepeatMode()
}

@objc private func toggleShuffle() {
    playback.shuffleEnabled.toggle()
}
```

- [ ] Save file
- [ ] Build project → verify no errors

---

### 2.3 Update O Button

**File:** `MacAmpApp/Views/WinampMainWindow.swift`

- [ ] Locate O button scaffolding (around line 530)
- [ ] Find this code:

```swift
// O button (Options) - Placeholder
Button {} label: {
    spriteImage(
        isActive: false,
        normal: .optionsOff,
        selected: .optionsOn
    )
}
.disabled(true)
.accessibilityHidden(true)
```

- [ ] Replace with:

```swift
// O button (Options) - NOW FUNCTIONAL ✅
Button {
    // Capture button view for menu positioning
    if let window = NSApp.keyWindow,
       let contentView = window.contentView {
        showOptionsMenu(from: contentView)
    }
} label: {
    spriteImage(
        isActive: false, // Menu doesn't have persistent state
        normal: .MAIN_CLUTTER_BAR_BUTTON_O,
        selected: .MAIN_CLUTTER_BAR_BUTTON_O_SELECTED
    )
}
.buttonStyle(PlainButtonStyle())
.accessibilityLabel("Options menu")
```

- [ ] Save file
- [ ] Build project → verify no errors

**Phase 2 Milestone:** ✅ O button menu implemented

---

## 🎯 PHASE 3: O Button Keyboard Shortcut (15 minutes)

### 3.1 Add Ctrl+T Command

**File:** `MacAmpApp/AppCommands.swift`

- [ ] Open AppCommands.swift
- [ ] Locate Ctrl+D (Double Size) command
- [ ] Add AFTER Ctrl+D command:

```swift
Button("Time: \(settings.timeDisplayMode == .elapsed ? "Elapsed" : "Remaining")") {
    settings.toggleTimeDisplayMode()
}
.keyboardShortcut("t", modifiers: [.command])
```

- [ ] Save file
- [ ] Build project → verify no errors
- [ ] Run app
- [ ] Test Ctrl+T → should toggle time display mode
- [ ] Verify menu item checkmark updates

**Phase 3 Milestone:** ✅ Keyboard shortcut working

---

## 🎯 PHASE 4: O Button Testing (15 minutes)

### 4.1 Manual Testing Checklist

- [ ] **Basic Functionality**
  - [ ] Click O button → menu appears
  - [ ] Menu positioned below button
  - [ ] Menu contains all expected items:
    - [ ] Time elapsed (with checkmark if selected)
    - [ ] Time remaining (with checkmark if selected)
    - [ ] Separator
    - [ ] Double Size (with checkmark if active)
    - [ ] Separator
    - [ ] Repeat (with checkmark if active)
    - [ ] Shuffle (with checkmark if active)

- [ ] **Time Display Toggle**
  - [ ] Click "Time elapsed" → checkmark appears
  - [ ] Click "Time remaining" → checkmark moves
  - [ ] State persists when reopening menu
  - [ ] Ctrl+T toggles mode
  - [ ] Menu label updates after toggle

- [ ] **Existing Features Integration**
  - [ ] Double Size menu item works (toggles mode)
  - [ ] Ctrl+D still works
  - [ ] Repeat menu item works
  - [ ] R key still works
  - [ ] Shuffle menu item works
  - [ ] S key still works

- [ ] **Menu Behavior**
  - [ ] Menu dismisses after selecting item
  - [ ] Click outside menu → menu closes
  - [ ] Press Esc → menu closes
  - [ ] Menu doesn't break double-size mode

- [ ] **Visual Feedback**
  - [ ] O button shows selected sprite while menu open (if possible)
  - [ ] Menu items show correct checkmarks
  - [ ] Menu fonts/spacing look correct

- [ ] **State Persistence**
  - [ ] Select "Time remaining"
  - [ ] Quit app
  - [ ] Relaunch app
  - [ ] Open options menu
  - [ ] Verify "Time remaining" still checked

**Phase 4 Milestone:** ✅ O button fully functional and tested

---

## 🎯 PHASE 5: I Button Foundation (30 minutes)

### 5.1 Add Dialog State

**File:** `MacAmpApp/Models/AppSettings.swift`

- [ ] Open AppSettings.swift
- [ ] Locate timeDisplayMode property
- [ ] Add AFTER timeDisplayMode:

```swift
var showTrackInfoDialog: Bool = false {
    didSet {
        UserDefaults.standard.set(showTrackInfoDialog, forKey: "showTrackInfoDialog")
    }
}
```

- [ ] Save file
- [ ] Build project → verify no errors

---

### 5.2 Create TrackInfoView File

**File:** `MacAmpApp/Views/Components/TrackInfoView.swift` (NEW)

- [ ] Right-click on `MacAmpApp/Views/Components/` folder
- [ ] Select "New File..."
- [ ] Choose "SwiftUI View"
- [ ] Name: `TrackInfoView.swift`
- [ ] Replace entire file contents with:

```swift
import SwiftUI

@MainActor
struct TrackInfoView: View {
    @EnvironmentObject var playback: PlaybackCoordinator
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 20) {
            // Header
            Text("Track Information")
                .font(.headline)
                .padding(.top)

            if let track = playback.currentTrack {
                // Track Details
                VStack(alignment: .leading, spacing: 12) {
                    InfoRow(label: "Title", value: track.title)

                    if let artist = track.artist {
                        InfoRow(label: "Artist", value: artist)
                    }

                    if let album = track.album {
                        InfoRow(label: "Album", value: album)
                    }

                    InfoRow(label: "Duration", value: formatDuration(track.duration))

                    if let format = track.fileFormat {
                        InfoRow(label: "Format", value: format.uppercased())
                    }

                    // Technical Details (if available)
                    if let metadata = track.metadata {
                        Divider()

                        if let bitrate = metadata.bitrate {
                            InfoRow(label: "Bitrate", value: "\(bitrate) kbps")
                        }

                        if let sampleRate = metadata.sampleRate {
                            InfoRow(label: "Sample Rate", value: "\(sampleRate) Hz")
                        }

                        if let channels = metadata.channels {
                            InfoRow(label: "Channels", value: channels == 2 ? "Stereo" : "Mono")
                        }
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
        .environmentObject(PlaybackCoordinator())
}
```

- [ ] Save file
- [ ] Build project → verify no errors
- [ ] Fix any compilation errors (adjust property names if needed)

**Phase 5 Milestone:** ✅ I button foundation ready

---

## 🎯 PHASE 6: I Button Integration (45 minutes)

### 6.1 Update I Button

**File:** `MacAmpApp/Views/WinampMainWindow.swift`

- [ ] Locate I button scaffolding (around line 545)
- [ ] Find this code:

```swift
// I button (Info) - Placeholder
Button {} label: {
    spriteImage(
        isActive: false,
        normal: .infoOff,
        selected: .infoOn
    )
}
.disabled(true)
.accessibilityHidden(true)
```

- [ ] Replace with:

```swift
// I button (Info) - NOW FUNCTIONAL ✅
Button {
    settings.showTrackInfoDialog = true
} label: {
    spriteImage(
        isActive: settings.showTrackInfoDialog,
        normal: .MAIN_CLUTTER_BAR_BUTTON_I,
        selected: .MAIN_CLUTTER_BAR_BUTTON_I_SELECTED
    )
}
.buttonStyle(PlainButtonStyle())
.accessibilityLabel("Track information")
```

- [ ] Save file
- [ ] Build project → verify no errors

---

### 6.2 Add Sheet Presentation

**File:** `MacAmpApp/Views/WinampMainWindow.swift`

- [ ] Locate the main VStack or ZStack in body (around line 170)
- [ ] Find the last modifier on the main container
- [ ] Add sheet modifier AFTER existing modifiers:

```swift
.sheet(isPresented: $settings.showTrackInfoDialog) {
    TrackInfoView()
        .environmentObject(playback)
}
```

- [ ] Save file
- [ ] Build project → verify no errors

---

### 6.3 Test Dialog Presentation

- [ ] Run app
- [ ] Play a track
- [ ] Click I button
- [ ] Verify dialog appears
- [ ] Verify track info displays correctly
- [ ] Click "Close" → dialog dismisses
- [ ] Fix any issues before proceeding

**Phase 6 Milestone:** ✅ I button dialog working

---

## 🎯 PHASE 7: I Button Keyboard Shortcut (15 minutes)

### 7.1 Add Ctrl+I Command

**File:** `MacAmpApp/AppCommands.swift`

- [ ] Open AppCommands.swift
- [ ] Locate Ctrl+T (Time Display) command
- [ ] Add AFTER Ctrl+T command:

```swift
Button("Track Information") {
    settings.showTrackInfoDialog = true
}
.keyboardShortcut("i", modifiers: [.command])
```

- [ ] Save file
- [ ] Build project → verify no errors
- [ ] Run app
- [ ] Test Ctrl+I → should open track info dialog
- [ ] Verify Esc key closes dialog

**Phase 7 Milestone:** ✅ Keyboard shortcut working

---

## 🎯 PHASE 8: I Button Testing (30 minutes)

### 8.1 Manual Testing Checklist

- [ ] **Basic Functionality**
  - [ ] Click I button → dialog appears
  - [ ] Dialog centered on screen
  - [ ] Dialog title "Track Information" visible

- [ ] **Track Info Display (With Track Playing)**
  - [ ] Play an MP3 track
  - [ ] Open dialog
  - [ ] Verify displays:
    - [ ] Title (correct)
    - [ ] Artist (if available)
    - [ ] Album (if available)
    - [ ] Duration (MM:SS format)
    - [ ] Format (e.g., "MP3")
  - [ ] Verify technical details (if available):
    - [ ] Bitrate (e.g., "320 kbps")
    - [ ] Sample Rate (e.g., "44100 Hz")
    - [ ] Channels ("Stereo" or "Mono")

- [ ] **Track Info Display (No Track Playing)**
  - [ ] Stop playback
  - [ ] Click I button
  - [ ] Verify shows: "No track currently playing"

- [ ] **Dialog Interaction**
  - [ ] Click "Close" button → dialog dismisses
  - [ ] Press Esc key → dialog dismisses
  - [ ] Click outside dialog (if macOS allows) → dialog dismisses
  - [ ] Ctrl+I opens dialog
  - [ ] Dialog doesn't pause playback

- [ ] **Visual Feedback**
  - [ ] I button shows selected sprite while dialog open
  - [ ] Button returns to normal sprite when dialog closes

- [ ] **Different File Formats**
  - [ ] Test with MP3 file
  - [ ] Test with FLAC file (if available)
  - [ ] Test with WAV file (if available)
  - [ ] Verify format detection correct

- [ ] **Edge Cases**
  - [ ] Dialog with very long title (truncates properly)
  - [ ] Dialog with missing artist/album (fields omitted)
  - [ ] Dialog with no metadata (basic info only)

- [ ] **Integration with Other Features**
  - [ ] Open dialog in double-size mode → works
  - [ ] Open dialog while options menu open → both work
  - [ ] Switch tracks while dialog open → info updates
  - [ ] Playback controls work while dialog open

**Phase 8 Milestone:** ✅ I button fully functional and tested

---

## 🎯 PHASE 9: Integration Testing (30 minutes)

### 9.1 Combined Functionality Testing

- [ ] **O and I Button Independence**
  - [ ] Click O button → menu appears
  - [ ] Click I button while menu open → dialog appears
  - [ ] Both work simultaneously
  - [ ] Menu and dialog don't interfere

- [ ] **Keyboard Shortcut Conflicts**
  - [ ] Verify all shortcuts work:
    - [ ] Ctrl+D: Double-size mode (existing)
    - [ ] Ctrl+A: Always on top (existing)
    - [ ] Ctrl+T: Time display toggle (new)
    - [ ] Ctrl+I: Track information (new)
    - [ ] R: Repeat (existing)
    - [ ] S: Shuffle (existing)
  - [ ] No conflicts detected
  - [ ] All work from any window state

- [ ] **State Persistence**
  - [ ] Set time display to "Remaining"
  - [ ] Enable double-size mode
  - [ ] Enable repeat
  - [ ] Quit app
  - [ ] Relaunch app
  - [ ] Verify all states restored:
    - [ ] Time display: Remaining
    - [ ] Double-size: On
    - [ ] Repeat: On

- [ ] **D/A Button Compatibility**
  - [ ] D button (double-size) still works
  - [ ] A button (always on top) still works
  - [ ] Visual feedback correct for all buttons
  - [ ] No regressions

---

### 9.2 Visual/Layout Testing

- [ ] **Clutter Bar Alignment**
  - [ ] All 5 buttons (O, A, I, D, V) aligned horizontally
  - [ ] Spacing between buttons correct
  - [ ] Buttons don't overlap
  - [ ] Clutter bar centered in titlebar

- [ ] **Double-Size Mode**
  - [ ] Enable double-size
  - [ ] All 5 buttons scale correctly
  - [ ] Spacing maintains proportion
  - [ ] Clickable areas correct
  - [ ] Visual feedback works at 2x

---

### 9.3 Sprite Rendering (Multiple Skins)

- [ ] **Base Skin (Default)**
  - [ ] O button normal sprite renders
  - [ ] O button selected sprite renders (if applicable)
  - [ ] I button normal sprite renders
  - [ ] I button selected sprite renders (when dialog open)
  - [ ] All sprites crisp and clear

- [ ] **Plastic Skin (If Available)**
  - [ ] Switch to Plastic skin
  - [ ] O button sprites render correctly
  - [ ] I button sprites render correctly
  - [ ] No missing sprites

- [ ] **Green Dimension Skin (If Available)**
  - [ ] Switch to Green Dimension skin
  - [ ] O button sprites render correctly
  - [ ] I button sprites render correctly
  - [ ] No missing sprites

---

### 9.4 Accessibility Testing

- [ ] **Keyboard Navigation**
  - [ ] Tab through UI → reaches clutter bar
  - [ ] Tab to O button → Enter opens menu
  - [ ] Tab to I button → Enter opens dialog
  - [ ] All keyboard shortcuts work without mouse

- [ ] **VoiceOver (Optional)**
  - [ ] Enable VoiceOver
  - [ ] Navigate to O button
  - [ ] Verify label: "Options menu"
  - [ ] Navigate to I button
  - [ ] Verify label: "Track information"

---

### 9.5 Performance Testing

- [ ] **Menu Performance**
  - [ ] Open/close menu 10 times rapidly
  - [ ] No lag or stutter
  - [ ] Memory usage stable

- [ ] **Dialog Performance**
  - [ ] Open/close dialog 10 times rapidly
  - [ ] No lag or stutter
  - [ ] Memory usage stable
  - [ ] Metadata loads instantly

- [ ] **Thread Sanitizer**
  - [ ] Build with Thread Sanitizer enabled
  - [ ] Test all O/I button functionality
  - [ ] No warnings reported
  - [ ] No data races detected

**Phase 9 Milestone:** ✅ All integration tests passing

---

## ✅ Post-Implementation Tasks

### Code Cleanup

- [ ] Remove any debug print statements
- [ ] Remove commented-out code
- [ ] Verify no `TODO` or `FIXME` comments left
- [ ] Check for unused imports
- [ ] Verify all files saved

### Code Review

- [ ] Review AppSettings.swift changes
  - [ ] didSet pattern correct
  - [ ] UserDefaults keys consistent
  - [ ] No @AppStorage used
- [ ] Review WinampMainWindow.swift changes
  - [ ] No `.disabled(true)` flags remain
  - [ ] Accessibility labels added
  - [ ] Proper @objc for action methods
- [ ] Review TrackInfoView.swift
  - [ ] Clean SwiftUI code
  - [ ] Proper error handling
  - [ ] Preview works
- [ ] Review AppCommands.swift
  - [ ] Keyboard shortcuts non-conflicting
  - [ ] Menu labels descriptive

### Build Verification

- [ ] Clean build folder (Cmd+Shift+K)
- [ ] Build project (Cmd+B)
- [ ] No warnings
- [ ] No errors
- [ ] Thread Sanitizer clean

---

### Documentation

- [ ] Update COMPLETION_SUMMARY.md (create if needed)
  - [ ] Actual time taken per phase
  - [ ] Challenges encountered
  - [ ] Solutions applied

- [ ] Update FEATURE_DOCUMENTATION.md (create if needed)
  - [ ] O button usage guide
  - [ ] I button usage guide
  - [ ] Keyboard shortcuts list
  - [ ] Screenshots (optional)

- [ ] Update README.md
  - [ ] Add O button to features list
  - [ ] Add I button to features list
  - [ ] Add Ctrl+T and Ctrl+I to keyboard shortcuts

---

### Git Workflow

- [ ] Stage changes
  - [ ] `git add MacAmpApp/Models/AppSettings.swift`
  - [ ] `git add MacAmpApp/Views/WinampMainWindow.swift`
  - [ ] `git add MacAmpApp/Views/Components/TrackInfoView.swift`
  - [ ] `git add MacAmpApp/AppCommands.swift`
  - [ ] `git add README.md` (if updated)

- [ ] Create commit
  ```bash
  git commit -m "feat(clutter-bar): implement O (Options) and I (Track Info) buttons

  O Button (Options Menu):
  - Opens context menu with player options
  - Time display toggle (elapsed/remaining)
  - Links to existing toggles (double-size, repeat, shuffle)
  - Keyboard shortcut: Ctrl+T

  I Button (Track Information):
  - Shows current track metadata in modal dialog
  - Displays title, artist, album, duration, format
  - Shows technical details (bitrate, sample rate, channels)
  - Keyboard shortcut: Ctrl+I

  Pattern: Follows double-size-button implementation
  Time: 6 hours (actual: TBD)
  Complexity: Low (3/10)
  Risk: Very Low (2/10)

  Files modified:
  - AppSettings.swift (+60 lines): State management
  - WinampMainWindow.swift (+120 lines): Button implementation
  - AppCommands.swift (+14 lines): Keyboard shortcuts
  - TrackInfoView.swift (NEW, +100 lines): Track info UI

  🤖 Generated with [Claude Code](https://claude.com/claude-code)

  Co-Authored-By: Claude <noreply@anthropic.com>"
  ```

- [ ] Push to remote
  ```bash
  git push origin feature/clutter-bar-oi-buttons
  ```

---

### Pull Request

- [ ] Create PR on GitHub
  - [ ] Title: "feat(clutter-bar): implement O (Options) and I (Track Info) buttons"
  - [ ] Description: Link to task folder, summarize changes
  - [ ] Add screenshots of menu and dialog
  - [ ] Tag as "enhancement" and "P2"

- [ ] Request review (if applicable)

- [ ] Address review feedback

- [ ] Merge to main when approved

---

## 📊 Time Tracking

| Phase | Estimated | Actual | Notes |
|-------|-----------|--------|-------|
| Phase 1 | 30 min | | O Button Foundation |
| Phase 2 | 60 min | | O Button Menu |
| Phase 3 | 15 min | | O Button Shortcut |
| Phase 4 | 15 min | | O Button Testing |
| Phase 5 | 30 min | | I Button Foundation |
| Phase 6 | 45 min | | I Button Integration |
| Phase 7 | 15 min | | I Button Shortcut |
| Phase 8 | 30 min | | I Button Testing |
| Phase 9 | 30 min | | Integration Testing |
| **Total** | **5 hours** | | |
| **+20%** | **6 hours** | | |

**Actual Total:** _________ hours

---

## 🎯 Success Metrics

### Must Pass (Blocking)

- [ ] All 30+ test cases passing
- [ ] No build errors or warnings
- [ ] Thread Sanitizer clean
- [ ] State persistence working
- [ ] Keyboard shortcuts non-conflicting

### Should Pass (Important)

- [ ] Works with 3+ skins
- [ ] Performance acceptable (no lag)
- [ ] Accessibility labels correct
- [ ] Documentation complete

### Nice to Have (Optional)

- [ ] VoiceOver tested
- [ ] Screenshots captured
- [ ] Feature video recorded

---

## 🚦 Definition of Done

Task is complete when:

1. ✅ All 9 phases implemented
2. ✅ All test cases passing
3. ✅ Code review complete
4. ✅ Documentation updated
5. ✅ PR merged to main
6. ✅ No regressions in existing features
7. ✅ Team approved

---

**Checklist Status:** 📋 READY
**Implementation Status:** ⏳ PENDING
**Next Action:** Begin Phase 1 - O Button Foundation
**Estimated Completion:** 6 hours from start
