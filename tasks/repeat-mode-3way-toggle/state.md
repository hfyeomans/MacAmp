# State - Three-State Repeat Mode Implementation

**Task:** repeat-mode-3way-toggle
**Status:** Planning Complete, Ready for Implementation
**Branch:** `repeat-mode-toggle` (to be created)
**Last Updated:** 2025-11-07

---

## Current Status: Pre-Implementation

### Completed ✅

1. **Research Phase** (2025-11-07)
   - Analyzed Webamp implementation (boolean only)
   - Researched Winamp 5 history (3-state with "1" badge)
   - Evaluated visual indicator options (A, B1, B2, B3, B4)
   - Cross-skin compatibility analysis (7 bundled skins)
   - Selected Option B1: White "1" + shadow overlay

2. **Documentation**
   - Created comprehensive research.md
   - Created winamp-repeat-mode-history.md
   - Created repeat-mode-overlay-analysis.md
   - Created implementation plan.md
   - Task folder structure organized

3. **Validation**
   - Pending: Oracle (Codex) review of approach

### In Progress 🔄

- None (pre-implementation)

### Pending ⏳

1. **Oracle Validation**
   - Review RepeatMode enum design
   - Validate badge overlay approach
   - Confirm playlist navigation logic
   - Verify cross-skin compatibility strategy

2. **Implementation**
   - Phase 1: Data model (RepeatMode enum)
   - Phase 2: Playlist navigation logic
   - Phase 3: UI button + badge
   - Phase 4: Keyboard shortcut
   - Phase 5: Options menu integration

3. **Testing**
   - Visual testing (7 skins)
   - Behavior testing (playlist boundaries)
   - Edge case testing
   - Persistence testing

4. **Documentation**
   - Update README.md
   - Update CHANGELOG
   - Add usage guide

---

## Technical Decisions Made

### 1. State Model: RepeatMode Enum ✅
**Decision:** Use 3-state enum instead of dual boolean flags
**Rationale:**
- Simpler mental model than Winamp's Repeat + MPA
- Type-safe state transitions
- Clear intent (off/all/one)
- Easier to extend (repeat-count, A-B repeat)

**Alternative Rejected:** Dual flags (repeat: Bool, manualAdvance: Bool)
- Too confusing (4 combinations, only 3 meaningful)
- Winamp legacy baggage

### 2. Visual Indicator: White "1" Badge + Shadow ✅
**Decision:** Option B1 from analysis
**Rationale:**
- Matches Winamp 5 Modern skins (user familiarity)
- Shadow ensures legibility on any background
- Simple implementation (1 line: `.shadow()`)
- Works on all 7 bundled skins (research validated)

**Alternatives Rejected:**
- Option A (tooltip only): No visual distinction
- Option B2 (badge circle): Too modern/prominent
- Option B3 (outlined text): Overcomplicated
- Option B4 (per-skin colors): Maintenance burden

### 3. Button Interaction: Cycle Through States ✅
**Decision:** Single button cycles Off → All → One → Off
**Rationale:**
- Consistent with Winamp 5 Modern skins
- Minimal UI changes
- Keyboard shortcut (Ctrl+R) also cycles
- Options menu provides direct access

**Alternative Rejected:** Separate buttons for each mode
- Takes more screen space
- Breaks classic layout

### 4. Keyboard Shortcut: Ctrl+R Cycles ✅
**Decision:** Single shortcut cycles modes
**Rationale:**
- Existing Ctrl+R pattern (if present)
- Quick cycling for power users
- Simple to remember

**Alternative Rejected:** Separate shortcuts (Ctrl+R, Ctrl+Shift+R, etc.)
- Too many shortcuts to remember

---

## Implementation Approach

### Data Flow
```
User Click/Shortcut
    ↓
settings.repeatMode = repeatMode.next()
    ↓
UserDefaults.standard.set(repeatMode.rawValue, forKey: "repeatMode")
    ↓
SwiftUI updates button sprite + badge visibility
    ↓
Playlist navigation uses new mode logic
```

### File Changes Summary
- `AppSettings.swift`: +35 lines (enum, persistence)
- `PlaylistManager.swift`: ~20 lines modified (navigation logic)
- `WinampMainWindow.swift`: +15 lines (badge overlay)
- `AppCommands.swift`: ~5 lines modified (keyboard shortcut)
- Options menu: +15 lines (if integrated)

**Total:** ~90 lines added/modified

---

## Known Constraints

### Skin Limitations
- Classic skins only have 2 button sprites (normal/selected)
- No "repeat-one" specific sprite in any skin
- **Solution:** SwiftUI overlay (doesn't require skin changes)

### Badge Positioning
- Must fit within 28×15px button bounds
- Position (x:8, y:0) is starting estimate
- **May need adjustment** after visual testing

### Edge Cases
1. **Empty Playlist:**
   - All modes return nil (no track to play)
   - Graceful degradation

2. **Single Track:**
   - Off: Stops after track
   - All: Replays track (same as One)
   - One: Replays track

3. **Shuffle + Repeat One:**
   - Repeat One takes precedence (always replay current)
   - **Alternative:** Disable shuffle in repeat-one mode
   - **Decision:** TBD during implementation

---

## Testing Strategy

### Cross-Skin Verification Matrix

| Skin | Background Color | Badge Contrast | Expected Result |
|------|-----------------|----------------|-----------------|
| Classic Winamp | Green/Gray | High | ✅ Readable |
| Internet Archive | Beige | Medium (shadow helps) | ✅ Readable |
| Tron Vaporwave | Dark Blue | High | ✅ Readable |
| Mac OS X | Light Gray | Medium (shadow helps) | ✅ Readable |
| Sony MP3 | Silver/White | Low (shadow critical) | ⚠️ Test needed |
| KenWood | Black/Red | High | ✅ Readable |
| Winamp3 Classified | Dark Blue/Silver | High | ✅ Readable |

**Worst Case:** Sony MP3 (light button + white badge)
**Mitigation:** Shadow with 0.8 opacity ensures contrast

### Behavior Test Cases

**Playlist Boundaries:**
- [ ] Off mode: Next at end → stops
- [ ] Off mode: Previous at start → stops
- [ ] All mode: Next at end → wraps to first
- [ ] All mode: Previous at start → wraps to last
- [ ] One mode: Next → replays current
- [ ] One mode: Previous → replays current

**State Cycling:**
- [ ] Button click: Off → All
- [ ] Button click: All → One
- [ ] Button click: One → Off
- [ ] Ctrl+R: Same cycling behavior
- [ ] Options menu: Direct mode selection

**Persistence:**
- [ ] Mode saved to UserDefaults
- [ ] Mode restored on app launch
- [ ] Migration from boolean (defaults to .off)

---

## Risks & Contingencies

### Risk 1: Badge Clipping on Some Skins
**Probability:** Low-Medium
**Impact:** Low (visual only)
**Mitigation:**
- Test all 7 skins before merge
- Adjust offset x/y as needed
- Reduce font size to 7px if needed

### Risk 2: Shadow Insufficient on Light Skins
**Probability:** Low
**Impact:** Medium (badge unreadable)
**Mitigation:**
- Increase shadow opacity to 1.0
- Increase shadow radius to 1.5
- **Fallback:** Option B2 (badge circle)

### Risk 3: Performance Impact of ZStack
**Probability:** Very Low
**Impact:** Low
**Mitigation:**
- ZStack only rendered when repeatMode == .one
- Minimal overhead (1 Text view)
- Profile if concerns arise

---

## Success Metrics

**Functional:**
- ✅ All three modes work correctly
- ✅ Playlist navigation respects mode
- ✅ Mode persists across restarts

**Visual:**
- ✅ Badge visible in repeat-one mode
- ✅ Badge legible on all 7 skins
- ✅ Button states match Winamp 5 behavior

**UX:**
- ✅ Intuitive mode cycling
- ✅ Tooltip shows current mode
- ✅ Keyboard shortcut works

**Code Quality:**
- ✅ Type-safe enum (no boolean flags)
- ✅ Clean state transitions
- ✅ No crashes on edge cases
- ✅ Oracle-reviewed (pending)

---

## Next Steps

1. **Validate with Oracle** (15-20 min)
   - Review RepeatMode enum design
   - Confirm badge overlay strategy
   - Verify playlist navigation logic

2. **Create Feature Branch** (2 min)
   ```bash
   git checkout -b repeat-mode-toggle
   ```

3. **Begin Implementation** (1.5-2 hours)
   - Follow plan.md phases 1-5
   - Commit incrementally

4. **Testing** (30-45 min)
   - Visual verification across skins
   - Behavior testing
   - Edge cases

5. **Documentation & Merge** (15-30 min)
   - Update README.md
   - Create PR
   - Merge to main

---

## Timeline

**Research:** ✅ Complete (2 hours)
**Planning:** ✅ Complete (1 hour)
**Oracle Validation:** ⏳ Pending (15 min)
**Implementation:** ⏳ Not started (2 hours)
**Testing:** ⏳ Not started (45 min)
**Documentation:** ⏳ Not started (15 min)

**Total Estimated:** 6 hours (research + implementation)
**Actual So Far:** 3 hours (research + planning)
**Remaining:** 3 hours (validation + implementation + testing)

---

## Open Questions for Oracle

1. **RepeatMode Enum Design:**
   - Is `next()` method the cleanest API?
   - Should we use `CaseIterable` for menu generation?
   - Better name than `RepeatMode`?

2. **Badge Overlay Strategy:**
   - Is ZStack the right approach or should we pre-render sprites?
   - Shadow radius 1.0 sufficient or increase to 1.5?
   - Font size 8px or reduce to 7px for safety?

3. **Playlist Navigation Logic:**
   - Confirm `getNextTrackId()` implementation is correct
   - Edge case: Shuffle + Repeat One - disable shuffle?
   - Edge case: Streams (infinite duration) + Repeat One?

4. **Testing Strategy:**
   - Any missing test cases?
   - Should we add unit tests or manual testing sufficient?
   - Performance profiling needed?

---

**Status:** ✅ Ready for Oracle review and implementation
**Blocking:** None
**Dependencies:** Oracle validation (optional but recommended)
