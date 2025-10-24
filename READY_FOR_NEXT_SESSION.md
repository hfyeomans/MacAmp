# Ready for Next Session - MacAmp Development

**Last Updated:** 2025-10-23
**Current Branch:** `main`
**Build Status:** ✅ Successful

---

## 🎯 Priority Queue: Deferred Tasks

This document tracks all deferred tasks by priority level for future implementation.

---

## P0 - Blocker (Immediate Fix Required)

### 0. M3U File Support
**Status:** Research complete, ready for implementation
**Location:** `tasks/m3u-file-support/`
**Branch:** `feature/m3u-file-support` (to create)

**Problem:**
M3U playlist files appear **grayed out** and cannot be selected in file dialogs, blocking:
- Internet radio playlist loading
- Winamp playlist import
- M3U file compatibility

**Root Cause:**
1. **NSOpenPanel restriction** - `allowedContentTypes = [.audio]` excludes playlists
2. **Missing UTI import** - No `UTImportedTypeDeclarations` in Info.plist

**Solution:**
```swift
// File: WinampPlaylistWindow.swift
openPanel.allowedContentTypes = [.audio, .m3uPlaylist]  // One line fix!
```

**Estimated Time:** 4-6 hours total (6 phases)
- Phase 1: Fix NSOpenPanel (30 min) ⚡ QUICK WIN
- Phase 2: Add UTI declaration (15 min)
- Phase 3: Implement M3U parser (2-3 hours)
- Phase 4: Integration (1-2 hours)
- Phase 5: Radio integration (P5 task)
- Phase 6: Export (optional, 1-2 hours)

**Impact:** Critical - Blocks P5 (Internet Radio Streaming)

**Implementation Checklist:**
- [ ] Change NSOpenPanel allowedContentTypes (30 min quick fix)
- [ ] Add UTImportedTypeDeclarations to Info.plist (15 min)
- [ ] Create M3UEntry model
- [ ] Create M3UParser with parse methods
- [ ] Handle standard M3U format
- [ ] Handle extended M3U (#EXTM3U, #EXTINF)
- [ ] Handle M3U8 (UTF-8 encoding)
- [ ] Resolve relative file paths
- [ ] Integrate with playlist loading
- [ ] Test with local file M3U
- [ ] Test with internet radio M3U
- [ ] Add error handling for malformed files

**Files to Create:**
- `MacAmpApp/Models/M3UEntry.swift`
- `MacAmpApp/Parsers/M3UParser.swift`
- `MacAmpAppTests/M3UParserTests.swift` (optional)

**Files to Modify:**
- `MacAmpApp/Views/WinampPlaylistWindow.swift` (openFileDialog + integration)
- `MacAmpApp/Info.plist` (add UTImportedTypeDeclarations)

**Documentation:**
- `tasks/m3u-file-support/README.md` - Overview
- `tasks/m3u-file-support/research.md` - Technical research
- `tasks/m3u-file-support/plan.md` - Implementation plan
- `tasks/m3u-file-support/state.md` - Current status
- `tasks/m3u-file-support/todo.md` - Detailed checklist

**Test Streams:**
```m3u
#EXTM3U
#EXTINF:-1,SomaFM: Groove Salad
http://ice1.somafm.com/groovesalad-256-mp3
#EXTINF:-1,Radio Paradise
http://stream.radioparadise.com/mp3-192
```

---

## P1 - Critical (Before 1.0 Release)

### 1. Async Audio Loading (threading-fixes)
**Status:** Research complete, ready for implementation
**Location:** `tasks/playlist-state-sync/KNOWN_LIMITATIONS.md`
**Branch:** `fix/async-audio-loading` (to create)

**Problem:**
- Track switching freezes UI (50-500ms)
- Slider dragging freezes visualizer/time display
- Eject button triggers `nextTrack()` unexpectedly
- All due to synchronous file I/O on main thread

**Root Cause:**
```swift
// AudioPlayer.swift:141 - BLOCKS MAIN THREAD
audioFile = try AVAudioFile(forReading: url)
```

**Solution:**
- Refactor `loadAudioFile()` to async/await
- Move file I/O to background thread
- Implement deferred seeking (only on drag end)
- Add loading indicators during track load

**Estimated Time:** 2-3 hours
**Impact:** High - Fixes major UX issue affecting every track switch

**Implementation Checklist:**
- [ ] Make `loadAudioFile()` async
- [ ] Update `playTrack()` to await loading
- [ ] Implement deferred seeking for position slider
- [ ] Implement deferred seeking for volume/balance sliders
- [ ] Add loading spinner/indicator
- [ ] Test with large files (>50MB)
- [ ] Fix Eject button/file dialog race condition
- [ ] Verify no state management regressions

**Files to Modify:**
- `MacAmpApp/Audio/AudioPlayer.swift` (main changes)
- `MacAmpApp/Views/WinampMainWindow.swift` (slider interactions)
- `MacAmpApp/Views/WinampPlaylistWindow.swift` (slider interactions)

---

## P2 - Important (Post 1.0, High Value)

### 2. Playlist Menu System
**Status:** Research complete, implementation plan ready
**Location:** `tasks/playlist-menu-system/` (research + plan)
**Branch:** `feature/playlist-menu-system` (to create)

**Features to Implement:**

**ADD Menu:**
- Add URL... (opens URL input dialog)
- Add Dir... (opens directory picker)
- Add File... (opens file picker)

**REM Menu (Remove):**
- Remove All (clears playlist)
- Crop (removes non-selected tracks)
- Remove Selected (removes selected tracks)

**SEL Menu (Selection):**
- Select All (Cmd+A)
- Select None (deselect all)
- Invert Selection (toggle all)

**MISC Menu:**
- Sort List... (opens sort dialog)
- File Info... (shows track metadata)
- Misc Options... (playlist preferences)

**LIST Menu:**
- New List (clears and starts fresh)
- Save List... (exports .m3u/.pls)
- Load List... (imports .m3u/.pls)

**Technical Requirements:**
- Sprite-based NSMenu with PLEDIT.BMP graphics
- Hover states (normal/highlighted)
- Proper menu positioning
- Keyboard shortcuts
- State management for selections

**Estimated Time:** 4-6 hours total
- Sprites: 1 hour
- Menu infrastructure: 2 hours
- Features: 2 hours
- Testing: 1 hour

**Impact:** Medium-High - Matches Winamp UX, essential for power users

**Implementation Phases:**
1. **Phase 1:** Sprite extraction and menu button hover states
2. **Phase 2:** Basic menu structure (empty menus popup)
3. **Phase 3:** Implement ADD menu features
4. **Phase 4:** Implement REM menu features
5. **Phase 5:** Implement SEL menu features
6. **Phase 6:** Implement MISC/LIST menu features

**Files to Create:**
- `MacAmpApp/Views/PlaylistMenu.swift` (base menu component)
- `MacAmpApp/Views/PlaylistAddMenu.swift`
- `MacAmpApp/Views/PlaylistRemoveMenu.swift`
- `MacAmpApp/Views/PlaylistSelectionMenu.swift`
- `MacAmpApp/Views/PlaylistMiscMenu.swift`
- `MacAmpApp/Views/PlaylistListMenu.swift`

**Files to Modify:**
- `MacAmpApp/Parsers/SkinSprites.swift` (add menu sprites)
- `MacAmpApp/Views/WinampPlaylistWindow.swift` (integrate menus)
- `MacAmpApp/Audio/AudioPlayer.swift` (selection management)

---

## P3 - Nice to Have (Quality of Life)

### 3. Magnetic Window Snapping
**Status:** Research complete, analysis documented
**Location:** `tasks/magnetic-window-docking/`
**Branch:** `feature/magnetic-window-snapping` (to create)

**Feature Description:**
Windows "snap" together when dragged within ~8 pixels of each other, mimicking classic Winamp's magnetic docking behavior.

**Behavior:**
- Main window + Playlist window snap together
- Main window + Equalizer window snap together
- Multiple windows can chain together
- Magnetic strength: 8px detection threshold
- Smooth snap animation (not instant jump)
- Windows stay docked during drag (move together)

**Technical Approach:**
- Track all window positions in AppState
- Detect proximity during drag (`onMove` handler)
- Adjust final position to align edges
- Use `@Published` properties for reactive updates
- SwiftUI `.onChange(of: windowPosition)` to cascade updates

**Estimated Time:** 3-4 hours
- Research/analysis: ✅ Done
- Proximity detection: 1 hour
- Snap implementation: 1 hour
- Cascade movement: 1 hour
- Polish/testing: 1 hour

**Impact:** Medium - Nostalgic feature, improves window management UX

**Implementation Checklist:**
- [ ] Create window position tracking system
- [ ] Implement proximity detection (8px threshold)
- [ ] Add snap-to-edge logic
- [ ] Implement cascading movement (docked windows move together)
- [ ] Add smooth snap animation
- [ ] Test with all window combinations
- [ ] Handle edge cases (screen boundaries, multiple monitors)

**Files to Create:**
- `MacAmpApp/ViewModels/WindowPositionManager.swift` (central coordinator)
- `MacAmpApp/Models/WindowPosition.swift` (position data)

**Files to Modify:**
- `MacAmpApp/MacAmpApp.swift` (window group configuration)
- `MacAmpApp/Views/WinampMainWindow.swift` (add position tracking)
- `MacAmpApp/Views/WinampPlaylistWindow.swift` (add position tracking)
- `MacAmpApp/Views/WinampEqualizerWindow.swift` (add position tracking)

**Research References:**
- `tasks/magnetic-window-docking/research.md` - Complete analysis
- `tasks/magnetic-window-docking/video-frame-analysis.md` - Frame-by-frame behavior
- `tasks/magnetic-window-docking/ANALYSIS.md` - Technical implementation details

---

## P4 - Future Enhancement (Post 1.0)

### 4. Playlist Window Resize
**Status:** Research complete, ready for deep-dive
**Location:** `tasks/playlist-window-resize/`
**Branch:** `feature/playlist-window-resize` (to create)

**Feature Description:**
Make the playlist window resizable (like classic Winamp), implementing the proper three-section layout that allows the center to expand/contract.

**Problem:**
Current MacAmp uses a **two-section workaround** (LEFT + RIGHT only) that prevents resizing. Classic Winamp uses **three-section layout** (LEFT + CENTER + RIGHT).

**Current Layout:**
```
┌─────────┬──────────┐
│  LEFT   │  RIGHT   │  ← Only 2 sections
│ 125px   │  154px   │  ← Total: 279px (fixed)
└─────────┴──────────┘
```

**Proper Layout:**
```
┌─────────┬─────────────────┬──────────┐
│  LEFT   │     CENTER      │  RIGHT   │  ← 3 sections
│ 125px   │   EXPANDABLE    │  150px   │  ← Total: 275px - 1000px
└─────────┴─────────────────┴──────────┘
```

**Implementation Requirements:**
1. **Three-Section Layout:**
   - Bottom left: 125px (menu buttons) - fixed
   - Bottom center: 0-500px (tiled background) - expandable
   - Bottom right: 150px (transport controls) - fixed

2. **Window Resize Support:**
   - Minimum size: 275×200 (center hidden)
   - Maximum size: ~1000×1000 (reasonable limit)
   - Resize handle: Bottom-right corner (20×20px)

3. **Sprite Additions:**
   - Add `PLAYLIST_BOTTOM_CENTER_TILE` sprite (1-2px wide, tiles horizontally)
   - Verify `PLAYLIST_BOTTOM_RIGHT_CORNER` width (150px vs 154px)

4. **State Management:**
   - Track window size in AppSettings
   - Persist size between launches
   - Update layout on size change

**Estimated Time:** 10 hours total
- Sprites: 1 hour
- Layout refactor: 2 hours
- Resize implementation: 2 hours
- State management: 1 hour
- Testing: 2 hours
- Polish: 2 hours

**Impact:** Low - Nice-to-have feature, not critical for 1.0

**Implementation Checklist:**
- [ ] Add `PLAYLIST_BOTTOM_CENTER_TILE` sprite definition
- [ ] Refactor bottom section to ZStack + HStack + Spacer
- [ ] Position left/right sections with fixed widths
- [ ] Implement center background tiling
- [ ] Add window resize support (min: 275px, max: ~1000px)
- [ ] Add resize handle (bottom-right corner)
- [ ] Track window size in state
- [ ] Persist size between launches
- [ ] Test with multiple skins
- [ ] Verify sprite tiling works correctly
- [ ] Add smooth resize animation

**Files to Create:**
- (Optional) `MacAmpApp/Views/PlaylistResizeHandle.swift` (custom resize handle)

**Files to Modify:**
- `MacAmpApp/Views/WinampPlaylistWindow.swift` (bottom section layout)
- `MacAmpApp/Parsers/SkinSprites.swift` (add PLAYLIST_BOTTOM_CENTER_TILE)
- Window group configuration (add resize support)

**Research Resources:**
- `tasks/playlist-window-resize/README.md` - Quick overview

---

## P5 - Future Feature (Distribution Ready)

### 5. Internet Radio Streaming
**Status:** Configuration complete, implementation ready
**Location:** `tasks/distribution-setup/`
**Branch:** `feature/internet-radio-streaming` (to create)

**Feature Description:**
Add support for URL-based internet radio streaming (HTTP/HTTPS streams, HLS, Icecast/SHOUTcast, M3U/PLS playlists).

**Configuration Complete:**
- ✅ Entitlements configured (network client, audio output)
- ✅ App Transport Security configured (HTTP media streaming)
- ✅ Playlist file handlers (M3U, PLS, WSZ)
- ✅ Custom URL scheme (macamp://)
- ✅ App category set to music
- ✅ Distribution certificates documented

**Supported Protocols:**
- HTTP/HTTPS direct streaming (MP3, AAC, OGG, FLAC)
- HLS (HTTP Live Streaming) - .m3u8 playlists
- Icecast/SHOUTcast - ICY protocol
- M3U/PLS playlist files
- RTSP (if needed)

**Implementation Requirements:**
1. **Stream Player:**
   - Use AVPlayer for HTTP/HTTPS streams
   - Handle HLS playlists automatically (AVPlayer native support)
   - Parse M3U/PLS files to extract stream URLs
   - Add buffering UI (loading indicators)

2. **Station Library:**
   - Curate popular stations (SomaFM, Radio Paradise, etc.)
   - Allow custom URL input
   - Save favorite stations
   - Category organization (Genre, Country, Language)

3. **Metadata Support (Optional):**
   - Parse ICY headers for "Now Playing" info
   - Display album art from stream metadata
   - Show bitrate and codec info
   - Display buffering status

4. **UI Integration:**
   - Add "Add URL..." to playlist ADD menu (requires P2)
   - Stream URL input dialog
   - Station browser/selector
   - "Now Playing" metadata display

**Estimated Time:** 6-8 hours total
- Stream player implementation: 2 hours
- M3U/PLS parser: 1 hour
- Station library: 2 hours
- UI integration: 2 hours
- Testing: 1 hour

**Impact:** Medium - Modern feature, extends app beyond local files

**Technical Notes:**
- All entitlements already in place
- `NSAllowsArbitraryLoadsInMedia` allows HTTP streams (App Store approved)
- AVFoundation handles most heavy lifting
- No additional permissions needed

**Implementation Checklist:**
- [ ] Create InternetRadioPlayer class (wraps AVPlayer)
- [ ] Implement M3U parser
- [ ] Implement PLS parser
- [ ] Create RadioStation model
- [ ] Build station library (hardcoded popular stations)
- [ ] Add "Add URL..." menu item
- [ ] Create stream URL input dialog
- [ ] Test with HTTP streams (SomaFM)
- [ ] Test with HTTPS streams
- [ ] Test with HLS (.m3u8)
- [ ] Test with M3U/PLS files
- [ ] Add buffering indicators
- [ ] Implement ICY metadata parsing (optional)
- [ ] Add station favorites system

**Files to Create:**
- `MacAmpApp/Audio/InternetRadioPlayer.swift` (stream player)
- `MacAmpApp/Models/RadioStation.swift` (station model)
- `MacAmpApp/Parsers/M3UParser.swift` (M3U playlist parser)
- `MacAmpApp/Parsers/PLSParser.swift` (PLS playlist parser)
- `MacAmpApp/ViewModels/RadioStationLibrary.swift` (station database)
- `MacAmpApp/Views/AddURLDialog.swift` (URL input dialog)

**Files to Modify:**
- `MacAmpApp/Views/WinampPlaylistWindow.swift` (integrate "Add URL" menu)
- `MacAmpApp/Audio/AudioPlayer.swift` (integrate radio player)

**Documentation:**
- `tasks/distribution-setup/internet-radio-streaming.md` - Complete implementation guide
- `tasks/distribution-setup/distribution-guide.md` - Distribution and notarization

**Test Streams:**
```
# SomaFM (Free, HTTP)
http://ice1.somafm.com/groovesalad-256-mp3
http://ice1.somafm.com/defcon-128-mp3

# Radio Paradise (Free, HTTP)
http://stream.radioparadise.com/mp3-192
http://stream.radioparadise.com/aac-320
```

---

## 📊 Task Summary

| Priority | Task | Status | Time | Impact |
|----------|------|--------|------|--------|
| **P0** | **M3U File Support** | **Ready** | **4-6h** | **Critical** |
| P1 | Async Audio Loading | Ready | 2-3h | High |
| P2 | Playlist Menu System | Planned | 4-6h | Med-High |
| P3 | Magnetic Window Snapping | Analyzed | 3-4h | Medium |
| P4 | Playlist Window Resize | Researched | 10h | Low |
| P5 | Internet Radio Streaming | Configured | 6-8h | Medium |

**Total Deferred Work:** ~29-37 hours

---

## ✅ Recently Completed

### M3U File Support Research (2025-10-23)
**Status:** ✅ Research complete, ready for implementation

**Problem Identified:**
- M3U files grayed out in file dialogs (cannot be selected)
- Root cause: NSOpenPanel only allows .audio types
- Secondary: Missing UTImportedTypeDeclarations

**Research Delivered:**
1. ✅ Root cause analysis (NSOpenPanel + UTI configuration)
2. ✅ M3U format specifications (standard vs extended)
3. ✅ Internet radio M3U structure research
4. ✅ Winamp/webamp behavior analysis
5. ✅ Complete 6-phase implementation plan
6. ✅ Parser algorithm designed
7. ✅ Test files documented

**Quick Win Available:** 30-minute one-line fix makes M3U files selectable!

**Documentation:**
- `tasks/m3u-file-support/README.md` - Quick overview
- `tasks/m3u-file-support/research.md` - Technical findings (14KB)
- `tasks/m3u-file-support/plan.md` - Implementation phases (13KB)
- `tasks/m3u-file-support/state.md` - Current status (7.4KB)
- `tasks/m3u-file-support/todo.md` - Detailed checklist (9.3KB)

### Distribution & Streaming Configuration (2025-10-23)
**Status:** ✅ Complete

**Features Delivered:**
1. ✅ Entitlements configured for audio playback and network streaming
2. ✅ App Transport Security configured for HTTP radio streams
3. ✅ File handlers for M3U, PLS, and WSZ files
4. ✅ Custom macamp:// URL scheme
5. ✅ Distribution setup documented (Developer ID + App Store)
6. ✅ TestFlight research and comparison vs Sparkle
7. ✅ ExportOptions.plist created for distribution

**Documentation:**
- `tasks/distribution-setup/distribution-guide.md` - Complete distribution workflow
- `tasks/distribution-setup/internet-radio-streaming.md` - Streaming implementation guide
- `tasks/distribution-setup/testflight-beta-testing.md` - TestFlight vs Sparkle analysis

### Playlist State Sync (2025-10-22 to 2025-10-23)
**Branch:** `fix/playlist-state-sync` (merged to main)
**Status:** ✅ Complete

**Features Delivered:**
1. ✅ Track selection working (Bug B fixed)
2. ✅ All 6 transport buttons rendering correctly
3. ✅ Sprite-based time display with PLEDIT.TXT colors
4. ✅ State synchronization between windows
5. ✅ Clean layout (no overlaps or gaps)

**Commits:** 36 commits
**Time:** ~10 hours
**Files Modified:** 6 files
**Lines Added:** ~470 lines

---

## 🔀 Git Workflow

### Current State
```
main (latest: distribution & streaming config)
  ↑
  └── (future branches will merge here)
```

### Creating New Feature Branches
```bash
# For P1 task (async audio loading)
git checkout main
git pull origin main
git checkout -b fix/async-audio-loading

# For P2 task (playlist menus)
git checkout main
git pull origin main
git checkout -b feature/playlist-menu-system

# For P3 task (magnetic snapping)
git checkout main
git pull origin main
git checkout -b feature/magnetic-window-snapping

# For P4 task (playlist resize)
git checkout main
git pull origin main
git checkout -b feature/playlist-window-resize

# For P5 task (internet radio)
git checkout main
git pull origin main
git checkout -b feature/internet-radio-streaming
```

---

## 🎯 Recommended Next Steps

### **RECOMMENDED: Start with P0 (Blocker)**
Fix **M3U file support** to unblock internet radio (has 30-min quick win!):
1. Create branch `feature/m3u-file-support`
2. Review `tasks/m3u-file-support/README.md`
3. **Quick Win:** Implement Phase 1 (30 min) - Makes M3U files selectable
4. Implement Phases 2-4 (4-6 hours total)
5. Test with local and internet radio M3U files
6. Merge to main

### Option 1: Fix Critical Issues First (P1)
Start with **async-audio-loading** to fix the main thread blocking issue:
1. Create branch `fix/async-audio-loading`
2. Review `tasks/playlist-state-sync/KNOWN_LIMITATIONS.md`
3. Implement async file loading (2-3 hours)
4. Test thoroughly with large files
5. Merge to main

### Option 2: Build User-Facing Features (P2)
Implement **playlist-menu-system** for complete Winamp experience:
1. Create branch `feature/playlist-menu-system`
2. Review `tasks/playlist-menu-system/plan.md`
3. Implement menus phase-by-phase (4-6 hours)
4. Test all menu features
5. Merge to main

### Option 3: Polish & Nostalgia (P3)
Add **magnetic-window-snapping** for classic Winamp feel:
1. Create branch `feature/magnetic-window-snapping`
2. Review `tasks/magnetic-window-docking/research.md`
3. Implement proximity detection and snapping (3-4 hours)
4. Test window combinations
5. Merge to main

### Option 4: Future Enhancement (P4)
Tackle **playlist-window-resize** when ready:
1. Review `tasks/playlist-window-resize/README.md`
2. Create branch `feature/playlist-window-resize`
3. Implement three-section layout (10 hours)
4. Test with multiple skins
5. Merge to main

### Option 5: Modern Feature (P5)
Implement **internet-radio-streaming**:
1. Create branch `feature/internet-radio-streaming`
2. Review `tasks/distribution-setup/internet-radio-streaming.md`
3. Implement stream player and parsers (6-8 hours)
4. Test with various stream types
5. Merge to main

---

## 📝 Notes

- All task folders contain complete research and documentation
- Estimates are conservative; actual time may vary
- Each task is independent and can be tackled in any order
- P1 is highest priority for 1.0 release
- P2-P5 can wait until post-1.0
- Distribution configuration is complete and ready for app release

---

## 🚀 Build & Run

**Current Build Status:** ✅ Successful
**Tested On:** macOS Sequoia 15.0+
**Skins Tested:**
- ✅ Classic Winamp skin
- ✅ Internet Archive skin

**To Run:**
```bash
cd /Users/hank/dev/src/MacAmp
open MacAmpApp.xcodeproj
# Press Cmd+R to build and run
```

---

**Last Session:** 2025-10-23 (Distribution, Streaming, TestFlight Research, M3U Investigation)
**Next Session:** **START WITH P0** (M3U File Support) - 30-min quick win available!
**Status:** ✅ Ready to continue development

---

## 🚀 Quick Start for Next Session

**Recommended Order:**
1. **P0: M3U File Support** (4-6h) - Blocker, enables internet radio
   - Quick win: 30-min fix makes files selectable
   - Full implementation: 4-6 hours
2. **P1: Async Audio Loading** (2-3h) - Fixes UI freezing
3. **P5: Internet Radio Streaming** (6-8h) - Modern feature
4. **P2: Playlist Menu System** (4-6h) - Power user features
5. **P3: Magnetic Window Snapping** (3-4h) - Nostalgic polish
6. **P4: Playlist Window Resize** (10h) - Future enhancement

**Total Work:** 29-37 hours across all priorities
