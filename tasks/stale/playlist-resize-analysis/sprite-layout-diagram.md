# Playlist Window Sprite Layout Diagram

## PLEDIT.bmp Sprite Atlas Coordinates

```
     0                                                       280
     ┌───────────────────────────────────────────────────────┐
  0  │ ┌──────┬────────────────┬──────┐  ┌──────┐  ┌──────┐ │  Selected state (top bar)
     │ │ L 25 │   TITLE 100    │ R 25 │  │BTILE │  │ VIS  │ │
 20  │ ├──────┼────────────────┼──────┤  │ 25×  │  │ 75×  │ │
     │ │ L 25 │   TITLE 100    │ R 25 │  │  38  │  │  38  │ │  Unselected state (top bar)
 40  │ └──────┴────────────────┴──────┘  └──────┘  └──────┘ │
     │                                                        │
 42  │ ┌──┬───┐  ┌──────┬──────┬──────┐                     │  Middle tiles
     │ │L │ R │  │CLOSE │SHADE │EXPND │                     │
     │ │12│20 │  │ 9×9  │ 9×9  │ 9×9  │                     │
 53  │ │× │ × │  └──────┴──────┴──────┘                     │  (PLAYLIST_LEFT_TILE)
     │ │29│29 │  ┌──────┬──────┐                            │  (PLAYLIST_RIGHT_TILE)
 71  │ └──┴───┘  │SCRL H│SCRL H│                            │
     │           │ 8×18 │ 8×18 │                            │
 72  │ ┌───────────────────────────────────────────┐        │  Bottom corners
     │ │                                           │        │
     │ │     PLAYLIST_BOTTOM_LEFT_CORNER           │┌──────┐│
     │ │              125×38                       ││BTMRT ││  PLAYLIST_BOTTOM_RIGHT
 110 │ └───────────────────────────────────────────┘│150×38││  _CORNER
     │                                              └──────┘│
 111 │ ┌──┬──┬──┬──┬──┬──┬──┬──┬──┬──┬──┬──┬──┬──┬──┬──┬──│  Menu sprites
     │ │  │  │  │  │  │  │  │  │  │  │  │  │  │  │  │  │  │  (Add, Remove, Select,
     │ │  ADD MENU  │  REMOVE MENU  │  SELECT MENU │  MISC│  Misc, List buttons)
 165 │ └──┴──┴──┴──┴──┴──┴──┴──┴──┴──┴──┴──┴──┴──┴──┴──┴──│
     │                                                        │
     │                                                        │
     └────────────────────────────────────────────────────────┘
```

## Window Layout at Different Sizes

### Minimum Size: [0,0] segments = 275×116 pixels

```
┌────────────────────────────────────────────────────────┐ 20px
│ ┌──┬────────────────┬──┐  PLAYLIST TOP BAR           │
│ │L │    TITLE       │R │  (275px total width)        │
└─┴──┴────────────────┴──┴──────────────────────────────┘
│ ├┬──────────────────────┬┐                             │
│ ││ Track 1              ││  Content Area               │
│ ││ Track 2              ││  (58px tall = 4 tracks)     │ 58px
│ ││ Track 3              ││                             │
│ ││ Track 4              ││                             │
│ ├┴──────────────────────┴┤                             │
└─┴────────────────────────┴──────────────────────────────┘
│ ┌───────────────────────────────────────────────────┐  │
│ │  LEFT 125px          │  RIGHT 150px               │  │ 38px
│ │  [Menus]             │  [Actions] [Resize]        │  │
│ └───────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────┘
  275px total width

  Note: CENTER section width = 0px (collapsed, invisible)
```

### Width +1 segment: [1,0] = 300×116 pixels

```
┌─────────────────────────────────────────────────────────────┐
│ PLAYLIST TOP BAR (300px)                                    │
└─────────────────────────────────────────────────────────────┘
│                                                               │
│ Content Area (still 58px tall = 4 tracks)                    │
│                                                               │
└─────────────────────────────────────────────────────────────┘
│ ┌───────────────┬───┬──────────────────┐                    │
│ │  LEFT 125px   │ C │  RIGHT 150px     │                    │
│ │  [Menus]      │ E │  [Actions]       │                    │
│ └───────────────┴─N─┴──────────────────┘                    │
└─────────────────────────────────────────────────────────────┘
  300px total                25px

  CENTER section: 300 - 275 = 25px (exactly 1 tile)
  PLAYLIST_BOTTOM_TILE (25×38) shown once
```

### Width +2 segments: [2,0] = 325×116 pixels

```
┌──────────────────────────────────────────────────────────────────┐
│ ┌──┬─┬──────────┬──────────┬─┬──┐  PLAYLIST TOP BAR            │
│ │L │S│  FILL    │  TITLE   │S│R │  Spacers shown (even width)  │
└─┴──┴─┴──────────┴──────────┴─┴──┴──────────────────────────────┘
  325px total
  Spacers: 12px + 13px = 25px added

│                                                                  │
│ Content Area (still 58px tall = 4 tracks)                       │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
│ ┌───────────────┬────────┬────────┬──────────────────┐          │
│ │  LEFT 125px   │  TILE  │  TILE  │  RIGHT 150px     │          │
│ │  [Menus]      │  25px  │  25px  │ ┌──────┐[Actions]│          │
│ └───────────────┴────────┴────────┴─│ VIS  │─────────┘          │
└──────────────────────────────────────│75×38 │──────────────────── ┘
                                       └──────┘
  CENTER: 50px (2 tiles)
  VISUALIZER: NOW VISIBLE (width > 2)
```

### Height +2 segments: [2,2] = 325×174 pixels

```
Same width layout as above (325px)

┌──────────────────────────────────────────────────────────────────┐
│ TOP BAR (325px with spacers)                                     │
└──────────────────────────────────────────────────────────────────┘
│ ├┬────────────────────────────────────────────────────────────┬┐ │
│ ││ Track 1                                                    ││ │
│ ││ Track 2                                                    ││ │
│ ││ Track 3                                                    ││ │
│ ││ Track 4                                                    ││ │
│ ││ Track 5                                                    ││ │ 116px
│ ││ Track 6                                                    ││ │ (58 + 29*2)
│ ││ Track 7                                                    ││ │
│ ││ Track 8                                                    ││ │
│ ││ Track 9                                                    ││ │
│ ├┴────────────────────────────────────────────────────────────┴┤ │
└──┴────────────────────────────────────────────────────────────┴──┘
│ ┌──────────────────────────────────────────────────────────────┐ │
│ │ BOTTOM BAR (same 38px height, same layout)                   │ │
│ └──────────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────────┘

  Visible tracks: floor((58 + 58) / 13) = floor(116/13) = 8 tracks
```

## Three-Section Bottom Layout Breakdown

```
Total Width: W pixels
────────────────────────────────────────────────────────────
│                                                          │
│ ┌──────────────┬──────────────────────┬───────────────┐ │
│ │              │                      │               │ │
│ │   LEFT       │      CENTER          │     RIGHT     │ │
│ │   125px      │   (W - 275)px        │    150px      │ │
│ │   FIXED      │   DYNAMIC TILES      │    FIXED      │ │
│ │              │                      │               │ │
│ │  [4 Menus]   │  ┌────┬────┬────┐   │ ┌────┐[Btns] │ │
│ │              │  │TILE│TILE│TILE│   │ │VIS │       │ │
│ │              │  │25px│25px│25px│   │ │75px│       │ │
│ │              │  └────┴────┴────┘   │ └────┘       │ │
│ │              │  (repeats N times)   │             │ │
│ └──────────────┴──────────────────────┴───────────────┘ │
│                                                          │
────────────────────────────────────────────────────────────
                   38px total height
```

**Key Points:**
1. LEFT and RIGHT are **fixed width sprites** from PLEDIT.bmp
2. CENTER is **empty div** that tiles PLAYLIST_BOTTOM_TILE via CSS `background-repeat`
3. CENTER width = `(totalWidth - 275)px` → can be **0** at minimum size
4. Each tile is exactly **25px wide** (matches WINDOW_RESIZE_SEGMENT_WIDTH)

## Sprite State Diagram

```
TOP BAR STATES:
───────────────

Window Selected (focused):
  Use: PLAYLIST_TOP_*_SELECTED sprites (y: 0-20)

Window Unselected (unfocused):
  Use: PLAYLIST_TOP_* sprites (y: 21-41)


SPACER VISIBILITY:
──────────────────

playlistSize.width % 2 == 0  →  SHOW spacers (12px + 13px)
playlistSize.width % 2 == 1  →  HIDE spacers


VISUALIZER VISIBILITY:
──────────────────────

playlistSize.width > 2  →  SHOW visualizer (75×38px area)
playlistSize.width ≤ 2  →  HIDE visualizer


CENTER TILE BEHAVIOR:
─────────────────────

Width:      0 segs   1 seg    2 segs   3 segs   4 segs
Pixels:     275px    300px    325px    350px    375px
Center:     0px      25px     50px     75px     100px
Tiles:      0        1        2        3        4
```

## Resize Handle Position

```
Bottom-right corner of playlist window:

┌─────────────────────────────────────────────┐
│                                             │
│                                             │
│                                             │
│                                             │
│                                             │
│                                    ┌────────┤
│                                    │ RESIZE │
│                                    │ HANDLE │
│                                    │ 20×20  │
└────────────────────────────────────┴────────┘
                                       ↑
                                  position: absolute
                                  right: 0
                                  bottom: 0
```

**Drag behavior:**
- Captures mouse at start position
- Calculates delta (x, y)
- Quantizes: `round(delta / segmentSize)`
- Updates size in segments: `[w + Δw, h + Δh]`
- Minimum enforced: `max(0, newValue)`

## Implementation Formula Reference

```swift
// Size conversion
let segmentWidth = 25
let segmentHeight = 29
let baseWidth = 275
let baseHeight = 116

pixelWidth = baseWidth + (segments.width * segmentWidth)
pixelHeight = baseHeight + (segments.height * segmentHeight)

// Track count
let baseContentHeight = 58
let trackHeight = 13

visibleTracks = floor((baseContentHeight + segments.height * segmentHeight) / trackHeight)

// Center section width
centerWidth = pixelWidth - 275  // Can be 0
tileCount = centerWidth / 25

// Spacer visibility
showSpacers = segments.width % 2 == 0

// Visualizer visibility
showVisualizer = segments.width > 2
```

---

**Diagram Legend:**
- `L` = Left corner/section
- `R` = Right corner/section
- `C` = Center section
- `S` = Spacer tile
- `VIS` = Visualizer area
- `TILE` = PLAYLIST_BOTTOM_TILE (25×38px)
- `FILL` = Flex-grow area (top bar)
