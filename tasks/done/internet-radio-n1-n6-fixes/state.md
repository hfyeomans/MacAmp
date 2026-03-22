# State: Internet Radio N1-N6 Fixes

> **Purpose:** Tracks the current state of the task including progress, blockers, decisions made, and open questions.

---

## Current Status: COMPLETE -- All 6 fixes implemented, Oracle-verified, committed on `fix/internet-radio-n1-n6`

## Branch

`fix/internet-radio-n1-n6` -- 7 commits (6 fixes + 1 SwiftLint cleanup)

## Commit History

| Commit | Fix | Description |
|--------|-----|-------------|
| 9c5b530 | N1 (HIGH) | Context-aware playlist navigation during stream playback |
| a4d60ba | N2 (MEDIUM) | Derive play state from active audio source (computed properties) |
| 862fc09 | (lint) | Resolve pre-existing SwiftLint violations in WinampMainWindow |
| 983b363 | N5 (MEDIUM) | Bind main window indicators to PlaybackCoordinator |
| 79db5a5 | N4 (LOW) | Preserve stream metadata during initial connection |
| 87cc107 | N6 (LOW) | Show live ICY metadata in Track Info dialog |
| 3f3effd | N3 (LOW) | Split externalPlaybackHandler into two callbacks |
| 5f2cef2 | N3 + lint | Complete N3 comment in WinampPlaylistWindow + resolve 20 lint violations |

## Progress

- [x] Task created with 6-file structure
- [x] Research synthesized from `internet-radio-review` and `internet-streaming-volume-control` task findings
- [x] Plan written (3-phase: N1 critical, N2+N5 recommended, N4+N6+N3 deferred)
- [x] Todo checklist created
- [x] Branch created: `fix/internet-radio-n1-n6`
- [x] Oracle review of plan + todo (gpt-5.3-codex, xhigh reasoning, 2026-02-21)
- [x] 5 Oracle corrections applied (1 HIGH, 3 MEDIUM, 1 LOW)
- [x] User approval
- [x] Phase 1 implementation (N1) -- commit 9c5b530, Oracle-verified PASS
- [x] Phase 2 implementation (N2 + N5) -- commits a4d60ba + 983b363, Oracle-verified PASS
- [x] Pre-existing SwiftLint debt resolved (WinampMainWindow) -- commit 862fc09
- [x] Phase 3 implementation (N4, N6, N3) -- commits 79db5a5 + 87cc107 + 3f3effd
- [x] Full branch Oracle review -- PASS (gpt-5.3-codex, xhigh, 2026-02-21)
- [x] Manual app smoke test -- no visual regressions observed
- [ ] Full manual regression testing (local + stream + mixed playlist)
- [ ] Downstream task unblocked (`internet-streaming-volume-control`) -- pending PR merge

## Key Decisions

1. **Phase ordering:** N1 (HIGH) first, then N2 before N5 (N5 depends on N2's computed properties), then N4+N6+N3 (LOW)
2. **N2 approach:** Computed properties deriving from active source, with `&& !isBuffering` guard for streams (Oracle correction #1)
3. **N2 isPaused for streams:** `!isPlaying && !isBuffering && error == nil` -- distinguishes user-pause from buffering stall and error
4. **N5 line 844:** Keep as `audioPlayer.isPlaying` -- scrubbing is local-file-only
5. **N3 approach:** Split into `onTrackMetadataUpdate` + `onPlaylistAdvanceRequest` (Oracle correction #2)
6. **N6 gate:** Use `case .radioStation = currentSource` instead of `currentTitle` to prevent idle-state regression (Oracle correction #3)
7. **N1 nil context:** Always call `updatePosition(with: track)` including nil, to clear stale index for direct station playback (Oracle correction #4)
8. **SwiftLint cleanup:** Extension-based split was tactical fix; Gemini + Oracle both recommend layer subview decomposition as follow-up

## Oracle Reviews

| Review | Model | Reasoning | Verdict | Corrections |
|--------|-------|-----------|---------|-------------|
| Plan review | gpt-5.3-codex | xhigh | NEEDS CORRECTIONS | 5 issues (1 HIGH, 3 MEDIUM, 1 LOW) -- all applied |
| N1 verify | gpt-5.3-codex | xhigh | FAIL -> PASS | Nil-context edge case found and fixed |
| N2 verify | gpt-5.3-codex | xhigh | PASS | No issues |
| N5 verify | gpt-5.3-codex | xhigh | PASS | No issues |
| Full branch | gpt-5.3-codex | xhigh | PASS | 1 LOW (access widening noted) |
| Architecture | gpt-5.3-codex | xhigh | Advisory | Recommends layer subview decomposition |
| Architecture | Gemini CLI | — | Advisory | Converges with Oracle on subview + @Observable pattern |

## Blockers

### Active Blockers
- None. All 6 fixes are implemented and committed.

### Downstream Impact
- `internet-streaming-volume-control` Phase 1 is unblocked once this branch is merged to main.

## Files Modified

| File | Fixes | Commits |
|------|-------|---------|
| `PlaylistController.swift` | N1 | 9c5b530 |
| `AudioPlayer.swift` | N1, N3 | 9c5b530, 3f3effd |
| `PlaybackCoordinator.swift` | N1, N2, N3 | 9c5b530, a4d60ba, 3f3effd |
| `StreamPlayer.swift` | N4 | 79db5a5 |
| `WinampMainWindow.swift` | N5, lint | 862fc09, 983b363 |
| `WinampMainWindow+Helpers.swift` | lint (NEW) | 862fc09 |
| `TrackInfoView.swift` | N6 | 87cc107 |
| `WinampPlaylistWindow.swift` | N3 comment (unstaged) | deferred -- pre-existing lint debt |
| `MacAmpApp.xcodeproj` | lint (new file ref) | 862fc09 |

## Open Questions (Resolved)

1. ~~Does StreamPlayer expose `isBuffering`?~~ **YES** (StreamPlayer.swift:122,127)
2. ~~Are there other views reading audioPlayer.isPlaying directly?~~ **Oracle found none beyond WinampMainWindow**
3. ~~Does StreamPlayer expose `error`?~~ **YES** (StreamPlayer.swift:38, type `String?`)
4. ~~Is `currentSource` accessible from TrackInfoView?~~ **YES** (internal access, PlaybackCoordinator is in @Environment)

## Follow-Up Items

1. **WinampMainWindow layer decomposition** (`tasks/mainwindow-layer-decomposition/`) — Gemini + Oracle recommend child subview structs + @Observable interaction state. Task created with full 6-file structure.
2. **WinampPlaylistWindow layer decomposition** (`tasks/playlistwindow-layer-decomposition/`) — Oracle audit confirmed same cross-file extension anti-pattern was repeated. Separate sibling task created.
3. ~~WinampPlaylistWindow.swift comment update~~ **DONE** — Completed in commit 5f2cef2 with lint cleanup.
4. **Manual regression testing** — Full test matrix (local files, streams, mixed playlists, video) should be run before PR merge.

## Architectural Debt Introduced (Documented)

The lint cleanups for WinampMainWindow and WinampPlaylistWindow both used cross-file extensions with widened @State access. Oracle audit (gpt-5.3-codex, xhigh, 2026-02-21) confirmed this is tactical debt:
- **WinampMainWindow:** 7 @State vars + Coords struct widened → tracked in `mainwindow-layer-decomposition`
- **WinampPlaylistWindow:** 6 properties widened → tracked in `playlistwindow-layer-decomposition`

Both tasks follow the same resolution pattern: @Observable interaction state + child view structs.
