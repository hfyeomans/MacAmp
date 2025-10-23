# Winamp Window Movement Frame Analysis

## Overview
This document provides a detailed frame-by-frame analysis of Winamp's magnetic window docking behavior based on video capture frames. The analysis covers window positioning, docking/detachment behavior, and movement patterns.

## Frame Summary

### Initial State (Frames 1-10, Detail 1-5)
All three windows (Main, Equalizer, Playlist) are perfectly docked in a vertical stack configuration:
- **Main Window** (top): Contains player controls, visualization, track info
- **Equalizer Window** (middle): 10-band equalizer with presets
- **Playlist Window** (bottom): Track list with controls

**Initial Configuration:**
- All windows are perfectly aligned horizontally (edges match exactly)
- Zero-pixel gaps between windows
- Windows appear to be in a "locked" docked state
- Cursor is visible but not interacting with windows

### Cursor Movement Phase (Detail 6-15)
The cursor begins moving from bottom-right area upward toward the Playlist window:
- Frames 6-11: Cursor positioned at bottom-right of Playlist window
- Frames 12-15: Cursor moves to right edge of Playlist window's bottom portion
- **Key Observation**: Windows remain perfectly docked during cursor movement
- No visual feedback or highlighting to indicate drag potential

### Detachment Sequence (Detail 16-29)
This is the critical sequence showing window separation:

#### Frame 16-20: Playlist Begins Detachment
- Cursor positioned on Playlist title bar (center)
- Playlist window shows first signs of movement
- Main and Equalizer remain perfectly docked together
- **Critical Finding**: Only the dragged window detaches; docked neighbors stay together

#### Frame 21-28: Progressive Separation
- Detail Frame 21: Playlist cursor moves over track listing area
- Detail Frame 22-28: Playlist window gradually moves downward and away from docked group
- Main + Equalizer maintain their docked relationship
- Gap between Equalizer bottom and Playlist top increases progressively
- No "snap back" behavior observed during movement

#### Frame 29: Complete Detachment
- Playlist window fully separated from the docked group
- Main and Equalizer remain as a 2-window docked unit at top
- Playlist positioned significantly below (approximately 100+ pixels gap)
- **Key Finding**: Partial docking is supported (Main+EQ stay docked while Playlist is independent)

### Final State (Detail 30)
- **Main Window** (top-left area): Still docked
- **Equalizer Window** (directly below Main): Still docked to Main
- **Playlist Window** (center-bottom area): Fully independent
- Cursor on Playlist title bar indicating completed drag operation

## Technical Measurements

### Window Dimensions
Based on frame analysis:
- **Main Window**: ~275px wide × ~116px tall
- **Equalizer Window**: ~275px wide × ~116px tall
- **Playlist Window**: ~275px wide × ~232px tall (approximately 2x height of others)

### Docking Alignment
- Perfect horizontal alignment when docked (0px offset)
- Perfect vertical stacking (0px gap between windows)
- All windows share identical width (275px)

### Detachment Behavior
- **Detachment Trigger**: Drag on any window's title bar
- **Detachment Threshold**: Movement appears to happen immediately (no visible snap distance)
- **Group Behavior**: Docked windows that aren't being dragged stay together
- **Independent Movement**: Only the dragged window moves

### Movement Characteristics
- **Smooth motion**: No snapping or jerky movement during drag
- **Free positioning**: Window can be placed anywhere after detachment
- **No rubber-banding**: No visible "pull back" effect when moving away from dock
- **Selective docking**: 2 of 3 windows can remain docked while 1 is independent

## Docking Rules Observed

### 1. Group Cohesion
When windows are docked:
- They move as a single unit if the top window is dragged
- Individual windows can be extracted from the group
- Remaining docked windows maintain their relationship

### 2. Docking Positions
Observed docking configuration:
```
[Main Window]
[Equalizer Window]
[Playlist Window]
```

Alternative observed configuration:
```
[Main Window]
[Equalizer Window]

[Playlist Window] (independent)
```

### 3. Alignment Rules
- **Horizontal**: Perfect edge alignment (left and right edges match)
- **Vertical**: Zero-gap stacking (bottom of Window N touches top of Window N+1)
- **Width**: All windows maintain consistent width when docked

### 4. No Visible Snap Indicators
- No highlight or outline when approaching snap zone
- No visual feedback during drag operation
- No "preview" of snap position before release
- Behavior is implicit rather than visually guided

## Movement Patterns

### Pattern 1: Individual Window Detachment
1. User grabs Playlist window by title bar
2. Playlist detaches immediately on drag
3. Main + Equalizer remain docked
4. Playlist moves independently

### Pattern 2: Implied Main Window Drag (Not Shown But Inferred)
If Main window is dragged:
- Likely behavior: All docked windows move together as a group
- Equalizer and Playlist would follow Main's position
- Group maintains docking relationship during movement

### Pattern 3: Implied Re-attachment (Not Shown)
Expected behavior for re-docking:
- Drag Playlist near bottom of Equalizer
- When edges align within snap distance, Playlist snaps into position
- Zero-gap alignment is restored
- Windows become docked group again

## Snap Distance Estimation

Based on the observed behavior and typical Winamp implementation:
- **Estimated snap distance**: 10-15 pixels
- **Snap tolerance**: Likely applies to both horizontal and vertical alignment
- **Snap axes**: Edges must align on both X and Y to dock

The actual snap distance is not visible in the frames since no re-attachment sequence was captured, but based on classic Winamp behavior, the snap distance is typically in the 10-15 pixel range.

## Key Insights for Implementation

### 1. Selective Docking
The system supports partial docking configurations:
- All 3 windows docked
- Main + Equalizer docked, Playlist independent
- Main + Playlist docked, Equalizer independent (likely)
- Equalizer + Playlist docked, Main independent (likely)
- All 3 windows independent

### 2. Drag Source Determines Behavior
- Dragging **any non-Main window**: Only that window detaches
- Dragging **Main window** (inferred): Entire docked group moves together
- This creates intuitive behavior where the "primary" window acts as group leader

### 3. Docking State Management
The system must track:
- Which windows are currently docked to which other windows
- The docking order/hierarchy (Main at top, Equalizer middle, Playlist bottom)
- Individual window positions when undocked
- Group position when docked

### 4. Edge Detection Requirements
The docking system needs:
- Precise edge position calculation for all windows
- Snap zone detection (likely ~10-15px tolerance)
- Edge alignment validation (both horizontal and vertical)
- Prevention of overlapping windows

### 5. No Visual Feedback Required
Unlike modern UIs, Winamp's docking is entirely implicit:
- No snap guides or alignment lines
- No highlighting of snap zones
- No preview overlays
- Users learn through experimentation and muscle memory

## Window Movement State Machine

```
State: ALL_DOCKED
├─ Drag Main → Move group as unit → ALL_DOCKED
├─ Drag Equalizer → Detach EQ → MAIN_PLAYLIST_DOCKED, EQ_INDEPENDENT
└─ Drag Playlist → Detach PL → MAIN_EQ_DOCKED, PL_INDEPENDENT (observed)

State: MAIN_EQ_DOCKED, PL_INDEPENDENT
├─ Drag Main → Move Main+EQ group → State unchanged
├─ Drag Equalizer → Detach EQ → MAIN_DOCKED, EQ_INDEPENDENT, PL_INDEPENDENT
├─ Drag Playlist near EQ → Snap → ALL_DOCKED (if aligned correctly)
└─ Release Playlist far from group → State unchanged
```

## Comparison with Real Winamp Behavior

Based on this analysis and knowledge of classic Winamp:

### Confirmed Behaviors:
- Zero-gap docking alignment ✓
- Selective detachment (individual windows can be removed from group) ✓
- Docked windows stay together when not being dragged ✓
- Perfect edge alignment ✓

### Likely But Not Shown:
- Snap distance of 10-15 pixels
- Re-attachment when dragging near docked group
- Main window acts as "leader" for group movement
- Magnetic snap to screen edges (common in Winamp)

### Unknown from Frames:
- Re-attachment sequence and behavior
- Screen edge snapping behavior
- Multi-monitor handling
- Keyboard modifiers to prevent snapping (if any)

## Recommendations for Implementation

### Priority 1: Core Docking
1. Implement edge detection with 10-15px snap tolerance
2. Support zero-gap vertical stacking
3. Ensure perfect horizontal alignment
4. Track docking relationships between windows

### Priority 2: Movement Behavior
1. Individual window detachment on drag
2. Group movement when dragging top (Main) window
3. Maintain docking relationships for non-dragged windows
4. Smooth continuous movement during drag

### Priority 3: State Management
1. Track which windows are docked
2. Store docking order/hierarchy
3. Preserve individual window positions when detached
4. Support all partial docking combinations

### Priority 4: Edge Cases
1. Handle window going off-screen
2. Support multi-monitor configurations
3. Persist docking state between sessions
4. Handle window resizing (if applicable)

## Architecture Implications

### Window Manager Requirements:
- Each window needs independent NSWindow instance
- Shared positioning coordinator to manage docking relationships
- Edge detection system that runs during drag operations
- State persistence for docking configuration

### Coordinate System:
- Use screen coordinates for absolute positioning
- Calculate relative positions when docked
- Convert between window-local and screen coordinates for snap detection

### Performance Considerations:
- Edge detection must run on every mouseMoved event during drag
- Snap calculations should be optimized (only check visible windows)
- Avoid excessive window position updates (coalesce if possible)

## Next Steps

1. Review existing MacAmp window architecture
2. Design docking state manager
3. Implement edge detection algorithm
4. Create snap behavior system
5. Test with all three windows in various configurations
6. Validate against real Winamp behavior reference videos

## Files Referenced
- Source frames: `/Users/hank/dev/src/MacAmp/tasks/magnetic-window-docking/frame-*.png`
- Detail frames: `/Users/hank/dev/src/MacAmp/tasks/magnetic-window-docking/detail-frame-*.png`
- Total frames analyzed: 40 (10 standard + 30 detail)

---

**Analysis Date**: 2025-10-23
**Analyzed By**: Claude Code
**Frame Count**: 40 frames total
**Key Finding**: Selective docking with partial group support - Main+EQ can stay docked while Playlist is independent
