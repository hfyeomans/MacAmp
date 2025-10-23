# Comprehensive Research Prompt - Magnetic Window Docking

**Use this prompt with Gemini, ChatGPT, Claude, or other AI research tools**

---

## 📋 Research Query

```
I'm building a Winamp clone for macOS called MacAmp. Currently, all three windows
(Main player, Equalizer, Playlist) are combined into a single NSWindow. I need to
refactor this into 3 separate NSWindows that:

1. Can be dragged independently when separated
2. Magnetically snap together on all edges when brought close
3. Move as a unit when docked together (drag any titlebar moves all)
4. Remember docking state and positions
5. Match classic Winamp's magnetic window behavior

Please analyze and provide:

### Part 1: Webamp Implementation Analysis
Analyze @webamp_clone codebase (JavaScript/React):
- How are the 3 windows implemented as separate DOM elements?
- How is magnetic snapping detected and applied?
- What is the snap distance threshold (pixels)?
- How does dragging one window move connected windows?
- How is docking state managed (which windows are connected, on which edges)?
- How are window positions saved/restored?
- What edge detection algorithm is used?

### Part 2: macOS Native Patterns
Research macOS NSWindow magnetic behavior:
- Does macOS provide built-in window snapping APIs?
- How do apps like Things 3, OmniFocus, or classic iTunes implement window grouping?
- What are the SwiftUI window management APIs for multi-window apps?
- How to detect window edge proximity for snap detection?
- How to move multiple windows together while maintaining relative positions?
- How to handle window close/minimize for docked groups?

### Part 3: Architecture Design
Propose an architecture for MacAmp:
- Should we use NSWindowController for each window type?
- How to share state between 3 separate NSWindows?
- What's the docking state model (struct/class)?
- How to implement the magnetic snapping logic?
- What coordinate system transformations are needed?
- How to handle window layering (z-order) when docked?

### Part 4: Implementation Roadmap
Break down into phases:
- Phase 1: Separate windows (no snapping)
- Phase 2: Magnetic snap detection
- Phase 3: Group movement when docked
- Phase 4: State persistence
- Estimate time for each phase

### Part 5: Edge Cases
Consider:
- Multiple displays/monitors
- Window minimized/maximized states
- Mission Control / Spaces integration
- Window resizing when docked
- Shade mode (collapsed windows)
- Window close behavior (close one vs close all)

---

## 📂 Reference Materials

**Webamp Clone:**
- Repo: webamp_clone/
- Windows: Main, Equalizer, Playlist
- Language: JavaScript/React/HTML
- Window management in: js/components/ or similar

**Current MacAmp:**
- File: MacAmpApp/Views/UnifiedDockView.swift (current single-window approach)
- File: MacAmpApp/ViewModels/DockingController.swift (manages visibility)
- Pattern: Single NSWindow with conditional view rendering

**Expected Behavior:**
- Video: ScreenRecording10-23.mov (demonstrates magnetic snapping)
- Classic Winamp (Windows): Reference for snapping behavior

---

## 🎯 Desired Output

Please provide:
1. Detailed analysis of webamp's window management code
2. Recommended macOS APIs and patterns
3. Architectural design (SwiftUI + AppKit hybrid likely needed)
4. Implementation phases with time estimates
5. Code examples for key concepts (snap detection, group movement)
6. Potential pitfalls and how to avoid them

---

## 🔍 Specific Questions

1. **Webamp:** What JavaScript libraries/APIs does webamp use for drag/snap?
2. **macOS:** Is NSWindow's `setFrame(_, display:, animate:)` sufficient for synchronized movement?
3. **State:** Should docking state live in a @StateObject shared via environment?
4. **Performance:** How to make snap detection performant (avoid lag during drag)?
5. **Z-Order:** How to ensure docked windows maintain correct layering?
6. **Persistence:** Where to save window positions (UserDefaults, Core Data)?

---

Use this prompt to get comprehensive architectural guidance for implementing
classic Winamp-style magnetic window docking in a modern macOS/SwiftUI app.
```
