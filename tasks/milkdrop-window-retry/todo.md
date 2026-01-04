# Milkdrop Window Retry - Task List

**Task ID:** milkdrop-window-retry
**Created:** 2026-01-04

---

## Phase 1: Coordinate Verification

- [ ] Extract GEN.bmp from base Winamp skin
- [ ] Get GEN.bmp dimensions (expected: 194×109)
- [ ] Use ImageMagick to extract M letter at documented coords
- [ ] Verify TOP piece (8×6 at x:86, y:88)
- [ ] Verify BOTTOM piece (8×2 at x:86, y:95)
- [ ] Compare extracted sprites with SkinSprites.swift definitions
- [ ] Document any coordinate corrections needed

---

## Phase 2: Implementation

- [ ] Read current MilkdropWindowChromeView.swift
- [ ] Add `makeLetter(_ letter:width:isActive:)` helper method
- [ ] Add `milkdropLetters` computed property with HStack
- [ ] Position letters in center titlebar section (x: 137.5, y: 10)
- [ ] Wire `isWindowActive` to letter rendering

---

## Phase 3: Coordinate Fix (If Needed)

- [ ] Apply Y-flip formula if verification fails
- [ ] Update SkinSprites.swift with corrected coordinates
- [ ] Re-verify with ImageMagick extraction

---

## Phase 4: Testing

- [ ] Build with Thread Sanitizer enabled
- [ ] Verify letters render in titlebar
- [ ] Test active state (click Milkdrop window)
- [ ] Test inactive state (click another window)
- [ ] Test with 3+ different skins
- [ ] Test skin hot-swap while window open
- [ ] Verify graceful fallback if sprites missing

---

## Phase 5: Review & Merge

- [ ] Run Oracle code review
- [ ] Address any review findings
- [ ] Create feature branch
- [ ] Commit changes
- [ ] Create PR
- [ ] Merge after approval

---

## Blockers

None currently.

---

## Notes

- Letters are 8 total: M, I, L, K, D, R, O, P
- Each letter = 2 sprites (TOP + BOTTOM)
- Total sprites: 32 (8 letters × 2 pieces × 2 states)
- Letter widths: M=8, I=5, L=6, K=7, D=7, R=7, O=7, P=7
- Total text width: 54px
- Centered in 75px center section
