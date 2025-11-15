# Research: Five-Window Documentation Updates

## Sources Reviewed

- `docs/MACAMP_ARCHITECTURE_GUIDE.md`
- `docs/IMPLEMENTATION_PATTERNS.md`
- `docs/README.md`
- `docs/MULTI_WINDOW_ARCHITECTURE.md`, `docs/MULTI_WINDOW_QUICK_START.md`, `docs/WINDOW_FOCUS_ARCHITECTURE.md`
- `MacAmpApp/ViewModels/WindowCoordinator.swift`
- `MacAmpApp/Windows/WinampVideoWindowController.swift`
- `MacAmpApp/Views/WinampVideoWindow.swift`
- `MacAmpApp/Views/Windows/VideoWindowChromeView.swift`
- `MacAmpApp/Windows/WinampMilkdropWindowController.swift`
- `MacAmpApp/Views/WinampMilkdropWindow.swift`
- `MacAmpApp/Views/Windows/MilkdropWindowChromeView.swift`
- `MacAmpApp/Models/WindowFocusState.swift`
- `MacAmpApp/Utilities/WindowFocusDelegate.swift`

## Key Findings

1. **Architecture Guide lagging window count.** The guide still frames window management around the legacy three-window stack (Main, EQ, Playlist) even though `WindowCoordinator` now instantiates five controllers (`mainController`, `eqController`, `playlistController`, `videoController`, `milkdropController`). Existing diagrams and the component breakdown never mention the Video or Milkdrop panes. Only the WindowFocusState section calls out `.isVideoKey`/`.isMilkdropKey`, so the broader document needs new sections/diagrams explaining how the Video and Milkdrop controllers plug into the NSWindowController pattern, docking pipeline, and focus delegate multiplexers.

2. **Video window implementation details:**
   - `WinampVideoWindowController.swift` creates a 275×232 borderless window, applies Winamp window configuration, injects shared environment objects, and installs the translucent hit surface.
   - `WinampVideoWindow.swift` renders VIDEO.bmp chrome when the skin supplies sprites and falls back to `VideoWindowFallbackChrome` when it does not. It uses `AudioPlayer.videoMetadataString` to show status copy.
   - `VideoWindowChromeView.swift` decomposes VIDEO.bmp into reusable sprite slices (titlebar caps/tiles, side borders, bottom segments), ties `WindowFocusState.isVideoKey` to sprite selection, and renders scrolling metadata using `SimpleSpriteImage("CHARACTER_...")` glyphs sourced from TEXT.bmp.

3. **Milkdrop window implementation details:**
   - `WinampMilkdropWindowController.swift` mirrors the video controller setup but includes optional debug logging keyed off `settings.windowDebugLoggingEnabled`.
   - `WinampMilkdropWindow.swift` wraps placeholder visualization content inside GEN.bmp chrome (via `MilkdropWindowChromeView`).
   - `MilkdropWindowChromeView.swift` maps GEN.bmp’s 11-column layout (caps, gold bar, center fill, right cap) and bottom bar (two-piece sprites) while using `WindowFocusState.isMilkdropKey` for titlebar selection. There is a documented TODO for dynamic GEN text glyph extraction.

4. **WindowFocusState + delegate support five windows.** `WindowFocusState.swift` tracks booleans for main/equalizer/playlist/video/milkdrop. `WindowFocusDelegate.swift` updates the appropriate flag in `windowDidBecomeKey` and clears it in `windowDidResignKey`. The architecture doc mentions this bridge but does not connect it back to the video/milkdrop chrome or the expanded coordinator responsibilities.

5. **Implementation Patterns gaps.** `docs/IMPLEMENTATION_PATTERNS.md` lacks:
   - A sprite composition pattern for VIDEO.bmp (titlebar, side borders, metadata ticker) or GEN.bmp (two-piece bottom fill, mixed-state sprites).
   - A pattern describing how `AVPlayerViewRepresentable` is embedded in SwiftUI for video playback.
   - Fallback chrome strategies when skins do not ship VIDEO.bmp.

6. **docs/README metadata mismatches.** The master index still says “10 active technical documents” and “9,845 lines,” and the search index omits keywords like “Video window,” “Milkdrop window,” “VIDEO.bmp,” “GEN.bmp,” “AVPlayer,” or “Butterchurn.” It also lacks instructions about any new dedicated window docs, so adding them would require table/index updates.

7. **Multi-window doc set vs shipping implementation.** `docs/MULTI_WINDOW_ARCHITECTURE.md` plus its quick start describe a multi-WindowGroup SwiftUI approach, but the production app still relies on the NSWindowController-based stack to preserve docking, double-size, and sprite-based chrome. The architecture guide should explicitly call out the decision to keep the NSWindowController pipeline (now expanded to five controllers) and how the new windows integrate with persistence, docking, and focus.

8. **Sprite catalog references.** `SPRITE_SYSTEM_COMPLETE.md` documents the semantic sprite namespace but does not yet walk through VIDEO.bmp or GEN.bmp slicing. Implementation guidance should link to that doc so developers know where sprite keys originate.

## Documentation Gaps Snapshot

| Area | Current Coverage | Missing Pieces |
|------|------------------|----------------|
| Architecture Guide | Three-layer overview, window focus basics | No write-up of the Video/Milkdrop controllers, no diagrams for five-window orchestration, no explanation of how focus/docking/persistence expanded |
| Implementation Patterns | Core sprite/button/state patterns | No VIDEO.bmp or GEN.bmp sprite composition, no AVPlayer embedding guidance, no fallback chrome guidance |
| docs/README | Master index & metrics | Needs updated stats, documentation count, new entries/links for Video/Milkdrop docs, search index additions |
| New dedicated docs | None today | Need to decide whether to add `VIDEO_WINDOW.md` + `MILKDROP_WINDOW.md` for per-window deep dives (layout constants, sprite naming, focus integration) |

