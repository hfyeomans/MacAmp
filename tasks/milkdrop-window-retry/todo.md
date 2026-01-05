# Milkdrop Window Retry - Task List

**Task ID:** milkdrop-window-retry
**Created:** 2026-01-04

---

## Phase 1: Coordinate Verification

- [x] Extract GEN.bmp from base Winamp skin
- [x] Get GEN.bmp dimensions (expected: 194×109) ✅ Confirmed
- [x] Use ImageMagick to extract M letter at documented coords
- [x] Verify TOP piece (8×6 at x:86, y:88) ✅ Correct
- [x] Verify BOTTOM piece (8×2 at x:86, y:95) ✅ Correct
- [x] Compare extracted sprites with SkinSprites.swift definitions ✅ Match
- [x] Document any coordinate corrections needed (none required)

---

## Phase 2: Implementation

- [x] Read current MilkdropWindowChromeView.swift
- [x] Add `makeLetter(_ letter:width:)` helper method (uses isWindowActive property)
- [x] Add `milkdropLetters` computed property with HStack
- [x] Position letters in center titlebar section (x: 137.5, y: 10)
- [x] Wire `isWindowActive` to letter rendering (via prefix selection)

---

## Phase 3: Coordinate Fix (If Needed)

- [x] Apply Y-flip formula if verification fails → NOT NEEDED
- [x] Coordinates already correct in SkinSprites.swift
- [x] GEN.bmp uses top-down coords that work correctly

---

## Phase 4: Testing

- [x] Build with Thread Sanitizer enabled (BUILD SUCCEEDED)
- [x] Verify letters render in titlebar (DONE - centered at x:137.5, y:8)
- [x] Test active state (click Milkdrop window) - User confirmed working
- [x] Test inactive state (click another window) - Sprite switching works
- [ ] Test with 3+ different skins (deferred)
- [ ] Test skin hot-swap while window open (deferred)
- [ ] Verify graceful fallback if sprites missing (deferred)

---

## Phase 5: Review & Merge

- [x] Research gap limitation (SwiftUI vs CSS flexbox)
- [x] Document findings in research.md
- [x] Create feature branch (feature/milkdrop-titlebar-letters)
- [ ] Run Oracle code review
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
