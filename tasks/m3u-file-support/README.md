# M3U File Support Task

## Problem

M3U playlist files appear **grayed out** and are **not selectable** in MacAmp's file open dialog.

**Impact:** Users cannot load:
- Internet radio station playlists
- Existing Winamp playlists
- M3U files from other sources

---

## Root Cause

### Primary Issue: NSOpenPanel Configuration ❌

**File:** `MacAmpApp/Views/WinampPlaylistWindow.swift`
**Line:** ~200-220 (openFileDialog function)

```swift
openPanel.allowedContentTypes = [.audio]  // ❌ Only allows audio files
```

**Fix:**
```swift
openPanel.allowedContentTypes = [.audio, .m3uPlaylist]  // ✅ Allow playlists too
```

### Secondary Issue: Missing UTI Import Declaration ⚠️

**File:** `MacAmpApp/Info.plist`

**Missing:** `UTImportedTypeDeclarations` section for `public.m3u-playlist`

---

## Solution Summary

### Quick Fix (30 minutes) ⚡
1. Add `.m3uPlaylist` to NSOpenPanel allowedContentTypes
2. Files immediately become selectable

### Complete Fix (4-6 hours) 📦
1. Fix NSOpenPanel (30 min)
2. Add UTI import declaration (15 min)
3. Implement M3U parser (2-3 hours)
4. Integrate with playlist loading (1-2 hours)

---

## Task Documentation

| File | Purpose |
|------|---------|
| `research.md` | Root cause analysis, M3U format research, technical findings |
| `plan.md` | 6-phase implementation plan with code examples |
| `state.md` | Current status, file locations, implementation status |
| `todo.md` | **START HERE** - Complete implementation checklist |

---

## Quick Start

**To Implement This Task:**

1. **Read Documentation:**
   ```bash
   cd /Users/hank/dev/src/MacAmp/tasks/m3u-file-support
   cat todo.md          # Implementation checklist
   cat plan.md          # Detailed implementation plan
   cat research.md      # Technical research and findings
   cat state.md         # Current state and status
   ```

2. **Create Branch:**
   ```bash
   git checkout main
   git pull origin main
   git checkout -b feature/m3u-file-support
   ```

3. **Start with Phase 1** (30 minutes):
   - Open `WinampPlaylistWindow.swift`
   - Change one line in `openFileDialog()`
   - Test immediately

4. **Continue with Remaining Phases**:
   - Follow todo.md checklist
   - Test after each phase
   - Commit incrementally

---

## Priority

**Overall:** P0 (Blocker)
**Rationale:** Required for internet radio feature (P5)

**Phase Priorities:**
- **Phase 1:** P0 - Fixes immediate bug (30 min) ⚡
- **Phase 2:** P1 - System integration (15 min) 📋
- **Phase 3:** P1 - Core functionality (2-3 hours) 🔧
- **Phase 4:** P1 - End-to-end integration (1-2 hours) 🔗
- **Phase 5:** P5 - Linked to Internet Radio task 🌐
- **Phase 6:** P3 - Optional export feature 💾

---

## Time Estimate

**Critical Path:** 4-6 hours (Phases 1-4)
**With Optional:** 5-8 hours (Add Phase 6)

---

## Impact

**User Impact:**
- ✅ Can load existing Winamp playlists
- ✅ Can import M3U files from internet
- ✅ Can load internet radio station lists
- ✅ Enables P5 (Internet Radio Streaming)

**Technical Impact:**
- ✅ Proper UTI system integration
- ✅ Standards-compliant M3U parsing
- ✅ Foundation for playlist features
- ✅ Winamp compatibility

---

## Dependencies

**Upstream:** None
**Downstream:** P5 (Internet Radio Streaming)

**Blocks:**
- P5 cannot be fully implemented without M3U support
- Users cannot load radio station playlists

**Enables:**
- Internet radio station libraries
- Playlist import/export (Phase 6)
- Full Winamp playlist compatibility

---

## Related Tasks

- **P5:** Internet Radio Streaming (consumes M3U URLs)
- **P2:** Playlist Menu System ("Load List" uses M3U)

---

## Status

**Research:** ✅ Complete
**Planning:** ✅ Complete
**Implementation:** ⏸️ Ready to start
**Testing:** ⏸️ Test files documented

---

## Key Files

### To Create
1. `MacAmpApp/Models/M3UEntry.swift`
2. `MacAmpApp/Parsers/M3UParser.swift`
3. `MacAmpAppTests/M3UParserTests.swift` (optional)

### To Modify
1. `MacAmpApp/Views/WinampPlaylistWindow.swift` (1 line + integration)
2. `MacAmpApp/Info.plist` (add UTImportedTypeDeclarations)
3. `MacAmpApp/Audio/AudioPlayer.swift` (optional, for stream detection)

---

**Created:** 2025-10-23
**Status:** ✅ Ready for implementation
**Next Step:** Review todo.md and begin Phase 1
