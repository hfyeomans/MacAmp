# Playlist Sprite Adjustments - Research

**Date:** 2025-10-28
**Issue:** Bottom right sprite of playlist window positioned 1-3px too far left
**Priority:** P2 (Visual bug)

---

## Problem Statement

**Issue:** Visible blue edge on right side of playlist window
**Root Cause:** Bottom right corner sprite (PLAYLIST_BOTTOM_RIGHT_CORNER) shifted 1-3 pixels left
**Likely Cause:** Accidental adjustment during previous black bar fixes

**Visual Evidence:** Screenshot.png shows thin blue line on right edge

---

## Investigation

### Visual Analysis (Screenshot.png)
- Blue edge visible on right side of playlist window
- Bottom right corner sprite not extending to window edge
- Approximately 4 pixels of gap

### Code Analysis (WinampPlaylistWindow.swift:285-293)

**Current Implementation:**
```swift
HStack(spacing: 0) {
    SimpleSpriteImage("PLAYLIST_BOTTOM_LEFT_CORNER", width: 125, height: 38)
    SimpleSpriteImage("PLAYLIST_BOTTOM_RIGHT_CORNER", width: 154, height: 38)
}
.frame(width: windowWidth)  // 275px
.position(x: 137.5, y: 213)
```

**Problem:**
- Left sprite: 125px wide
- Right sprite: 154px wide
- Total: 279px
- Frame constraint: 275px (windowWidth)
- **Result:** 279px squeezed into 275px = 4px compression on right edge

### Sprite Dimensions (SkinSprites.swift:233)
- PLAYLIST_BOTTOM_LEFT_CORNER: 125 × 38 pixels
- PLAYLIST_BOTTOM_RIGHT_CORNER: 154 × 38 pixels

### Root Cause
Using HStack with frame constraint causes sprite compression. Should position individually like top corners.

---

**Status:** ✅ Investigation complete - ready to implement fix
