# Research Notes

## Scope
- Review double-size button implementation across AppSettings, SkinSprites, SkinToggleStyle, WinampMainWindow, UnifiedDockView
- Check for dead code, bloat, duplication, architecture issues, naming, Swift 6 problems, performance, best practices

## Observations
- `AppSettings` holds new `isDoubleSizeMode`, `mainWindow`, `baseWindowSize`, `targetWindowFrame`; includes debug `print` statements in initializer and `didSet`
- Skin sprites extended with clutter bar buttons; coordinates for selected sprites identical to base assets
- `SkinToggleStyle` defines reusable ToggleStyle but not referenced anywhere
- `WinampMainWindow` adds clutter bar buttons using plain Buttons, with debug prints and disabled scaffolds
- `UnifiedDockView` scales windows based on `isDoubleSizeMode`, duplicates scale calculations across multiple helpers, logs via `print`
- Numerous placeholder states remain (Options/AlwaysOnTop/Info/Visualizer) with `Button(action: {})` patterns and `.disabled(true)` but still declared each render

## Existing Patterns
- Other components use `SimpleSpriteImage` and environment injection for dependencies
- Scaling typically derived from `WinampSizes` constants; double-size logic centralised in new helpers but also repeated manual `scaleEffect` usage per view
- Logging elsewhere generally uses custom logging or avoids `print` (need to confirm) — new prints may be inconsistent

## Potential Risks to Examine
- Residual `NSWindow` references in `AppSettings` (retain cycles? concurrency?)
- Dead code: unused ToggleStyle, `targetWindowFrame`, scaffolding states
- Performance impact of recalculating sizes & repeated `Group` with disabled buttons
- Adherence to architecture: AppSettings as global store? check for separation of view logic vs settings
- Swift 6: ensure @Observable + `@MainActor` safe; check prints referencing `self` in didSet

