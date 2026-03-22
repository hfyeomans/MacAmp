# Deprecated Code: Swift 6.2 Concurrency Cleanup

> **Purpose:** Document code patterns being removed or replaced during this task.
> Each entry explains what was removed, why, and what replaced it.
>
> **Created:** 2026-03-13

---

## Patterns Being Removed

### 1. `nonisolated(unsafe)` for deinit access

**Files:** AudioPlayer.swift, VisualizerPipeline.swift, VideoPlaybackController.swift

**What:** Properties marked `nonisolated(unsafe)` solely to allow `deinit` to access `@MainActor` state.

**Why removed:** Swift 6.2 `isolated deinit` runs on the class's actor, making these workarounds unnecessary. The `nonisolated(unsafe)` annotation disables compiler safety checks — removing it restores full compile-time verification.

**Replaced with:** `isolated deinit` keyword on the class.

**Specific removals:**
- `AudioPlayer.progressTimer` — `nonisolated(unsafe)` removed in PR 2 (PR #58) with `isolated deinit`
- `VisualizerPipeline.tapInstalled` — `nonisolated(unsafe)` removed
- `VisualizerPipeline.mixerNode` — `nonisolated(unsafe)` removed
- `VisualizerPipeline.pollTimer` — `nonisolated(unsafe)` removed
- `VideoPlaybackController.endObserver` — `nonisolated(unsafe)` removed
- `VideoPlaybackController.timeObserver` — `nonisolated(unsafe)` removed
- `VideoPlaybackController._playerForCleanup` — entire shadow property removed

### 2. `Thread.isMainThread` + `DispatchQueue.main.async` in deinit

**File:** AudioPlayer.swift:185-191

**What:** Runtime thread check with conditional dispatch to ensure `removeTap()` runs on main thread.

**Why removed:** `isolated deinit` guarantees main actor execution at compile time.

**Replaced with:** Direct call in `isolated deinit`.

### 3. `DispatchQueue.main.async` for deferred execution

**File:** WindowAccessor.swift:9

**What:** GCD dispatch to defer window access until view is in hierarchy.

**Why removed:** Swift concurrency equivalent (`Task { @MainActor in }`) provides same deferral with uniform concurrency model.

### 4. `DispatchQueue.main.asyncAfter` for animation delays

**File:** PreferencesView.swift:97, 108

**What:** GCD delayed dispatch for animation timing.

**Why removed:** `Task { try? await Task.sleep(for:) }` is the Swift concurrency equivalent, supports cancellation, and keeps the codebase uniform.

### 5. `@preconcurrency import AVFoundation` — N/A (StreamPlayer rewritten)

**File:** StreamPlayer.swift:1

**Status:** N/A — StreamPlayer was completely rewritten by the unified audio pipeline (T7).
No longer uses AVFoundation for streaming. The `@preconcurrency import` was removed along
with AVPlayer, NSObject, and Combine.

### 6. Redundant `@MainActor` annotations (Phase 5) — DEFERRED

**Status:** DEFERRED — Phase 5 was evaluated and determined to have questionable ROI.
Removes ~30 `@MainActor` annotations but adds ~37-41 `nonisolated` annotations.
See research.md "Phase 5 Blast Radius" for full analysis.
Tracked in `_context/state.md` as deferred item for future triage.
