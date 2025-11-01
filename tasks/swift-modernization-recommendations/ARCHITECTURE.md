# MacAmp Modern Swift Architecture

**Date:** 2025-10-28
**Purpose:** Reference architecture for modern Swift patterns in MacAmp
**Target:** macOS 15+ (Sequoia) and macOS 26+ (Tahoe)

---

## Overview

This document defines the modern Swift architecture patterns used in MacAmp after the Swift Modernization effort. All future code should adhere to these patterns.

---

## 1. Sprite Rendering - Pixel-Perfect Pattern

### **Requirement: ALL Sprites MUST Use Pixel-Perfect Rendering**

**Pattern:**
```swift
Image(nsImage: spriteImage)
    .interpolation(.none)    // REQUIRED: Disables GPU pixel blending
    .antialiased(false)      // REQUIRED: Keeps sharp pixel edges
    .resizable()
    .frame(width: w, height: h)
```

**Why:**
- MacAmp is a retro interface from 1997
- The aesthetic DEPENDS on visible pixel blocks
- GPU interpolation creates smooth gradients (ruins retro look)
- `.interpolation(.none)` maintains authentic pixelated appearance

**Components:**
- ✅ SimpleSpriteImage.swift - Core component (CORRECT)
- ✅ All Image(nsImage:) calls - Now have proper interpolation (Phase 1)

**Rule:** Any new sprite rendering MUST include `.interpolation(.none) + .antialiased(false)`

---

## 2. State Management - @Observable Framework

### **Target: Migrate to @Observable (macOS 14+)**

**Current (Legacy):**
```swift
class SkinManager: ObservableObject {
    @Published var currentSkin: Skin?
}

// In views
@EnvironmentObject var skinManager: SkinManager
```

**Modern (Target):**
```swift
@Observable class SkinManager {
    var currentSkin: Skin?  // Auto-observed
}

// In views
@Environment(SkinManager.self) private var skinManager
```

**Benefits:**
- 10-20% better performance (fine-grained updates)
- No manual `objectWillChange`
- Modern Swift pattern
- Automatic observation

**Classes to Migrate:**
1. AppSettings (2 properties)
2. DockingController (1 property)
3. SkinManager (4 properties)
4. AudioPlayer (28 properties)

---

## 3. View Injection Patterns

### **Without Bindings (Read-Only)**

```swift
struct MyView: View {
    @Environment(SkinManager.self) private var skinManager

    var body: some View {
        Text(skinManager.currentSkin?.name ?? "None")
    }
}
```

### **With Bindings (Two-Way)**

**CRITICAL:** Use @Bindable for Toggle, Picker, TextField, etc.

```swift
struct PreferencesView: View {
    @Environment(AppSettings.self) private var appSettings
    @Bindable private var settings = appSettings

    var body: some View {
        Toggle("Enable", isOn: $settings.enableLiquidGlass)  // ✅ Binding works
        Picker("Mode", selection: $settings.materialIntegration) { ... }
    }
}
```

**Rule:** If view needs `$property` bindings → use @Bindable

---

## 4. SwiftUI Gesture Ordering

### **Rule: Declare Gestures in Reverse Priority**

**WRONG:**
```swift
.onTapGesture { }           // Single-click
.onTapGesture(count: 2) { } // Double-click NEVER FIRES
```

**CORRECT:**
```swift
.onTapGesture(count: 2) { } // Double-click FIRST
.onTapGesture { }           // Single-click SECOND
```

**Why:** SwiftUI processes gestures in declaration order. Single-click consumes the first click of a double-click if declared first.

**Application:**
- Playlist track rows (double-click plays, single-click selects)
- Any view with multiple tap gestures

---

## 5. Multi-Selection Pattern

### **Use Set<Int> for Multi-Selection**

```swift
@State private var selectedIndices: Set<Int> = []

// Single-click: Clear and select
selectedIndices = [index]

// Shift+Click: Toggle selection
if modifiers.contains(.shift) {
    if selectedIndices.contains(index) {
        selectedIndices.remove(index)
    } else {
        selectedIndices.insert(index)
    }
}

// Command+A: Select all
selectedIndices = Set(0..<audioPlayer.playlist.count)

// Escape/Cmd+D: Deselect all
selectedIndices = []
```

**Removal Pattern (CRITICAL):**
```swift
// ✅ CORRECT: Reverse order to maintain indices
for index in selectedIndices.sorted().reversed() {
    audioPlayer.playlist.remove(at: index)
}

// ❌ WRONG: Forward order causes index shifting bugs
for index in selectedIndices.sorted() {
    audioPlayer.playlist.remove(at: index)  // Breaks after first removal
}
```

---

## 6. Keyboard Event Monitor Lifecycle

### **Pattern: Store Reference and Cleanup**

```swift
@State private var keyboardMonitor: Any?

var body: some View {
    content
        .onAppear {
            keyboardMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [self] event in
                return handleKeyPress(event: event)
            }
        }
        .onDisappear {
            if let monitor = keyboardMonitor {
                NSEvent.removeMonitor(monitor)
                keyboardMonitor = nil
            }
        }
}
```

**Why:**
- Monitor must be stored or gets garbage collected
- Must cleanup or monitor stays active after view removed
- Closure must capture `[self]` to maintain reference

**Application:**
- WinampPlaylistWindow.swift (Command+A, Escape keyboard shortcuts)
- Any view with NSEvent monitoring

---

## 7. NSMenu Sprite System

### **Architecture: Custom NSMenuItem with Sprite Views**

**Components:**
1. **SpriteMenuItem** - NSMenuItem subclass
2. **HoverTrackingView** - NSView with NSTrackingArea
3. **SpriteMenuItemView** - SwiftUI view for sprite rendering
4. **PlaylistWindowActions** - Action handlers (singleton)

**Pattern:**
```swift
let menuItem = SpriteMenuItem(
    normalSprite: "SPRITE_NAME",
    selectedSprite: "SPRITE_NAME_SELECTED",
    skinManager: skinManager,
    action: #selector(PlaylistWindowActions.actionMethod),
    target: PlaylistWindowActions.shared
)
menuItem.representedObject = audioPlayer
menu.addItem(menuItem)
```

**Click Forwarding:**
```swift
// HoverTrackingView must forward clicks
override func mouseDown(with event: NSEvent) {
    if let menuItem = menuItem,
       let action = menuItem.action,
       let target = menuItem.target {
        NSApp.sendAction(action, to: target, from: menuItem)
    }
    menuItem?.menu?.cancelTracking()
}
```

**Future (Phase 3):**
- Replace HoverTrackingView with NSMenuDelegate
- Simpler, better accessibility

---

## 8. Coordinate System - NSMenu Positioning

### **NSMenu Uses Flipped Coordinates**

**Y-axis:**
- Y=0 at TOP
- Increasing Y moves DOWN
- Counter-intuitive but documented

**Positioning:**
```swift
// Window height: 232px
// Button at bottom: y: 206
// Menu should appear ABOVE button

// ❌ WRONG
let y = 206 - 54  // Subtracting moves UP (wrong direction)

// ✅ CORRECT
let y = 400       // Larger Y moves DOWN to bottom
```

**Rule:** Menu too HIGH → INCREASE Y, Menu too LOW → DECREASE Y

---

## 9. Sprite Coordinate Verification

### **NEVER Trust AI Coordinates**

**Process:**
1. Open PLEDIT.BMP in Preview
2. Tools → Show Inspector (⌘I)
3. Hover over sprite top-left corner
4. Read (x, y) coordinates from Inspector
5. Verify in code

**Issue:** AI hallucinates sprite coordinates
**Solution:** Manual verification required
**Reference:** BUILDING_RETRO_MACOS_APPS_SKILL.md Section 6

---

## 10. NSMenu vs NSHostingMenu

### **Decision: Use NSMenu for Sprite Menus**

**Attempted:** NSHostingMenu migration (macOS 15+)
**Result:** Unavoidable AppKit padding (8-12px on each side)
**Decision:** Stick with NSMenu pattern

**Why NSMenu:**
- Tight width control (no padding)
- Proven pattern working well
- Full control over layout

**When to Use NSHostingMenu:**
- Pure SwiftUI content
- Don't need pixel-perfect sizing
- Modern UI aesthetic (not retro)

**Research:** Fully documented in tasks/playlist-menu-system/

---

## 11. App Entry Point Pattern

### **Current:**
```swift
@main
struct MacAmpApp: App {
    @StateObject private var skinManager = SkinManager()
    @StateObject private var audioPlayer = AudioPlayer()
    @StateObject private var dockingController = DockingController()
    @StateObject private var settings = AppSettings.instance()

    var body: some Scene {
        WindowGroup {
            UnifiedDockView()
                .environmentObject(skinManager)
                .environmentObject(audioPlayer)
                .environmentObject(dockingController)
                .environmentObject(settings)
        }
    }
}
```

### **Target (After Phase 2):**
```swift
@main
struct MacAmpApp: App {
    @State private var skinManager = SkinManager()
    @State private var audioPlayer = AudioPlayer()
    @State private var dockingController = DockingController()
    @State private var settings = AppSettings.instance()

    var body: some Scene {
        WindowGroup {
            UnifiedDockView()
                .environment(skinManager)
                .environment(audioPlayer)
                .environment(dockingController)
                .environment(settings)
        }
    }
}
```

**Changes:**
- @StateObject → @State (for @Observable objects)
- .environmentObject() → .environment() (for @Observable objects)

---

## 12. Performance Patterns

### **Avoid Main Thread Blocking**

**Audio File Loading:**
- Currently: Synchronous (blocks UI)
- Target: Async/await pattern (future task)

**M3U Parsing:**
- Currently: Main thread
- Target: Background thread with Task.detached

**State Updates:**
- Current: ObservableObject (全updates)
- Target: @Observable (fine-grained updates) → 10-20% improvement

---

## Summary - Modern Swift Checklist

### **✅ Always Do:**
- `.interpolation(.none) + .antialiased(false)` for ALL sprites
- Double-click gesture BEFORE single-click
- Store keyboard monitor reference, cleanup in .onDisappear
- Verify sprite coordinates manually (Preview Inspector)
- Use Set<Int> for multi-selection
- Remove items in reverse order

### **🎯 Target (Phases 2-3):**
- @Observable instead of ObservableObject
- @Bindable for views with bindings
- @Environment instead of @EnvironmentObject
- NSMenuDelegate for accessibility

### **❌ Never Do:**
- Trust AI sprite coordinates
- Use .interpolation(.high) for pixel art
- Declare single-click before double-click
- Remove array items in forward order
- Add keyboard monitor without cleanup

---

**This architecture ensures:**
- Pixel-perfect retro aesthetic
- Modern Swift patterns
- Best performance
- Full accessibility
- Maintainable codebase

**Reference:** All future code changes should follow these patterns
