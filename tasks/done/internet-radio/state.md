# Internet Radio Streaming - Current State

**Date:** 2025-10-31
**Status:** ✅ COMPLETE - All Oracle Fixes Applied, Ready for PR

---

## ✅ Implementation Summary

**Branch:** `internet-radio`
**Commits:** 38 total
  - 26 implementation (Phases 1-4)
  - 7 planning/documentation
  - 5 Oracle bug fixes + cleanup
**Time Spent:** ~15-16 hours (within Oracle estimate)
**Build Status:** ✅ SUCCESS - Zero deprecations, zero warnings, Thread Sanitizer enabled
**Testing:** ✅ COMPLETE - User tested all features, everything works
**Code Quality:** ✅ Modern Swift 6 / macOS 15+ only, Oracle Grade: A-

**FINAL IMPLEMENTATION (Oracle Verified):**
- ✅ Dual-backend architecture (AVAudioEngine + AVPlayer)
- ✅ PlaybackCoordinator as single source of truth
- ✅ Streams → playlist (ephemeral, Winamp parity)
- ✅ RadioStationLibrary ready for Phase 5+ (favorites menu)
- ✅ All playback controls route through coordinator
- ✅ Modern APIs only (@preconcurrency, async/await)
- ✅ Zero deprecation warnings
- ✅ Swift 6 strict concurrency compliant

### ✅ Oracle Requirements - ALL IMPLEMENTED

1. **PlaybackCoordinator** ✅ COMPLETE
   - Manages AudioPlayer + StreamPlayer
   - Prevents simultaneous playback
   - Unified API implemented
   - Comprehensive documentation added

2. **StreamPlayer Observers** ✅ FIXED
   - Old observers canceled before new ones
   - Status observer for error detection
   - RunLoop.main used (not DispatchQueue.main)
   - Proper cleanup (Combine auto-cancels)

3. **Metadata Extraction** ✅ FIXED
   - Uses item.commonKey and item.stringValue
   - Avoids KVC approach
   - ICY metadata working

4. **RadioStationLibrary Injection** ✅ COMPLETE
   - Injected via environment
   - Passed to PlaylistWindowActions.shared
   - Available throughout app

5. **M3U/M3U8 Integration** ✅ COMPLETE
   - Streams added to RadioStationLibrary
   - Local files added to playlist
   - Mixed playlists handled correctly

6. **Info.plist** ✅ VERIFIED
   - NSAllowsArbitraryLoadsInMedia confirmed
   - No changes needed

### Actual Commit Summary (39 commits):

**Phases 1-3:** Infrastructure (12 commits)
**Phase 4:** Coordinator migration (7 commits)
**Bug Fixes:** Oracle issues (15 commits)
**Cleanup:** Code quality (5 commits)

**All commits:** Clean, build successfully, Oracle reviewed

---


---

## Task Status

### Research Phase ✅
- ✅ Existing documentation reviewed
- ✅ Webamp clone analyzed
- ✅ Architecture decisions made
- ✅ Oracle review complete

### Planning Phase ✅
- ✅ Comprehensive plan created
- ✅ Oracle corrections incorporated
- ✅ Commit strategy defined
- ✅ 7 commits planned

### Implementation Phase ✅
- ✅ Phase 1: Core Streaming (Commits 1-4)
- ✅ Phase 2: M3U/M3U8 Integration (Commit 5)
- ✅ Phase 3: UI & Documentation (Commits 6-7)
- ✅ All code compiles and builds
- ✅ No TODO/FIXME comments left

### Documentation Phase ✅
- ✅ Comprehensive architecture docs
- ✅ Code documentation (StreamPlayer, PlaybackCoordinator)
- ✅ README_INTERNET_RADIO.md created
- ✅ Future work clearly identified

### Testing Phase ✅ (Complete)
- ✅ Manual testing complete (user verified all features)
- ✅ User acceptance testing passed

### Phase 4 Implementation ✅ (Complete)
- ✅ Commit 13: Track extension + AudioPlayer guards
- ✅ Commit 14: M3U + ADD URL fixed (playlist ONLY)
- ✅ Commit 15: StreamPlayer URL overload
- ✅ Commit 16: PlaybackCoordinator transport methods
- ✅ Commit 17: ALL playback controls wired
- ✅ Commit 18: ALL UI bindings updated
- ✅ Commit 19: Final verification
- ✅ Fix: Remaining playlist transport buttons

### Verification ✅ (Complete)
- ✅ All playback entry points route through coordinator
- ✅ All UI bindings use coordinator state
- ✅ No crashes on stream URLs (guards in place)
- ✅ displayTitle includes buffering status
- ✅ All builds successful with Thread Sanitizer
- ✅ Ready for manual testing

---

## ✅ What Was Built

### M3U Parser Infrastructure ✅
- **File:** `MacAmpApp/Models/M3UParser.swift`
- **Status:** Complete and tested
- **Capabilities:**
  - Parses #EXTM3U format
  - Extracts EXTINF metadata
  - Detects HTTP/HTTPS URLs
  - `M3UEntry.isRemoteStream` property

### M3U Integration Hook ✅
- **File:** `MacAmpApp/Views/WinampPlaylistWindow.swift`
- **Line:** 503-506
- **Status:** TODO placeholder ready
- **Current:** Logs remote streams, doesn't play them
- **Ready for:** Integration with StreamPlayer

### Entitlements ✅
- **File:** `MacAmpApp/MacAmp.entitlements`
- **Line 32:** `com.apple.security.network.client` = true
- **Status:** ✅ All streaming protocols supported

### Info.plist ✅ VERIFIED
- **Key:** `NSAllowsArbitraryLoadsInMedia`
- **Purpose:** Allow HTTP streams
- **Status:** ✅ Oracle verified - exists in MacAmpApp/Info.plist
- **No changes needed**

---

## ✅ Core Infrastructure (All Complete)

### Core Streaming ✅
- [x] StreamPlayer class (AVPlayer wrapper)
- [x] RadioStation model
- [x] RadioStationLibrary (persistence)
- [x] PlaybackCoordinator (dual backend orchestration)
- [x] Observable state for metadata, buffering, errors

### M3U/M3U8 Integration ✅
- [x] Update WinampPlaylistWindow M3U loading
- [x] Add stations to library from M3U/M3U8
- [x] Inject RadioStationLibrary via environment
- [x] Support .m3u, .m3u8 playlists, and HLS URLs
- [x] User feedback on station additions

### UI ✅ (Basic)
- [x] ADD URL dialog (manual stream entry)
- [x] URL validation (http/https)
- [x] Error handling and user feedback

### Documentation ✅
- [x] Comprehensive README_INTERNET_RADIO.md
- [x] Code documentation (StreamPlayer, PlaybackCoordinator)
- [x] Architecture diagrams
- [x] Future work roadmap

## ✅ Phase 4 Complete (Full Coordinator Migration)

### Implemented
- [x] Extend Track + add AudioPlayer guards (prevent crashes)
- [x] M3U + ADD URL: Streams to **playlist ONLY** (removed all library usage)
- [x] Add StreamPlayer.play(url:) overload
- [x] Extend PlaybackCoordinator: play(track:), next(), previous()
- [x] Wire ALL playback controls (playlist + transport + mini buttons)
- [x] Update ALL UI bindings (displayTitle, currentTrack highlighting)
- [x] Buffering status display (via displayTitle)
- [x] Comprehensive verification

**Oracle Corrections Applied:**
- Scope: Not just playlist - ALL transport controls
- UI: ALL bindings must use coordinator state
- Effort: 6-8 hours (not 3.75)
- Commits: 7 (not 4)

### Why Phase 4 is Needed
**User reported gap:** Streams not behaving like Winamp
**Root cause:** Used RadioStationLibrary (wrong mental model)
**Winamp behavior:** Streams ARE playlist items (ephemeral, not saved)
**Fix:** Streams → playlist directly, library ONLY for favorites menu (Phase 5+)

### Architecture Correction
**Before:** M3U → streams to RadioStationLibrary (separate storage)
**After:** M3U → streams to playlist (like Winamp)
**RadioStationLibrary:** Reserved for favorites menu (Phase 5+)

## ⏸️ Future Work (Phase 5+)

### Favorites Menu (High Priority)
- [ ] Add "Radio Stations" top menu (like "Skins", "Windows" menus)
- [ ] Show saved favorite stations from RadioStationLibrary
- [ ] Add/edit/delete favorites UI
- [ ] Load favorite into playlist
- [ ] Station organization (categories/genres)
- [ ] Quick access to frequently used streams

### Stream Visualizers (Complex - 10-20+ hours)
- [ ] **MTAudioProcessingTap Implementation**
  - Tap AVPlayer audio output for stream visualization
  - Process raw PCM data from HTTP streams
  - Feed to existing spectrum analyzer
  - Feed to existing oscilloscope
  - Enable visualizers for internet radio (currently unavailable)
  - Complexity: High - requires Core Audio expertise
  - Effort: 10-20+ hours development + testing
  - Benefit: Full Winamp parity for stream playback
  - Reference: tasks/internet-radio/research.md (Oracle noted this)

### Other Enhancements
- [ ] Export playlist as M3U/M3U8 (save current playlist)
- [ ] Recently played streams history
- [ ] Stream quality selection (for multi-bitrate streams)
- [ ] Search/browse radio directory
- [ ] Station rating system

---

## Architecture Decisions (Implemented & Verified)

### Dual Backend Approach ✅

**Local Files:**
- Backend: AVAudioEngine
- Features: 10-band EQ, full control
- Sources: .mp3, .flac, .m4a, etc.

**Streaming:**
- Backend: AVPlayer
- Features: HTTP streaming, metadata
- Sources: http://, https:// URLs
- Limitation: No EQ (AVPlayer can't use AVAudioUnitEQ)

**Why:**
- AVAudioEngine can't stream HTTP
- AVPlayer can't use custom audio units
- Must use both for complete feature set

**Oracle Review:** ✅ Validated - dual backend is correct approach

---

## Prerequisites Checklist

### ✅ Already Have
- [x] M3U parser with remote detection
- [x] Network client entitlement
- [x] Swift 6 @Observable architecture
- [x] Existing local file playback

### ✅ All Created
- [x] StreamPlayer class
- [x] RadioStation model
- [x] RadioStationLibrary
- [x] PlaybackCoordinator
- [x] All UI integration

---

## Implementation Scope ✅ COMPLETE

### Phase 1-4: All Implemented
- ✅ StreamPlayer with modern APIs
- ✅ PlaybackCoordinator orchestration
- ✅ M3U/M3U8 integration (playlist)
- ✅ ADD URL dialog
- ✅ All transport wiring
- ✅ All UI bindings

**Actual: ~15-16 hours** (Oracle was correct)

---

## Test Resources

### Available M3U Files
- `/Users/hank/Downloads/DarkAmbientRadio.m3u`
- Can create more from SomaFM

### Test Stream URLs (From Docs)
```
http://ice1.somafm.com/groovesalad-256-mp3  # SomaFM Groove Salad
http://ice1.somafm.com/defcon-128-mp3       # DEF CON Radio
http://stream.radioparadise.com/mp3-192     # Radio Paradise
```

---

## Current Codebase Analysis

### AudioPlayer.swift
- **Lines:** 94-1200+
- **Architecture:** AVAudioEngine based
- **Graph:** playerNode → eqNode → mainMixerNode → outputNode
- **Compatibility:** Perfect for local files
- **Limitation:** Cannot stream HTTP

### M3UParser.swift
- **Status:** Complete
- **Detection:** `url.scheme == "http" || "https"`
- **Ready:** For integration

### WinampPlaylistWindow.swift
- **Integration Point:** Line 503-506
- **Status:** Placeholder ready
- **Action:** Replace TODO with library integration

---

## Integration Strategy (Oracle to Review)

### Option A: Separate Players (Recommended)
- AudioPlayer handles local files (AVAudioEngine + EQ)
- StreamPlayer handles radio (AVPlayer, no EQ)
- UI switches between them based on source
- Clean separation of concerns

### Option B: Unified Player
- AudioPlayer extended with streaming
- Internal mode switching
- Single API for UI
- More complex state management

### Option C: StreamPlayer Delegates to AudioPlayer
- StreamPlayer for streams
- Delegates local files to AudioPlayer
- Wrapper pattern
- Complex delegation

**Recommendation:** Option A for clarity

**Oracle Review Question:** Is dual backend the right approach?

---

## Risks and Concerns

### Technical Risks
- Dual backend complexity
- State synchronization between players
- Mode switching audio glitches
- No EQ for streams (user expectation)

### Implementation Risks
- AVPlayer KVO observations (Swift 6 compliance)
- Metadata extraction reliability
- Network error handling
- Buffer stalling recovery

---

## Next Steps

1. ✅ ~~Verify NSAllowsArbitraryLoadsInMedia~~ (Confirmed exists)
2. ✅ ~~Oracle review of architecture~~ (Approved, corrections applied)
3. ✅ ~~Implement Phase 1~~ (Core streaming complete)
4. ✅ ~~Implement Phase 2~~ (M3U integration complete)
5. ✅ ~~Implement Phase 3~~ (Infrastructure complete)
6. ✅ ~~Gap analysis~~ (User reported Winamp behavior mismatch)
7. ✅ ~~Plan Phase 4~~ (Playlist integration planned)
8. ✅ ~~Oracle review of Phase 4 plan~~ (COMPLETE - 5 critical issues identified)
9. ✅ ~~Update all docs with Oracle corrections~~ (plan, todo, state, research)
10. ✅ ~~Implement Phase 4~~ (7 commits, ~6 hours actual)
11. ✅ ~~Bug fixes~~ (All Oracle issues resolved - 15 commits)
12. ✅ ~~Code cleanup~~ (Removed unused/deprecated code)
13. ✅ ~~Manual testing~~ (User tested - all features working)
14. ✅ ~~Skills documentation~~ (BUILDING_RETRO_MACOS_APP_SKILLS.md)
15. ✅ ~~Final verification~~ (39 commits, zero warnings)
16. ⏸️ **PR creation** (no direct merge to main)
17. ⏸️ **User acceptance and merge**

## Files Created (6)

1. ✅ `MacAmpApp/Models/RadioStation.swift` - 24 lines (for favorites Phase 5+)
2. ✅ `MacAmpApp/Models/RadioStationLibrary.swift` - 58 lines (for favorites Phase 5+)
3. ✅ `MacAmpApp/Audio/StreamPlayer.swift` - 141 lines (AVPlayer backend)
4. ✅ `MacAmpApp/Audio/PlaybackCoordinator.swift` - 145 lines (orchestration)
5. ✅ `tasks/internet-radio/README_INTERNET_RADIO.md` - 273 lines (docs)
6. ✅ `MacAmpApp.xcodeproj/project.pbxproj` - Modified to include files

## Files Modified (4)

1. ✅ `MacAmpApp/MacAmpApp.swift` - radioLibrary injection (will be corrected in Phase 4)
2. ✅ `MacAmpApp/Views/WinampPlaylistWindow.swift` - M3U integration (will be corrected in Phase 4)
3. ✅ `tasks/internet-radio/plan.md` - Phase 4 added
4. ✅ `tasks/internet-radio/todo.md` - Phase 4 checklist added

## Files Modified in Phase 4 ✅

1. ✅ `MacAmpApp/Audio/AudioPlayer.swift` - Track.isStream, guards, PlaylistAdvanceAction
2. ✅ `MacAmpApp/Views/WinampPlaylistWindow.swift` - M3U + ADD URL (playlist), controls
3. ✅ `MacAmpApp/MacAmpApp.swift` - PlaybackCoordinator creation and injection
4. ✅ `MacAmpApp/Views/WinampMainWindow.swift` - All bindings, buffering display
5. ✅ `MacAmpApp/Audio/PlaybackCoordinator.swift` - Full transport, state management
6. ✅ `MacAmpApp/Audio/StreamPlayer.swift` - Modern APIs, dual play methods

---

**Status:** ✅ IMPLEMENTATION COMPLETE - ALL ORACLE REVIEWS PASSED

---

## Final Summary

**Implementation:** ✅ Complete (39 commits)
**Testing:** ✅ Complete (user verified)
**Documentation:** ✅ Complete (README + skills doc)
**Code Quality:** ✅ Oracle Grade A- (production ready)
**Build:** ✅ Zero deprecations, zero warnings
**Ready:** ✅ PR CREATION
