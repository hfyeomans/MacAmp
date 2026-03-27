# Research

## Scope

Reviewed `refactor/codebase-wide-simplification` against `main` for:
- dead file and symbol deletions
- DRY consolidations into shared utilities
- concurrency-sensitive utility extraction
- API rename propagation

## Methods

- Read the branch task docs in `tasks/codebase-wide-simplification/`.
- Diffed the branch against `main` for all touched `MacAmpApp` files.
- Searched current `HEAD` and `main` for deleted files/types/symbols with `rg`, `git grep`, and `sg`.
- Checked selector/reflection-style references with `rg` for `#selector`, `NSSelectorFromString`, `NSClassFromString`, and removed type names.
- Built and tested the macOS target with XcodeBuildMCP.

## Key Evidence

- No surviving references on `HEAD` to deleted files/types: `WindowSpec`, `SpritePositions`, `EqGraphView`, `VisualizerOptions`, `SkinnedBanner`, `WindowAccessor`.
- No surviving references on `HEAD` to removed APIs: `supportsEQ`, `supportsBalance`, `supportsVisualizer`, `markEnded()`, `selectTrack(at:)`, `closeKeyWindow()`, `fromVideoPixels(_:)`, `fallbackSkinsDirectory()`, `dimensions(for:)`, `selectPreset(byName:)`, and other documented removals.
- `supportsAudioProcessing` is used exactly at the two old call sites and preserves the old boolean expression from both `supportsEQ` and `supportsBalance`.
- `QueueConfined` is used only by `AudioFileStreamParser` and `AudioConverterDecoder`; `assertConfinement()` call sites are unchanged.
- `MenuItemFactory` is used only in the two menu builders that previously had identical local target classes.
- `TimeFormatting.formatDuration(_:)` is used only in the three views that previously had duplicate local formatters.
- `build_macos` succeeded for scheme `MacAmpApp`.
- `test_macos` passed: 55/55 tests.

## Conclusion

No actionable correctness or regression finding surfaced from static search, diff review, selector/reflection scan, or build/test verification.
