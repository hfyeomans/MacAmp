# Research: Milkdrop Titlebar Layout

## Source Files Examined
- `MacAmpApp/Views/Windows/MilkdropWindowChromeView.swift`
- `MacAmpApp/Views/Windows/VideoWindowChromeView.swift`
- `MacAmpApp/Models/SkinSprites.swift` (for sprite references)

## Key Observations
1. **Current Milkdrop layout**
   - Titlebar width hard-coded to 275px; titlebar height 20px.
   - Sections implemented via `SimpleSpriteImage` with `.position` anchored to centers.
   - Section counts: left cap, left end (fixed 25px each), center fill (4 tiles, 25px each), right end (25px), stretch fill (2 tiles, 25px each), right cap (25px).
   - Center + stretch width = 150px, but required width is 175px, producing a 25px gap before the right cap.
   - Section 4 & 5 positions assume only 4 center tiles and start too early when more tiles are added.

2. **Video window reference**
   - Similar drag handle layout; uses sequential `.position` placements to tile across full width.
   - Demonstrates pattern for computing center positions: start-of-section + half tile width + index * width.

3. **Sprite constraints**
   - Each GEN titlebar piece is 25px wide and 20px tall (per user spec + `SkinSprites`).
   - GEN titlebar uses six sections (caps, fixed ends, center fill, stretch fill).

## Requirements Implied by Research
- Need 275px total coverage: `4 fixed segments * 25px = 100px`, leaving `175px` for center + stretch tiles ⇒ `7 tiles total`.
- Center fill should expand to accommodate "MILKDROP" text area (prefers odd number for symmetry).
- Stretch segment should cover remainder and align with right cap.
- `.position(x:, y:)` uses centers, so x-offsets must reflect new coverage lengths.

