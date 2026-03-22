# Magnetic Window Docking - Executive Summary

**Date:** 2025-11-02
**Decision:** CONDITIONAL GO (High Risk, High Value)
**Time Estimate:** 18-24 hours (worst case, with contingency)
**Success Probability:** 70%

---

## Critical Findings

### 1. Documentation Bug Found ⚠️
**Snap distance is 15px, not 10px**
- Source: `SnapUtils.swift:27` = `static let SNAP_DISTANCE: CGFloat = 15`
- Oracle caught this, others missed it
- Multiple docs need correction

### 2. Most Accurate Review: Oracle (Codex) ✅
- Feasibility: 7/10 (correct)
- Risk: 8/10 High (correct)
- Caught concrete bugs (15px)
- Identified architectural showstoppers
- Most conservative but most accurate

### 3. Gemini Underestimated Risk
- Feasibility: 9/10 (too optimistic)
- Risk: 6/10 Medium (too low)
- Focused on features over architecture
- Valuable feature gap identification
- Missed lifecycle complexity

---

## Key Decisions

### Architecture: NSWindowController (Not WindowGroup) ✅
**Rationale:**
- Guarantees singleton windows
- Full lifecycle control
- Easier menu synchronization
- Lower risk

**Oracle's Warning:**
> "Raw WindowGroups risk duplicate instances and flaky close/restore behaviour."

**Decision: Use NSWindowController with WindowCoordinator singleton**

---

### Priority: Drag Regions Immediately ✅
**Oracle's Insight:**
> "Perform drag-region work immediately after splitting windows; otherwise users lose the ability to move borderless windows."

**Critical:**
- Borderless windows can't be dragged without custom regions
- Must implement in Phase 1B (before snap detection)
- Adds 2-3 hours to timeline

**Decision: Phase 1B dedicated to drag regions**

---

### Integration: Merge Snap Detection + Group Movement ✅
**Oracle's Insight:**
> "Merge 'snap detection' and 'group movement' into a single integration phase using the existing manager."

**Rationale:**
- WindowSnapManager already does both
- Separating is artificial
- Saves development time

**Decision: Single Phase 2 for WindowSnapManager integration**

---

## Top 3 Showstoppers

### 1. Window Lifecycle Architecture
- **Issue:** WindowGroup doesn't guarantee singletons
- **Impact:** Duplicate windows, lost state
- **Solution:** Use NSWindowController + WindowCoordinator
- **Time:** 0h (architectural decision)

### 2. Drag Region Implementation
- **Issue:** Borderless windows can't be moved
- **Impact:** Feature completely unusable
- **Solution:** Custom titlebar areas with NSEvent tracking
- **Time:** 2-3h

### 3. Delegate Conflict Resolution
- **Issue:** WindowSnapManager takes over window.delegate
- **Impact:** Can't add custom behaviors
- **Solution:** Delegate multiplexer pattern
- **Time:** 1-2h

---

## Final Scores

| Metric | Score | Notes |
|--------|-------|-------|
| Feasibility | 7/10 | Achievable but complex |
| Risk | 8/10 High | Architectural concerns |
| Time | 18-24h | Worst case with contingency |
| Confidence | 70% | Conditional success |

---

## Revised Phase Plan

| Phase | Description | Time | Priority |
|-------|-------------|------|----------|
| 1A | Separate Windows (NSWindowController) | 2-3h | Critical |
| 1B | Drag Regions | 2-3h | **CRITICAL** |
| 2 | WindowSnapManager Integration | 3-4h | Critical |
| 3 | Delegate Multiplexer | 1-2h | High |
| 4 | Double-Size Coordination | 2-3h | High |
| 5 | Playlist Resize | 1-2h | Medium |
| 6 | Z-Order Management | 1h | Medium |
| 7 | Snap Threshold Scaling | 0.5h | Low |
| 8 | State Persistence | 1-2h | Low |
| 9 | Testing & Polish | 1-2h | Critical |
| **TOTAL** | | **14-20h** | |
| **Contingency** | +20% | **+3-4h** | |
| **WORST CASE** | | **18-24h** | |

---

## Comprehensive Issues List

### CRITICAL (Blockers)
1. ⚠️ Documentation bug: 15px (not 10px)
2. ⚠️ Drag regions missing from plan
3. ⚠️ Window lifecycle architecture (WindowGroup vs NSWindowController)

### HIGH (Major Risks)
4. ⚠️ Delegate conflicts (WindowSnapManager is delegate)
5. ⚠️ Double-size alignment bugs (3 windows must scale together)
6. ⚠️ Coordinate system complexity (bottom-left vs top-left)

### MEDIUM (Feature Gaps)
7. ⚠️ Playlist resize handling (Gemini)
8. ⚠️ Z-order management (Gemini)
9. ⚠️ Snap threshold scaling for double-size (Gemini)

### LOW (Polish)
10. ⚠️ Persistence off-screen detection (Oracle)
11. ⚠️ Mission Control behavior (Gemini)
12. ⚠️ Accessibility (VoiceOver) (Gemini)

---

## Implementation Checklist

### Before Starting:
- [ ] Fix snap distance documentation (15px everywhere)
- [ ] Update plan.md with revised phases
- [ ] Update todo.md with drag regions + multiplexer
- [ ] Get team approval on NSWindowController approach
- [ ] Review Oracle's recommendations again

### Phase Gates:
- [ ] Phase 1A complete → Windows created
- [ ] Phase 1B complete → Windows draggable (BLOCKER for Phase 2)
- [ ] Phase 2 complete → Snap detection works
- [ ] Phase 3 complete → Delegate multiplexer ready

### Abort Conditions:
- Phase 1B takes > 4 hours → Fundamental problem
- Phase 2 snap detection doesn't work → Incompatibility
- Phase 4 causes visual artifacts → Architectural issue
- Timeline exceeds 24 hours → Cut scope (defer polish features)

---

## Minimum Viable Implementation

**If timeline slips, ship:**
- Phase 1A: Separate windows ✅
- Phase 1B: Drag regions ✅
- Phase 2: Snap detection ✅

**Total: 7-10 hours for core functionality**

**Defer to v1.1:**
- Delegate multiplexer
- Double-size coordination
- Playlist resize
- Z-order
- Persistence

---

## Oracle vs Gemini: Key Differences

| Aspect | Oracle | Gemini | Winner |
|--------|--------|--------|--------|
| Feasibility | 7/10 | 9/10 | Oracle ✅ |
| Risk | 8/10 High | 6/10 Medium | Oracle ✅ |
| Time | 12-18h | 12-18h | Both (but add contingency) |
| Focus | Architecture | Features | Oracle ✅ |
| Accuracy | Caught bugs | Missed bugs | Oracle ✅ |
| Completeness | Core concerns | Feature gaps | Gemini ✅ |
| Recommendations | Concrete | Comprehensive | Both valuable |

**Synthesis:** Oracle identifies showstoppers, Gemini identifies polish. Both needed.

---

## Final Recommendation

### Decision: CONDITIONAL GO ✅

**Proceed with implementation IF:**
1. NSWindowController architecture approved
2. Team understands 18-24h time commitment
3. Drag regions implemented before snap detection
4. Contingency plan for scope reduction

**Success Factors:**
- Experienced Swift/AppKit developer
- Rigorous testing (Phase 9)
- Willingness to abort if Phase 1B fails
- Acceptance of high risk (8/10)

**Value Proposition:**
- Authentic Winamp experience
- Best-in-class window management
- Competitive differentiation
- High user satisfaction

**Alternative:**
- Ship v1.0 with unified window
- Implement magnetic docking in v1.1
- Lower risk, delayed gratification

---

## Next Steps

1. **Immediate:** Fix snap distance docs (15px)
2. **Day 1:** Implement Phase 1A (separate windows)
3. **Day 1:** Implement Phase 1B (drag regions) - GATE
4. **Day 2:** Implement Phase 2 (snap detection)
5. **Day 2-3:** Continue through phases
6. **Day 3:** Testing & polish

**Go/No-Go Decision Point:** End of Phase 1B
- If drag regions work smoothly: Continue
- If drag regions problematic: Abort and revert

---

**Prepared by:** 10x Engineer (Claude)
**Reviewed:** Oracle (Codex), Gemini, Original Plan
**Confidence:** High (70% success probability with proper execution)
**Risk Level:** HIGH (8/10) - Proceed with caution
