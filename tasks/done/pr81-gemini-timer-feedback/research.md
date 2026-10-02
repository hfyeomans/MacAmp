# PR 81 Gemini Timer Feedback Research

## Question

Validate whether the two open Gemini review threads on PR #81 are still real after the PR was merged.

## Findings

- PR #81 (`fix/timer-runloop-mode-audit`) was merged on 2026-04-29 at 22:24 UTC.
- Current `main` / current branch contains the PR #81 merge commit and later closeout commits.
- `scripts/resolve-pr-comments.sh 81 list-all` shows two remaining open Gemini threads:
  - `MacAmpApp/ViewModels/ButterchurnPresetManager.swift:212`
  - `MacAmpApp/ViewModels/ButterchurnPresetManager.swift:246`
- The current file still contains both flagged callbacks:
  - `Task { @MainActor in self?.nextPreset() }`
  - `Task { @MainActor in self?.showCurrentTrackTitle() }`
- `ButterchurnPresetManager` is annotated `@MainActor`.
- Both timers are manually created with `Timer(timeInterval:repeats:)` and added to `RunLoop.main` with mode `.common`.
- Existing same-family timer callbacks in `AudioEngineController` and `VisualizerPipeline` use `MainActor.assumeIsolated` after asserting main-queue execution.
- `StreamPlayer` uses `MainActor.assumeIsolated` without an explicit dispatch precondition.

## Technical Assessment

The Gemini comments are still valid as a small optimization and consistency issue. They are not stale and not a correctness blocker. Since these timers are added to the main run loop, their blocks are expected to execute on the main thread. For this `@MainActor` manager, using `MainActor.assumeIsolated` avoids allocating/scheduling an unstructured task on every timer tick and makes the code match the lower-overhead timer pattern used elsewhere.

The safest local form is to include `dispatchPrecondition(condition: .onQueue(.main))` before `MainActor.assumeIsolated`, matching the defensive pattern used by `AudioEngineController` and `VisualizerPipeline`.
