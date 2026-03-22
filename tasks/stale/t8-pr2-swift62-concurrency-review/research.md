# Research

## Scope
Review PR changes in:
- `MacAmpApp/Audio/AudioPlayer.swift`
- `MacAmpApp/Audio/EQPresetStore.swift`
- `MacAmpApp/ViewModels/SkinManager.swift`
- `MacAmpApp/Audio/MetadataLoader.swift`

Validation targets:
1. `isolated deinit` correctness and cleanup safety
2. `@concurrent` static function isolation
3. `SkinArchiveLoader.loadAsync()` wrapper correctness
4. Sendable crossings for `@concurrent` boundaries
5. Remaining `Task.detached` usage
6. Other concurrency risks

## Methods
- Read target files with line numbers.
- Structural scan with `ast-grep` for `Task.detached` and MainActor task usage.
- Text scan for `@concurrent`, deinit/isolation, and call sites.
- Checked model types used across `@concurrent` boundaries (`EQPreset`, `EqfPreset`, `SkinArchivePayload`).
- Built macOS target with XcodeBuildMCP under Swift 6.2 / strict concurrency.

## Key Findings
- `AudioPlayer` uses `isolated deinit` and calls only synchronous actor-isolated cleanup (`progressTimer?.invalidate()`, `deactivateStreamBridge()`, `visualizerPipeline.removeTap()`).
- `EQPresetStore` `@concurrent` static functions operate on value inputs/outputs and do not access actor-isolated instance state.
- `SkinArchiveLoader.loadAsync()` correctly wraps sync ZIP load in `@concurrent` async function.
- Crossed data types are Sendable-safe:
  - `EQPreset` is `Sendable`
  - `EqfPreset` is `Sendable`
  - `SkinArchivePayload` has Sendable field types and is private/internal-use
- No `Task.detached` usage remains in Swift sources (`rg -n "Task\.detached" -g '*.swift'` returned none).
- Build passed (`build_macos`) with `SWIFT_VERSION = 6.2` and `SWIFT_STRICT_CONCURRENCY = complete`.

## Residual Risk Notes
- `EQPresetStore.savePerTrackPresets()` can schedule overlapping async disk writes; completion order is not guaranteed, so latest snapshot persistence is probabilistic under bursty writes.
- `SkinManager.loadSkin(from:)` uses generation checks to prevent stale apply, but prior background loads are not cancelled.
