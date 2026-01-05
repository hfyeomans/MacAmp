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
- [~] Test with 3+ different skins (DEFERRED - base skin priority)
- [~] Test skin hot-swap while window open (DEFERRED - future enhancement)
- [~] Verify graceful fallback if sprites missing (DEFERRED - future enhancement)

---

## Phase 5: Review & Merge

- [x] Research gap limitation (SwiftUI vs CSS flexbox)
- [x] Document findings in research.md
- [x] Create feature branch (feature/milkdrop-titlebar-letters)
- [x] Commit changes (fe12e6d - MILKDROP HD with H and V sprites)
- [~] Run Oracle code review (SKIPPED - user will review on GitHub)
- [x] Create PR
- [ ] Merge after approval

---

## Blockers

None currently.

---

## Notes

- Final text: "MILKDROP HD" (10 letters + space + gap)
- Letters: M, I, L, K, D, R, O, P, H, D (H and V sprites added)
- Each letter = 2 sprites (TOP + BOTTOM)
- Total sprites: 40 (10 letters × 2 pieces × 2 states)
- Letter widths: M=8, I=4, L=5, K=7, D=6, R=7, O=6, P=6, space=5, H=6, gap=1, D=6
- Total text width: 67px (vs original MILKDROP at 49px)
- Gap each side: 4px (vs original 13px)
- Centered in 75px center section at x:137.5, y:8
