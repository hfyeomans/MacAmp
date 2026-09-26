# Research: GitHub Issues Triage

> **Status:** STUB — research not started (scaffolded 2026-09-05, S4-2).
> **Method per issue:** reproduce on HEAD first, then hypothesize. No fix planning until every issue has a confirmed (or explicitly failed) repro.
> **Gate:** findings feed `plan.md`, which must reach Codex Oracle ≥ 9/10 before any code.

> ⚠️ Re-fetch each issue with `gh issue view <n>` at pickup — comments may have been added since 2026-09-05, and the reporters may have posted skins, screen recordings, or version details.

---

## #84 — Nucleo NLog v2G rendering defects (@morozov, 2026-05-16)

### Repro
TBD — obtain the **Nucleo NLog v102** skin, load it, capture the defects against the same windows under the default skin.

### Hypothesis
TBD

### Subsystem
TBD — expected `Skins/` (parsing, `SpriteResolver`, `region.txt` / `pledit.txt`). Cross-check `docs/WINAMP_SKIN_VARIATIONS.md`.

---

## #79 — Can't drag files, or open by doubleclick (@MatteAce, 2026-04-11)

### Repro
TBD — three separate paths to test independently: drag onto the window, drag onto the Dock icon, double-click a file in Finder. Also check Cmd+O, which restricts the panel to `[.audio]` (`AppCommands.swift:99`).

### Hypothesis
TBD

### Subsystem
TBD — expected document-type registration (`Info.plist` / `project.yml`), drag-destination registration, `NSApplicationDelegate` open-file handling.

---

## #78 — Windows can't be permanently joined/clamped, no minimization (@Crater-Dude, 2026-04-08)

### Repro
TBD — four distinct sub-symptoms, verify each separately: (1) playlist detaches when the player moves, (2) minimization does nothing, (3) window positions not persisted, (4) EQ window closed on every launch.

### Hypothesis
TBD — likely overlaps the long-standing "Hide Main Window not working" deferred item (`DockingController.toggleMain()` flips an internal `visible` boolean that is never wired to the `NSWindow`).

### Subsystem
TBD — expected `DockingController`, `WindowVisibilityController`, `NSWindow` subclasses, `AppSettings` persistence.

---

## #47 — Keyboard shortcut conflict: Cmd+Shift+1-3 (@hfyeomans, 2026-02-10)

### Repro
TBD — enumerate every binding of Cmd+Shift+1/2/3 and confirm which wins.

### Hypothesis
TBD

### Subsystem
TBD — expected `AppCommands` / menu + shortcut map.

---

## P-6 (internal) — Video→audio transition does not auto-play

### Repro
TBD — play a video, then load an audio track; expected auto-play, observed silence until Next. Audio→audio is fine. **Re-confirm against HEAD after S3-2 PR #C merges** — the pivot may have moved this.

### Hypothesis
TBD — carried from `tasks/avplayer-native-video-dsp/placeholder.md` P-6: either `.video → .audio` cleanup leaves transport state that no-ops the `play()`, or async `loadAudioFile` races the immediate `play()`.

### Subsystem
TBD — expected `Audio/AudioPlayer.swift`, `Audio/PlaybackCoordinator.swift`, `Audio/VideoPlaybackController.swift`.

---

## Cross-issue notes

TBD — shared root causes, ordering constraints, file-conflict map between the per-issue branches.
