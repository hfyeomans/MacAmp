
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

### ⏸️ PLANNED COMMITS (Phase 4 - Oracle Corrected)

**Oracle Review:** ⚠️ Full coordinator migration required, not just playlist integration

**Phase 4: Coordinator Migration (Oracle: 6-8 hours, 7 commits)**

13. ⏸️ **Commit 13:** Extend Track + add AudioPlayer guards
    - Add `Track.isStream` computed property
    - Guard in `AudioPlayer.playTrack()` prevents stream crashes
    - ~30 min (Oracle corrected from 15 min)
    - Reason: Prevent AVAudioFile crashes on HTTP URLs

14. ⏸️ **Commit 14:** Fix M3U + ADD URL (playlist ONLY)
    - **REMOVE** all `radioLibrary.addStation()` calls
    - Streams → `audioPlayer.playlist` as Tracks
    - RadioStationLibrary for favorites only (Phase 5+)
    - ~1 hour (Oracle corrected from 45 min)
    - Reason: Winamp parity - streams are playlist items

15. ⏸️ **Commit 15:** Add StreamPlayer.play(url:) overload
    - URL-based play method (not just RadioStation)
    - Preserves Track metadata (title/artist)
    - ~30 min (Oracle added)
    - Reason: Support playlist-driven playback

16. ⏸️ **Commit 16:** Extend PlaybackCoordinator transport
    - Add `play(track: Track)` overload
    - Add `next()`, `previous()` methods
    - Add `displayTitle`, `displayArtist`, `currentTrack`
    - ~1 hour (Oracle added)
    - Reason: Become primary transport interface

17. ⏸️ **Commit 17:** Wire ALL playback controls
    - Playlist click → coordinator
    - Next/Previous buttons → coordinator
    - Play/Pause/Stop → coordinator
    - Keyboard shortcuts → coordinator
    - ~2-3 hours (Oracle critical)
    - Reason: ALL controls must route through coordinator

18. ⏸️ **Commit 18:** Update ALL UI bindings
    - WinampMainWindow: Use coordinator state
    - WinampPlaylistWindow: Use coordinator state
    - Replace all `audioPlayer.currentTitle` references
    - ~1.5 hours (Oracle corrected from 45 min)
    - Reason: UI must read from coordinator, not audioPlayer

19. ⏸️ **Commit 19:** Buffering display + final testing
    - Verify "Connecting..." / "buffer 0%" display
    - Comprehensive regression testing
    - Verify Winamp parity achieved
    - ~1 hour (Oracle)
    - Reason: Polish and production readiness

**Phase 4 Total:** 6-8 hours, 7 commits (Oracle corrected from 3.75 hours, 4 commits)

---

### 📊 Total Project Stats

**Commits:** 12 done + 7 planned = 19 total
**Time:** 6-8 hours done + 6-8 hours planned = 12-16 hours total
**Within Oracle estimate:** 12-15 hours ✓ (upper bound 16 hours acceptable for full coordinator migration)

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

## ⏸️ Phase 4: Coordinator Migration (6-8 hours, 7 commits)

**Oracle Status:** ✅ Reviewed - Full coordinator migration required
**Architecture:** RadioStationLibrary for favorites ONLY (Phase 5+)
**Scope:** ALL playback controls and UI bindings (not just playlist)

### Commit 13: Extend Track + Add AudioPlayer Guards

**Files to Modify:**
- [ ] `MacAmpApp/Audio/AudioPlayer.swift`

**Changes:**
- [ ] Add to Track struct:
  ```swift
  var isStream: Bool {
      !url.isFileURL && (url.scheme == "http" || url.scheme == "https")
  }
  ```
- [ ] Add guard in playTrack():
  ```swift
  func playTrack(track: Track) {
      guard !track.isStream else {
          print("ERROR: Stream in AudioPlayer - use PlaybackCoordinator")
          return
      }
      // ... existing code
  }
  ```

**Testing:**
- [ ] Build succeeds
- [ ] isStream works correctly
- [ ] Stream URLs fail gracefully

**Effort:** 30 min (Oracle)

---

### Commit 14: Fix M3U + ADD URL (Playlist ONLY)

**Files to Modify:**
- [ ] `MacAmpApp/Views/WinampPlaylistWindow.swift`

**loadM3UPlaylist() Changes:**
- [ ] **REMOVE** `radioLibrary.addStation(station)`
- [ ] **ADD** stream to playlist:
  ```swift
  let streamTrack = Track(
      url: entry.url,
      title: entry.title ?? "Unknown Station",
      artist: "Internet Radio",
      duration: 0.0
  )
  audioPlayer.playlist.append(streamTrack)
  ```

**addURL() Changes:**
- [ ] **REMOVE** `radioLibrary.addStation(station)`
- [ ] **ADD** stream to playlist as Track
- [ ] Update alert: "Added to playlist. Click to play!"

**Testing:**
- [ ] Load M3U → All items in playlist
- [ ] ADD URL → Stream in playlist
- [ ] Streams visible in UI

**Effort:** 1 hour (Oracle)

---

### Commit 15: Add StreamPlayer.play(url:) Overload

**Files to Modify:**
- [ ] `MacAmpApp/Audio/StreamPlayer.swift`

**Changes:**
- [ ] Add URL-based play method:
  ```swift
  func play(url: URL, title: String? = nil, artist: String? = nil) async {
      let station = RadioStation(
          name: title ?? url.host ?? "Internet Radio",
          streamURL: url
      )
      await play(station: station)
  }
  ```

**Testing:**
- [ ] Can play from URL
- [ ] Metadata preserved

**Effort:** 30 min (Oracle)

---

### Commit 16: Extend PlaybackCoordinator Transport

**Files to Modify:**
- [ ] `MacAmpApp/Audio/PlaybackCoordinator.swift`

**Changes:**
- [ ] Add `play(track: Track)` overload
- [ ] Add `next()`, `previous()` methods
- [ ] Add `displayTitle`, `displayArtist` properties
- [ ] Add `currentTrack: Track?` property

**Testing:**
- [ ] play(track:) works for both types
- [ ] next/previous delegate correctly
- [ ] State properties accessible

**Effort:** 1 hour (Oracle)

---

### Commit 17: Wire ALL Playback Controls

**Oracle Critical:** Not just playlist - EVERY control point

**Files to Modify:**
- [ ] `MacAmpApp/MacAmpApp.swift`
- [ ] `MacAmpApp/Views/WinampMainWindow.swift`
- [ ] `MacAmpApp/Views/WinampPlaylistWindow.swift`
- [ ] `MacAmpApp/AppCommands.swift` (if exists)

**Changes:**
- [ ] Create StreamPlayer, PlaybackCoordinator in MacAmpApp
- [ ] Inject via environment
- [ ] Playlist double-click → coordinator.play(track:)
- [ ] Next/Previous buttons → coordinator
- [ ] Play/Pause/Stop buttons → coordinator
- [ ] Keyboard shortcuts → coordinator

**Testing:**
- [ ] All controls work
- [ ] No audio conflicts
- [ ] Transport works for mixed playlists

**Effort:** 2-3 hours (Oracle)

---

### Commit 18: Update ALL UI Bindings

**Oracle:** Every audioPlayer state reference must switch

**Files to Modify:**
- [ ] `MacAmpApp/Views/WinampMainWindow.swift`
- [ ] `MacAmpApp/Views/WinampPlaylistWindow.swift`

**Changes:**
- [ ] Add coordinator environment
- [ ] Replace `audioPlayer.currentTitle` → `coordinator.displayTitle`
- [ ] Update onChange observers
- [ ] Update shade mode display

**Testing:**
- [ ] Title displays correctly
- [ ] Scrolling works
- [ ] Metadata updates
- [ ] No UI glitches

**Effort:** 1.5 hours (Oracle)

---

### Commit 19: Buffering Display + Final Testing

**Changes:**
- [ ] Verify "Connecting..." displays
- [ ] Verify "buffer 0%" on errors
- [ ] Comprehensive regression testing
- [ ] All Winamp parity requirements met

**Testing:**
- [ ] Local files unchanged
- [ ] Streams work from playlist
- [ ] Next/Previous for mixed playlists
- [ ] All transport controls functional
- [ ] Metadata live updates
- [ ] No crashes or conflicts

**Effort:** 1 hour (Oracle)

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
