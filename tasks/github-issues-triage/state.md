# Task State: GitHub Issues Triage

> **Purpose:** Triage and fix the issues other users filed on `hfyeomans/MacAmp`, sequenced so the fixes land in the post-Structure-Sprint layout rather than being rebased across a file-move sprint.
> **Created:** 2026-09-05
> **Sprint:** S4-2 (Post-Structure-Sprint)
> **Status:** 📋 **QUEUED** — blocked on the Post-S3 Structure Sprint (user mandate) and on S4-1 `swift64-macos27-readiness` (assumption). Research not started.

---

## Predecessors

| Predecessor | Why | Basis |
|-------------|-----|-------|
| Post-S3 Structure Sprint | The user's mandate: the issue fixes land in the new `.swift` layout, so they are not rebased across a stop-the-world file-move pass. #78 touches windowing and benefits most from the moves having landed. | **User mandate** |
| S4-1 `swift64-macos27-readiness` | S4-1's deprecation findings may change *how* these issues are fixed; fixing first would risk reworking fresh code. | **ASSUMPTION — pending user confirmation.** See `_context/state.md` decision D-S4. |

The Structure Sprint itself starts only after S3-4 `ogg-vorbis-support` merges, which is behind S3-3 `hls-streaming-support`, which is behind the S3-2 PR #C.

---

## Issues in scope

Open on `hfyeomans/MacAmp` as of 2026-09-05 (`gh issue list`; no recently closed issues).

| # | Filed | Author | Title | Summary | Size guess | Likely subsystem |
|---|-------|--------|-------|---------|:----------:|------------------|
| #84 | 2026-05-16 | @morozov | Nucleo NLog v2G rendering defects | Classic-skin rendering defects surfaced by the **Nucleo NLog v102** skin; everything renders correctly under the default skin, so this is a skin-variation parsing/sprite issue rather than a general render bug | Medium | `Skins/` — skin parsing, `SpriteResolver`, `region.txt` / `pledit.txt` handling. See `docs/WINAMP_SKIN_VARIATIONS.md` + `docs/SPRITE_SYSTEM_COMPLETE.md` |
| #79 | 2026-04-11 | @MatteAce | Can't drag files, or open by doubleclick | Dragging onto the window, onto the Dock, and onto the app icon all do nothing. **Related UX gap:** Cmd+O restricts the open panel to `[.audio]` (`MacAmpApp/AppCommands.swift:99`), so video files can't be opened that way either | Medium | App/document lifecycle — drag-and-drop registration, `Info.plist` document types, `NSApplicationDelegate` open-file handling, `AppCommands` |
| #78 | 2026-04-08 | @Crater-Dude | Windows can't be permanently joined/clamped, no minimization | Moving the player detaches the playlist; minimization doesn't work; user wants full window-state persistence (the EQ window closes on every launch). **Likely the largest of the four** | Large | Windowing — `DockingController`, `WindowVisibilityController`, the `NSWindow` subclasses, `AppSettings` persistence. See `docs/MULTI_WINDOW_ARCHITECTURE.md` + `docs/WINDOW_FOCUS_ARCHITECTURE.md`. Note the pre-existing "Hide Main Window not working" deferred item in `_context/state.md` — probably the same wiring gap |
| #47 | 2026-02-10 | @hfyeomans | Keyboard shortcut conflict: Cmd+Shift+1-3 (skins vs window toggles) | The same chord is bound twice — skin selection and window toggles | Small | `AppCommands` / menu + keyboard shortcut map |
| **P-6** | 2026-05-28 | internal | Video→audio transition does not auto-play | After a video plays, loading an audio track does not auto-play (user must hit Next). Audio→audio is fine. Suspected: `.video → .audio` cleanup leaves transport state that no-ops the `play()`, or async `loadAudioFile` races the immediate `play()`. Non-blocking; surfaced in S3-2 Phase 8 gate 8.14 | Small | `Audio/AudioPlayer.swift`, `Audio/PlaybackCoordinator.swift`, `Audio/VideoPlaybackController.swift` |

**P-6 provenance:** carried over from `tasks/avplayer-native-video-dsp/placeholder.md` (P-6) and the "Post-S3-2 `avplayer-native-video-dsp` Findings" section of `_context/state.md`, which records it as still open and needing a dedicated follow-up task. This is that task. It should be re-confirmed against HEAD after PR #C merges — the S3-2 pivot may have moved it.

---

## Approach

**One branch + one PR per issue**, each Oracle-gated per `feedback_sprint_workflow.md` (every sprint task gets Oracle review + a PR for user review before merge, regardless of size). Suggested execution order once unblocked: #47 (smallest, isolated) → P-6 → #79 → #84 → #78 (largest, windowing).

---

## Deliverables

| File | Content |
|------|---------|
| `research.md` | Per-issue reproduction on HEAD + root-cause hypothesis |
| `plan.md` | Per-issue fix plan, one branch/PR each. **Oracle-gated ≥ 9/10 before any code.** |
| `todo.md` | Phase 0 triage → Phase 1 plan → Phase 2 per-issue implementation |

---

## Status log

| Date | Entry |
|------|-------|
| 2026-09-05 | Folder scaffolded. Queued as S4-2. Issue list captured from `gh issue list`. No reproduction attempted yet. |
