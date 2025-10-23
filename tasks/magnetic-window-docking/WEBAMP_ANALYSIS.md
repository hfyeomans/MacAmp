# Webamp Magnetic Docking - Complete Analysis

**Source:** Gemini analysis of webamp_clone codebase
**Date:** 2025-10-23

---

## 🏗️ Architecture Summary

### Window Implementation
- **Type:** React components rendered as positioned `div` elements
- **Positioning:** `position: absolute` with `transform: translate(x, y)`
- **Components:** `MainWindow`, `EqualizerWindow`, `PlaylistWindow`
- **Manager:** `WindowManager.tsx` orchestrates all 3 windows

### State Management
- **Framework:** Redux
- **Reducer:** `js/reducers/windows.ts`
- **State Shape:**
  ```typescript
  {
    genWindows: {
      [windowId]: {
        open: boolean,
        shade: boolean,
        size: {width, height},
        position: {x, y}
      }
    },
    focused: string,  // Current window ID
    windowOrder: string[],  // Z-index stacking
    positionsAreRelative: boolean
  }
  ```

---

## 🧲 Magnetic Snapping Logic

### Constants
```typescript
const SNAP_DISTANCE = 15;  // pixels
```

### Core Algorithm (`js/snapUtils.ts`)

**1. Proximity Detection:**
```typescript
const near = (a, b) => Math.abs(a - b) < SNAP_DISTANCE;
```

**2. Overlap Detection:**
```typescript
const overlapX = (boxA, boxB) => {
  return !(right(boxA) < left(boxB) || left(boxA) > right(boxB));
};

const overlapY = (boxA, boxB) => {
  return !(bottom(boxA) < top(boxB) || top(boxA) > bottom(boxB));
};
```

**3. Snap Calculation:**
```typescript
export const snap = (boxA: Box, boxB: Box) => {
  let x, y;

  // Horizontal snapping (requires vertical overlap)
  if (overlapY(boxA, boxB)) {
    if (near(left(boxA), right(boxB))) {
      x = right(boxB);  // Snap left edge to right edge
    } else if (near(right(boxA), left(boxB))) {
      x = left(boxB) - boxA.width;  // Snap right edge to left edge
    } else if (near(left(boxA), left(boxB))) {
      x = left(boxB);  // Align left edges
    } else if (near(right(boxA), right(boxB))) {
      x = right(boxB) - boxA.width;  // Align right edges
    }
  }

  // Vertical snapping (requires horizontal overlap)
  if (overlapX(boxA, boxB)) {
    if (near(top(boxA), bottom(boxB))) {
      y = bottom(boxB);  // Snap top to bottom
    } else if (near(bottom(boxA), top(boxB))) {
      y = top(boxB) - boxA.height;  // Snap bottom to top
    } else if (near(top(boxA), top(boxB))) {
      y = top(boxB);  // Align tops
    } else if (near(bottom(boxA), bottom(boxB))) {
      y = bottom(boxB) - boxA.height;  // Align bottoms
    }
  }

  return { x, y };
};
```

---

## 🔗 Group Movement (Docked Windows)

### Connection Detection (`js/snapUtils.ts`)

```typescript
// Recursively find all connected windows
export const traceConnection = (
  windowId: string,
  windows: WindowInfo[],
  visited: Set<string> = new Set()
): Set<string> => {
  if (visited.has(windowId)) return visited;
  visited.add(windowId);

  const window = windows.find(w => w.id === windowId);
  if (!window) return visited;

  // Find all windows abutting this one
  for (const other of windows) {
    if (other.id !== windowId && abuts(window, other)) {
      traceConnection(other.id, windows, visited);
    }
  }

  return visited;
};

// Check if two windows are touching
const abuts = (a: WindowInfo, b: WindowInfo) => {
  const distance = Math.min(
    Math.abs(a.position.x + a.size.width - b.position.x),
    Math.abs(b.position.x + b.size.width - a.position.x),
    Math.abs(a.position.y + a.size.height - b.position.y),
    Math.abs(b.position.y + b.size.height - a.position.y)
  );
  return distance < 2;  // Touching if < 2px apart
};
```

### Movement Synchronization (`WindowManager.tsx`)

```typescript
const useHandleMouseDown = (windowId) => {
  return (e) => {
    // Only drag main window moves connected group
    if (windowId === 'main') {
      const connectedIds = traceConnection(windowId, allWindows);
      const windowsToMove = Array.from(connectedIds);

      // Calculate bounding box of group
      const boundingBox = getBoundingBox(windowsToMove);

      // On mouse move: apply delta to all windows in group
      const handleMouseMove = (moveEvent) => {
        const delta = {
          x: moveEvent.clientX - startX,
          y: moveEvent.clientY - startY
        };

        // Update positions for all windows in group
        const newPositions = {};
        for (const id of windowsToMove) {
          newPositions[id] = {
            x: originalPositions[id].x + delta.x,
            y: originalPositions[id].y + delta.y
          };
        }

        dispatch(updateWindowPositions(newPositions));
      };
    }
  };
};
```

---

## 🎯 Key Insights for macOS Implementation

### 1. Snap Distance
**Webamp:** 15 pixels
**Recommendation:** Use same (industry standard)

### 2. Connection Graph
**Webamp:** Dynamically computed on drag start
**macOS:** Can use same approach with NSWindow.frame

### 3. Group Movement
**Webamp:** Only main window drag moves group
**macOS:** Could make any window drag move group (more flexible)

### 4. Docking State
**Webamp:** Not persisted, computed from positions
**macOS:** Could persist to avoid computation cost

### 5. Edge Cases
**Webamp handles:**
- Window close/shade triggers layout adjustment
- Z-order via windowOrder array
- Relative vs absolute positioning mode

---

## 📋 macOS Translation Guide

### Webamp → macOS Mapping

| Webamp Concept | macOS Equivalent |
|---------------|------------------|
| `div` with `position: absolute` | `NSWindow` with custom frame |
| `transform: translate(x, y)` | `window.setFrame(...)` |
| `onMouseDown` + window listeners | `NSEvent` monitoring or NSWindowController override |
| Redux state | `@StateObject` + `@Published` properties |
| `traceConnection()` BFS | Same algorithm in Swift |
| localStorage | UserDefaults |
| CSS z-index via array | `window.level` + `orderFront()` |

### Key macOS APIs

```swift
// Window positioning
window.setFrame(NSRect, display: Bool, animate: Bool)

// Get window frame
window.frame  // NSRect with origin (bottom-left in screen coordinates!)

// Z-order
window.orderFront(nil)  // Bring to front
window.level = .floating  // Keep above others

// Drag tracking
NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDragged])
```

---

## ⚠️ macOS Gotchas

1. **Coordinate System:** NSWindow uses bottom-left origin, not top-left!
2. **Multi-Monitor:** NSScreen.screens array, different coordinate spaces
3. **Mission Control:** Windows may be in different Spaces
4. **Full Screen:** Need to handle full-screen windows differently
5. **Accessibility:** VoiceOver needs proper window roles/titles

---

## 📂 Critical Webamp Files

**Must Read:**
- `packages/webamp/js/snapUtils.ts` - Core snapping algorithm
- `packages/webamp/js/components/WindowManager.tsx` - Drag handling
- `packages/webamp/js/resizeUtils.ts` - Layout maintenance on resize/shade
- `packages/webamp/js/reducers/windows.ts` - State shape

**Reference:**
- `packages/webamp/js/actionCreators/windows.ts` - Window actions
- `packages/webamp/js/utils/windows.ts` - Helper functions

---

## 🎓 Lessons Learned from Webamp

1. **Don't persist connections** - Compute from positions (simpler, fewer bugs)
2. **Use BFS/DFS** - Recursive connection tracing handles complex graphs
3. **Bounding box approach** - Maintain relative positions during group drag
4. **Special case main window** - Only main drag moves group (UX clarity)
5. **Snap on all 4 edges** - Left, right, top, bottom + alignment variants
6. **15px threshold** - Feels right, industry standard

---

**Analysis Status:** ✅ COMPLETE
**Next:** Create Swift implementation plan based on these findings
