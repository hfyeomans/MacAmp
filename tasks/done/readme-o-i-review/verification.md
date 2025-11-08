# Verification - README O/I Button Features

- ✅ Ctrl+O opens the Options menu via `AppCommands` (`MacAmpApp/AppCommands.swift:44-49`).
- ✅ Ctrl+T toggles time display using `AppSettings.toggleTimeDisplayMode()` (`MacAmpApp/AppCommands.swift:49-53`).
- ✅ Ctrl+I opens the Track Information sheet (`MacAmpApp/AppCommands.swift:54-58`).
- ⚠️ Ctrl+R and Ctrl+S are not registered as global keyboard shortcuts; they only appear as key equivalents in the popup menu (`MacAmpApp/Views/WinampMainWindow.swift:870-888`).
- ✅ Options menu includes time display, double size, repeat, and shuffle toggles with checkmark state and Control key equivalents (`MacAmpApp/Views/WinampMainWindow.swift:826-889`).
- ✅ Track information dialog shows title, artist, duration, bitrate, sample rate, channels, stream name fallback, and limited metadata notes (`MacAmpApp/Views/Components/TrackInfoView.swift:12-86`).
- ✅ Clutter bar O/A/I/D buttons are wired to functional actions; V remains pending (`MacAmpApp/Views/WinampMainWindow.swift:512-549`).
