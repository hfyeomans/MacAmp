# Research: Internet Radio N1-N6 Fixes

> **Purpose:** Synthesized research from `tasks/internet-radio-review/` findings and `tasks/internet-streaming-volume-control/` prerequisite analysis. Provides root cause analysis, code references, and fix strategies for all 6 issues.

---

## Status: COMPLETE - Synthesized from Oracle-validated findings (gpt-5.3-codex, xhigh reasoning, 2026-02-14)

## Background

Oracle validation of the internet radio streaming infrastructure (post-PlaylistController extraction and memory/CPU optimization) found 4 original issues (O1-O4) ALL FIXED, but uncovered 6 new issues (N1-N6). These block the `internet-streaming-volume-control` task Phase 1.

**Source documents:**
- `tasks/internet-radio-review/findings.md` - Full Oracle analysis with line references
- `tasks/internet-radio-review/research.md` - Validated findings with code walkthrough
- `tasks/internet-radio-review/plan.md` - Remediation plan (3-phase)
- `tasks/internet-streaming-volume-control/plan.md` - Prerequisites section documenting blocking relationship
- `tasks/internet-streaming-volume-control/state.md` - Blocker documentation

---

## Issue Analysis

### N1: Playlist Navigation Broken During Stream Playback - HIGH

**Symptom:** `next()` always jumps to track 0; `previous()` does nothing during stream playback.

**Root Cause Chain (Oracle-verified, exact line references):**
1. `PlaybackCoordinator.next()` calls `audioPlayer.nextTrack(isManualSkip: true)` (PlaybackCoordinator.swift:173)
2. `AudioPlayer.nextTrack()` syncs position with `playlistController.updatePosition(with: currentTrack)` (AudioPlayer.swift:1030)
3. During stream playback, `audioPlayer.currentTrack` is `nil` -- cleared by `audioPlayer.stop()` at PlaybackCoordinator.swift:106, which clears at AudioPlayer.swift:485
4. `PlaylistController.updatePosition(with: nil)` sets `currentIndex = nil` (PlaylistController.swift:142-144)
5. `resolveActiveIndex()` falls through to return `-1` (PlaylistController.swift:266)
6. `nextIndex = -1 + 1 = 0` -- always jumps to first track (PlaylistController.swift:194)
7. For `previous()`, `currentIndex` is nil and `findCurrentTrackIndex()` returns nil (currentTrack is nil), so `.none` is returned (PlaylistController.swift:232)

**Key Insight:** The coordinator DOES have the correct `currentTrack` (set at PlaybackCoordinator.swift:102 during stream start), but it's not passed through to PlaylistController during navigation. AudioPlayer's `currentTrack` is nil because `audioPlayer.stop()` was called to yield to StreamPlayer.

**Fix Strategy (from Oracle plan):** Pass coordinator's `currentTrack` context into navigation methods.

**Files:**
- `MacAmpApp/Audio/PlaylistController.swift` (lines 142-144, 194, 232, 266)
- `MacAmpApp/Audio/AudioPlayer.swift` (lines 485, 1030)
- `MacAmpApp/Audio/PlaybackCoordinator.swift` (lines 102, 106, 173, 179)

---

### N2: PlayPause Indicator Desync from StreamPlayer - MEDIUM

**Symptom:** Coordinator `isPlaying`/`isPaused` flags diverge from StreamPlayer's actual AVPlayer state during buffering stalls or network errors.

**Root Cause:**
- Coordinator sets flags imperatively at play/pause/resume time (PlaybackCoordinator.swift:42-43, 93, 113, 145, 191)
- StreamPlayer updates asynchronously via `AVPlayer.timeControlStatus` KVO (StreamPlayer.swift:111-131)
- Buffering stalls (`waitingToPlayAtSpecifiedRate`) or network errors change `StreamPlayer.isPlaying` without coordinator awareness
- No subscription, observation, or callback link between coordinator and stream player state

**Fix Strategy (from Oracle plan - Option C, simplest):** Convert `isPlaying`/`isPaused` from stored to computed properties that derive from the active source. Both `StreamPlayer` and `AudioPlayer` are `@Observable`, so SwiftUI will automatically re-evaluate.

**Files:**
- `MacAmpApp/Audio/PlaybackCoordinator.swift` (lines 42-43, ~83, ~93, ~96, ~112-113, ~134-135, ~142, ~145, ~150, ~156-157, ~187, ~191, ~196, ~228-229)
- `MacAmpApp/Audio/StreamPlayer.swift` (lines 111-131)

**Consideration:** Converting to computed properties requires removing ALL imperative `isPlaying = ...` / `isPaused = ...` assignments throughout PlaybackCoordinator. Must audit every assignment to ensure the computed derivation covers all states correctly.

---

### N3: externalPlaybackHandler Naming Ambiguity - LOW (Not a Bug)

**Analysis:** The handler fires when a placeholder track is replaced with loaded metadata (AudioPlayer.swift:270), but coordinator correctly routes through `updateLocalPlaybackState()` (PlaybackCoordinator.swift:272) which only updates display state -- does NOT replay. The name implies playback initiation but it's actually a metadata update callback.

**Fix Strategy:** Rename to `onTrackMetadataUpdate` or split into two callbacks. Naming-only, no logic change.

**Files:**
- `MacAmpApp/Audio/AudioPlayer.swift` (declaration + call site at line 270)
- `MacAmpApp/Audio/PlaybackCoordinator.swift` (init assignment)

---

### N4: StreamPlayer Metadata Overwrite on play(url:title:artist:) - LOW

**Root Cause:**
- StreamPlayer.swift:83-84 set `streamTitle = title` and `streamArtist = artist`
- StreamPlayer.swift:87 calls `await play(station:)` which clears them at StreamPlayer.swift:60-61
- Result: initial Track metadata is lost until ICY metadata arrives from the stream

**Mitigation exists:** Coordinator's `displayTitle` falls back to `currentTrack?.title` (PlaybackCoordinator.swift:295), so title is still visible. But `streamTitle`/`streamArtist` are nil during initial connection period.

**Fix Strategy:** Reapply title/artist after `await play(station:)` returns, guarded by `if streamTitle == nil` to avoid overwriting ICY metadata that arrived during connection.

**Files:**
- `MacAmpApp/Audio/StreamPlayer.swift` (lines 60-61, 75-90)

---

### N5: Main Window Indicator Bound to AudioPlayer, Not Coordinator - MEDIUM

**Evidence (Oracle-verified):** WinampMainWindow.swift references `audioPlayer.isPlaying` / `audioPlayer.isPaused` in multiple locations:
- `buildPlayPauseIndicator()` at line 316-319: reads `audioPlayer.isPlaying` / `audioPlayer.isPaused`
- Pause blink timer at line 154: reads `audioPlayer.isPaused`
- Time display blink at line 367: reads `audioPlayer.isPaused`
- Scrubbing state at line 844: reads `audioPlayer.isPlaying`

**Impact:** Play/pause indicator shows "stopped" during stream playback because `audioPlayer.isPlaying` is false (audioPlayer was stopped when stream started).

**Fix Strategy:** Rebind all 5 references to `playbackCoordinator.isPlaying`/`playbackCoordinator.isPaused`. PlaybackCoordinator is already in the view's environment (`@Environment(PlaybackCoordinator.self)`).

**Dependency:** N2 should be fixed first so that `playbackCoordinator.isPlaying` is derived correctly from the active source.

**Special case:** Line 844 `wasPlayingPreScrub = audioPlayer.isPlaying` may need evaluation since scrubbing is a local-file-only feature.

**Files:**
- `MacAmpApp/Views/WinampMainWindow.swift` (lines 154, 316, 318, 367, 844)

---

### N6: Track Info Dialog Missing Live ICY Metadata - LOW

**Evidence:** TrackInfoView.swift line 59 uses `playbackCoordinator.currentTitle` (set once at play-time) instead of `playbackCoordinator.displayTitle` (which includes live ICY metadata updates from StreamPlayer).

**Impact:** Shows static station name instead of live song title in Track Info dialog during radio playback.

**Fix Strategy:** Replace `currentTitle` with `displayTitle` in TrackInfoView.

**Files:**
- `MacAmpApp/Views/Components/TrackInfoView.swift` (line 59)

---

## Priority and Ordering

| Phase | Issues | Severity | Rationale |
|-------|--------|----------|-----------|
| Phase 1 | N1 | HIGH | Blocks streaming-volume-control; navigation fundamentally broken |
| Phase 2 | N2, then N5 | MEDIUM | N2 must precede N5 (N5 reads coordinator state that N2 fixes) |
| Phase 3 | N4, N6, N3 | LOW | Can defer; functional mitigations exist for all three |

**Ordering constraint:** N2 before N5 is critical. N5 rebinds UI to `playbackCoordinator.isPlaying`, which only works correctly after N2 converts it from stored to computed.

---

## Files Modified Summary

| File | Issues | Changes |
|------|--------|---------|
| `PlaylistController.swift` | N1 | Add `from:` navigation overloads |
| `AudioPlayer.swift` | N1, N3 | Add `from:` forwarding methods, rename handler |
| `PlaybackCoordinator.swift` | N1, N2, N3 | Use `from:` navigation, computed isPlaying/isPaused, rename handler reference |
| `StreamPlayer.swift` | N4 | Reapply metadata after play(station:) |
| `WinampMainWindow.swift` | N5 | Rebind 5 indicator references to coordinator |
| `TrackInfoView.swift` | N6 | Use displayTitle instead of currentTitle |

---

## Sources

- `tasks/internet-radio-review/findings.md` - Oracle validation findings (gpt-5.3-codex, xhigh, 2026-02-14)
- `tasks/internet-radio-review/research.md` - Validated codebase walkthrough
- `tasks/internet-radio-review/plan.md` - 3-phase remediation plan with code snippets
- `tasks/internet-radio-review/todo.md` - Phase-ordered checklist
- `tasks/internet-streaming-volume-control/plan.md` - Prerequisites section (line 892+)
- `tasks/internet-streaming-volume-control/state.md` - Blocker documentation (line 49+)
- `tasks/internet-streaming-volume-control/todo.md` - Prerequisite table (line 11+)
