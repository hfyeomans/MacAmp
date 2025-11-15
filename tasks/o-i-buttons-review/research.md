# O/I Buttons Review – Research

## Scope
Files analyzed per request:
- `MacAmpApp/Models/AppSettings.swift`
- `MacAmpApp/Views/WinampMainWindow.swift`
- `MacAmpApp/AppCommands.swift`
- `MacAmpApp/Views/Components/TrackInfoView.swift`

## Key Findings
- **AppSettings (`MacAmpApp/Models/AppSettings.swift`)**
  - `@Observable @MainActor` singleton with didSet persistence for many toggles (double size, always-on-top, video window, repeat mode, new `timeDisplayMode`).
  - `timeDisplayMode` enum persisted via `UserDefaults.standard` key `timeDisplayMode`; `toggleTimeDisplayMode()` flips between `.elapsed` and `.remaining`.
  - Transient clutter bar triggers `showOptionsMenuTrigger` and `showTrackInfoDialog` stored in settings for cross-component coordination.

- **WinampMainWindow.swift**
  - Binds to `AppSettings` via `@Environment` and uses `settings.timeDisplayMode` to show minus sign + digits for remaining time. `onTapGesture` toggles mode.
  - Clutter bar: O button opens `showOptionsMenu` (contextual NSMenu). I button sets `settings.showTrackInfoDialog = true` and sheet binding uses `settings.showTrackInfoDialog`.
  - Options `NSMenu` built dynamically; uses nested `createMenuItem` helper capturing `[weak settings]` or `[weak audioPlayer]` closures. Strong reference to menu stored in `@State private var activeOptionsMenu` (set to new `NSMenu()` but not retained elsewhere?). `MenuItemTarget` `@MainActor` bridging class retains closure via `representedObject`.
  - Menu attaches to Winamp window by scanning `NSApp.windows`, deriving screen point from `buttonPosition` scaled for double-size. Items cover time display toggle, double size, repeat states, shuffle.

- **AppCommands.swift**
  - Adds matching keyboard shortcuts (Ctrl+O for options, Ctrl+T toggles time, Ctrl+I opens track info). Uses `settings.showOptionsMenuTrigger` bool to request UI show.

- **TrackInfoView.swift**
  - SwiftUI modal reading from `AudioPlayer` and `PlaybackCoordinator`. Presents metadata for local tracks or streams, includes InfoRow subview. Dismiss button uses environment.

## Potential Review Targets
- Ensure `activeOptionsMenu` retains `NSMenu` long enough (needs assignment?).
- Validate `MenuItemTarget` lifecycle (no global storage; relies on `representedObject`).
- Check concurrency: `MenuItemTarget` `@MainActor`, but closures toggling settings may capture `@Environment` objects already `@MainActor`.
- Examine `showTrackInfoDialog` binding for accurate dismissal (sheet binding sets `settings.showTrackInfoDialog`). Need to confirm `TrackInfoView` uses dismiss to update binding? (sheet binding handles automatically when dismissed?).
- Confirm `timeDisplayMode` migration uses new `UserDefaults` key and handles toggles from menu/time display tap/Command+T.

