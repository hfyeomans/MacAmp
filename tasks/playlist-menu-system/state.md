# Playlist Menu System - State

**Date:** 2025-10-25
**Status:** 🚀 IN PROGRESS - Active implementation
**Priority:** P2 (Enhancement)
**Estimated Time:** 6-8.5 hours

---

## 📝 Current Status: ACTIVE DEVELOPMENT

**Branch:** `feature/playlist-menu-system`
**Started:** 2025-10-25

### ✅ Phase 0: Research & Planning (COMPLETE)

**Completed:**
- ✅ Analyzed PLEDIT.BMP sprite organization (comprehensive)
- ✅ Read complete webamp_clone implementation files
- ✅ Documented all 5 menus with 12+ menu items
- ✅ Identified sprite coordinates for all button states
- ✅ Mapped webamp actions to MacAmp equivalents
- ✅ Created implementation plan
- ✅ Created todo.md with phased tasks

**Documentation:**
- `research.md` - Comprehensive webamp + PLEDIT.BMP analysis
- `plan.md` - Implementation architecture
- `todo.md` - Detailed task breakdown (7 phases)

### 🎯 Current Phase: Phase 2 - Menu Components

**Phase 1 Completed:**
1. ✅ Audited SkinSprites.swift - found REM coordinates wrong, SEL missing
2. ✅ Fixed REM menu sprite coordinates (shifted down one row)
3. ✅ Added REMOVE_MISC sprites (top of REM menu)
4. ✅ Added complete SEL menu sprites (6 sprites)
5. ✅ Verified all 32 menu item sprites present and correctly mapped

**Next Actions (Phase 2):**
1. Create PlaylistMenuButton base component
2. Create SpriteMenuItem with hover detection
3. Test menu popup behavior

### 📊 Progress Tracking

| Phase | Tasks | Status |
|-------|-------|--------|
| 0. Research & Planning | 7 tasks | ✅ COMPLETE |
| 1. Sprite Audit | 5 tasks | ✅ COMPLETE |
| 2. Menu Components | 2 tasks | 🔄 IN PROGRESS |
| 3. Menu Actions | 5 tasks | ⏳ PENDING |
| 4. Selection State | 2 tasks | ⏳ PENDING |
| 5. M3U File I/O | 3 tasks | ⏳ PENDING |
| 6. UI Integration | 2 tasks | ⏳ PENDING |
| 7. Testing | 3 tasks | ⏳ PENDING |

---

## 🔧 Implementation Notes

### Confirmed Sprite Gaps

From grep of SkinSprites.swift:
- ✅ ADD menu sprites (URL, DIR, FILE) - Present
- ✅ REM menu sprites (ALL, CROP, SELECTED) - Present
- ❌ **SEL menu sprites - MISSING** (INVERT, ZERO, ALL)
- ⚠️ MISC menu sprites - Partially present
- ⚠️ LIST menu sprites - Need verification

### Technical Decisions

1. **Menu System:** NSMenu with custom NSMenuItem views (native macOS)
2. **Sprite Rendering:** SwiftUI SimpleSpriteImage bridged via NSHostingView
3. **Hover Detection:** Will need custom tracking (possibly NSTrackingArea)
4. **Selection State:** New @State var selectedTrackIndices: Set<Int>

---

**Current Decision:** ✅ ACTIVE IMPLEMENTATION
**Branch:** `feature/playlist-menu-system`
**Next Milestone:** Complete sprite audit and add missing sprites
