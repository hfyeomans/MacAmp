# Tasks Index

Updated: 2026-10-02

Index of task folders only. Order, scope and predecessors live in `plan.md`; current state in `state.md`; deferred items in `deferred.md`.

Status words as defined in `plan.md` (Summary), which is the status source, plus PAUSED for the vaer reference folder (kept as reference, not resumed).

## Active folders (11)

| Folder | Plan id | Status | Purpose |
|--------|---------|--------|---------|
| `hls-streaming-support` | S3-3 | NEXT | Audio-only HLS (M3U8 master/media playlists, AAC ADTS segments, live + VOD) through a new `MacAmpApp/Audio/HLS/`. |
| `ogg-vorbis-support` | S3-4 | BLOCKED | OGG Vorbis for local files and Icecast via vendored libogg/libvorbis, plus the chained-format fix; commit C1 also settles the root `Package.swift` and pins package versions in `project.yml`. |
| `swift-project-structure-research` | SS-0 | QUEUED | Structure Sprint map. Also the approved placement policy and target layout, in force now. |
| `audioplayer-seek-extraction` | SS-1 | DEFERRED | Re-evaluate D8 (Option C) and, if go, extract the seek state machine from `AudioPlayer.swift`. |
| `streamdecodepipeline-decomposition` | SS-2 | DEFERRED | `DecodeContext` extraction and concurrency-contract retrofit; re-baseline after S3-4. |
| `windowing-structure-consolidation` | SS-3 | DEFERRED | Move window infrastructure to `Windowing/`, plus the #78 and amp follow-ups in its `todo.md`. |
| `milkdrop-feature-consolidation` | SS-4 | DEFERRED | Move Milkdrop/Butterchurn code and the repo-root `Butterchurn/` resources to `Features/Milkdrop/`. |
| `swift64-macos27-readiness` | S4-1 | QUEUED | macOS 27 / Swift 6.4 adoption (deprecations, Span/InlineArray, strict memory safety, language-mode ADR), plus the `Skin` Sendable and `LockFreeRingBuffer` overrun amp items. |
| `github-issues-triage` | S4-2 | QUEUED | Fix #47, P-6, #79 and #84, one branch and PR each. |
| `video-multichannel-output` | S4-4 | QUEUED | #88: multichannel/spatial video output with speaker-side balance. |
| `video-audio-engine-routing` | none | PAUSED | First S3-2 attempt (video audio through AVAudioEngine); branch `feat/video-audio-engine-routing` @ `5af91eb`. |

## Roadmap rows without folders

| Plan id | Item | Status | Folder |
|---------|------|--------|--------|
| SS-5 | `Features/` consolidation: MainWindow, Playlist, Equalizer, Video, Preferences, Skins, Radio | QUEUED | `features-consolidation`, created by SS-0 |
| SS-6 | `Audio/` consolidation: Playback/, Streaming/, Equalizer/, Visualization/, VideoDSP/, Persistence/, ObjCBridge/, HLS/, Vorbis/ | QUEUED | `audio-consolidation`, created by SS-0 |
| SS-7 | `App/`, `Core/`, `Shared/` and the composition root | QUEUED | `app-core-shared-consolidation`, created by SS-0 |
| SS-8 | Mirror tests to source layout; last required Structure Sprint step (SS-9 optional) | QUEUED | none; tracked in `swift-project-structure-research/todo.md` |
| SS-9 | Local packages (Windowing, AudioStreamingCore, SkinEngine) | OPTIONAL | none |
| S4-3 | AirPlay route picker: in-app `AVRoutePickerView` over the Winamp logo | QUEUED | `airplay-route-picker`, created when planning starts |
| AT-1 | #86 test isolation: pin `repeatMode` in `PlaylistNavigationTests` | NEXT | none |
| AT-2 | One Timer helper for the 7 `RunLoop.main.add(timer, forMode: .common)` sites | DEFERRED | none; fits `Core/` once SS-7 creates it |
| BL-1 | Visualizer fidelity audit: spectrum analyzer vs real frequencies and Winamp/Webamp | BACKLOG | none; created when started |

## Archive

- `tasks/done/`: 87 entries (85 folders, 2 files), finished tasks. Shipped work is summarized in `state.md` (Shipped).
- `tasks/stale/`: 88 entries (80 folders, 8 files), abandoned work and review scratch, including the paused vaer branch's review-scratch folders.
- `tasks/depreciated/`: 2 folders (`airplay`, `winamp-airplay-overlay`), inputs to S4-3.

## `_context/` file map

| File | Use |
|------|-----|
| `state.md` | Current state only: release, branches, open PRs and issues, test baseline, decisions in force, architecture invariants, owner decisions pending, Shipped table. |
| `plan.md` | Future work in order (S3-3 through BL-1): scope, predecessors, status, amp items per slot. |
| `todo.md` | Checklist derived from `plan.md`; checked only when verifiably done. |
| `deferred.md` | Every deferred item with its slot. Deferred items are never tracked only in a task file or PR comment. |
| `research.md` | Cross-task research findings and gotchas. |
| `depreciated.md` | One line per superseded item, pointing into `depreciated/`. |
| `principles.md` | Decomposition principles 1-7 and the pre-decomposition gate. |
| `instruments-allocations-workflow.md` | In-repo Instruments leak-check procedure; caveats in `research.md`. |
| `tasks_index.md` | This index. |
| `resume-prompt.md` | Pickup prompt for a fresh session. |
| `depreciated/` | Archived `_context` docs: Waves 1-3 plan and research, the S3-2 pivot record, the AVPlayer-bridge deep research, and the stream-loopback / dual-backend lessons. |
