# TODO: WindowCoordinator Cleanup

> **Purpose:** Checklist of all implementation tasks for this cleanup effort. Items are checked off as they are completed. Tracks build verification and manual testing requirements.

## Phase 1: Remove Unused lastVideoAttachment
- [x] Remove `private var lastVideoAttachment: VideoAttachmentSnapshot?` from WindowResizeController.swift
- [x] Build with Thread Sanitizer
- [x] Grep confirms no remaining references

## Phase 2: Replace Polling Loop with Observation
- [x] Add `import Observation` to WindowCoordinator+Layout.swift
- [x] Replace `presentWindowsWhenReady()` with synchronous `withObservationTracking` (Oracle-corrected: no async gap)
- [x] Add `observeSkinReadiness()` private method with immediate re-check after registration
- [x] Remove old `skinPresentationTask` polling Task (property + deinit cancel + all references removed)
- [x] Build with Thread Sanitizer
- [x] Manual test: App launch with default skin - windows appear correctly
- [x] Manual test: No visual delay on app startup

## Phase 3A: Safe Optional Singleton
- [x] Change `static var shared: WindowCoordinator!` to `static var shared: WindowCoordinator?`
- [x] Remove `// swiftlint:disable:next implicitly_unwrapped_optional` comment
- [x] Build with Thread Sanitizer

## Phase 3B: DockingController Property Injection
- [x] Add `@ObservationIgnored weak var windowCoordinator: WindowCoordinator?` to DockingController
- [x] Replace `WindowCoordinator.shared` with `windowCoordinator` in `togglePlaylist()`
- [x] Replace `WindowCoordinator.shared` with `windowCoordinator` in `toggleEqualizer()`
- [x] Add `dockingController.windowCoordinator = coordinator` in MacAmpApp.init()
- [x] Build with Thread Sanitizer
- [x] Run full test suite
- [x] Manual test: Toggle EQ/Playlist via keyboard shortcuts

## Post-Implementation
- [x] Oracle review (gpt-5.3-codex, reasoningEffort: xhigh) on all changed files — no issues found
- [x] Update depreciated.md with completed items
- [x] Update state.md with final results
- [x] Commit with descriptive message
