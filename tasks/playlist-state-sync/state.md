# Playlist State Synchronization - State Tracking

**Date Started:** 2025-10-22
**Current Time:** 10:15 PM EDT
**Branch:** `fix/playlist-state-sync` (to be created off `feature/phase4-polish-bugfixes`)
**Status:** Planning Complete, Ready to Begin Implementation

---

## Task Overview

**Goal:** Fix Bug B - Track Selection and add missing playlist window controls

**Scope:**
- Fix broken track selection (tracks play wrong/same track)
- Add missing transport buttons (play, pause, stop, next, prev)
- Add missing time displays (current/total, remaining)
- Synchronize state between main and playlist windows

**Priority:** P0 - Critical (blocks playlist functionality)

---

## Progress Tracking

### ✅ Phase 0: Planning & Research (COMPLETE)
- [x] Analyzed current implementation
- [x] Identified root causes
- [x] Created research documentation
- [x] Created implementation plan
- [x] Gathered reference screenshots
- [x] Analyzed PLEDIT.BMP sprite layout

**Time Spent:** 1 hour
**Status:** Complete

---

### Phase 1: Add PLEDIT Sprite Definitions (PENDING)
**Estimated:** 30 minutes
**Status:** Not Started

**Tasks:**
- [ ] Add playlist transport button sprites to SkinSprites.swift
- [ ] Add playlist time display digit sprites
- [ ] Add colon, minus, slash character sprites
- [ ] Build and verify sprites load without errors
- [ ] Commit changes

**Files to Modify:**
- `MacAmpApp/Models/SkinSprites.swift`

---

### Phase 2: Add Transport Buttons (PENDING)
**Estimated:** 1 hour
**Status:** Not Started

**Tasks:**
- [ ] Create `buildPlaylistTransportButtons()` method
- [ ] Wire buttons to AudioPlayer methods
- [ ] Add button state highlighting based on isPlaying/isPaused
- [ ] Add buttons to window overlay
- [ ] Test all button functionality
- [ ] Commit changes

**Files to Modify:**
- `MacAmpApp/Views/WinampPlaylistWindow.swift`

---

### Phase 3: Add Time Displays (PENDING)
**Estimated:** 1.5 hours
**Status:** Not Started

**Tasks:**
- [ ] Add time computation properties
- [ ] Create `buildTimeDisplays()` method
- [ ] Implement `formatTime()` helper
- [ ] Calculate total playlist duration
- [ ] Add remaining time display logic
- [ ] Handle idle state (show `:` only)
- [ ] Add displays to window overlay
- [ ] Test time updates
- [ ] Commit changes

**Files to Modify:**
- `MacAmpApp/Views/WinampPlaylistWindow.swift`

---

### Phase 4: Fix Track Selection (PENDING)
**Estimated:** 1 hour
**Status:** Not Started

**Tasks:**
- [ ] Verify Track model ID generation
- [ ] Update track matching to use URL comparison
- [ ] Fix `trackBackground()` highlighting logic
- [ ] Fix `trackTextColor()` logic
- [ ] Add Track.duration property if needed
- [ ] Test track selection with multiple tracks
- [ ] Verify visual feedback
- [ ] Commit changes

**Files to Modify:**
- `MacAmpApp/Views/WinampPlaylistWindow.swift`
- `MacAmpApp/Models/Track.swift` (possibly)
- `MacAmpApp/Audio/AudioPlayer.swift` (for duration loading)

---

### Phase 5: Integration & Polish (PENDING)
**Estimated:** 1 hour
**Status:** Not Started

**Tasks:**
- [ ] Comprehensive testing of all features together
- [ ] Test state synchronization between windows
- [ ] Fix any edge cases discovered
- [ ] Test with multiple skins
- [ ] Update documentation
- [ ] Final commit
- [ ] Merge to `feature/phase4-polish-bugfixes`

---

## Overall Progress

**Total Estimated Time:** 5 hours
**Time Spent:** 1 hour (planning)
**Time Remaining:** 4 hours (implementation)
**Completion:** 0% (planning done, implementation pending)

---

## Current Issues

### Known Bugs
1. 🔴 **Bug B:** Track selection plays wrong track (PRIMARY ISSUE)
2. ❌ No transport buttons in playlist
3. ❌ No time displays in playlist
4. ⚠️ Track highlighting may use wrong comparison logic

### Blockers
- None identified

### Risks
- Track model changes may affect existing code
- Duration loading may be slow for large playlists
- Sprite positions may need fine-tuning per skin

---

## Next Steps

1. ✅ Review plan with user
2. ⏭️ Create sub-branch: `fix/playlist-state-sync`
3. ⏭️ Begin Phase 1: Add sprite definitions
4. ⏭️ Implement phases incrementally
5. ⏭️ Test after each phase
6. ⏭️ Merge when complete

---

**Current Status:** ⏸️ AWAITING USER APPROVAL TO BEGIN
**Next Action:** Create sub-branch and start Phase 1
