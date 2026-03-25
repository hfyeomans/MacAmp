# Research: Responsibility Sweep (SRP + AHA Audit)

> **Description:** Synthesized findings from 5-agent team sweep of all 109 .swift files.
> **Updated:** 2026-03-25 (all agents complete, findings synthesized)

---

## Agent Team Results

| Agent | Files | Clean | Justified | Actionable |
|-------|-------|-------|-----------|------------|
| audio-agent | 16 | 10 | 6 | 0 |
| views-agent | 40 | 28 | 10 | 2 |
| models-agent | 20 | 14 | 4 | 2 |
| viewmodels-agent | 6 | 4 | 1 | 1 |
| infra-agent | 27 | 20 | 5 | 2 |
| **Total** | **109** | **76** | **26** | **7** |

**69.7% Clean, 23.9% Justified, 6.4% Actionable.**

The codebase is architecturally healthy. Most files have a single cohesive responsibility. The "large" files (500-766 lines) are justified facades/orchestrators with low cognitive complexity relative to their size.

---

## Decomposition Plan Verdicts

| Task | Target | Verdict | Reasoning |
|------|--------|---------|-----------|
| 1 | StreamDecodePipeline (697→~380) | **No-Go** | DecodeContext + SessionDelegateProxy are `private`. Extraction requires `internal` (Principle 5 violation). PlaylistResolver has 1 caller (Rule of Three not met). ~380 residual is already clean single responsibility. |
| 2 | WinampEqualizerWindow (616→~100) | **No-Go** | File is verbose declarative SwiftUI with LOW cognitive complexity. 7 @ViewBuilder methods are flat UI declarations. EQFullLayer would be a pass-through middleman (Principle 6). Extraction requires making EQCoords/slider constants internal (Principle 5). All 3 types serve one feature. |
| 3 | VisualizerPipeline (645→~231) | **No-Go** | SharedBuffer + ScratchBuffers are `private @unchecked Sendable`. Making them `internal` widens unsafe surface area (Principle 5). File is 645 lines but LOW cognitive complexity (verbose DSP math, not interleaved responsibilities). |
| 4 | SkinManager (766→~392) | **Revise** | Steps 1-3 are Go (genuinely separate types). Step 4 (Fallback extension) is No-Go — requires `private → internal` for 3 mutable caches with append-only invariants (Principle 5). Revised residual: ~460 lines. |
| 5 | AudioPlayer (734→~554) | **No-Go** | Seek state (`currentSeekID`, `seekGuardActive`, `playbackState`) is tightly coupled to play/stop/onPlaybackEnded. Extraction fragments state ownership (Principle 3). 6-callback pattern creates pass-through middleman (Principle 6). File is a facade with one responsibility: local audio playback orchestration. |

### SkinManager Revised Plan (Steps 1-3 only)

| Step | Extraction | Lines | Verdict | Reasoning |
|------|-----------|-------|---------|-----------|
| 1 | SkinArchiveLoader.swift | ~70 | **Go** | Already self-contained caseless enum, zero SkinManager state coupling |
| 2 | SkinManager+Import.swift | ~186 | **Go** | Only calls `scanAvailableSkins()` + `switchToSkin()`, both already internal |
| 3 | SkinBackgroundPreprocessor.swift | ~36 | **Go** | Pure function, zero state |
| 4 | ~~SkinManager+Fallback.swift~~ | ~~77~~ | **No-Go** | Mutates 3 private caches with append-only invariants. `private → internal` breaks encapsulation. |

**Revised residual: ~460 lines** (766 - 70 - 186 - 36 = 474, adjusted for shared imports). Single cohesive responsibility: skin state management, loading, fallback resolution, orchestration.

---

## Actionable Findings (New)

### Priority 1: Dead Code

| File | Lines | Issue | Action |
|------|-------|-------|--------|
| `PresetsButton.swift` | 146 | Likely deprecated — parallel implementation exists in PresetPickerView (WinampEqualizerWindow.swift). Uses EqfPreset/EQFCodec while current uses EQPreset. | Investigate if dead, document in depreciated.md, remove |
| `WinampButtonStyle.swift` | 37 | Unused abstraction — 0 callers. `.buttonStyle(.plain).focusable(false)` appears 39x manually but none use WinampButtonStyle. | Remove dead code (Principle 10) |
| `WinampAlertHelper.promptText` | ~15 | Unused API — 0 callers. | Delete method |

### Priority 2: AHA Rule of Three Triggered

| Pattern | Occurrences | Files | Recommendation |
|---------|-------------|-------|----------------|
| WindowSizeState persistence/resize | 3 | VideoWindowSizeState, MilkdropWindowSizeState, PlaylistWindowSizeState | Consider `WindowSizeState` protocol with defaults (sizeKey, defaultSize, minimumSize). Each conformer keeps window-specific layout properties. No behavior flags needed. |

### Priority 3: Minor Hygiene

| File | Issue | Action |
|------|-------|--------|
| `SnapUtils.swift` | Generic top-level type names (Point, Diff, Box, BoundingBox) | Consider nesting inside `SnapUtils` enum |
| `PlaylistWindowSizeState.swift` | `segmentWidth`/`segmentHeight` (25, 29) duplicated as literals in `Size2D.toPixels()` | Move to named constants on `Size2D` |
| `AppCommands.swift` | Minor SRP: mixes Options menu + file-open orchestration | Flag for future if file grows |
| `WinampAlertHelper` | Only 2 file callers for showInfo/showError (below Rule of Three) | Low priority — keep or inline |

---

## AHA Validation of Phase 2.5 Utilities

| Utility | Callers | Rule of Three | Exception | Verdict |
|---------|---------|---------------|-----------|---------|
| `TimeFormatting.swift` | 3 files, 5 call sites | **Passes** | N/A | **Justified** |
| `MenuActionTarget.swift` | 2 files, 15 call sites | Below (2 files) | **Safety invariant** (ARC lifetime) | **Justified** |
| `WinampAlertHelper.swift` | 2 files | **Fails** | None | **Borderline** — `promptText` dead, consider inlining rest |
| `QueueConfined.swift` | 2 files | Below (2 files) | **Safety invariant** (threading) | **Justified** |
| `WinampWindowConfigurator.swift` | 5 files | **Passes** (5x) | N/A | **Justified** |

---

## Cross-Cutting AHA Findings

### Justified WET (Do NOT abstract)

| Pattern | Occurrences | Why WET is correct |
|---------|-------------|-------------------|
| Resize handle (drag + preview + coordinator call) | 3 (Video, Milkdrop, Playlist) | Each has window-specific coordinator calls + different segment dimensions. Abstraction needs flags → wrong abstraction (Principle 4). |
| Window controller init pattern | 5 | Each has meaningful divergences (resizable, lifecycle ownership, contentView strategy). Flag-based factory → wrong abstraction. |
| `switch currentSource` in PlaybackCoordinator | ~10 | Each switch body is different. Declarative case matching, not logic duplication. |
| `withObservationTracking` boilerplate in WindowSettingsObserver | 4 | Generic KeyPath helper would add complexity without reducing cognitive load. |
| Time display code (MainWindowFullLayer vs ShadeLayer) | 2 | Below Rule of Three. Different scaling/positioning. |

### Correctly Extracted (Phase 2a/2.5)

| Abstraction | Why correct |
|-------------|-------------|
| `resample(_:to:)` | 3 callers, identical algorithm, no flags |
| `copyFloatBuffer(from:to:count:)` | 3 publish sites, identical memory copy, no flags |
| `parsePlaylistStyle(from:fallback:)` | Bug fix motivation (not DRY), `fallback:` is domain input not flag |
| `parseVisualizerColors(from:fallback:)` | Same as above |

---

## Summary

The codebase has **no SRP violations** among its large files. The 5 decomposition targets (697-766 lines) are:
- **Facades** (AudioPlayer, SkinManager) or **orchestrators** (StreamDecodePipeline, PlaybackCoordinator) that are naturally large
- **Verbose but low-complexity** files (VisualizerPipeline, WinampEqualizerWindow) where physical size does not correlate with cognitive complexity

4 of 5 planned decompositions would **damage architecture** by requiring visibility leaks (`private → internal`), creating pass-through middlemen, or fragmenting state ownership. Only SkinManager Steps 1-3 (extracting genuinely independent types) pass the gate.

The 7 actionable findings are small: 2 dead files (~183 lines), 1 dead API, 1 protocol opportunity, 3 minor hygiene items.
