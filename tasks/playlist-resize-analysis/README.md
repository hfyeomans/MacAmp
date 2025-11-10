# Playlist Resize Analysis

**Status:** Complete
**Date:** 2025-11-09
**Analyzed:** Webamp playlist window resize implementation
**Target:** MacAmp SwiftUI implementation

---

## Document Index

### 1. SUMMARY.md
**Start here first**
Executive summary of findings, all questions answered, implementation roadmap.

**Key Info:**
- All measurements extracted
- Questions answered with source references
- 4-phase implementation plan
- File list (10 files analyzed)

---

### 2. QUICK_REFERENCE.md
**Print this for your desk**
One-page cheat sheet with constants, formulas, sprite coordinates, and test cases.

**Use When:**
- Writing code (copy-paste constants)
- Debugging layout issues
- Verifying sprite coordinates
- Testing size calculations

---

### 3. research.md
**Deep technical specification**
Complete 13-section technical document (500+ lines) with every detail extracted from Webamp source.

**Sections:**
1. Resize Constants
2. Resize Constraints
3. Resize Handle Implementation
4. Bottom Bar Layout (Three Sections)
5. Top Bar Layout (Spacers)
6. Sprite Atlas (PLEDIT.bmp)
7. Visualizer Behavior
8. Window Relationships (Graph System)
9. SwiftUI Requirements
10. Key Findings Summary
11. Implementation Checklist
12. Critical Notes
13. Open Questions

**Use When:**
- Understanding WHY decisions were made
- Researching edge cases
- Planning architecture
- Answering "how does X work?"

---

### 4. sprite-layout-diagram.md
**Visual reference**
ASCII art diagrams showing sprite layouts, window states, and layout breakdowns.

**Contains:**
- PLEDIT.bmp atlas map
- Window layouts at [0,0], [1,0], [2,0], [2,2]
- Three-section bottom bar breakdown
- Sprite state diagrams (selected/unselected)
- Resize handle positioning
- Formula reference diagrams

**Use When:**
- Visualizing layout structure
- Understanding sprite placement
- Planning SwiftUI view hierarchy
- Debugging alignment issues

---

### 5. swiftui-implementation-guide.md
**Production-ready code**
Complete SwiftUI implementation patterns (600+ lines) ready to copy into MacAmp.

**Sections:**
1. Data Models (`Size2D`, `PlaylistWindowState`)
2. Resize Gesture (quantized drag)
3. Bottom Bar Layout (three-section)
4. Top Bar Layout (spacers)
5. Complete Window Assembly
6. Sprite Loading Utility
7. Window Graph System (magnetic)
8. Size Constraints & Validation
9. Testing Utilities
10. Usage Examples

**Use When:**
- Writing SwiftUI views
- Implementing resize gesture
- Building layout components
- Testing implementation

---

## Quick Start Guide

### For Developers (First Time)

1. **Read:** `SUMMARY.md` (5 minutes)
2. **Reference:** `QUICK_REFERENCE.md` (bookmark it)
3. **Skim:** `sprite-layout-diagram.md` (understand visuals)
4. **Code:** `swiftui-implementation-guide.md` (copy patterns)
5. **Deep Dive:** `research.md` (when stuck)

### For Code Review

1. Check constants match `QUICK_REFERENCE.md`
2. Verify formulas against test cases
3. Validate sprite coordinates from `research.md`
4. Test at all sizes in quick reference

### For Bug Fixing

1. Check formula in `QUICK_REFERENCE.md`
2. Verify expected behavior in `research.md`
3. Compare layout to `sprite-layout-diagram.md`
4. Review implementation pattern in `swiftui-implementation-guide.md`

---

## Key Findings at a Glance

### Resize Behavior
- **Quantized:** 25×29 pixel segments (not continuous)
- **No maximum:** Unbounded (user's screen is limit)
- **Minimum:** [0,0] = 275×116 pixels
- **Both axes:** Width AND height resize together

### Center Section (Bottom Bar)
- **Width:** `totalWidth - 275` pixels (can be 0)
- **Sprite:** PLAYLIST_BOTTOM_TILE (25×38px)
- **Behavior:** Always exists, tiles horizontally
- **NOT conditional:** Never hidden, just 0 width at minimum

### Spacers (Top Bar)
- **Shown when:** Width is EVEN ([0,0], [2,0], [4,0]...)
- **Hidden when:** Width is ODD ([1,0], [3,0], [5,0]...)
- **Width:** 12px left + 13px right = 25px total

### Visualizer
- **Threshold:** Width > 2 segments (NOT >=)
- **Visible at:** 350px+ total width ([3,0] and up)
- **Dimensions:** 75×38 pixels
- **Position:** Inside bottom-right section

---

## Files Analyzed (Source Material)

```
webamp_clone/packages/webamp/
├── js/
│   ├── components/
│   │   ├── PlaylistWindow/
│   │   │   ├── index.tsx                    # Main structure
│   │   │   └── PlaylistResizeTarget.tsx     # Wrapper
│   │   └── ResizeTarget.tsx                 # Drag gesture
│   ├── actionCreators/
│   │   └── windows.ts                       # Graph system
│   ├── reducers/
│   │   └── windows.ts                       # State management
│   ├── constants.ts                         # Size constants
│   ├── selectors.ts                         # Calculations
│   ├── resizeUtils.ts                       # Position diff
│   └── skinSprites.ts                       # Sprite coords
└── css/
    └── playlist-window.css                  # Layout/positioning
```

---

## Terminology

| Term | Definition |
|------|------------|
| **Segment** | Resize unit (25×29 pixels) |
| **Size** | Array [width, height] in segments |
| **Pixel Size** | Actual window dimensions in pixels |
| **Center Section** | Dynamic middle part of bottom bar |
| **Spacers** | 12px + 13px tiles shown on even widths |
| **Quantization** | Snapping to discrete segment increments |
| **Graph** | Spatial relationship between windows |

---

## Implementation Status

- [x] Research complete
- [x] Specifications documented
- [x] SwiftUI patterns provided
- [ ] Code implementation (next phase)
- [ ] Testing
- [ ] Integration

---

## Questions? Issues?

All questions from the original request have been answered:

1. **Resize handle location:** Bottom-right, 20×20px
2. **Sprite used:** Cursor region (PSIZE selector)
3. **Min/max constraints:** Min [0,0], Max unlimited
4. **Center sprite behavior:** PLAYLIST_BOTTOM_TILE, always present
5. **Three-section layout:** 125px + dynamic + 150px
6. **Resize behavior:** Both axes, quantized 25×29

If you encounter new questions during implementation:
1. Check `QUICK_REFERENCE.md` formulas
2. Search `research.md` for keywords
3. Review `swiftui-implementation-guide.md` code
4. Examine `sprite-layout-diagram.md` visuals

---

**Ready for implementation.** All technical details extracted and documented.
