# MacAmp Current State

Updated: 2026-10-02

This file holds the current state, the decisions in force and the owner decisions pending. Related files in `tasks/_context/`:

- `plan.md`: the roadmap (S3-3 onward).
- `todo.md`: the checklist derived from `plan.md`.
- `deferred.md`: every deferred item and its slot.
- `research.md`: findings that still apply.
- `depreciated.md`: superseded approaches; archived docs live in `depreciated/`.
- `tasks_index.md`: the task folders and their status.
- `principles.md`: the rules every refactor follows.
- `resume-prompt.md`: how to pick up work in a new session.

History lives in git and `tasks/done/`.

## Snapshot

| Item | Value |
|------|-------|
| Release | v2.0, build 14, tagged 2026-09-28 (`v2.0` at `6703b8c`) and shipped as a notarized `MacAmp-2.0.dmg` ([release page](https://github.com/hfyeomans/MacAmp/releases/tag/v2.0)). `project.yml` sets MARKETING_VERSION 2.0 and CURRENT_PROJECT_VERSION 14. The release recipe is in `docs/RELEASE_BUILD_GUIDE.md`. |
| Platform | macOS 27.0 minimum, Apple Silicon (arm64) only. |
| Toolchain | Xcode 27.0 (27A5194q) with Swift 6.4, on host macOS 27.0 (26A428). Language mode is Swift 6.2 (`SWIFT_VERSION 6.2`, `SWIFT_STRICT_CONCURRENCY complete`). `project.yml` still says `xcodeVersion: '26.0'`; this has no effect on the build. |
| Build | XcodeGen builds from `project.yml`; `MacAmpApp.xcodeproj` is generated and gitignored. Packages are ZIPFoundation (`from: 0.9.20`) and swift-atomics (`from: 1.2.0`), resolved to 0.9.20 and 1.3.0 in root `Package.resolved`, the only tracked lockfile. |
| Code | `MacAmpApp/` has 121 `.swift` files. The largest are `Audio/AudioPlayer.swift` (1,097 lines) and `Audio/Streaming/StreamDecodePipeline.swift` (825). |
| `main` | At `30d9de3` (PR #91 merge), in sync with `origin/main`. |
| Open PRs | None. #92 (#86 test fix) merged as `f7c480c`; #91 (dead code and the Appearance Mode preferences) merged as `30d9de3`. |
| Tests | 137 tests in 21 suites passed under TSan on PR #91's head (2026-10-02). #86 is fixed: the navigation test pins repeat mode. |
| Active work | Nothing is being implemented. Next is S3-3 `hls-streaming-support` (plan approved at Oracle 9.0/10), starting with pre-flight PF.3. Then S3-4, the Structure Sprint and S4 (see `plan.md`). |
| Docs | The index is `docs/README.md`. `docs/diagrams/` holds 11 Excalidraw diagrams with PNG exports. |

## Open issues

| # | Title | Slot |
|---|-------|------|
| #47 | Keyboard shortcut conflict: Cmd+Shift+1-3 (skins vs window toggles) | S4-2 |
| #79 | Can't drag files, or open by double-click | S4-2 |
| #84 | Nucleo NLog v2G rendering defects | S4-2 |
| #88 | Video: multichannel (5.1+) output with speaker-side balance | S4-4 |
| P-6 | Video-to-audio transition does not auto-play. Internal item, not filed on GitHub. | S4-2 |

## Branches of note

| Branch | Head | State |
|--------|------|-------|
| `feat/video-audio-engine-routing` | `5af91eb` | The paused S3-2 attempt (Phase 7 partial). Kept on origin and locally as a reference. |
| Origin cleanup | various | 70 branches to delete: 68 merged (including `fix/window-docking-78` and `fix/86-test-repeat-mode`) plus 2 never merged (`docs/review-uncommitted-docs`, superseded scaffolding; `spike/avplayer-inplace-tap-dsp`, the S3-2 Phase 0 spike, findings in `tasks/done/avplayer-native-video-dsp/research.md`). The GH013 ruleset refuses deletion from the CLI; commands are in the gitignored `tmp/branch-cleanup.md` (owner decision 1). |
| Local branches | | Cleaned 2026-10-02: only `main`, `feat/video-audio-engine-routing` and (until its archive commit lands) `review/codebase-audit-2026-09` remain. |

## Local-only files

- `chats/`: chat and session transcripts, gitignored.
- `CLAUDE.md`, `AGENTS.md` and `GEMINI.md`: gitignored.
- `module-cache/` and `weak_struct`: untracked in `b3894d9` and now ignored.
- No git history purge (owner, 2026-10-02): the transcript and module cache stay in history (`95ebc06`, `5c4b8fa`); the transcript holds no secrets, and a purge would rewrite 684 commits and every release tag.

## Decisions in force

### Sequencing

- **D-STRUCTURE (2026-03-15):** every file move happens in one Structure Sprint, which starts after S3-4 merges. Until then, decomposition splits files in place.
  - Why: a move touches `project.yml`, imports, bundle resource paths and test references. That stops all other work and conflicts with every open feature branch, so one pass after decomposition is lower risk.
- **Placement policy (part of D-STRUCTURE):** `tasks/swift-project-structure-research/` is the reference. A new file goes to its target owner (App, Core, Shared, Features, Audio, Windowing or Resources), not into the top-level `Utilities/` or `ViewModels/` without a documented exception.
  - Why: the layout should not get worse before the sprint.
  - Files that broke the policy after 2026-03-15 are covered by the SS-0 mapping.
- **S3 order:** S3-3 (HLS) merges before S3-4 (OGG).
  - Why: both edit `StreamDecodePipeline.swift`. OGG goes last because it also touches `project.yml` and vendored C, and it rebases using HLS plan §17.1.2.
- **D-S4 (owner, 2026-09-05):** GitHub-issue fixes land after the Structure Sprint, and S4-1 runs before S4-2.
  - Why: the fixes should land in the new layout rather than be rebased across a file-move sprint, and S4-1's deprecation findings may change how they are done.
  - S4-1's research half touches no code and may run any time. S4-2 stays hard-gated.
- **D-WIN78 (owner, 2026-09-26):** the only exception to D-S4. #78 and the off-screen-windows-after-sleep problem were pulled ahead because they are windowing problems. Done in #90; follow-ups are in `windowing-structure-consolidation`.

### Platform and build

- **D-TARGET27 (owner, 2026-09-25):** minimum macOS 27.0, Apple Silicon only. v1.3 is the last release for macOS 15/26, and users on those systems stay on it.
  - Why: it unlocks the macOS 27 APIs the video tap uses (`MTAudioProcessingTapCreateWithPreferredFormat`, whole-mix taps) and `InlineArray`/`Span` without availability gates.
  - Implemented in PR #87. It turned S4-1 into an adoption task.
- **Language mode:** Swift 6.2 (`SWIFT_VERSION` 6.2, swift-tools-version 6.2, strict concurrency complete) on the Swift 6.4 toolchain. Moving to 6.4 needs a separate S4-1 ADR.
- **Build source of truth:** `project.yml`. Because `.xcodeproj` is gitignored, pbxproj is no longer a merge-conflict surface.
- **Root `Package.swift`:** unbuildable since `80540c2`, and nothing runs `swift build`. S3-4 decides its fate and acts in commit C1 on `feat/ogg-vorbis-support`, not on the throwaway spike branch. Because root `Package.resolved` is the only tracked lockfile, the same change pins exact ZIPFoundation and swift-atomics versions in `project.yml`. Fallback slot: S4-1. Detail: `plan.md` S3-4.
- **ZIPFoundation stays at 0.9.20 or later.** 0.9.19 crashes TSan at skin load.

### Process

- **Spike policy:** Phase 0 spikes run on throwaway branches. Findings go into the task's `research.md`, and the branch is then deleted, so spike code never reaches `main`. Known exception: `spike/avplayer-inplace-tap-dsp` (owner decision 5, recommended delete).
- **Manual-gate rule (from S3-2; applies to the S3-3 and S3-4 manual gates):** a manual-gate FAILURE produces an ADR amendment and a targeted retry, never a soft-skip.
- **Workflow:**
  - One task per branch and PR.
  - Before each PR, run one exhaustive `/codex:review --base main` and fix what affects correctness. Before running another round, say what it would chase and what it costs.
  - No Oracle gates: per-commit reviews were dropped 2026-09-24 and the plan-level ≥9/10 gate on 2026-10-02 (owner). The PR plus one `/codex:review` replaces both.
  - The owner reviews, merges and deletes branches; the GH013 ruleset blocks branch deletion from the CLI.
  - `_context` docs are committed directly to `main`. Nothing is committed or pushed unless the owner asks.
- **Verification:**
  - After each phase, run `xcodegen generate`, then `xcodebuildmcp macos build` and `xcodebuildmcp macos test`, each with `--json '{"extraArgs":["-enableThreadSanitizer","YES"]}'`. Pass it on every invocation, because no session default works.
  - The baseline is 137 tests in 21 suites.
  - Inside the Claude Code sandbox, SwiftPM's `sandbox-exec` is refused, so run tests unsandboxed:
    `xcodebuild test -scheme MacAmpApp -destination 'platform=macOS' -enableThreadSanitizer YES -derivedDataPath build/DerivedDataDev -IDEPackageSupportDisableManifestSandbox=YES -IDEPackageSupportDisablePluginExecutionSandbox=YES`
    This kills a running MacAmp.
- **Task folders:** each task folder has six files: `state.md`, `research.md`, `plan.md` (created when planning starts), `todo.md`, `placeholder.md` and `depreciated.md`. `depreciated.md` is the standard spelling; review-bot comments flagging the spelling are false positives. A finished folder moves to `tasks/done/`.
- **Deferred items** are tracked in `tasks/_context/deferred.md`, never only in a task file or a PR comment.
- **Swift and platform level (owner, 2026-10-02):** code must build in Swift 6.2 language mode, prefer Swift 6.4 idioms where 6.2 allows them, and use macOS 27 APIs without availability gates below 27, so the S4-1 language-mode switch needs no rework.
- **Comments:** production comments are at most one line and never cite reviews, PR numbers or ADR ids.
- **Refactors** follow Principles 1-7 and the pre-decomposition gate in `principles.md`.

### Architecture invariants

- **Audio paths:** local audio and streams go through AVAudioEngine. Streams use URLSession, AudioFileStream, AudioConverter and LockFreeRingBuffer, feeding an AVAudioSourceNode.
  - Local video gets in-place DSP inside AVPlayer's own `MTAudioProcessingTap` (`Audio/VideoDSP/`, stereo at the source rate, ADR-12): no ring, no engine clock, no second SRC, and AVPlayer keeps its clock and route handling.
  - HLS audio joins the engine path. HLS video is out of scope.
- **Streaming taps:** `MTAudioProcessingTap` does not fire for streaming AVPlayerItems (Apple QA1716, confirmed for SHOUTcast and Icecast). All streaming audio, including HLS, therefore uses the custom decode path.
- **Video tap rules:** `audioMix` is set while the AVPlayerItem is being built, never on an existing item. EQ and balance reach the tap only through `installCoefficients` and the atomics.
- **Duplicated DSP math, on purpose:**
  - EQ math exists twice: AVAudioUnitEQ on the engine path and `BiquadCascade` on the tap path, because their threading and ownership differ (Principle 4).
  - RMS/Goertzel is also duplicated (S3-2 ADR-6); the FFT is shared.
  - Add a parity test before changing either one.
- **ADR-3a:** `@unchecked Sendable` is contained by three gates: a header contract, the `RenderThreadSafe` marker and DEBUG gate tests. `VideoTapContext`, `VisualizerFeed`, `VisualizerScratchBuffers` and `BiquadCascade` follow it; `DecodeContext` is next (SS-2).
- **Windows:**
  - `DockGraph` is the single docking model. `followResize` handles shade and double size, and `snapToMany` picks the nearest edge.
  - `WindowScreenGuard` owns recovery after sleep/wake and display changes.
  - Group minimize lives in `WindowVisibilityController`.
  - See `docs/MULTI_WINDOW_ARCHITECTURE.md` § Docking, Recovery, Minimize & Windowshade.
- **Playback progress:** the engine file duration (frames / sample rate) is authoritative for audio progress. AVAsset metadata duration is used only for the playlist display and as the fallback before a file loads.

## Under re-evaluation

- **D8 (keep AudioPlayer whole, Option C):** under re-evaluation in SS-1; two of its three triggers (size, new responsibility) have fired, the testability trigger has not. See `tasks/audioplayer-seek-extraction/state.md`.

## Owner decisions pending

1. Delete the merged branches on origin: the GH013 ruleset ("restrict deletions") refuses it from the CLI. Add a bypass or disable that rule temporarily and run the commands in `tmp/branch-cleanup.md`, or use GitHub's Branches page.
2. S3-4 scope, after the 2026-10-02 live check (`tasks/ogg-vorbis-support/research.md`, Gate G1b): Ogg Vorbis is about 1.5% of Icecast directory streams and under 1% of listeners; none of the plan's reference stations (SomaFM, Radio Paradise, BBC) still serve Vorbis; no live station changed format at a chain boundary. Options: (a) full S3-4 as planned (local files and streams); (b) local `.ogg` files only, deferring Ogg streaming to the backlog, which skips the StreamDecodePipeline backend/lifecycle changes; (c) defer S3-4 entirely. Recommended: (b), since local playback is the Winamp-fidelity value and the streaming half carries most of the risk for little use. Either (b) or (c) needs a short plan revision before Phase 0.

## Shipped

Newest first; dates are git local dates.

| Date | Sprint / wave | PRs / commits |
|------|---------------|---------------|
| 2026-10-02 | Amp review cleanup | #91 (`30d9de3`): dead EQ code and the Appearance Mode preferences, with the Preferences window and Cmd+,. #92 (`f7c480c`): #86 test fix (AT-1). `b3894d9`: transcripts to the gitignored `chats/`; `module-cache/` and `weak_struct` untracked. `_context` rebuilt (`4654aa5`). |
| 2026-09-28 | Docs diagrams | `f12bb7b`: 11 Excalidraw diagrams with PNGs in `docs/diagrams/`. |
| 2026-09-28 | v2.0 release, build 14 | Tag `v2.0` (`6703b8c`). Contains #77, #80-#83, #87, #89 and #90. |
| 2026-09-28 | S4-2a `window-docking-78` (D-WIN78) | #90 (`88ba342`), which closed #78. |
| 2026-09-25 | S3-2 `avplayer-native-video-dsp` | #89 (`ae15f5c`). It also brought the engine configuration observer to `main`. |
| 2026-09-25 | D-TARGET27, minimum macOS 27 | #87 (`c79c2ca`). |
| 2026-04-28 to 04-30 | S3-1 and follow-ups | #80 `mainwindow-visualizer-isolation` (`7f3d76f`), #82 `stream-pause-tail` (`b60fd57`), #81 `timer-runloop-mode-audit` (`ac09dd4`), #83 Butterchurn timer callbacks (`1d24258`). |
| 2026-03-27 | EQ frequency accuracy | #77 (`a632c44`). |
| 2026-03-26 | v1.3 release | Tag `v1.3` (`5ac294a`). |
| 2026-03-24 to 03-25 | Post-S2 decomposition | #71-#76. |
| 2026-03-22 to 03-24 | S2 | #66-#70. |
| 2026-03-22 | S1 and v1.2 | #60-#64, plus #65 (v1.2 docs and release). |
| 2026-03-14 | S0 | #59. |
| 2026-02-14 to 03-14 | Waves 1-3 | #48-#58. |
