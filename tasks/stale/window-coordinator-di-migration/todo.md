# TODO: WindowCoordinator DI Migration

> **Purpose:** Checklist of all implementation tasks for the DI migration effort. Items will be checked off as they are completed. Task is currently deferred pending prerequisite completion.

## Prerequisites
- [ ] Complete `window-coordinator-cleanup` task (safe optional + DockingController DI)
- [ ] Create feature branch

## Phase 1: Create WindowCoordinatorProvider
- [ ] Create `MacAmpApp/ViewModels/WindowCoordinatorProvider.swift`
- [ ] Add to Xcode project (pbxproj)
- [ ] Build with Thread Sanitizer

## Phase 2: Inject Provider into Window Controllers
- [ ] Add `coordinatorProvider` parameter to WinampMainWindowController.init()
- [ ] Add `coordinatorProvider` parameter to WinampEqualizerWindowController.init()
- [ ] Add `coordinatorProvider` parameter to WinampPlaylistWindowController.init()
- [ ] Add `coordinatorProvider` parameter to WinampVideoWindowController.init()
- [ ] Add `coordinatorProvider` parameter to WinampMilkdropWindowController.init()
- [ ] Add `.environment(coordinatorProvider)` to each controller's rootView
- [ ] Update WindowCoordinator.init() to create provider and pass to controllers
- [ ] Add `coordinatorProvider.coordinator = self` after full initialization
- [ ] Build with Thread Sanitizer

## Phase 3: Migrate View Usages (one at a time, build after each)
- [ ] WinampEqualizerWindow.swift: Add @Environment, replace 2 usages
- [ ] Build + manual test EQ window
- [ ] WinampVideoWindow.swift: Add @Environment, replace 1 usage
- [ ] Build + manual test Video window
- [ ] WinampMilkdropWindow.swift: Add @Environment, replace 1 usage
- [ ] Build + manual test Milkdrop window
- [ ] MilkdropWindowChromeView.swift: Add @Environment, replace 2 usages
- [ ] Build + manual test Milkdrop resize
- [ ] WinampMainWindow.swift: Add @Environment, replace 3 usages
- [ ] Build + manual test Main window (EQ/Playlist toggles)
- [ ] VideoWindowChromeView.swift: Add @Environment, replace 4 usages
- [ ] Build + manual test Video resize
- [ ] WinampPlaylistWindow.swift: Add @Environment, replace 6 usages
- [ ] Build + manual test Playlist resize + preview

## Phase 4: Cleanup & Verification
- [ ] Verify no remaining `WindowCoordinator.shared` in migrated Views
- [ ] Run full test suite with Thread Sanitizer
- [ ] Oracle review (gpt-5.3-codex, reasoningEffort: xhigh) on all changed files
- [ ] Update depreciated.md with completed items
- [ ] Update state.md with final results
- [ ] Commit and create PR
