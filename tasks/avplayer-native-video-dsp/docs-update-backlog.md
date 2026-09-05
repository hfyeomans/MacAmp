# S3-2 Documentation Update Backlog (for Phase 9 mandatory docs pass)

> **Purpose:** Precise, file-by-file list of what the `docs/` set needs to reflect the S3-2 "AVPlayer-native video DSP" feature (Phases 2–5). Produced 2026-05-28 by a 5-agent team that each read its assigned `docs/` file IN FULL (not excerpts). This is a planning artifact — **no `docs/` edits have been made yet.** Phase 9 (UI polish + mandatory docs) executes this.
>
> **Constraint reminder:** project deploys to macOS 15.0+ and is built with Xcode 27 / Swift 6.4 toolchain in Swift 6.2 language mode (migrated 2026-06-26). Doc language must say `Synchronization.Atomic`/`Mutex` (Swift 6 stdlib), NOT swift-atomics, for the video DSP subsystem.
>
> **Scope gap:** this backlog covers `docs/` only. It omits `CLAUDE.md` and `.ai-shared/macamp/project.md`, which carry the same "all audio through one unified AVAudioEngine" framing and omit `VideoDSP/` — now tracked as todo **9.6b / 9.6c** (agent instructions; higher correction priority than `docs/`).

---

## The one cross-cutting theme (load-bearing)

Every doc repeats some form of **"all audio routes through ONE unified AVAudioEngine"** (EQ/visualizer/balance work for all sources *because* of the single engine). **That thesis is now half-true.** S3-2 adds a **second, parallel DSP path**: local **video** gets EQ + balance + visualizer via an **in-place `MTAudioProcessingTap` on AVPlayer's native pipeline**, NOT through AVAudioEngine. The mental model to thread through all docs is **dual-architecture**:

| Path | Routing | Processing |
|---|---|---|
| Local audio files + streams | AVAudioEngine graph | `AVAudioUnitEQ` + engine balance + engine mixer-tap visualizer (UNCHANGED) |
| Local video | AVPlayer native + `MTAudioProcessingTap` (in-place) | tap-side `BiquadCascade` EQ + tap-side balance + tap-side visualizer feed (NEW) |
| HLS / streaming video | — | OUT OF SCOPE (`MTAudioProcessingTap` unreliable for streaming AVPlayerItems, QA1716) |

Several docs contain statements that are now **flatly false** and must be fixed (highest priority):
- `MACAMP_ARCHITECTURE_GUIDE.md` line ~2662: "`snapshotButterchurnFrame()` … returns nil during video playback (no PCM tap available)" — **false** (video has a tap producer now).
- `MACAMP_ARCHITECTURE_GUIDE.md` line ~3892: video "Audio Routing: Shares audio session with main playback engine" — **false** (native AVPlayer path).
- `VIDEO_WINDOW.md` lines ~319-323: "EQ not available for video playback (AVPlayer limitation)" — **false** (this is the exact UI-lie S3-2 fixes).

---

## New files the docs don't mention yet (add to file inventories / metrics)

- `MacAmpApp/Audio/RenderThreadSafe.swift` (marker protocol)
- `MacAmpApp/Audio/VideoDSP/VideoTapContext.swift`
- `MacAmpApp/Audio/VideoDSP/VideoTap.swift`
- `MacAmpApp/Audio/VideoDSP/BiquadCoefficientSet.swift`
- `MacAmpApp/Audio/VideoDSP/BiquadCascade.swift`
- `MacAmpApp/Audio/VideoDSP/VideoTapVisualizerRender.swift`
- `MacAmpApp/Utilities/WeakBox.swift`
- `MacAmpApp/Audio/VisualizerFeed.swift` + `VisualizerScratchBuffers.swift` (extracted out of `VisualizerPipeline.swift` in Phase 1 — `VisualizerPipeline` shrank from ~699 → ~416 lines)

---

## Per-doc backlog

### 1. `docs/MACAMP_ARCHITECTURE_GUIDE.md` (PRIMARY — biggest surface; ~5,253 lines)

**Phase 9 MANDATE:** add an **"Audio Mechanism Concurrency Contract"** subsection here (this is the explicit Phase 9 deliverable). Recommended placement: inside a new top-level "AVPlayer-Native Video DSP Architecture (S3-2)" section.

**Stale/false (fix):**
- Header/version (~3-5): bump version, add "AVPlayer-Native Video DSP (S3-2)" to State list.
- Exec summary "what makes MacAmp unique" #1 (~36): "all audio … through AVAudioEngine" → dual-architecture.
- Codebase metrics + Component Breakdown table (~56-111): recount files/LoC; add VideoDSP rows; correct `VisualizerPipeline` 699→416.
- Three-Layer Mechanism box (~248-260): add `EqualizerController`, VideoDSP cluster, VideoPlaybackController's tap role.
- Unified Audio Pipeline intro + ASCII diagram (~341-384): qualify "all audio" → "all engine-routed audio"; add the third (video) lane that does NOT converge at the engine.
- `setBalance` routing (~520-542): balance now also fans to registered video-tap Contexts (ADR-5).
- Swift 6 Concurrency table (~1345-1356): rename `VisualizerSharedBuffer`→`VisualizerFeed`; add `VideoTapContext` (@unchecked Sendable, all-atomic), `BiquadCoefficientSet` (Sendable), `RenderThreadSafe`.
- AVAudioEngine Graph + Visualizer Pipeline + **Butterchurn Data Flow** diagrams (~2540-2678): the "returns nil during video" node is FALSE — show video as a producer; dual-producer feed; consumer gates on `isVisualizerRendering`.
- EQ Implementation (~2704-2734): add the tap-side `BiquadCascade` (RBJ, TDF-II, ≤0.5 dB vs AVAudioUnitEQ, fail-closed, denormal flush).
- Package deps (~3157): clarify video DSP uses stdlib `Synchronization`, not swift-atomics.
- Video Window → AVPlayer Integration (~3785-3892): replace bare `AVPlayer(url:)` model with audioMix+tap at item construction (ADR-7); fix "shares audio session with main engine" (false).
- File-structure + line counts throughout (~1182-1302, Quick Reference ~4948-5064).

**New sections:**
- Recent Architectural Changes → new entry #14 "AVPlayer-Native Video DSP (S3-2)".
- New top-level "AVPlayer-Native Video DSP Architecture (S3-2)" after "Audio Processing Pipeline" (~2882): dual-architecture topology table/diagram; video signal flow (`tapProcess`: StartOfStream reset → preamp → isEqOn gate → BiquadCascade → balance → visualizer feed → in-place write-back); DSP details; fanout (ADR-5) + Mutex hand-off (ADR-4 amend #2) + tap lifecycle (ADR-7) + dual-producer visualizer (ADR-6).
- **"Audio Mechanism Concurrency Contract" subsection (MANDATED):** @unchecked Sendable FFI boundary; every field Atomic/Mutex/RenderThreadSafe; enforcement = Gate-1 header contract + RenderThreadSafe marker + 3 contract tests (Mirror / var-regex / .cascade source scan); stdlib Synchronization; Float-as-Atomic<UInt32> via bitPattern; render never blocks (no priority inversion).

**Diagrams (most important new one):** dual-architecture topology (engine path vs AVPlayer-native tap path, HLS-video out-of-scope) + video tap signal chain.

### 2. `docs/IMPLEMENTATION_PATTERNS.md` (~3,799 lines, v2.1.0) — coding patterns

**Stale/false (fix):**
- Line ~1615 (Video Playback Embedding): "AVPlayer (video only) doesn't support audio features (EQ, visualization)" — the central falsehood; rewrite to DSP-parity-via-tap.
- Line ~1992 + refs: `VisualizerSharedBuffer` was **renamed `VisualizerFeed` and extracted** to `VisualizerFeed.swift` — global rename sweep (no `VisualizerSharedBuffer` symbol remains); update file path `VisualizerPipeline.swift:36-146` → `VisualizerFeed.swift`.
- `balance` didSet (~374-380) + Coordinator `setBalance` (~611): now also fan to the video-tap registry (ADR-5); reconcile the "didSet must NOT propagate to other backends" pitfall (~402) into a two-tier model — coordinator fans across *backends*, canonical owner fans to *render taps*.
- Capability flag `supportsAudioProcessing` (~703): video is now genuinely audio-processing-capable (flag's `true` for video is no longer a no-op).
- `loadVideo(url:autoPlay:)` example (~1819): signature is now async `loadVideo(...audioMixBuilder:isStillRelevant:)`.

**Homes:** patterns #1-#4, #7, #8 → "Audio Processing Patterns" (§~1688); #5 → "State Management Patterns" (§~70, near Coordinator Volume Routing ~581); #6 → extend the SPSC Shared Buffer section (~1878) in place. Add TOC entries + bump version to a "(New - S3-2)" tag matching the existing "(New - S1)" convention.

New patterns to add (map to existing sections or new ones):
1. **@unchecked Sendable FFI-boundary containment** — Gate-1 header contract + RenderThreadSafe marker (conformances centralized in one file) + 3 contract tests (Mirror 3a / var-regex 3b / .cascade source-scan 3c).
2. **`Synchronization.Atomic<T>`** usage (Swift 6 stdlib, NOT swift-atomics); Float-as-`Atomic<UInt32>` via bitPattern; memory orderings (.relaxed params, .acquiring/.releasing format gate).
3. **Render-thread coefficient hand-off via `Mutex` + `withLockIfAvailable`** (double-optional three-case handling; copy-out-under-lock then process lock-free; skip-on-contention; never-blocks).
4. **Real-time render-thread discipline** (no heap/ARC/unbounded work in per-sample loop; pre-allocated scratch; denormal flush; manual z1/z2 buffers not Array).
5. **Two-canonical-owner parallel fanout (ADR-5)** with `WeakBox<T>` weak registries (AHA: 2 callers, no shared abstraction).
6. **Dual-producer visualizer (ADR-6)** — two producer functions, one SPSC feed, duplicated RMS/Goertzel + shared FFT.
7. **audioMix-on-construction (ADR-7 amend)** — configure audioMix before AVPlayer adopts the item; async loadVideo + generation-counter orchestrator.
8. **`Unmanaged.passRetained` ↔ `tapFinalize` balance** + release-on-create-failure (ADR-10).

### 3. `docs/VIDEO_WINDOW.md` (~1,151 lines) — most user-facing

**Stale/false (fix):**
- **CRITICAL** lines ~319-323: "EQ not available for video (AVPlayer limitation)" → delete; video audio is DSP-processed in place.
- Layer Architecture (~160-166): add VideoPlaybackController + VideoDSP tap chain to Mechanism.
- Media Type Switching + Part 21 snippets (~326-463): obsolete `AVPlayer(url:)` model → `startVideoLoad`→`loadVideo(audioMixBuilder:isStillRelevant:)`, audioMix-at-construction, generation guard; `addPeriodicTimeObserver`/seek moved to VideoPlaybackController; cleanup must add tap detach + Context unregister + video-visualizer poll-timer stop.
- Header metadata + Summary + Version History (~3-6, 1119-1151): bump to v3.x, add audio-DSP achievements.

**New sections:** "Video Audio DSP Pipeline"; "Tap Lifecycle & the audioMix-at-Construction Invariant (ADR-7)"; "Video Visualizer (Phase 4, ADR-6) + Real-Time EQ/Balance Fanout (Phase 5, ADR-5)"; "Known Issue: Video→Audio Auto-Play (P-6)". Add manual + automated test checklists (cite `VideoTapLifecycleTests`, `VideoTapFanoutTests`, `VideoSeekStateMatrixTests`, `VideoTapSendableContractTests`).

### 4. `docs/MILKDROP_WINDOW.md` (~1,660 lines) — only §9 (Butterchurn Integration) affected

**Stale/false (fix):**
- §9.4 "End-to-End Audio Flow (Local Playback Only)" (~645): drop "Local Playback Only"; same feed driven by video now.
- §9.1 + §9.4 data-flow diagrams (~569-687): single AVAudioEngine source → **two producers** (engine `makeTapHandler` + video `videoTapVisualizerRender`) → shared `VisualizerFeed` → consumer. Fan-in shape.
- §9.4 "Note (S1 update)" ownership chain (~689-694): add S3-2 note — during video NO engine mixer tap; producer is `videoTapVisualizerRender`, 30 Hz poll started via `startVideoVisualization()`.
- Purpose (~16): "music playback" → "music or video playback".

**New sections:** §9.11 "Dual-Producer Audio Feed (ADR-6)"; §9.12 "Video-Driven Visualization Lifecycle". Add the consumer-gating note (`snapshotButterchurnFrame` now gated on `isVisualizerRendering`) + the EQ-ordering invariant (visualizer reflects EQ'd signal). **Editor caveat:** doc shows `getVisualizationSamples(count:)` (line ~725) vs the real `snapshotButterchurnFrame()` — reconcile against code during the edit.

### 5. `docs/MULTI_WINDOW_ARCHITECTURE.md` (~1,382 lines) — mostly UNAFFECTED (window topology unchanged)

- No hard errors. One tension to reconcile: §"Critical: Shared Audio State Pattern" (~232) recommends AGAINST multiple windows reading `AudioPlayer` directly; S3-2's visualizer deliberately does the opposite (one shared `VisualizerView()` in both windows). Add a counterpoint subsection: **"Shared View Component Across Windows"** — `VisualizerView()` is instantiated in BOTH `MainWindowFullLayer` (main) and `WinampPlaylistWindow` (mini-visualizer when main is **shaded**), both reading the same `@Environment(AudioPlayer.self)`; the `isVisualizerRendering` gating flows to both with zero duplication. Valid because the view is internally poll-throttled.

### 6. `docs/README.md` (docs index)

- Reconcile the repeated "all audio through AVAudioEngine / ONE unified engine path" claims (lines ~126, 328, 564, 627, 723) with the AVPlayer-native video path.
- Update Key-Section bullets for ARCHITECTURE_GUIDE / VIDEO_WINDOW / IMPLEMENTATION_PATTERNS / MILKDROP to mention video audio DSP + video-driven visualizer.
- Add Search-Index rows: `isVisualizerRendering`, "AVPlayer-native video DSP", "video EQ + balance", "video drives visualizer", "video audio taps (ADR-5)".
- **Recommendation: do NOT create a standalone "Video Audio DSP" doc** — fold into VIDEO_WINDOW.md (primary) + cross-ref ARCHITECTURE_GUIDE §audio. (If a dedicated doc is later chosen, it must be registered in ALL index blocks + every "12 docs" count → 13.)
- After edits land: update every line-count / metadata block (header ~6, exec summary ~29, category ~115, per-doc sizes, Quality Metrics ~786-805, Statistics ~949-962, footer ~1004-1006) + add a "Recent Update: S3-2" changelog block + bump doc version.

---

## Execution note for Phase 9

Suggested sequencing (per the architecture-guide agent): (1) metrics/file-structure/line-count sweep; (2) add the "Recent Change" entries; (3) write the new Video DSP section + mandated Concurrency Contract subsection + the two key new diagrams; (4) retrofit the "all audio" framing + kill the false "no PCM tap / EQ unavailable" claims across ARCHITECTURE_GUIDE + VIDEO_WINDOW; (5) fanout/balance/visualizer diagram updates; (6) version footers. Run Codex Oracle on the doc diffs before the PR (per project convention). Verify all cited symbols/line numbers against code at edit time (the agents captured them at HEAD `9bce090` on 2026-05-28; branch HEAD is now `056c69a` — they drift).
