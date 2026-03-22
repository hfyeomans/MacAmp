## Status

**Last Updated:** 2026-02-14 (Post-memory-optimization validation)

### Validation Complete (Oracle Review: gpt-5.3-codex, xhigh reasoning)

- [x] Initial review complete (original findings documented)
- [x] Post-refactoring validation complete (after WindowCoordinator decomposition)
- [x] Post-optimization validation complete (after memory/CPU optimization work)
- [x] Oracle synthesis complete (gpt-5.3-codex, xhigh reasoning)
- [ ] **BLOCKED:** Fix N1 (HIGH severity) before proceeding with new features

### Original Issues: ALL FIXED ✅

The PlaylistController extraction and AudioPlayer.stop() cleanup resolved all 4 original findings:

| # | Original Issue | Status | Fixed By |
|---|---------------|--------|----------|
| O1 | externalPlaybackHandler replaying on metadata refresh | **FIXED** | PlaybackCoordinator routes through updateLocalPlaybackState() |
| O2 | AudioPlayer.stop() leaves currentTrack populated | **FIXED** | AudioPlayer.swift:485 now clears currentTrack = nil |
| O3 | nextTrack() plays streams directly | **FIXED** | PlaylistController returns .requestCoordinatorPlayback for streams |
| O4 | previousTrack() wrong context during stream | **FIXED** | PlaylistController action enum routing |

### New Issues Found: 6 Issues (1 HIGH, 2 MEDIUM, 3 LOW)

**BLOCKING ISSUES (must fix before new features):**

**N1 - HIGH: Playlist navigation broken during stream playback**
- **Severity:** HIGH (blocks streaming-volume-control work)
- **Symptom:** next() always jumps to track 0, previous() does nothing
- **Root cause:** audioPlayer.currentTrack is nil during stream → PlaylistController.currentIndex = nil → resolveActiveIndex() = -1
- **Fix required:** Pass coordinator's currentTrack context into navigation
- **Files:** PlaybackCoordinator.swift:173, PlaylistController.swift:194,232
- **Details:** See findings.md §N1

**RECOMMENDED FIXES (before new features):**

**N2 - MEDIUM: PlayPause indicator desync from StreamPlayer**
- **Severity:** MEDIUM
- **Symptom:** Coordinator isPlaying flag doesn't reflect StreamPlayer buffering/errors
- **Root cause:** Imperative flags vs KVO state changes, no observation link
- **Fix:** Derive from active source or add StreamPlayer callbacks
- **Files:** PlaybackCoordinator.swift:42-43, StreamPlayer.swift:111-131

**N5 - MEDIUM: Main window indicator bound to AudioPlayer**
- **Severity:** MEDIUM
- **Symptom:** Play/pause button shows stopped during stream playback
- **Root cause:** WinampMainWindow reads audioPlayer.isPlaying (false during stream)
- **Fix:** Bind to playbackCoordinator.isPlaying
- **Files:** WinampMainWindow.swift (indicator binding)

**LOW PRIORITY (can defer):**

- **N3:** externalPlaybackHandler naming (clarity only, not a bug)
- **N4:** StreamPlayer metadata overwrite on play (cosmetic)
- **N6:** Track Info missing live ICY metadata (minor UX)

### Current Status

**State:** ⚠️ **BLOCKED ON N1 FIX**

The original internet radio implementation has a HIGH severity navigation bug discovered during validation. This must be fixed before proceeding with streaming-volume-control features to ensure a stable foundation.

**Next Actions:**
1. Fix N1 (playlist navigation context during streams)
2. Fix N2 + N5 (UI state binding correctness)
3. Validate fixes with Oracle
4. THEN proceed with streaming-volume-control implementation
