# Resume Prompt

> **Purpose:** One-stop pickup for a fresh session. Keep it to the current state and the next action; history belongs in `tasks/done/<task>/` and `tasks/_context/state.md`.
>
> **How to use:** paste *"Read `tasks/_context/resume-prompt.md` and follow it."*
>
> **Last update:** 2026-10-02

---

## Current State

- **Release:** MacAmp **v2.0** (build 14) shipped 2026-09-29 — notarized DMG on the [release page](https://github.com/hfyeomans/MacAmp/releases/tag/v2.0). `project.yml`: `MARKETING_VERSION 2.0`, `CURRENT_PROJECT_VERSION 14`. Recipe: `docs/RELEASE_BUILD_GUIDE.md`.
- **Platform:** macOS 27+, Apple Silicon only; Xcode 27 / Swift 6.4 toolchain, Swift 6.2 language mode, strict concurrency.
- **`main`:** clean, synced with `origin/main`. Last merged PR: **#90** (`window-docking-78`, `88ba342`). No PRs open.
- **Tests:** 137 tests in 21 suites under TSan; only the pre-existing **#86** (`PlaylistNavigationTests` repeat-mode leak from real UserDefaults) can fail.
- **Open GitHub issues:** #47, #79, #84 (→ S4-2), #86 (test), #88 (→ S4-4).
- **Recently closed:** S4-2a `window-docking-78` (PR #90, `tasks/done/window-docking-78/`); S3-2 `avplayer-native-video-dsp` (PR #89, `tasks/done/avplayer-native-video-dsp/`).
- **amp code review (2026-10-02):** verified against `main`; stale claims dropped, small dead code removed, the rest deferred to planned tasks — table in `state.md` § "From the amp code review".
- **Docs:** index `docs/README.md`; simplified diagrams in `docs/diagrams/` (`.excalidraw` + PNG).
- **Local-only files:** chat/session transcripts go in the gitignored `chats/` folder; `CLAUDE.md`/`AGENTS.md`/`GEMINI.md` are gitignored.

### Waiting on the owner

- Delete the merged origin branch `fix/window-docking-78` (the GH013 ruleset blocks deletion from the CLI).
- Decide whether `spike/avplayer-inplace-tap-dsp` (`dd53d64`, not in `main`) can be deleted from `origin`.
- Decide the Appearance Mode (Material/Liquid Glass) preferences: keep for S4-1 or remove (they only restyle the Preferences window).

### Reference branches (not merged, keep)

- `feat/video-audio-engine-routing` @ `5af91eb` — the paused engine-routing attempt at S3-2; reference for channel mapping, tap callbacks, TSan test patterns.

---

## Work Queue (start at the top)

1. **NEXT — S3-3 `tasks/hls-streaming-support/`.** Audio-only HLS (M3U8 master + media playlists, AAC ADTS segments, live + VOD); new `MacAmpApp/Audio/HLS/` feeding `DecodeContext.handleIncomingData` through an injected closure. Plan Oracle-approved 9.0/10 (2026-04-27) — it predates S3-2, macOS 27 and Swift 6.4, so pre-flight PF.3–PF.5 must re-read every "Files Affected" source at HEAD. PF.1/PF.2 are satisfied (S3-2 shipped as the in-place tap pivot). Branch `feat/hls-streaming-support`.
2. **S3-4 `tasks/ogg-vorbis-support/`.** Rebase its plan on post-HLS HEAD (HLS plan §17.1). Phase 0a also decides the root `Package.swift` (it cannot build; recommended: delete it).
3. **Structure Sprint** (after S3-4 merges): `windowing-structure-consolidation` (with its #78 and amp follow-ups in `todo.md`), the Features/ and Audio/ moves, and re-evaluating the fired file-growth triggers (`AudioPlayer.swift`, `StreamDecodePipeline.swift`).
4. **S4-1 `swift64-macos27-readiness`** (adoption: 16 macOS-27 deprecations, strict memory safety, the `Skin` `@unchecked Sendable` and `LockFreeRingBuffer` overrun race) → **S4-2 `github-issues-triage`** (#84, #79, #47, P-6) → S4-3 `airplay-route-picker` → S4-4 `video-multichannel-output` (#88, unblocked). S4-1's research half may run earlier.
5. **Any time:** `timer-scheduled-on-common-extension` (no folder yet); Backlog `visualizer-fidelity-audit`.

Full tables: `tasks/_context/tasks_index.md`; decisions and deferred items: `tasks/_context/state.md`.

---

## Pickup Process (per task)

1. Read `tasks/_context/state.md` and `tasks/_context/principles.md`, then the task folder's canonical files (`research.md`, `plan.md`, `todo.md`, `state.md`, `placeholder.md`, `depreciated.md`).
2. Re-read every "Files Affected" source at HEAD and reconcile drift before Phase 1.
3. `git status` clean; branch from `main`.
4. After each phase, build and test with TSan (per invocation; no session default works):
   ```bash
   xcodegen generate
   xcodebuildmcp macos build --json '{"extraArgs":["-enableThreadSanitizer","YES"]}'
   xcodebuildmcp macos test  --json '{"extraArgs":["-enableThreadSanitizer","YES"]}'
   ```
   In the Claude Code sandbox SwiftPM's own `sandbox-exec` is refused; run unsandboxed `xcodebuild test -scheme MacAmpApp -destination 'platform=macOS' -enableThreadSanitizer YES -derivedDataPath build/DerivedDataDev -IDEPackageSupportDisableManifestSandbox=YES -IDEPackageSupportDisablePluginExecutionSandbox=YES`. `xcodebuild test` kills a running MacAmp — relaunch it afterwards.
5. One exhaustive `/codex:review --base main` before the PR; fix what affects correctness.
6. Push, `gh pr create`, and stop — the owner reviews and merges.
7. Close-out after merge: task `state.md` → MERGED; `git mv tasks/<task> tasks/done/`; update `_context/state.md`, `tasks_index.md` and this file.

Conventions: comments are one line max and never cite reviews/PRs/ADR ids; deferred items go in `_context/state.md`, never only in a task file; never bypass git hooks without asking.

---

## Invariants that still bite

- **Audio:** local audio + streams go through `AVAudioEngine`; local video gets in-place DSP in AVPlayer's `MTAudioProcessingTap` (`Audio/VideoDSP/`). HLS audio joins the engine path; HLS video is out of scope. Set `audioMix` while building the `AVPlayerItem`, never on an existing item. EQ/balance reach the video tap only via `installCoefficients` and the atomics.
- **Windows:** `DockGraph` is the one docking model (`followResize` for shade and double size; `snapToMany` picks the nearest edge); `WindowScreenGuard` owns sleep/wake/display recovery; group minimize lives in `WindowVisibilityController`. See `docs/MULTI_WINDOW_ARCHITECTURE.md` § Docking, Recovery, Minimize & Windowshade.
- **Dependencies:** ZIPFoundation must stay ≥ 0.9.20 (0.9.19 crashes TSan at skin load).

---

## First Action

Open `tasks/hls-streaming-support/`, follow the Pickup Process, run pre-flight PF.3–PF.5 against HEAD, then cut `feat/hls-streaming-support`. Report back before pushing the PR.
