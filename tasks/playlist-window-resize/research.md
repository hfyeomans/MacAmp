# Playlist Window Resize Research

## Task Overview
**Priority:** P4 (Deferred)
**Status:** Research Phase
**Related Task:** tasks/playlist-state-sync/

## Background

The Winamp classic playlist window is unique among all windows because it is **resizable**. When resized, a **middle section becomes visible** that is hidden when the window is at its minimum size. This is different from the main window, equalizer, and other UI elements which have fixed dimensions.

### Connection to playlist-state-sync Task

During the implementation of playlist-state-sync, we encountered a critical discovery:

**The playlist bottom section has THREE parts, not TWO:**

1. **playlist-bottom-left** (125px) - Menu buttons
2. **playlist-bottom-center** (expandable) - **THIS WAS MISSING IN MACAMP**
3. **playlist-bottom-right** (154px) - Transport controls

**The Issue:**
In tasks/playlist-state-sync/, we initially created the bottom section as only LEFT + RIGHT, which caused the PLAYLIST_BOTTOM_TILE overlay to obscure the rightmost transport icons. The fix was to remove the tile overlay, but the **real problem** is that MacAmp doesn't implement the **center section** because the playlist window isn't resizable yet.

**From CODEX_RENDERING_SUGGESTION.md:**
> After fixing the playlist window sprite rendering (by removing PLAYLIST_BOTTOM_TILE overlay), Codex analyzed the SimpleSpriteImage rendering logic...

The overlay was blocking sprites because we were trying to tile a background across a section that should actually be a **separate flexbox element** (the center section).

**Current MacAmp Workaround:**
- Used HStack layout: `LEFT | RIGHT` (no center)
- Set PLAYLIST_BOTTOM_RIGHT_CORNER to 154px width
- Disabled PLAYLIST_BOTTOM_TILE to prevent overlap

**Proper Solution (This Task):**
- Implement three-section layout: `LEFT | CENTER | RIGHT`
- Make playlist window resizable
- Center section expands/contracts based on window width
- Re-enable PLAYLIST_BOTTOM_TILE for center section tiling

## webamp_clone Analysis

### Three-Section Layout Structure

The playlist window in webamp_clone has a three-part layout for the **bottom section**:

**File:** `webamp_clone/packages/webamp/js/components/PlaylistWindow/index.tsx`

```tsx
<div className="playlist-bottom draggable">
  <div className="playlist-bottom-left draggable">
    <AddMenu />
    <RemoveMenu />
    <SelectionMenu />
    <MiscMenu />
  </div>
  <div className="playlist-bottom-center draggable" />  {/* CENTER SECTION */}
  <div className="playlist-bottom-right draggable">
    {showVisualizer && (
      <div className="playlist-visualizer">
        {activateVisualizer && (
          <div className="visualizer-wrapper">
            <Vis analyser={analyser} />
          </div>
        )}
      </div>
    )}
    <PlaylistActionArea />
    <ListMenu />
    <div id="playlist-scroll-up-button" onClick={scrollUpFourTracks} />
    <div id="playlist-scroll-down-button" onClick={scrollDownFourTracks} />
    <PlaylistResizeTarget />
  </div>
</div>
```

### Sections Breakdown

#### 1. **playlist-bottom-left** (Fixed Width: 125px)
- **Contains:** Four menu buttons (Add, Remove, Selection, Misc)
- **Position:** Absolute left side
- **Width:** 125px (fixed)

#### 2. **playlist-bottom-center** (Flexible/Growable)
- **Contains:** Empty div (for skin graphics to tile/repeat)
- **Position:** Between left and right sections
- **Behavior:** This section becomes visible when window width increases
- **Purpose:** Fills the gap between left menu buttons and right controls with repeating background graphics

#### 3. **playlist-bottom-right** (Fixed Width: 150px)
- **Contains:**
  - Playlist visualizer (75px, positioned absolutely)
  - Running time display
  - Action buttons (new, save, load)
  - List menu button
  - Scroll up/down buttons
  - Resize target (bottom-right corner handle)
- **Position:** Absolute right side
- **Width:** 150px (fixed)

### CSS Layout Strategy

**File:** `webamp_clone/packages/webamp/css/playlist-window.css`

```css
#webamp .playlist-bottom {
  width: 100%;
  height: 38px;
  min-height: 38px;
  max-height: 38px;
  position: relative;  /* Container is relative */
}

#webamp .playlist-bottom-left {
  width: 125px;
  height: 100%;
  position: absolute;  /* Positioned left */
}

#webamp .playlist-bottom-center {
  /* No explicit styles - fills remaining space */
}

#webamp .playlist-bottom-right {
  width: 150px;
  height: 100%;
  position: absolute;
  right: 0;  /* Positioned right */
}
```

**Key Strategy:**
- Left and right sections are **absolutely positioned** with fixed widths
- Center section implicitly fills the space between them
- When window width = minimum (275px), center section has no space
- When window expands, center section grows to fill gap

### Visualizer Visibility Logic

```tsx
const showVisualizer = playlistSize[0] > 2;
```

The visualizer only shows when the window width exceeds a certain size (represented in some unit system where `> 2` means wider than minimum).

### Resize Implementation

**File:** `webamp_clone/packages/webamp/js/components/PlaylistWindow/PlaylistResizeTarget.tsx`

```tsx
function PlaylistResizeTarget({ widthOnly }: Props) {
  const windowSize = useTypedSelector(Selectors.getWindowSize);
  const setWindowSize = useActionCreator(Actions.setWindowSize);
  const currentSize = windowSize("playlist");

  return (
    <ResizeTarget
      currentSize={currentSize}
      id="playlist-resize-target"
      setWindowSize={(size) => {
        setWindowSize("playlist", size);
      }}
      widthOnly={widthOnly}
    />
  );
}
```

The resize target is positioned in the bottom-right corner (20x20px clickable area) and allows dragging to resize both width and height.

## Top Section Also Has Three Parts

Looking at the top section:

```tsx
<div className="playlist-top draggable" onDoubleClick={toggleShade}>
  <div className="playlist-top-left draggable" />
  {showSpacers && <div className="playlist-top-left-spacer draggable" />}
  <div className="playlist-top-left-fill draggable" />
  <div className="playlist-top-title draggable" />
  {showSpacers && <div className="playlist-top-right-spacer draggable" />}
  <div className="playlist-top-right-fill draggable" />
  <div className="playlist-top-right draggable">
    <WinampButton id="playlist-shade-button" onClick={toggleShade} />
    <WinampButton id="playlist-close-button" onClick={() => close(WINDOWS.PLAYLIST)} />
  </div>
</div>
```

The top uses a **flex layout** with grow sections instead of absolute positioning:

```css
#webamp .playlist-top {
  width: 100%;
  min-height: 20px;
  max-height: 20px;
  position: relative;
  display: flex;  /* Flexbox layout */
}

#webamp .playlist-top-left-fill {
  flex-grow: 1;  /* Grows to fill space */
  background-position: right;
}

#webamp .playlist-top-right-fill {
  flex-grow: 1;  /* Grows to fill space */
  background-position: right;
}
```

## Middle Section (Tracklist Area)

```tsx
<div className="playlist-middle draggable">
  <div className="playlist-middle-left draggable" />
  <div className="playlist-middle-center">
    <TrackList />
  </div>
  <WinampButton className="playlist-middle-right draggable">
    <PlaylistScrollBar />
  </WinampButton>
</div>
```

Also uses flexbox with side borders:

```css
#webamp .playlist-middle {
  flex-grow: 1;
  display: flex;
  flex-direction: row;
  overflow: hidden;
}

#webamp .playlist-middle-left {
  background-repeat: repeat-y;
  width: 12px;
  min-width: 12px;
}

#webamp .playlist-middle-center {
  flex-grow: 1;  /* Grows to fill space */
  padding: 3px 0;
  min-width: 0;
}
```

## Key Findings

1. **Playlist window is the ONLY resizable window** in classic Winamp
2. **Three sections** in bottom area: left (menus), center (expandable), right (controls)
3. **Two positioning strategies:**
   - Top/middle: Flexbox with `flex-grow: 1`
   - Bottom: Absolute positioning with implicit center gap
4. **Minimum width:** ~275px (125px left + 150px right)
5. **Center sections purpose:** Display repeating skin graphics when window expands
6. **Resize handle:** 20x20px bottom-right corner drag target
7. **Visualizer visibility:** Only shows when width exceeds minimum

## MacAmp Implementation Considerations

### Current State
- MacAmp currently implements playlist window as **fixed size** (like other windows)
- No resize functionality implemented
- No center section rendered (because window doesn't resize)

### Implementation Strategy for SwiftUI

1. **Window Sizing:**
   - Use `.windowResizability(.contentSize)` or `.contentMinSize()`
   - Set minimum size: ~275px width × minimum height
   - Allow width/height resizing

2. **Layout Structure:**
   ```swift
   VStack(spacing: 0) {
     // Top bar (20px height)
     HStack {
       leftSection
       Spacer() // Grows to fill
       centerTitle
       Spacer() // Grows to fill
       rightButtons
     }

     // Middle (tracklist area)
     HStack {
       leftBorder  // 12px
       trackList   // Grows
       scrollBar   // 20px
     }

     // Bottom bar (38px height)
     ZStack {
       // Background center (repeating texture)
       bottomCenterBackground

       HStack {
         bottomLeft  // 125px, aligned leading
         Spacer()
         bottomRight // 150px, aligned trailing
       }
     }
   }
   ```

3. **Skin Graphics:**
   - Extract center section graphics from PLEDIT.BMP
   - Implement tiling/repeating pattern in center areas
   - Position left/right sections absolutely over background

4. **Resize Handle:**
   - Add drag gesture to bottom-right corner
   - Update window size constraints
   - Redraw skin graphics based on new dimensions

## Next Steps

1. **Analyze PLEDIT.BMP skin file** - Identify which parts are center section graphics
2. **Measure exact dimensions** - Determine minimum/maximum window sizes
3. **Study SwiftUI window resizing** - Learn macOS window management APIs
4. **Implement resize gesture** - Add bottom-right corner drag handle
5. **Test with multiple skins** - Ensure center graphics tile correctly

## Visual References Needed

- [ ] Screenshot of minimum-width playlist (center hidden)
- [ ] Screenshot of expanded playlist (center visible)
- [ ] PLEDIT.BMP sprite sheet with sections labeled
- [ ] Diagram showing measurement of all fixed dimensions
