# State
- Research complete: mapped how PLEDIT sprites are defined (`SkinSprites.swift`), extracted (`SkinManager.applySkinPayload`), and rendered (`WinampPlaylistWindow.buildCompleteBackground`).
- Identified VIDEO pipeline differences: runtime slicing with mismatched widths, cyan delimiters included, and stretching inside `VideoWindowChromeView`.
- Plan drafted to add VIDEO metadata to `SkinSprites`, drop manual registration, and mirror playlist-style layout/tiling.
- Awaiting implementation + verification steps once we commit to the code changes.
