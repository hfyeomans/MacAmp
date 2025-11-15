# Plan: Milkdrop GEN.bmp Sprite Review

1. **Summarize coordinate assumptions**
   - Use research findings to explain that Webamp sticks to top-down Winamp coordinates while CGImage expects bottom-up.

2. **Map GEN.bmp layout**
   - Describe sprite grouping (title bars active/inactive, middle rails, buttons, bottom fills) and relate them to y-ranges within the 194×109 canvas.

3. **Compute flipped coordinates**
   - Apply `flippedY = 109 - height - y` to each sprite to derive the correct rectangles for MacAmp’s CGImage usage. Record both original and flipped values for comparison.

4. **Deliverables**
   - Provide answers for the five explicit questions in the user request.
   - Supply corrected `SkinSprites.swift` entries (full list) and textual layout diagram.
   - Document recommended conversion approach (reuse VIDEO.bmp `flipY`).
