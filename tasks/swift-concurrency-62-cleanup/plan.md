# Plan: Swift 6.2 Concurrency Cleanup

> **Purpose:** Step-by-step implementation plan for adopting Swift 6.2 concurrency features.
> Split into two PRs due to cross-task dependency with `unified-audio-pipeline`.
>
> **Created:** 2026-03-13
> **Updated:** 2026-03-13 (cross-task ordering with unified-audio-pipeline; split into PR1 + PR2)
> **Depends on:** `research.md` audit findings
> **Cross-task dependency:** AudioPlayer `isolated deinit` (Phase 1d) deferred to PR 2 (after pipeline).
> Phase 3 (StreamPlayer @preconcurrency) DROPPED — StreamPlayer rewritten by pipeline.
> See `_context/state.md`.

---

## Execution Order (Cross-Task Coordinated)

```
PR 1 — swift-concurrency-62-cleanup (this branch)
  Step 1: Phase 0 — SWIFT_VERSION 6.2 + dependency fixes
  Step 2: Phase 2 — DispatchQueue → Task cleanup
  Step 3: Phase 1 PARTIAL — isolated deinit (VideoPlaybackController, VisualizerPipeline, WindowCoordinator)
  Step 4: Merge PR to main

  ──── unified-audio-pipeline executes here (separate branch/PR) ────

PR 2 — swift-concurrency-62-cleanup-part2 (new branch after pipeline merges)
  Step 5: Phase 1d — AudioPlayer isolated deinit (final shape with streamSourceNode)
  Step 6: Phase 4 — @concurrent static functions

DROPPED: Phase 3 — StreamPlayer @preconcurrency (file rewritten by pipeline)
DEFERRED: Phase 5 — Default MainActor isolation (questionable ROI)
```

---

## PR 1: Foundation + Non-Conflicting Cleanup

### Phase 0: Upgrade Swift Language Mode to 6.2 (PREREQUISITE)

**Goal:** Enable Swift 6.2 language features in the XcodeGen build.

**Why this is required:** `project.yml` currently sets `SWIFT_VERSION: '6.0'`. Swift 6.2 features
(`isolated deinit`, `@concurrent`, default MainActor isolation, isolated conformances) are **only
available in Swift 6.2 language mode**. Without this upgrade, Phase 1 cannot compile.

**Files to modify:**

#### 0a. Dependency audit — ZIPFoundation Swift 6.2 compatibility
- **BLOCKER (Oracle-identified):** ZIPFoundation 0.9.19/0.9.20 has non-concurrency-safe global
  mutable vars (`var maxUInt32`, `var maxUInt16` in `Archive+ZIP64.swift:142-143`) that fail
  under `SWIFT_STRICT_CONCURRENCY=complete` with Swift 6.2 language mode.
- **Research findings (2026-03-13):**
  - 0.9.20 (latest, Sep 2025): NOT fixed. Same `var` globals.
  - `development` branch (Jan 2026): NOT fixed. Same `var` globals.
  - Issue #345 "Swift 6 Support": Open since Dec 2024, 0 comments, no one working on it.
  - SWCompression: Also not Swift 6 compliant (PR #58 rejected by maintainer).
  - Apple Compression framework: Not a ZIP parser, only raw compression.
  - No Swift ZIP library in the ecosystem is fully Swift 6.2 compliant.
- **Resolution:** Add `@preconcurrency import ZIPFoundation` in `SkinManager.swift`.
  This is the standard approach (already used for AVFoundation in `StreamPlayer.swift:1`).
  One-line fix, zero migration risk, proven pattern in the codebase.

#### 0b. project.yml
- Change `SWIFT_VERSION: '6.0'` to `SWIFT_VERSION: '6.2'` under `settings.base`
- Also update `MacAmpTests` target if it has its own `SWIFT_VERSION`

#### 0c. Regenerate Xcode project
- Run `xcodegen generate`

#### 0d. Fix new compiler warnings
- **LockFreeRingBuffer.swift:** Unused return values from `wrappingIncrementThenLoad` on lines
  78, 129, 179 — add explicit `_ =` or switch to `wrappingIncrement` (Oracle-identified)
- Any other new diagnostics from the language mode change

#### 0e. Clean build with TSan
- Full rebuild to surface any new diagnostics from the language mode change
- **Key behavioral change in 6.2:** `nonisolated async` functions now stay on the caller's actor
  by default (instead of hopping to the cooperative pool). This could surface new warnings if any
  `nonisolated async` functions rely on running off-MainActor.
- Audit any new compiler warnings/errors before proceeding

**Known risk:** The nonisolated async behavior change may affect `MetadataLoader.loadTrackMetadata()`,
`MetadataLoader.loadAudioProperties()`, and `MetadataLoader.loadVideoMetadata()` — these are static
async functions called from `@MainActor` contexts. Under Swift 6.2, they would stay on MainActor
unless explicitly offloaded. If they do heavy work, they may need `@concurrent` (addressed in PR 2 Phase 4).

**Testing:** Clean build (including all dependencies), run test suite, verify no new warnings.
If warnings appear, fix them as part of this phase before proceeding.

---

### Phase 2: DispatchQueue → Swift Concurrency Migration (Medium Impact)

**Goal:** Replace remaining GCD patterns with Swift concurrency equivalents.

**Requires:** Nothing — uses Task/Task.sleep available since Swift 5.5.

**Files to modify:**

#### 2a. WindowAccessor.swift
- Replace `DispatchQueue.main.async` with `Task { @MainActor in }`
- Same deferral behavior (waits for view to be in window hierarchy)

#### 2b. PreferencesView.swift
- Replace `DispatchQueue.main.asyncAfter(deadline: .now() + 0.6)` with `Task { try? await Task.sleep(for: .seconds(0.6)) }`
- Replace `DispatchQueue.main.asyncAfter(deadline: .now() + 1.8)` with `Task { try? await Task.sleep(for: .seconds(1.8)) }`
- Both are cosmetic animation delays — low risk

**Note:** `StreamPlayer.swift:163` `DispatchQueue.main` as delegate queue is an AVFoundation API
requirement — do NOT change. (StreamPlayer will be rewritten by pipeline task anyway.)

**Testing:** Build. Open preferences, change settings, verify animations still work.
Test WindowAccessor by opening windows.

---

### Phase 1 PARTIAL: `isolated deinit` (Non-AudioPlayer Files Only)

**Goal:** Adopt `isolated deinit` on files that are NOT modified by the pipeline task.

**Requires:** Phase 0 (Swift 6.2 language mode)

**Why partial:** AudioPlayer.swift gains ~8 new properties/methods from the pipeline task
(streamSourceNode, streamRingBuffer, isBridgeActive, etc.). Its `isolated deinit` must cover
the final shape. Doing it now would require redoing it after pipeline.

**Files to modify:**

#### 1a. VideoPlaybackController.swift
- Replace `deinit` with `isolated deinit`
- Remove `nonisolated(unsafe)` from `endObserver`, `timeObserver`, `_playerForCleanup`
- Remove `_playerForCleanup` shadow property entirely (use `player` directly in deinit)
- Remove comments explaining the nonisolated workaround

#### 1b. VisualizerPipeline.swift
- Change `removeTap()` from `nonisolated func` back to regular `func` (MainActor-isolated)
- Remove `nonisolated(unsafe)` from `tapInstalled`, `mixerNode`, `pollTimer`
- Remove `dispatchPrecondition(condition: .onQueue(.main))` from `removeTap()` (compiler enforces it)
- Change `isTapInstalled` from `nonisolated var` to regular `var`
- Keep `nonisolated static func makeTapHandler()` — this must remain nonisolated for the audio tap

**Architecture note:** After this change, `removeTap()` is MainActor-isolated. The pipeline task's
VisualizerPipeline usage is unaffected — pipeline doesn't modify VisualizerPipeline.

#### 1c. WindowCoordinator.swift (Oracle-identified)
- Check if `deinit` needs to call `settingsObserver.stop()` — currently can't because deinit
  is nonisolated. If so, add `isolated deinit` and call `settingsObserver.stop()` directly.
- Verify whether this is already handled by the `stop()` lifecycle or only needed for cleanup.

**Timing risk (Oracle-identified):** `isolated deinit` is enqueued on the actor's executor, not
executed immediately at the point of last release. This means taps, timers, and observers may
live slightly longer. In practice this is low risk — explicit `cleanup()`/`stop()` methods are
the primary cleanup path; deinit is a safety net.

**Testing:** Build with TSan. Verify no runtime warnings. Test: load track → play → close app.
Test: play → switch skin → close app. Verify no audio glitches from delayed tap removal.

---

### PR 1 Merge

- Push branch `feature/swift-concurrency-62-cleanup`
- Create PR against `main`
- Oracle review of PR diff
- Merge to main
- This establishes the Swift 6.2 foundation for the pipeline task

---

## PR 2: Post-Pipeline Cleanup (After unified-audio-pipeline merges)

### Phase 1d: AudioPlayer `isolated deinit` (Final Shape)

**Goal:** Add `isolated deinit` to AudioPlayer after pipeline has added all bridge properties.

**Requires:** unified-audio-pipeline merged to main

**Why deferred:** Pipeline Phase 1.7 adds `streamSourceNode`, `streamRingBuffer`, `isBridgeActive`,
`isEngineRendering`, `activateStreamBridge()`, `deactivateStreamBridge()`. The `isolated deinit`
must clean up ALL of these plus the existing `progressTimer` and `visualizerPipeline.removeTap()`.

**AudioPlayer.swift changes:**
- Replace `deinit` with `isolated deinit`
- Remove `nonisolated(unsafe)` from `progressTimer`
- Remove `Thread.isMainThread` check and `DispatchQueue.main.async` fallback
- Call `visualizerPipeline.removeTap()` directly
- Call `deactivateStreamBridge()` for bridge cleanup
- Nil `streamSourceNode` and `streamRingBuffer`
- Final deinit body: `isolated deinit { progressTimer?.invalidate(); deactivateStreamBridge(); visualizerPipeline.removeTap() }`

**Testing:** Build with TSan. Test: play local → close app, play stream → close app,
switch stream↔local → close app.

---

### Phase 4: `@concurrent` for Offloaded Work (Medium Impact)

**Goal:** Replace `Task.detached` with `@concurrent` functions for self-documenting offloading.

**Requires:** Phase 0 (already merged in PR 1)

**IMPORTANT constraint (Oracle-identified):** `@concurrent` on a method inside a `@MainActor`
class creates an isolation mismatch. The extracted functions should be either:
- `nonisolated` static functions (preferred — no self reference needed for I/O)
- Functions on a separate `nonisolated` helper type
- NOT `@concurrent private func` on the `@MainActor` class itself

#### 4a. EQPresetStore.swift
- Extract `loadPerTrackPresetsFromDisk()` as `@concurrent private nonisolated static func`
- Extract `savePerTrackPresetsToDisk()` as `@concurrent private nonisolated static func`
- Extract `parseEqfFile()` as `@concurrent private nonisolated static func`
- Each replaces the inline `Task.detached { ... }.value` pattern
- Callers pass data in/out explicitly (no `self` capture)

#### 4b. SkinManager.swift
- `SkinArchiveLoader.load()` is already a `private enum` with static methods — annotate
  with `@concurrent` directly (it's already nonisolated by being a separate type)

#### 4c. MetadataLoader.swift
- Audit `loadTrackMetadata()`, `loadAudioProperties()`, `loadVideoMetadata()`
- Under Swift 6.2, these `nonisolated async` functions stay on caller's actor (MainActor)
- If they do blocking I/O, they must be marked `@concurrent` to offload
- If they only call other async APIs (like AVAsset.load), they're fine — the suspension
  naturally yields the actor

**Testing:** Build. Load skins, save EQ presets, import EQF files, add tracks (metadata loading).
Verify identical behavior.

---

## DROPPED: Phase 3 (`@preconcurrency` Audit)

**Reason:** The unified-audio-pipeline task completely rewrites `StreamPlayer.swift`, removing
AVPlayer, AVPlayerItemMetadataOutputPushDelegate, `@preconcurrency import AVFoundation`, and
all Combine observers. Phase 3 work would be immediately discarded.

## DEFERRED: Phase 5 (Default MainActor Isolation)

**Reason:** Questionable ROI — removes ~30 `@MainActor` but adds ~37-41 `nonisolated`.
See research.md "Phase 5 Blast Radius" for full analysis.

---

## Risk Assessment

| Phase | PR | Risk | Mitigation |
|-------|-----|------|------------|
| 0 (SWIFT_VERSION) | PR 1 | Medium | Clean build catches all issues; nonisolated async behavior change is main risk |
| 2 (DispatchQueue) | PR 1 | Very Low | Cosmetic animations only |
| 1 partial (isolated deinit) | PR 1 | Low | Well-understood feature; TSan catches issues; non-conflicting files only |
| 1d (AudioPlayer deinit) | PR 2 | Low | Deferred to final shape; includes bridge cleanup |
| 4 (@concurrent) | PR 2 | Low-Medium | Same runtime behavior; MetadataLoader audit may find blocking I/O |

---

## Dependency Graph

```
PR 1 (this branch):
  Phase 0 (SWIFT_VERSION 6.2)
  ├── Phase 1 partial (isolated deinit: VPC, VisPipeline, WinCoord)
  └── Phase 2 (DispatchQueue cleanup — independent)
  → MERGE TO MAIN

unified-audio-pipeline (separate branch, depends on PR 1 merge):
  → StreamPlayer rewrite, AudioPlayer bridge, PlaybackCoordinator
  → MERGE TO MAIN

PR 2 (new branch, depends on pipeline merge):
  Phase 1d (AudioPlayer isolated deinit — final shape)
  Phase 4 (@concurrent static functions)
  → MERGE TO MAIN
```
