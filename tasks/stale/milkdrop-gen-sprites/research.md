# Research: Milkdrop GEN.bmp Sprite Alignment

## Inputs Consulted
- `webamp_clone/packages/webamp/js/skinSprites.ts` – Winamp/Webamp sprite definitions for GEN.bmp.
- `webamp_clone/packages/webamp/js/skinParserUtils.ts` – sprite extraction helper, establishes coordinate expectations.
- `MacAmpApp/Models/SkinSprites.swift` – current MacAmp sprite rects mirrored from Webamp.
- `tasks/milk-drop-video-support/coordinate-fix.md` – prior VIDEO.bmp coordinate flip analysis.
- `tmp/Winamp/GEN.BMP` dimensions confirmed via `sips`.

## Findings
1. **Webamp coordinate origin (top-down):**
   - `getSpriteUrisFromImg()` (skinParserUtils.ts lines ~44-75) renders onto a canvas with `context.drawImage(img, -sprite.x, -sprite.y)`. HTML canvas origin is the *top-left* corner with +Y pointing downward, so supplying the documented Winamp coordinates extracts using a **top-down** system. No flipping is performed anywhere in Webamp.

2. **GEN.bmp dimension confirmation:**
   - `sips -g pixelWidth -g pixelHeight tmp/Winamp/GEN.BMP` reports 194×109 px, matching Winamp docs. All `x + width` and `y + height` in `skinSprites.ts` stay within this extent (max x+width = 178, max y+height = 86), so Webamp only uses the upper-left 180×86 region of the sheet but still assumes the full 194×109 canvas.

3. **Sprite layout implied by Webamp rectangles:**
   - Rows follow Winamp docs exactly:
     - Row 1 (active title bar pieces): `y=0`, `height=20` for six slices.
     - Row 2 (inactive title bar): `y=21`, `height=20` (1px gap between rows).
     - Row 3 (mid rails/buttons): y values 42–71 covering middle rails (29 px tall) and button clusters (14–29 px tall).
     - Row 4 (bottom fill): `y=72`, `height=14` for bottom filler strip.

4. **MacAmp currently using top-down coordinates verbatim:**
   - `SkinSprites.swift` lines 213-232 paste the same `(x,y,width,height)` tuples as skinSprites.ts with no `flipY`, so CGImage (bottom-up) crops the wrong region—exact scenario described in `coordinate-fix.md` for VIDEO.bmp.

5. **Required conversion logic already documented:**
   - `coordinate-fix.md` states `flippedY = imageHeight - spriteHeight - documentedY`. For GEN.bmp height = 109. Applying that formula to every sprite will align MacAmp with CGImage’s bottom-up origin.

## Open Questions
- None; sprite dimensions and layout fully determined from existing assets.
