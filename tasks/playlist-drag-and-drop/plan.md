# Plan

1. Audit SwiftUI drop APIs (`.onDrop`, `DropDelegate`) and AppKit bridging options to determine which approach preserves pixel-perfect layout for the playlist window.
2. Prototype a minimal drop target that forwards dropped file URLs into `PlaylistWindowActions.handleSelectedURLs` so it shares the main-actor-safe ingestion path.
3. Decide on UX affordances (highlight states, drag cursor) that fit the retro aesthetic without violating sprite rendering guidelines, then document the implementation steps.
