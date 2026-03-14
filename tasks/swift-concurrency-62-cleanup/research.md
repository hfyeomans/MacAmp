# Research: Swift 6.2 Concurrency Cleanup

> **Purpose:** Document current concurrency patterns, identify modernization targets, and validate
> Swift 6.2 feature applicability for the MacAmp codebase.
>
> **Created:** 2026-03-13

---

## Pre-Upgrade Build Configuration (captured 2026-03-13)

| Setting | Value | Source |
|---------|-------|--------|
| `swift-tools-version` | 6.2 | `Package.swift:1` |
| `SWIFT_VERSION` | 6.0 | `project.yml:35` |
| `SWIFT_STRICT_CONCURRENCY` | complete | `project.yml:38` |
| Deployment target | macOS 15.0+ (Sequoia) | `project.yml:5` |
| Xcode version | 26.0 | `project.yml:6` |

**CRITICAL BLOCKER:** `SWIFT_VERSION: '6.0'` means the compiler uses Swift 6.0 language mode. Swift 6.2
features (`isolated deinit`, `@concurrent`, default MainActor isolation, isolated conformances) are
**not available** in Swift 6.0 language mode. Upgrading to `SWIFT_VERSION: '6.2'` in project.yml is a
hard prerequisite for Phases 1, 3, 4, 5. Phase 2 (DispatchQueue cleanup) does NOT require 6.2 — `Task`
and `Task.sleep` are available in Swift 5.5+.

**Risk of upgrading SWIFT_VERSION 6.0 → 6.2:** The Swift 6.2 language mode changes the default behavior
of `nonisolated async` functions (they now stay on the caller's actor instead of hopping off). This could
cause new warnings or behavior changes in existing async code. Must do a clean build and verify no new
diagnostics appear.

---

## Audit: `@MainActor` Usage Across Codebase

Nearly every `@Observable` class and controller is explicitly annotated `@MainActor`:

| File | Type | `@MainActor` |
|------|------|:------------:|
| `AudioPlayer.swift` | `@Observable final class` | ✅ |
| `PlaybackCoordinator.swift` | `@Observable final class` | ✅ |
| `StreamPlayer.swift` | `@Observable final class` | ✅ |
| `EqualizerController.swift` | `@Observable final class` | ✅ |
| `EQPresetStore.swift` | `@Observable final class` | ✅ |
| `VisualizerPipeline.swift` | `@Observable final class` | ✅ |
| `VideoPlaybackController.swift` | `@Observable final class` | ✅ |
| `PlaylistController.swift` | `@Observable final class` | ✅ |
| `SkinManager.swift` | `@Observable final class` | ✅ |
| `AppSettings.swift` | `@Observable final class` | ✅ |
| `WindowCoordinator.swift` | `@Observable final class` | ✅ |
| `DockingController.swift` | `@Observable final class` | ✅ |
| `ButterchurnBridge.swift` | `@Observable final class` | ✅ |
| `ButterchurnPresetManager.swift` | `@Observable final class` | ✅ |
| `RadioStationLibrary.swift` | `@Observable final class` | ✅ |
| `WindowFocusState.swift` | `@Observable final class` | ✅ |
| `VideoWindowSizeState.swift` | `@Observable final class` | ✅ |
| `PlaylistWindowSizeState.swift` | `@Observable final class` | ✅ |
| `MilkdropWindowSizeState.swift` | `@Observable final class` | ✅ |
| `PlaylistWindowInteractionState.swift` | `@Observable final class` | ✅ |
| `WinampMainWindowInteractionState.swift` | `@Observable final class` | ✅ |
| `WindowVisibilityController.swift` | `@Observable final class` | ✅ |
| All `*WindowController.swift` | `@MainActor final class` | ✅ |
| `WindowSettingsObserver.swift` | `@MainActor final class` | ✅ |
| `WindowSnapManager.swift` | `@MainActor final class` | ✅ |
| `WindowFramePersistence.swift` | `@MainActor final class` | ✅ |
| `WindowResizeController.swift` | `@MainActor final class` | ✅ |
| Various menu presenters | `@MainActor final class` | ✅ |

**Conclusion:** ~30+ types carry explicit `@MainActor`. Default main actor isolation would eliminate all of these annotations.

---

## Audit: `nonisolated(unsafe)` Properties

Used in 3 files to allow `deinit` access to `@MainActor` state:

### AudioPlayer.swift:18
```swift
@ObservationIgnored nonisolated(unsafe) private var progressTimer: Timer?
```
**Purpose:** `deinit` needs to invalidate timer but `deinit` is nonisolated.

### VisualizerPipeline.swift:358-361
```swift
@ObservationIgnored nonisolated(unsafe) private var tapInstalled = false
@ObservationIgnored nonisolated(unsafe) private weak var mixerNode: AVAudioMixerNode?
@ObservationIgnored nonisolated(unsafe) private var pollTimer: Timer?
```
**Purpose:** `removeTap()` is `nonisolated` for calling from `AudioPlayer.deinit`.

### VideoPlaybackController.swift:28-30
```swift
@ObservationIgnored nonisolated(unsafe) private var endObserver: NSObjectProtocol?
@ObservationIgnored nonisolated(unsafe) private var timeObserver: Any?
@ObservationIgnored nonisolated(unsafe) private var _playerForCleanup: AVPlayer?
```
**Purpose:** `deinit` needs to remove observers and pause player. Shadow `_playerForCleanup` property exists solely for deinit access.

**Conclusion:** All 3 files are candidates for `isolated deinit`, which would eliminate 7 `nonisolated(unsafe)` properties and the `_playerForCleanup` shadow.

---

## Audit: `DispatchQueue` Usage

| File | Line | Pattern | Replacement |
|------|------|---------|-------------|
| `WindowAccessor.swift:9` | `DispatchQueue.main.async` | `Task { @MainActor in }` |
| `AudioPlayer.swift:188` | `DispatchQueue.main.async` (deinit) | `isolated deinit` |
| `StreamPlayer.swift:163` | `DispatchQueue.main` (delegate queue) | Keep — AVFoundation API requirement |
| `PreferencesView.swift:97,108` | `DispatchQueue.main.asyncAfter` | `Task { try? await Task.sleep(for:) }` |

---

## Audit: `Task.detached` Usage

| File | Line | Purpose | Verdict |
|------|------|---------|---------|
| `EQPresetStore.swift:106` | File I/O off main thread | ✅ Correct — candidate for `@concurrent` |
| `EQPresetStore.swift:137` | Fire-and-forget file write | ✅ Correct — candidate for `@concurrent` |
| `EQPresetStore.swift:163` | EQF import file I/O | ✅ Correct — candidate for `@concurrent` |
| `SkinManager.swift:606` | ZIP archive parsing | ✅ Correct — candidate for `@concurrent` |

All `Task.detached` usages are legitimate CPU/IO offloading. Can be replaced with `@concurrent` for self-documenting intent.

---

## Audit: `@unchecked Sendable` Usage

| Type | File | Justification | Verdict |
|------|------|---------------|---------|
| `Skin` | `Skin.swift:10` | All `let` properties; `NSImage`/`NSCursor` not `Sendable` but accessed only via `@MainActor` `SkinManager` | ✅ Legitimate |
| `LockFreeRingBuffer` | `LockFreeRingBuffer.swift:17` | `ManagedAtomic` + `UnsafeMutablePointer` with acquire/release ordering | ✅ Legitimate |
| `VisualizerSharedBuffer` | `VisualizerPipeline.swift:36` | `os_unfair_lock` protecting all mutable state | ✅ Legitimate |
| `VisualizerScratchBuffers` | `VisualizerPipeline.swift:187` | Confined to audio tap queue (single-threaded access) | ✅ Legitimate |

**Conclusion:** All `@unchecked Sendable` usages are correct and well-documented. No changes needed.

---

## Audit: `@preconcurrency` Usage

| File | Line | Usage | Action |
|------|------|-------|--------|
| `StreamPlayer.swift:1` | `@preconcurrency import AVFoundation` | Test removal with Xcode 26 SDK |
| `StreamPlayer.swift:30` | `@preconcurrency AVPlayerItemMetadataOutputPushDelegate` | Try `@MainActor` isolated conformance (Swift 6.2) |

---

## Audit: Swallowed Errors in `Task` Closures

| File | Line | Pattern | Risk |
|------|------|---------|------|
| `EQPresetStore.swift:33` | `Task { await loadPerTrackPresets() }` | Low — function doesn't throw today |
| `EqualizerController.swift:113` | `Task { ... importEqfPreset ... }` | Medium — import could fail silently |

---

## Swift 6.2 Features Applicable to MacAmp

### 1. Default Main Actor Isolation
- **Applicability:** HIGH — ~30+ types explicitly annotated
- **Setting:** `SWIFT_DEFAULT_ISOLATION: MainActor` in project.yml
- **Risk:** Low — already the de facto pattern; opt-out with `nonisolated` where needed
- **Prerequisite:** Verify Xcode 26 toolchain supports this build setting

### 2. `isolated deinit`
- **Applicability:** HIGH — 3 files with `nonisolated(unsafe)` workarounds
- **Files:** AudioPlayer, VisualizerPipeline, VideoPlaybackController
- **Risk:** Low — well-understood behavior change
- **Benefit:** Eliminates 7 `nonisolated(unsafe)` properties, 1 shadow property, DispatchQueue.main.async in deinit

### 3. `@concurrent` for offloaded work
- **Applicability:** MEDIUM — 4 `Task.detached` call sites
- **Files:** EQPresetStore (3), SkinManager (1)
- **Risk:** Low — same runtime behavior, better documentation
- **Benefit:** Self-documenting intent vs `Task.detached`

### 4. `@MainActor` isolated conformances
- **Applicability:** LOW — 1 conformance (`StreamPlayer` delegate)
- **Risk:** Low — same behavior, cleaner than `@preconcurrency`

### 5. `Task.immediate`
- **Applicability:** LOW — optional enhancement for latency-sensitive callbacks
- **Risk:** Very low — still unstructured task, just starts sooner

### 6. Task naming
- **Applicability:** LOW — debugging enhancement only
- **Risk:** Zero — no runtime behavior change

---

## Phase 5 Blast Radius: Default MainActor Isolation

With `SWIFT_DEFAULT_ISOLATION: MainActor`, every declaration in the module defaults to `@MainActor`
unless explicitly opted out with `nonisolated`. This section maps what MUST be opted out.

### Value Types Inventory (102 total)

- **48 SwiftUI View structs** — Already `@MainActor` via `View` protocol conformance. No change needed.
- **13 Sendable structs** — `Track`, `EQPreset`, `EqfPreset`, `Skin`, `PlaylistStyle`, `VisualizerData`,
  `ButterchurnFrame`, `SpriteResolver`, `PlaylistAttachmentSnapshot`, `VideoAttachmentSnapshot`,
  `PlaylistDockingContext`, `PersistedWindowFrame`, `Size2D`. These cross isolation boundaries.
  **Must be marked `nonisolated`** or their `Sendable` conformance will conflict.
- **Pure-data structs** — `M3UEntry`, `SpritePositions`, `SpriteCoords`, `Sprite`, `SkinSprites`,
  `WindowSpec`, `RadioStation`, `DockPaneState`. If only used on MainActor, no issue. If passed
  across boundaries, need `nonisolated`.
- **Geometry/utility structs** — `Point`, `Diff`, `Box`, `BoundingBox` (SnapUtils). Pure value types.
  `WindowDockingGeometry` already marked `nonisolated struct`.

### Static Method Namespaces Needing `nonisolated`

These are enum/struct namespaces with static methods that do NOT need MainActor:

| Type | File | Reason |
|------|------|--------|
| `SkinArchiveLoader` | SkinManager.swift | File I/O — called from `Task.detached`/`@concurrent` |
| `MetadataLoader` | MetadataLoader.swift | Async I/O — `loadTrackMetadata`, `loadAudioProperties`, `loadVideoMetadata` |
| `EQFCodec` | EQF.swift | Pure data parsing |
| `M3UParser` | M3UParser.swift | Pure data parsing |
| `PLEditParser` | PLEditParser.swift | Pure data parsing |
| `VisColorParser` | VisColorParser.swift | Pure data parsing |
| `AppLog` | AppLogger.swift | Logging — called from any context |
| `SnapUtils` | SnapUtils.swift | Pure geometry calculations |

**All of these need `nonisolated` annotation** under default MainActor isolation.

### Enums Needing `nonisolated`

| Type | File | Reason |
|------|------|--------|
| `PlaybackState` | Track.swift | Used across boundaries |
| `PlaybackStopReason` | Track.swift | Used across boundaries |
| `SkinSource` | Skin.swift | Hashable, used in collections |
| `WindowType` | WindowSpec.swift | CaseIterable |
| `M3UParseError` | M3UParser.swift | Error type |
| `SkinImportError` | SkinManager.swift | Error type |
| `LogCategory` | AppLogger.swift | Used from any context |
| `SemanticSprite` | SpriteResolver.swift | Used by Sendable SpriteResolver |

### Classes NOT Needing Change (already @MainActor)

All ~30+ `@Observable` and `@MainActor` classes in the audit table above. Default isolation
matches their current explicit annotation. The `@MainActor` annotation can be removed.

### Estimated Opt-Out Count

| Category | Count | Action |
|----------|-------|--------|
| Remove `@MainActor` from classes | ~30 | Remove annotation |
| Add `nonisolated` to Sendable structs | ~13 | Add `nonisolated struct` |
| Add `nonisolated` to static namespaces | ~8 | Add `nonisolated enum/struct` |
| Add `nonisolated` to enums | ~8 | Add `nonisolated enum` |
| Add `nonisolated` to pure-data structs | ~8-12 | Case-by-case |
| **Total annotations changed** | **~67-71** | |

**Conclusion:** Phase 5 removes ~30 `@MainActor` annotations but adds ~37-41 `nonisolated` annotations.
The net annotation count is roughly similar. The benefit is that `nonisolated` opt-outs make the
concurrency boundaries MORE visible — you can scan for "what escapes the main actor?" instead of
"what forgot the annotation?". However, the cost-benefit is less clear-cut than initially assessed.

**Revised recommendation:** Phase 5 should be **optional / deferred** unless the team values
the "MainActor by default, opt-out for concurrency" mental model. The annotation count doesn't
decrease meaningfully.

---

## Oracle Review Findings (2026-03-13)

Codex Oracle (gpt-5.3-codex, xhigh reasoning) reviewed the plan against the codebase. Key findings:

### 1. ZIPFoundation Compatibility Blocker (RESOLVED)
ZIPFoundation 0.9.19/0.9.20 has non-concurrency-safe global mutable vars (`var maxUInt32`,
`var maxUInt16` in `Archive+ZIP64.swift:142-143`) that fail under strict concurrency + Swift 6.2.

**Deep research (2026-03-13):**
- 0.9.20 (latest release, Sep 2025): NOT fixed
- `development` branch (Jan 2026 commits): NOT fixed
- Issue #345 "Swift 6 Support": Open since Dec 2024, 0 comments, no activity
- SWCompression (tsolomko): PR #58 for Swift 6 was REJECTED by maintainer (Sep 2024)
- Apple Compression framework: Raw compression only, not a ZIP parser
- ZipArchive: Obj-C wrapper, no Swift concurrency support
- **No Swift ZIP library in the ecosystem is fully Swift 6.2 compliant**

**Resolution:** `@preconcurrency import ZIPFoundation` in `SkinManager.swift`.
Standard approach, already used in the codebase (`StreamPlayer.swift:1` for AVFoundation).

### 2. LockFreeRingBuffer New Warnings
Under Swift 6.2, unused return values from `wrappingIncrementThenLoad` (lines 78, 129, 179)
produce warnings. Need `_ =` or switch to `wrappingIncrement`.

### 3. `@concurrent` Isolation Constraint
`@concurrent` on instance methods of `@MainActor` classes creates an isolation mismatch. Extracted
I/O functions must be `nonisolated static` or on separate nonisolated types. This affects Phase 4
design for `EQPresetStore` (which is `@MainActor @Observable`).

### 4. WindowCoordinator Isolated Deinit Candidate
`WindowCoordinator.deinit` cannot call `settingsObserver.stop()` because deinit is nonisolated.
This is an additional `isolated deinit` candidate not in the original plan.

### 5. Isolated Deinit Timing
`isolated deinit` is enqueued on the actor's executor, not immediate. Taps, timers, and observers
may live slightly longer. Low practical risk because explicit `cleanup()`/`stop()` methods are
the primary cleanup path; deinit is a safety net.

### 6. Phase 5 Deferral Confirmed
Oracle agrees deferral is justified — explicit `@MainActor` is already consistent and clear in
this codebase.

---

## Prior Art in Codebase

- `tasks/concurrency-review/` — Previous concurrency audit (2026-01), findings-only reference
- `tasks/swift6-concurrency-review/` — Swift 6 strict concurrency review of Butterchurn code
- `tasks/swift-6-features/` — Research on Swift 6 language features (completed 2025-11)

These are all REFERENCE artifacts. This task is the first to make implementation changes.
