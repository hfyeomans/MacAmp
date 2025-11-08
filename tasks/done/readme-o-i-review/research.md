# Research Notes - README O/I Button Verification

## Key Implementation Findings

- `AppCommands.swift` defines clutter bar command menu items with Control-based shortcuts: Ctrl+O triggers options menu via `settings.showOptionsMenuTrigger`, Ctrl+T toggles time display, Ctrl+I opens track info dialog. No commands register Ctrl+R or Ctrl+S shortcuts.
- `WinampMainWindow.swift` clutter bar buttons connect to settings/audio state: O button calls `showOptionsMenu`, A toggles `isAlwaysOnTop`, I sets `showTrackInfoDialog`, D toggles double size.
- Options menu (`showOptionsMenu`) offers items for elapsed/remaining time display, double size (Ctrl+D), repeat (Ctrl+R), and shuffle (Ctrl+S) with checkmark state managed via NSMenuItem `state`.
- `TrackInfoView.swift` sheet renders current track metadata: title, artist, formatted duration, bitrate, sample rate (kHz), channel count with mono/stereo text, plus stream title fallback and limited metadata notes.
- `AppSettings.swift` stores clutter bar state booleans and toggles; `showTrackInfoDialog` binding drives sheet presentation for TrackInfoView.

## Context

- README additions describe Options menu contents, Track Info dialog fields, clutter bar functionality, and new keyboard shortcuts.
- Need to verify README claims against the Swift implementation identified above.
