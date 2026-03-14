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

**Specific removals (PR 1):**
- `AudioPlayer.progressTimer` — `nonisolated(unsafe)` still present (deferred to PR 2 — AudioPlayer needs `isolated deinit` after pipeline adds bridge state)
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

### 5. `@preconcurrency import AVFoundation` (if removable)

**File:** StreamPlayer.swift:1

**What:** Pre-concurrency import annotation suppressing Sendable warnings from AVFoundation types.

**Why removed (if applicable):** Xcode 26 SDK may have added proper Sendable annotations. If removal causes compiler errors, this entry will be marked as "kept — still needed."

### 6. Redundant `@MainActor` annotations (Phase 5)

**Files:** ~30+ types across the codebase

**What:** Explicit `@MainActor` annotations on types that would inherit isolation from the module default.

**Why removed:** Default main actor isolation (`SWIFT_DEFAULT_ISOLATION: MainActor`) makes these implicit. Removing them reduces annotation noise and makes `nonisolated` opt-outs more visible.
