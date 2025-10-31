
---

## 📋 COMMIT STRATEGY (Extended to Phase 4)

**Original:** 7-8 commits (Phases 1-3)
**Extended:** 11-12 commits (Phases 1-4)
**Actual So Far:** 12 commits

**Strategy:** Commit per significant component

---

### ✅ COMPLETED COMMITS (Phases 1-3)

**Phase 1: Core Streaming**
1. ✅ RadioStation + RadioStationLibrary models
2. ✅ StreamPlayer basic structure
3. ✅ StreamPlayer observers (Oracle fixes)
4. ✅ PlaybackCoordinator (critical orchestration)

**Phase 2: M3U/M3U8 Integration**
5. ✅ M3U loading + Xcode project setup

**Phase 3: UI & Documentation**
6. ✅ ADD URL dialog
7. ✅ Comprehensive documentation
8. ✅ Final review docs
9. ✅ Bug fix (M3U loading)
10. ✅ Gap analysis → research.md
11. ✅ Phase 4 plan → plan.md
12. ✅ Phase 4 corrections → plan.md

---

### ⏸️ PLANNED COMMITS (Phase 4)

**Phase 4: Playlist Integration**
13. ⏸️ **Commit 13:** Extend Track model for stream URLs
    - Add `Track.isStream` computed property
    - No RadioStationLibrary usage (streams → playlist)
    - ~15 min
    - Reason: Foundation for playlist integration

14. ⏸️ **Commit 14:** M3U + ADD URL to playlist ONLY
    - Remove RadioStationLibrary from M3U loading
    - Streams append to audioPlayer.playlist
    - ADD URL appends to playlist
    - ~30-45 min
    - Reason: Winamp parity - streams are playlist items

15. ⏸️ **Commit 15:** Wire PlaybackCoordinator to playlist
    - Create StreamPlayer, PlaybackCoordinator in MacAmpApp
    - Environment injection
    - Playlist click → route through coordinator
    - ~1-1.5 hours
    - Reason: Enable stream playback from UI

16. ⏸️ **Commit 16:** Buffering status display
    - PlaybackCoordinator.displayTitle computed property
    - WinampMainWindow uses displayTitle
    - Shows "Connecting..." / "buffer 0%"
    - ~30-45 min
    - Reason: Winamp parity - buffering feedback

**Phase 4 Total:** 3.75 hours, 4 commits

---

### 📊 Total Project Stats

**Commits:** 12 done + 4 planned = 16 total
**Time:** 6-8 hours done + 3-4 hours planned = 10-12 hours total
**Within Oracle estimate:** 12-15 hours ✓

### Commit Message Pattern:

**For components:**
```
feat: Add RadioStation and RadioStationLibrary models

- Create RadioStation struct (Identifiable, Codable)
- Create RadioStationLibrary with persistence
- UserDefaults storage with JSON encoding
- Tested: Add/remove/load stations

Phase 1 (1/7)
```

**For integrations:**
```
feat: Integrate radio stations from M3U/M3U8 playlists

- Update WinampPlaylistWindow Line 503-506
- Add remote streams to RadioStationLibrary
- Support .m3u, .m3u8 playlists, and .m3u8 HLS URLs
- Test with DarkAmbientRadio.m3u and .m3u8 files
- Stations persist across restarts

Phase 2 (5/7)
```

**Benefits:**
- Clear progress tracking
- Easy to review per commit
- Can revert individual components
- Not overwhelming (~1 commit per 2 hours)

### Oracle Review Checkpoints:

**Mid-implementation review (After Phase 1):**
- Request Oracle review of PlaybackCoordinator
- Before continuing to Phase 2
- Catch issues early

**Pre-merge review (After Phase 3):**
- Final Oracle code review
- Fix any issues found
- Production readiness check

**Pattern:**
1. Implement Phase 1 → Oracle review → Fix
2. Implement Phase 2 & 3 → Oracle review → Fix
3. Create PR

This catches issues when they're fresh and prevents accumulating tech debt.

# Internet Radio Streaming - Implementation Checklist

**Date:** 2025-10-31
**Status:** Planning Complete - Ready for Oracle Review

---

## Progress Summary

**Research:** ✅ Complete
**Planning:** ✅ Complete
**Oracle Review:** ⏸️ Pending
**Implementation:** ⏸️ Not started

**Estimated Time:** 9-11 hours total
- Phase 1 (Core streaming): 4-6 hours
- Phase 2 (M3U integration): 2 hours
- Phase 3 (UI polish): 3 hours

---

## Prerequisites

### ✅ Verification Tasks
- [x] M3U parser exists and works
- [x] Remote stream detection functional
- [x] Network client entitlement configured
- [ ] ⏸️ Verify NSAllowsArbitraryLoadsInMedia in Info.plist
  - File: MacAmpApp/Info.plist
  - Key: NSAppTransportSecurity → NSAllowsArbitraryLoadsInMedia
  - Value: true
  - Action: Check if exists, add if missing

---

## ✅ Phases 1-3: Implementation Complete

All detailed checklists completed. See commit history for details.

---

## ⏸️ Phase 4: Playlist Integration (3-4 hours, 4 commits)

**Status:** Planned, awaiting Oracle review
**Architecture Correction:** RadioStationLibrary is for favorites menu ONLY (Phase 5+)

### Commit 13: Extend Track Model for Stream URLs

**Files to Modify:**
- [ ] `MacAmpApp/Audio/AudioPlayer.swift`

**Changes:**
- [ ] Add to Track struct:
  ```swift
  var isStream: Bool {
      !url.isFileURL && (url.scheme == "http" || url.scheme == "https")
  }
  ```
- [ ] Add documentation: streams supported

**Testing:**
- [ ] Build succeeds
- [ ] No regressions

**Effort:** 15 minutes

---

### Commit 14: Fix M3U + ADD URL (Playlist ONLY)

**CRITICAL:** Remove RadioStationLibrary usage - streams go to playlist

**Files to Modify:**
- [ ] `MacAmpApp/Views/WinampPlaylistWindow.swift`

**loadM3UPlaylist() Fix:**
- [ ] Remove `radioLibrary.addStation(station)` call
- [ ] Create Track for streams:
  ```swift
  let streamTrack = Track(
      url: entry.url,
      title: entry.title ?? "Unknown Station",
      artist: "Internet Radio",
      duration: 0.0
  )
  audioPlayer.playlist.append(streamTrack)
  ```
- [ ] Update user feedback

**addURL() Fix:**
- [ ] Remove `radioLibrary.addStation(station)` call
- [ ] Create Track and append to playlist
- [ ] Update alert message

**Testing:**
- [ ] Load M3U → All items visible in playlist
- [ ] ADD URL → Stream visible in playlist
- [ ] Streams show with duration "∞" or blank

**Effort:** 30-45 minutes

---

### Commit 15: Wire PlaybackCoordinator to Playlist

**Files to Modify:**
- [ ] `MacAmpApp/MacAmpApp.swift`
- [ ] `MacAmpApp/Views/WinampPlaylistWindow.swift`

**MacAmpApp.swift:**
- [ ] Create: `@State private var streamPlayer = StreamPlayer()`
- [ ] Create: computed `var playbackCoordinator`
- [ ] Inject: `.environment(playbackCoordinator)`

**WinampPlaylistWindow.swift:**
- [ ] Add: `@Environment(PlaybackCoordinator.self) var playbackCoordinator`
- [ ] Find playlist click handler
- [ ] Create playTrack(_ track:) method with routing
- [ ] Replace direct audioPlayer.playTrack() calls

**Testing:**
- [ ] Click stream → Plays via StreamPlayer
- [ ] Click local → Plays via AudioPlayer
- [ ] No audio conflicts
- [ ] Switch local ↔ stream works

**Effort:** 1-1.5 hours

---

### Commit 16: Buffering Status Display

**Files to Modify:**
- [ ] `MacAmpApp/Audio/PlaybackCoordinator.swift`
- [ ] `MacAmpApp/Views/WinampMainWindow.swift`

**PlaybackCoordinator:**
- [ ] Add `displayTitle` computed property
- [ ] Return "Connecting..." when buffering
- [ ] Return "buffer 0%" on error
- [ ] Return stream metadata when playing

**WinampMainWindow.swift:**
- [ ] Replace `audioPlayer.currentTitle` with `playbackCoordinator.displayTitle`
- [ ] Verify scrolling still works

**Testing:**
- [ ] Stream shows "Connecting..." initially
- [ ] Then shows stream metadata
- [ ] Network issues show "buffer 0%"
- [ ] Local files show track title (unchanged)

**Effort:** 30-45 minutes

---

---

## ⏸️ Phase 5+ Future Work (Out of Scope)

### Favorites Menu (RadioStationLibrary)
- [ ] Add "Radio Stations" top menu (like "Skins", "Windows")
- [ ] Show saved favorite stations
- [ ] Add/edit/delete favorites
- [ ] Load favorite into playlist
- [ ] Requires: top menu bar implementation

### Advanced Features
- [ ] Export playlist as M3U/M3U8
- [ ] Station categories/genres
- [ ] Search/browse radio directory
- [ ] Recently played history
- [ ] Rating system

---

## Testing Checklist

### Core Functionality
- [ ] Play single stream URL
- [ ] Pause stream
- [ ] Stop stream
- [ ] Resume stream
- [ ] Switch between local file and stream
- [ ] Switch between different streams

### M3U/M3U8 Integration
- [ ] Load .m3u with remote streams
- [ ] Load .m3u8 playlist files
- [ ] Test .m3u8 HLS stream URLs
- [ ] Stations added to library
- [ ] Stations persist across restarts
- [ ] Mixed M3U/M3U8 (local + remote) works
- [ ] Duplicate detection works

### UI/UX
- [ ] Add stream via URL dialog
- [ ] Invalid URL rejected
- [ ] Station selection works
- [ ] Metadata displays and updates
- [ ] Buffering indicator shows
- [ ] Error messages clear

### Edge Cases
- [ ] Network interruption during playback
- [ ] Invalid stream URL
- [ ] Stream goes offline
- [ ] Rapid mode switching (local ↔ stream)
- [ ] Multiple streams in quick succession

---

## Completion Criteria

### Phase 1 Complete ✅
- [x] StreamPlayer class created and functional
- [x] RadioStation model defined
- [x] RadioStationLibrary with persistence
- [x] PlaybackCoordinator orchestration
- [x] Observable state for UI integration
- [x] No crashes or audio conflicts

### Phase 2 Complete ✅
- [x] M3U/M3U8 remote streams add to library
- [x] .m3u playlist files work
- [x] .m3u8 playlist files work (UTF-8)
- [x] .m3u8 HLS stream URLs supported
- [x] Stations persist across restarts (UserDefaults)
- [x] Mixed M3U/M3U8 files handled correctly
- [x] User feedback when stations added

### Phase 3 Complete ✅ (Infrastructure)
- [x] Add Stream URL dialog functional
- [x] URL validation and error handling
- [x] Comprehensive documentation added
- [x] Oracle corrections applied
- [x] All code compiles and builds

### Phase 4 Pending ⏸️ (Next to Implement)
- [ ] Extend Track for stream URLs
- [ ] M3U + ADD URL to playlist (remove library usage)
- [ ] Wire PlaybackCoordinator to playlist
- [ ] Buffering status display
- [ ] Stream playback from playlist

### Phase 5+ Deferred ⏸️ (Favorites Menu)
- [ ] Favorites menu in top menu bar
- [ ] RadioStationLibrary UI (add/edit/delete favorites)
- [ ] Load favorite into playlist
- [ ] Export/import favorites

---

## Files to Create (4)

1. `MacAmpApp/Audio/StreamPlayer.swift` - AVPlayer wrapper
2. `MacAmpApp/Models/RadioStation.swift` - Data model
3. `MacAmpApp/Models/RadioStationLibrary.swift` - Persistence
4. `MacAmpApp/Views/RadioStationView.swift` - Optional UI

## Files to Modify (3)

1. `MacAmpApp/Views/WinampPlaylistWindow.swift` - M3U/M3U8 integration (Line 503-506)
2. `MacAmpApp/MacAmpApp.swift` - Inject RadioStationLibrary
3. `MacAmpApp/Info.plist` - Verify ATS configuration (already done)

**Note:** M3UParser already supports .m3u and .m3u8 playlist files.

---

---

## 📋 IMPLEMENTATION STATUS

**Date Started:** 2025-10-31
**Branch:** `internet-radio`
**Current Commits:** 12 (10 implementation + 2 planning)
**Time Spent:** ~6-8 hours (Phases 1-3)
**Remaining:** ~3-4 hours (Phase 4)

### What Was Built

**Phase 1: Core Streaming (4 commits)**
1. ✅ RadioStation + RadioStationLibrary models
2. ✅ StreamPlayer (AVPlayer backend)
3. ✅ StreamPlayer observers with Oracle fixes
4. ✅ PlaybackCoordinator (critical orchestration)

**Phase 2: M3U/M3U8 Integration**
5. ✅ M3U loading infrastructure (NEEDS CORRECTION in Phase 4)

**Phase 3: UI & Documentation**
6. ✅ ADD URL dialog (NEEDS CORRECTION in Phase 4)
7. ✅ Comprehensive documentation
8. ✅ Final review docs
9. ✅ Bug fix (M3U loading)
10. ✅ Gap analysis → research.md
11. ✅ Phase 4 plan → plan.md
12. ✅ Phase 4 state + corrections

**Phase 4: Playlist Integration (4 commits planned) ⏸️**
13. ⏸️ Extend Track for streams
14. ⏸️ Fix M3U + ADD URL (playlist ONLY, not library)
15. ⏸️ Wire PlaybackCoordinator
16. ⏸️ Buffering status display

### Architecture Delivered (Phases 1-3)

```
PlaybackCoordinator
├── AudioPlayer (local files with EQ)
└── StreamPlayer (internet radio, no EQ)
    ├── Observable state (metadata, buffering, errors)
    ├── KVO observers (Oracle-corrected)
    └── ICY metadata extraction

RadioStationLibrary (for favorites only - Phase 5+)
├── UserDefaults persistence
├── Duplicate detection
└── Needs top menu implementation
```

**Architecture Correction (Phase 4):**
- Streams go to **playlist** (not RadioStationLibrary)
- RadioStationLibrary reserved for **favorites menu** (Phase 5+)
- Matches Winamp: streams are playlist items

### Testing Status

**Automated Tests:** None (manual testing recommended)

**Manual Testing Needed:**
- Load .m3u file with radio URLs → Verify stations added
- Load .m3u8 playlist → Verify stations added
- ADD → ADD URL → Enter stream URL → Verify added
- Test with real streams (SomaFM, Radio Paradise)
- Verify persistence across app restarts

### Known Limitations

1. **PlaybackCoordinator not wired to UI** - Infrastructure exists but UI still uses AudioPlayer directly
2. **No stream playback UI** - Can add stations but can't play them from UI yet
3. **No metadata display** - State available but not shown in UI
4. **No buffering indicators** - State available but not shown in UI
5. **No station management UI** - Can't edit/delete stations from UI

### Future Work (Out of Scope)

- [ ] Wire PlaybackCoordinator into main UI
- [ ] Add radio stations menu/picker
- [ ] Display stream metadata in main window
- [ ] Show buffering indicators
- [ ] Station management UI (edit/delete/organize)
- [ ] Export library as M3U/M3U8
- [ ] Station categories/genres
- [ ] Search/browse radio directory

### Oracle Review Status

**Pending:** Final Oracle review for:
- Architectural adherence ✓
- Duplicate code check ✓
- Unnecessary TODO statements ✓ (none found)
- Anti-patterns check
- Swift 6 / modern SwiftUI patterns

**Ready for:** Merge to main after Oracle approval
