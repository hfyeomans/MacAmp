# Research: GitHub Issues Triage (S4-2)

Updated: 2026-10-02

**Status:** Not started.

**Method:** reproduce each item on HEAD before forming a hypothesis, and plan no fix until every item has a confirmed or explicitly failed repro. Re-fetch each issue with `gh issue view <n>` at pickup; reporters may have added skins, recordings or version details.

Anchors below are from `main` at `b3894d9`. The Structure Sprint will move files, so re-resolve them at pickup.

## #47: Cmd+Shift+1-3 shortcut conflict

### Leads

- Window toggles: Show/Hide Main, Playlist and Equalizer on Cmd+Shift+1/2/3 (`MacAmpApp/AppCommands.swift:14-19`).
- Skin switching: `keyboardShortcut(for:)` gives bundled skins Cmd+Shift+1-9 (`MacAmpApp/SkinsCommands.swift:80`, applied at `:28`).

### Repro

TBD. Enumerate every Cmd+Shift+1/2/3 binding and confirm which one wins.

### Hypothesis

TBD.

## P-6: video to audio does not auto-play

Discovered 2026-05-28 during the S3-2 todo 2.40 leak check. Full record: `tasks/done/avplayer-native-video-dsp/placeholder.md` (P-6). Listed as a known issue in `docs/VIDEO_WINDOW.md:321-322`.

### Leads

- The `.video → .audio` path in `AudioPlayer.playTrack` runs `invalidateInFlightVideoLoad()`, `pauseAndDetachVideoTapIfNeeded()` and `videoPlaybackController.cleanup()` (`MacAmpApp/Audio/AudioPlayer.swift:547-549`), then `loadAudioFile` (`:562`) and `play()`.
- Suspects: the cleanup leaves transport state that turns `play()` into a no-op, or the async `loadAudioFile` races `play()`. Likely fix: fire `play()` after the teardown and engine-ready complete.

### Repro

TBD. Play a video, then start an audio track; expected auto-play. Audio to audio works. The S3-2 gate 8.14 run did not observe it either way, so re-confirm on HEAD.

## #79: drag-and-drop and double-click open

### Leads

- Dropping onto the window, the Dock icon and the app icon does nothing. Finder double-click fails, and "Open With" shows MacAmp greyed out.
- `MacAmpApp/Info.plist` `CFBundleDocumentTypes` (`:47-68`) registers only Winamp skins (`wsz`, `public.zip-archive`), with no audio or video document types.
- No `onDrop` or `dropDestination` handlers exist in `MacAmpApp/`.
- Cmd+O limits the open panel to `[.audio]` (`MacAmpApp/AppCommands.swift:107`), so video files cannot be opened that way.

### Repro

TBD. Test each drop target, Finder double-click, "Open With" and Cmd+O with a video file separately.

### Hypothesis

TBD. Expected areas: document-type registration (`Info.plist` / `project.yml`), drop destinations, `NSApplicationDelegate` open-file handling, `AppCommands`.

## #84: Nucleo NLog v2G rendering defects

### Repro

TBD. Obtain the Nucleo NLog v102 skin and capture the defects next to the same windows under the default skin.

### Hypothesis

TBD. Expected: skin-variation parsing or sprite handling in `MacAmpApp/Skins/`, `SpriteResolver`, `region.txt` / `pledit.txt`. Cross-check `docs/WINAMP_SKIN_VARIATIONS.md` and `docs/SPRITE_SYSTEM_COMPLETE.md`.

## `timeControlStatus` residual

`VideoPlaybackController` does not observe `AVPlayer.timeControlStatus` (no references in `MacAmpApp/`), so an external pause of the video `AVPlayer` is not mirrored in the UI. Found during the S3-2 Phase B route gates.

## RemoteLayerTreeDisplayLinkClient watch item

"RemoteLayerTreeDisplayLinkClient stuck 0.50s" main-thread warnings appeared only while LLDB had the app paused. If they recur with no debugger attached, treat them as a main-thread-hang UI-performance item; the suspect is the Butterchurn WebView plus SwiftUI at 2x.

## Cross-issue notes

TBD: shared root causes and the file-conflict map between the per-item branches.
