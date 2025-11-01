# Swift Modernization Recommendations - Research

**Date:** 2025-10-28
**Source:** AMP_FINDINGS.md - Modern Swift / macOS 15+/26 Recommendations
**Priority:** TBD (depends on validity of recommendations)

---

## Overview

Investigating 6 Swift modernization recommendations from code review to determine:
1. Are they still valid for macOS 15+ (Sequoia) and macOS 26+ (Tahoe)?
2. What are the benefits vs costs of implementation?
3. Are there breaking changes or gotchas?
4. Should we implement them?

---

## Recommendations from AMP_FINDINGS.md

### **Recommendation 1: Swift 6 Strict Concurrency**

**Status in Code:** Not Yet Applied
**Description:** Add `@MainActor` to AppKit subclasses

```swift
@MainActor final class HoverTrackingView: NSView { }
@MainActor final class SpriteMenuItem: NSMenuItem { }
```

**Rationale:** Swift 6 strict concurrency checking requires explicit actor annotations on types that access main-thread-only APIs (AppKit).

**Research Needed:**
- Is this required for macOS 15+ / macOS 26+?
- What are the benefits?
- Any breaking changes?

---

### **Recommendation 2: Async File Panel Pattern**

**Status in Code:** Not Yet Applied
**Description:** Move file I/O and M3U parsing off main thread

```swift
extension NSOpenPanel {
    @MainActor func pickURLs() async -> [URL]? {
        await withCheckedContinuation { cont in
            begin { resp in cont.resume(returning: resp == .OK ? self.urls : nil) }
        }
    }
}

// Usage
Task.detached(priority: .userInitiated) {
    // Parse M3U off main thread
    let entries = try M3UParser.parse(fileURL: url)
    await MainActor.run {
        audioPlayer.addTrack(url: entry.url)
    }
}
```

**Benefit:** Keeps UI responsive during file parsing

**Research Needed:**
- Is this the recommended pattern for macOS 15+/26+?
- Are there newer APIs we should use?
- Performance impact?

---

### **Recommendation 3: Observation Framework Migration**

**Status in Code:** Not Yet Applied
**Description:** Migrate SkinManager from @ObservedObject to @Observable (macOS 14+)

```swift
// Old
class SkinManager: ObservableObject {
    @Published var currentSkin: Skin?
}

// New (macOS 14+)
@Observable final class SkinManager {
    var currentSkin: Skin?
}

// In view
@Environment(SkinManager.self) var skinManager
```

**Benefits:**
- Automatic fine-grained updates
- Better performance
- Modern Swift pattern

**Research Needed:**
- Is @Observable fully stable in macOS 15+/26+?
- Migration complexity?
- Breaking changes for existing code?

---

### **Recommendation 4: NSMenu Delegate for Hover**

**Status in Code:** Not Yet Applied
**Description:** Use NSMenu highlight delegate instead of only tracking areas

```swift
final class SpriteMenuDelegate: NSObject, NSMenuDelegate {
    func menu(_ menu: NSMenu, willHighlight item: NSMenuItem?) {
        for case let sprite as SpriteMenuItem in menu.items {
            sprite.setHighlighted(sprite === item)
        }
    }
}
```

**Benefits:**
- Keyboard navigation support (arrow keys)
- VoiceOver compatibility
- Correct highlight behavior in all cases

**Research Needed:**
- Does this work properly with custom NSMenuItem views?
- Does it improve our current hover implementation?
- macOS 15+/26+ compatibility?

---

### **Recommendation 5: Keyboard Event Monitor Cleanup**

**Status in Code:** ✅ ALREADY IMPLEMENTED (PR #21)
**Description:** Add cleanup for keyboard monitor

```swift
@State private var keyMonitor: Any?

.onAppear {
    keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown, handler: handleKeyPress)
}
.onDisappear {
    if let m = keyMonitor {
        NSEvent.removeMonitor(m)
        keyMonitor = nil
    }
}
```

**Status:** ✅ This was already fixed in the text rendering PR
**Location:** WinampPlaylistWindow.swift:227-239

---

### **Recommendation 6: SwiftUI Image Interpolation for Pixel Art**

**Status in Code:** Partially Applied
**Description:** Use .interpolation(.none) for pixel-perfect sprites

```swift
Image(nsImage: image)
    .resizable()
    .interpolation(.none)  // ✅ Pixel-perfect for retro sprites
    .antialiased(false)
    .frame(width: 22, height: 18)
```

**Research Needed:**
- Where is .interpolation(.none) already used?
- Where is it missing?
- Should we add .antialiased(false) as well?

---

## Research Questions

1. **Swift 6 Concurrency:** Are @MainActor annotations required or just recommended?
2. **Async File Panel:** Is this the best pattern for macOS 15+/26+?
3. **@Observable:** Is it production-ready and worth migrating?
4. **NSMenu Delegate:** Does it improve our sprite menu implementation?
5. **Interpolation:** Where should we add it? Any performance impact?

---

## Next Steps

1. Research each recommendation with Gemini for macOS 15+/26+ validity
2. Use swift-macos-ios-engineer agent to validate and provide specific guidance
3. Determine which recommendations to implement
4. Create implementation plan

---

**Status:** Recommendations extracted, ready for research phase
