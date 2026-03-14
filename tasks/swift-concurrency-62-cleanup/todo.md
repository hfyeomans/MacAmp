# TODO: Swift 6.2 Concurrency Cleanup

> **Purpose:** Checklist tracking implementation progress. Items derived from `plan.md`.
> Split into PR 1 (pre-pipeline) and PR 2 (post-pipeline).
>
> **Created:** 2026-03-13
> **Updated:** 2026-03-14 (PR 1 merged as PR #56)

---

## PR 1: Foundation + Non-Conflicting Cleanup — ✅ MERGED (PR #56, 2026-03-14)

### Phase 0: Upgrade Swift Language Mode to 6.2

- [x] **0a.** SkinManager.swift — add `@preconcurrency import ZIPFoundation`
- [x] **0b.** project.yml — change `SWIFT_VERSION: '6.0'` → `SWIFT_VERSION: '6.2'` (both targets)
- [x] **0c.** Run `xcodegen generate`
- [x] **0d.** Fix LockFreeRingBuffer.swift — `wrappingIncrementThenLoad` → `wrappingIncrement` (Gemini finding)
- [x] **0e.** Clean build with TSan — no new diagnostics, zero warnings
- [x] **0f.** Audit MetadataLoader — safe: all methods await immediately, no blocking I/O before first suspension
- [x] **0g.** Run test suite — 40/40 pass with TSan

### Phase 2: DispatchQueue → Swift Concurrency

- [x] **2a.** WindowAccessor.swift — `DispatchQueue.main.async` → `Task { @MainActor in }`
- [x] **2b.** PreferencesView.swift — 2x `DispatchQueue.main.asyncAfter` → `Task { @MainActor in; Task.sleep(for:) }`
- [x] **2c.** Build with TSan — clean, zero warnings

### Phase 1 PARTIAL: `isolated deinit` (Non-AudioPlayer Files)

- [x] **1a.** VideoPlaybackController.swift — `isolated deinit`, removed 3 `nonisolated(unsafe)` + shadow `_playerForCleanup`
- [x] **1b.** VisualizerPipeline.swift — restored `removeTap()` to MainActor-isolated, removed 3 `nonisolated(unsafe)`, removed `dispatchPrecondition`, restored `isTapInstalled`
- [x] **1c.** WindowCoordinator.swift — `isolated deinit` added, now calls `settingsObserver.stop()` directly
- [x] **1c-bridge.** AudioPlayer.swift — temporary `MainActor.assumeIsolated` bridge in deinit for removeTap() call (will be replaced by `isolated deinit` in PR 2)
- [x] **1d.** Build with TSan — clean build, zero warnings
- [x] **1e.** Manual test — play → close app, switch skin → close app — no issues found

### PR 1 Merge

- [x] **M1.** Push branch `feature/swift-concurrency-62-cleanup`
- [x] **M2.** Oracle review of PR diff — 3 low findings, all fixed
- [x] **M3.** Create PR #56 against `main`
- [x] **M4.** Squash-merged PR #56 (2026-03-14) — Swift 6.2 foundation established

---

## ── unified-audio-pipeline executes here (Step 5-6) ──

---

## PR 2: Post-Pipeline Cleanup (new branch after pipeline merges)

### Phase 1d: AudioPlayer `isolated deinit` (Final Shape)

- [x] **1d-1.** AudioPlayer.swift — `isolated deinit`, removed `nonisolated(unsafe)` on `progressTimer`
- [x] **1d-2.** Removed entire `Thread.isMainThread`/`DispatchQueue.main.async`/`MainActor.assumeIsolated` bridge (17 lines → 3 lines)
- [x] **1d-3.** Bridge cleanup via `deactivateStreamBridge()` (idempotent, handles nil gracefully)
- [x] **1d-4.** Final deinit: `isolated deinit { progressTimer?.invalidate(); deactivateStreamBridge(); visualizerPipeline.removeTap() }`
- [x] **1d-5.** Build with TSan — 40/40 pass

### Phase 4: `@concurrent` for Offloaded Work

- [x] **4a.** EQPresetStore.swift — 3 `Task.detached` → `@concurrent` static functions (loadPresetsFromDisk, savePresetsToDisk, parseEqfFile)
- [x] **4b.** SkinManager.swift — `@concurrent` async wrapper `SkinArchiveLoader.loadAsync()`, replaced `Task.detached`
- [x] **4c.** MetadataLoader.swift — audited: all methods await immediately, no blocking I/O, `@concurrent` not needed
- [x] **4d.** Build with TSan — 40/40 pass

### PR 2 Merge

- [x] **M5.** Push branch `feature/swift-concurrency-62-cleanup-pr2`
- [x] **M6.** Oracle review — clean (1 LOW fixed: overlapping async writes)
- [x] **M6b.** Swift 6.2 concurrency audit — CLEAN (zero nonisolated(unsafe), zero Task.detached, zero DispatchQueue.main.async)
- [x] **M7.** Create PR #58 against `main`
- [ ] **M8.** Merge PR

---

## DROPPED

- ~~Phase 3: StreamPlayer @preconcurrency audit~~ — StreamPlayer completely rewritten by pipeline

## DEFERRED

- Phase 5: Default MainActor isolation — questionable ROI (see research.md)

## Final

- [x] **F1.** Update `state.md` with PR 1 completion
- [x] **F2.** Update `_context/state.md` with PR 1 merged
