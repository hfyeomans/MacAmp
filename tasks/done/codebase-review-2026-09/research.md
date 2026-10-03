# Research — codebase review 2026-09

Method:
- Mechanical scans: `rg`, `fd`, `git ls-files`, `du`, `swiftlint lint --quiet` (0.65.1).
- Direct reading of core orchestration files: `AudioPlayer`, `PlaybackCoordinator`, `WindowCoordinator(+Layout)`, `DockingController`, `WindowVisibilityController`, `AppCommands`, `SkinsCommands`, `MacAmpApp`, `AppSettings`.
- Four parallel read-only area reviews: Audio/; Views/**; Windows/ + Utilities/ + ViewModels/; Models/ + Tests/ + config + hygiene. Each returned file:line evidence, which was spot-verified before inclusion.

Verified facts:
- HEAD `0de0a58` on `feat/avplayer-native-video-dsp`; review branch `review/codebase-audit-2026-09`.
- ~20.4k lines Swift in `MacAmpApp/`, ~3.0k in tests; 22 `@Observable`, 0 `ObservableObject`, 0 `print`, 0 `try!`/`as!`.
- `SkinManager` is `@Observable @MainActor` (comment at `:7-9` is stale).
- `module-cache/` 157 tracked `.pcm` files, 120 MB, from commit `6c98ddb`; `weak_struct` Mach-O also from `6c98ddb`.
- `project.yml` floor 15.0 vs `Package.swift` 26.0; `Package.swift` target includes ObjC sources.
- `AudioPlayer.playTrack` `:518-535` sets `seekGuardActive` true, schedules a 50 ms clear, then clears synchronously.

Findings are consolidated in `review.md`.
