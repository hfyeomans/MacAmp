# Research

## Context
- Reviewed `MacAmpApp/Views/WinampMainWindow.swift` focusing on clutter bar O button menu lifecycle and time display rendering.
- Inspected `MacAmpApp/Models/AppSettings.swift` for new state used to trigger the menu from keyboard shortcuts.
- Examined `MacAmpApp/AppCommands.swift` for command bindings associated with the Control+O shortcut.

## Existing Patterns
- `WinampMainWindow` keeps SwiftUI `@State` for transient UI state including menus; new `activeOptionsMenu` follows same pattern seen elsewhere for timers and toggles.
- Menu item creation relies on custom `MenuItemTarget` objects to bridge closures to `NSMenuItem` selectors, consistent with existing design.
- Keyboard shortcut commands rely on binding to `AppSettings` flags (`showTrackInfoDialog`, etc.), matching the approach adopted for other clutter bar buttons.

## Open Questions
- None identified during initial inspection; implementation appears self-contained.
