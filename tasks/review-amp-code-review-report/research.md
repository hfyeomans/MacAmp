# Research

## Scope
- Re-run review for the last 12 commits in this repo.
- Validate issues listed in amp_code_review.md against the current codebase and docs/README.md + docs/MACAMP_ARCHITECTURE_GUIDE.md.
- Perform a lightweight concurrency-focused scan using ast-grep (sg).

## Last 12 commits
- dc020a5 docs: Add download section with v0.9.1 release info
- 5452260 chore: Bump version to 0.9.1 (build 2) for release
- 96ba924 docs: Update README with v0.9.1 playlist resize + mini visualizer features
- 49b0d6a feat: Playlist Window Resize + Scroll Slider + Mini Visualizer (#34)
- a649ffc Code Review Sweep: AppLog Migration & Development Comment Cleanup (#33)
- 6dc5203 docs: Add hybrid AppKit/SwiftUI architecture lessons and fix build config
- 31cb98e docs: Update READY_FOR_NEXT_SESSION.md for v0.8.9 release
- 744d5ec feat: Video & Milkdrop Windows (5-Window Architecture) - v0.8.9 (#32)
- 6c98ddb Magnetic Window Docking Foundation - 3-Window Architecture (#31)
- 6ff6feb docs: Update READY_FOR_NEXT_SESSION and skill doc with v0.7.9
- f3a3b0e docs: Update architecture guides with RepeatMode implementation
- 1706fb4 chore: Archive repeat-mode-3way-toggle task to done/

## Architecture references
- docs/README.md is the master documentation index.
- docs/MACAMP_ARCHITECTURE_GUIDE.md is authoritative for architecture and component mapping.

## Codebase findings (sg)
- No DispatchQueue.sync usage in Swift sources.
- No @Published usage; state models use @Observable and most stateful types are @MainActor.
- Task.detached usage appears only in SkinManager.loadSkin for background archive parsing.
- No WindowManager/PluginManager/SkinAssetCache/AudioEngine types in repo; window persistence is via WindowCoordinator.WindowFrameStore.

## Implications
- amp_code_review.md issues target files/types that do not exist in this repo revision; most items are not applicable to current sources.
