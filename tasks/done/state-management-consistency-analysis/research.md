# Research Notes

## Sources Reviewed
- `tasks/state-management-consistency-analysis/README.md`
- `tasks/state-management-consistency-analysis/analysis.md`
- `tasks/state-management-consistency-analysis/fixes.md`
- `MacAmpApp/Audio/AudioPlayer.swift`
- `MacAmpApp/ViewModels/SkinManager.swift`
- `MacAmpApp/Models/AppSettings.swift`
- `MacAmpApp/ViewModels/DockingController.swift`
- `MacAmpApp/Views/Components/WinampVolumeSlider.swift`

## Key Observations
- The highlighted “race condition” risks for `AudioPlayer`, `SkinManager`, and `AppSettings` assume uncontrolled multithreaded access. Each type is annotated with `@MainActor`, so state mutations are already serialized (`MacAmpApp/Audio/AudioPlayer.swift:68`, `MacAmpApp/ViewModels/SkinManager.swift:12`, `MacAmpApp/Models/AppSettings.swift:28`). Issues should be reframed around state complexity and validation instead of thread unsafety.
- `AudioPlayer.startProgressTimer()` invalidates the prior timer before creating a new one (`MacAmpApp/Audio/AudioPlayer.swift:655`), so the described “multiple timers” leak in README.md is inaccurate.
- `DockingController.toggleVisibility` and `toggleShade` guard against missing indices before mutation (`MacAmpApp/ViewModels/DockingController.swift:73`, `MacAmpApp/ViewModels/DockingController.swift:88`), invalidating the “unsafe array access” item in analysis.md.
- `BalanceSliderView.swift`, referenced in analysis.md and fixes.md, no longer exists; balance handling now lives in `MacAmpApp/Views/Components/WinampVolumeSlider.swift:133`.
- `tasks/state-management-consistency-analysis/README.md` references `critical-issues.md`, but the file is absent from the task directory.
- Several fix snippets in `tasks/state-management-consistency-analysis/fixes.md` would currently fail or violate existing patterns:
  - Moving `SkinManager.loadSkin` work to a background queue conflicts with the type’s `@MainActor` isolation, risking cross-actor violations.
  - The EQF parsing example references `values` before assignment.
  - Clearing a `cancellables` set assumes SkinManager owns Combine subscriptions; the property is not declared.
- Valid improvement opportunities remain:
  - `AppSettings.userSkinsDirectory` swallows directory-creation errors (`MacAmpApp/Models/AppSettings.swift:94`).
  - `SkinManager.loadSkin` never clears `loadingError` after a successful load (`MacAmpApp/ViewModels/SkinManager.swift:327`–520).
  - `AudioPlayer` still uses numerous boolean flags, which complicates state reasoning even if it does not introduce cross-thread races.

## Open Questions
- Do we intend to keep a documentation file dedicated to “critical issues”? If so, we should restore it; otherwise, strip the reference from README.md.
- Should timer accuracy or lifecycle be improved (e.g., using `DispatchSourceTimer`), or is the current `Timer` sufficient once documentation is corrected?
- Are there existing unit tests or infrastructure that we should align with when updating state validation logic?
