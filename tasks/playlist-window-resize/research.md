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

---

## Playlist Visualizer Research

### Overview

The playlist window in Winamp includes a **mini visualizer** in the bottom-right section. This visualizer is the **same component** as the main window spectrum analyzer, but with different visibility conditions and positioning.

### Key Finding: Same Vis Component, Different Context

**Webamp reuses the exact same `<Vis />` component** in both windows:

```tsx
// From webamp_clone/packages/webamp/js/components/PlaylistWindow/index.tsx
<div className="playlist-bottom-right draggable">
  {showVisualizer && (
    <div className="playlist-visualizer">
      {activateVisualizer && (
        <div className="visualizer-wrapper">
          <Vis analyser={analyser} />  {/* SAME COMPONENT AS MAIN WINDOW */}
        </div>
      )}
    </div>
  )}
  ...
</div>
```

### Visibility Conditions

The playlist visualizer has **two conditions** that control its display:

```tsx
const showVisualizer = playlistSize[0] > 2;           // Width condition
const activateVisualizer = !getWindowOpen(WINDOWS.MAIN);  // Main window hidden
```

1. **`showVisualizer`**: Only renders the container when playlist width exceeds minimum
   - `playlistSize[0] > 2` means the playlist width unit is > 2 (approx 3× minimum width)
   - This creates space for the visualizer in the bottom-right section

2. **`activateVisualizer`**: Only activates animation when main window is closed/hidden
   - If main window is visible → visualizer container exists but is empty
   - If main window is hidden → visualizer runs the animation loop
   - **Purpose:** Avoid running two identical visualizers simultaneously (performance optimization)

### Webamp Documentation Confirms This

From `webamp_clone/packages/webamp-docs/docs/05_features/04_playlist.md`:

> **Mini Visualizer**
>
> If the main and Milkdrop windows are both hidden (via the context menu) and the playlist is horizontally expanded, Webamp will display a mini visualizer in the playlist window. If the main window is visible, the mini visualizer will not be active.

### Visual Dimensions Comparison

| Property | Main Window | Playlist Mini |
|----------|-------------|---------------|
| Container Width | 76px | 75px |
| Container Height | 16px | 38px (full bottom section) |
| Visualizer Wrapper | 76×16 | 72px wide, positioned `top:12px, left:2px` |
| Render Height | 16px (normal) / 5px (shade) | Uses same render logic |
| Bar Count | 19 (wide) / 38 (thin) | Same component |

**CSS from `webamp_clone/packages/webamp/css/playlist-window.css`:**

```css
#webamp #playlist-window .playlist-visualizer {
  width: 75px;
  height: 100%;          /* Full 38px height of bottom section */
  position: absolute;
  right: 150px;          /* Positioned to the left of the 150px right section */
}

#webamp #playlist-window .visualizer-wrapper {
  position: absolute;
  top: 12px;             /* Vertical offset within container */
  left: 2px;
  width: 72px;
  overflow: hidden;
}
```

### Technical Implementation Details

#### Shared AnalyserNode

Both visualizers share the same Web Audio API `AnalyserNode`:

```tsx
// From Vis.tsx
type Props = {
  analyser: AnalyserNode;  // Same audio source for both
};

export default function Vis({ analyser }: Props) {
  useLayoutEffect(() => {
    analyser.fftSize = 1024;  // FFT size for frequency analysis
  }, [analyser, analyser.fftSize]);
  ...
}
```

#### Rendering Modes

The Vis component supports three modes (same for both windows):

1. **`VISUALIZERS.BAR`** - Spectrum analyzer (bar graph)
2. **`VISUALIZERS.OSCILLOSCOPE`** - Waveform display
3. **`VISUALIZERS.NONE`** - Disabled

#### Paint Handlers (from `VisPainter.ts`)

| Handler | Description |
|---------|-------------|
| `BarPaintHandler` | Spectrum analyzer with FFT processing, peaks, gradient colors |
| `WavePaintHandler` | Oscilloscope waveform with multiple styles (dots, solid, lines) |
| `NoVisualizerHandler` | Empty/disabled state |

#### Color Palette (VISCOLOR.TXT)

Colors are defined by skin's `VISCOLOR.TXT` file:

| Index | Purpose |
|-------|---------|
| 0 | Background |
| 1 | Foreground dots |
| 2-17 | Spectrum gradient (bottom green → top red) |
| 18-22 | Oscilloscope colors |
| 23 | Peak dots |

### MacAmp's Existing Visualizer Infrastructure

MacAmp already has a complete spectrum analyzer implementation:

**File: `MacAmpApp/Views/VisualizerView.swift`**

```swift
struct VisualizerView: View {
    @Environment(AudioPlayer.self) var audioPlayer
    @Environment(SkinManager.self) var skinManager
    @Environment(AppSettings.self) var settings

    private let barCount = 19
    private let barWidth: CGFloat = 3
    private let barSpacing: CGFloat = 1
    private let maxHeight: CGFloat = 16

    var body: some View {
        Group {
            switch settings.visualizerMode {
            case .none: Rectangle().fill(Color.black)
            case .oscilloscope: OscilloscopeView()
            case .spectrum:
                HStack(spacing: barSpacing) {
                    ForEach(0..<barCount, id: \.self) { index in
                        SpectrumBar(...)
                    }
                }
            }
        }
        .frame(width: VisualizerLayout.width, height: VisualizerLayout.height)
    }
}
```

**Audio Data Source (`AudioPlayer.swift`):**

```swift
func getFrequencyData(bands: Int) -> [Float] {
    // Returns normalized frequency data for spectrum analyzer
    // Uses AVAudioEngine tap with Goertzel-style frequency binning
}

func getWaveformSamples(count: Int) -> [Float] {
    // Returns raw waveform samples for oscilloscope
}
```

### Implementation Strategy for MacAmp Playlist Visualizer

#### Option A: Reuse Existing VisualizerView (Recommended)

Since MacAmp already has `VisualizerView`, we can:

1. **Wrap it with visibility logic:**
   ```swift
   struct PlaylistMiniVisualizer: View {
       @Environment(WindowCoordinator.self) var windowCoordinator

       var showVisualizer: Bool {
           // Only show when main window is hidden AND playlist is wide enough
           !windowCoordinator.isMainWindowVisible && playlistWidth > minimumForVis
       }

       var body: some View {
           if showVisualizer {
               VisualizerView()
                   .frame(width: 72, height: 16)  // Adjusted for playlist placement
           } else {
               Rectangle().fill(Color.black)  // Placeholder
           }
       }
   }
   ```

2. **Position in playlist bottom-right:**
   ```swift
   // Inside playlist-bottom-right section
   ZStack(alignment: .topLeading) {
       PlaylistMiniVisualizer()
           .offset(x: 2, y: 12)  // Match webamp positioning
   }
   ```

#### Option B: Create Separate PlaylistVisualizer

If different rendering is needed:

- Create `PlaylistVisualizerView` with:
  - Smaller dimensions (72×16 vs 76×16)
  - Same `AudioPlayer.getFrequencyData()` data source
  - Possibly reduced bar count for smaller width

### Key Implementation Considerations

1. **Performance:** Only run ONE visualizer animation at a time
   - If main window visible → playlist visualizer static or hidden
   - If main window hidden → playlist visualizer active

2. **Shared Audio Data:** Use same `AudioPlayer` audio tap
   - No need to duplicate FFT processing
   - Both visualizers read from `latestSpectrum` / `latestWaveform`

3. **VISCOLOR.TXT Colors:** Same skin colors apply to both
   - Reuse existing `SkinManager.currentSkin?.visualizerColors`

4. **Click to Cycle:** Both should cycle modes on click
   - Toggle `AppSettings.visualizerMode`

5. **CRITICAL: Clipping Behavior** (Verified by Gemini)
   - The standard Vis component renders at **76px wide**
   - The playlist wrapper is only **72px wide** with `overflow: hidden`
   - This means **4px are clipped** from the right side
   - In MacAmp/SwiftUI, use `.frame(width: 72, alignment: .leading).clipped()`
   - Do NOT resize/scale the visualizer - clip it to maintain historical accuracy

### Skin Resource Analysis

The playlist visualizer **does NOT** use separate skin resources:

- **No PLEDIT.BMP visualizer sprites** - uses same rendering as main window
- **VISCOLOR.TXT** - shared color palette
- **Background:** Black (VISCOLOR index 0)

The `playlist-visualizer` CSS class in base-skin uses no special background image:
```css
#webamp #playlist-window .playlist-visualizer {
  /* No background-image defined */
  width: 75px;
  height: 100%;
  position: absolute;
  right: 150px;
}
```

### Summary: Playlist vs Main Window Visualizer

| Aspect | Main Window | Playlist |
|--------|-------------|----------|
| Component | `Vis` | Same `Vis` component |
| Always Visible | Yes (when playing) | Only when main hidden + wide enough |
| Dimensions | 76×16 | 72×wide within 75×38 container |
| Position | Fixed in main window | `top:12px, left:2px` in bottom-right |
| Audio Source | `AnalyserNode` / AVAudioEngine tap | Same |
| Colors | VISCOLOR.TXT | Same |
| Click Action | Cycle modes | Same |
| Skin Graphics | None (canvas rendered) | Same |

### References

- Webamp Vis Component: `webamp_clone/packages/webamp/js/components/Vis.tsx`
- Webamp VisPainter: `webamp_clone/packages/webamp/js/components/VisPainter.ts`
- Webamp Playlist: `webamp_clone/packages/webamp/js/components/PlaylistWindow/index.tsx`
- Webamp Docs: `webamp_clone/packages/webamp-docs/docs/05_features/04_playlist.md`
- MacAmp Visualizer: `MacAmpApp/Views/VisualizerView.swift`
- MacAmp Audio: `MacAmpApp/Audio/AudioPlayer.swift` (lines 1071-1204, 1372-1438)
- Winamp Forums: [Config drawer](https://forums.winamp.com/forum/winamp/winamp-technical-support/180839-config-drawer)
- Winamp Help: [WinampHeritage.com](https://winampheritage.com/help)
