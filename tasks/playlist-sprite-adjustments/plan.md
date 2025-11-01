# Playlist Sprite Adjustments - Implementation Plan

**Objective:** Fix bottom right corner sprite positioning
**Scope:** Adjust PLAYLIST_BOTTOM_RIGHT_CORNER x-position
**Time:** 15-30 minutes

---

## Implementation Steps

### Step 1: Identify Current Position ✅
- Found HStack with both bottom corners at line 285-293
- Current x-position: 137.5px (windowWidth / 2)

### Step 2: Calculate Correct Position ✅
- Playlist window width: 275px
- Bottom left sprite width: 125px
- Bottom right sprite width: 154px
- Total: 279px (squeezed into 275px frame = 4px compression)
- Fix: Shift HStack +2px right to 139.5px

### Step 3: Apply Fix ✅
- Updated .position(x: (windowWidth / 2) + 2, y: 213)
- Shifted entire bottom section 2 pixels right

### Step 4: Verify ✅
- Built and ran app
- Blue edge eliminated
- Right corner aligns with window edge
- Left corner still properly positioned

---

## Solution

**File:** `MacAmpApp/Views/WinampPlaylistWindow.swift`
**Line:** 293
**Change:** `.position(x: windowWidth / 2, y: 213)` → `.position(x: (windowWidth / 2) + 2, y: 213)`
**Result:** Shifts HStack 2px right, eliminating blue edge

---

**Status:** ✅ Complete - Ready to commit
