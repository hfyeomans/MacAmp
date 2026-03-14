# TODO: Swift 6.2 Concurrency Cleanup

> **Purpose:** Checklist tracking implementation progress. Items derived from `plan.md`.
> Split into PR 1 (pre-pipeline) and PR 2 (post-pipeline).
>
> **Created:** 2026-03-13
> **Updated:** 2026-03-13 (cross-task split: PR1 before pipeline, PR2 after pipeline)

---

## PR 1: Foundation + Non-Conflicting Cleanup

### Phase 0: Upgrade Swift Language Mode to 6.2

- [x] **0a.** SkinManager.swift — add `@preconcurrency import ZIPFoundation`
- [x] **0b.** project.yml — change `SWIFT_VERSION: '6.0'` → `SWIFT_VERSION: '6.2'` (both targets)
- [x] **0c.** Run `xcodegen generate`
- [x] **0d.** Fix LockFreeRingBuffer.swift unused return values (lines 79, 129, 179)
- [x] **0e.** Clean build with TSan — no new diagnostics, zero warnings
- [x] **0f.** Audit MetadataLoader — safe: all methods await immediately, no blocking I/O before first suspension
- [x] **0g.** Run test suite — 40/40 pass with TSan

### Phase 2: DispatchQueue → Swift Concurrency

- [x] **2a.** WindowAccessor.swift — `DispatchQueue.main.async` → `Task { @MainActor in }`
- [x] **2b.** PreferencesView.swift — 2x `DispatchQueue.main.asyncAfter` → `Task { Task.sleep(for:) }`
- [x] **2c.** Build with TSan — clean, zero warnings

### Phase 1 PARTIAL: `isolated deinit` (Non-AudioPlayer Files)

- [x] **1a.** VideoPlaybackController.swift — `isolated deinit`, removed 3 `nonisolated(unsafe)` + shadow `_playerForCleanup`
- [x] **1b.** VisualizerPipeline.swift — restored `removeTap()` to MainActor-isolated, removed 3 `nonisolated(unsafe)`, removed `dispatchPrecondition`, restored `isTapInstalled`
- [x] **1c.** WindowCoordinator.swift — `isolated deinit` added, now calls `settingsObserver.stop()` directly
- [x] **1c-bridge.** AudioPlayer.swift — temporary `MainActor.assumeIsolated` bridge in deinit for removeTap() call (will be replaced by `isolated deinit` in PR 2)
- [x] **1d.** Build with TSan — clean build, zero warnings
- [ ] **1e.** Manual test — play → close app, switch skin → close app

### PR 1 Merge

- [ ] **M1.** Push branch `feature/swift-concurrency-62-cleanup`
- [ ] **M2.** Oracle review of PR diff
- [ ] **M3.** Create PR against `main`
- [ ] **M4.** Merge PR — establishes Swift 6.2 foundation for pipeline task

---

## ── unified-audio-pipeline executes here (separate branch/PR) ──

---

## PR 2: Post-Pipeline Cleanup (new branch after pipeline merges)

### Phase 1d: AudioPlayer `isolated deinit` (Final Shape)

- [ ] **1d-1.** AudioPlayer.swift — `isolated deinit`, remove `nonisolated(unsafe)` on `progressTimer`
- [ ] **1d-2.** Remove `Thread.isMainThread`/`DispatchQueue.main.async` deinit pattern
- [ ] **1d-3.** Add bridge cleanup: `deactivateStreamBridge()`, nil streamSourceNode/streamRingBuffer
- [ ] **1d-4.** Final deinit: `progressTimer?.invalidate(); deactivateStreamBridge(); visualizerPipeline.removeTap()`
- [ ] **1d-5.** Build with TSan — test local play → close, stream play → close, switch → close

### Phase 4: `@concurrent` for Offloaded Work

- [ ] **4a.** EQPresetStore.swift — extract `@concurrent nonisolated static` functions (3 call sites)
- [ ] **4b.** SkinManager.swift — annotate `SkinArchiveLoader.load()` with `@concurrent`
- [ ] **4c.** MetadataLoader.swift — audit async functions, add `@concurrent` if blocking I/O
- [ ] **4d.** Build and test — verify skin loading, EQ presets, metadata loading

### PR 2 Merge

- [ ] **M5.** Push branch
- [ ] **M6.** Oracle review
- [ ] **M7.** Create PR against `main`
- [ ] **M8.** Merge PR

---

## DROPPED

- ~~Phase 3: StreamPlayer @preconcurrency audit~~ — StreamPlayer completely rewritten by pipeline

## DEFERRED

- Phase 5: Default MainActor isolation — questionable ROI (see research.md)

## Final

- [ ] **F1.** Update `state.md` with completion status
- [ ] **F2.** Update `_context/state.md`
