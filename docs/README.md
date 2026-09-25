# MacAmp Documentation Guide

**Version:** 3.13.0
**Date:** 2026-09-25
**Purpose:** Master index and navigation guide for all MacAmp documentation
**Total Documentation:** 8,811 active lines across 12 current docs + 27 archived docs

---

## Table of Contents

1. [Quick Start by Audience](#quick-start-by-audience)
2. [Test Plan Quick Reference](#test-plan-quick-reference)
3. [Complete Documentation Inventory](#complete-documentation-inventory)
4. [Topic Lookup](#topic-lookup)
5. [Common Questions](#common-questions)
6. [Other Directories and Archive](#other-directories-and-archive)
7. [Documentation Statistics](#documentation-statistics)
8. [Maintenance Guidelines](#maintenance-guidelines)
9. [Version History](#version-history)

---

MacAmp's docs cover a pixel-perfect Winamp 2.x recreation for macOS 27+: architecture, implementation patterns, the multi-window system, each window type, the sprite/skin system, and build/release. `docs/*.md` describes the current codebase; `docs/archive/` holds superseded material.

## Quick Start by Audience

| If You Are... | Start With... | Then Read... |
|---------------|---------------|--------------|
| **New Developer** | [MACAMP_ARCHITECTURE_GUIDE.md](MACAMP_ARCHITECTURE_GUIDE.md) from [Executive Summary](MACAMP_ARCHITECTURE_GUIDE.md#executive-summary) through [Skin System](MACAMP_ARCHITECTURE_GUIDE.md#skin-system-complete-architecture) | [Pattern Overview](IMPLEMENTATION_PATTERNS.md#pattern-overview), [State Management](IMPLEMENTATION_PATTERNS.md#state-management-patterns), [UI Component Patterns](IMPLEMENTATION_PATTERNS.md#ui-component-patterns), then [Test Plan Quick Reference](#test-plan-quick-reference) |
| **Bug Fixer** | [Architecture Quick Reference](MACAMP_ARCHITECTURE_GUIDE.md#quick-reference), [Topic Lookup](#topic-lookup) | [Anti-Patterns to Avoid](IMPLEMENTATION_PATTERNS.md#anti-patterns-to-avoid), [Common Pitfalls & Solutions](MACAMP_ARCHITECTURE_GUIDE.md#common-pitfalls--solutions) |
| **Feature Developer** | [State](IMPLEMENTATION_PATTERNS.md#state-management-patterns), [UI Component](IMPLEMENTATION_PATTERNS.md#ui-component-patterns), [Audio Processing Patterns](IMPLEMENTATION_PATTERNS.md#audio-processing-patterns), [Three-Layer Architecture](MACAMP_ARCHITECTURE_GUIDE.md#three-layer-architecture-deep-dive), [Component Integration Maps](MACAMP_ARCHITECTURE_GUIDE.md#component-integration-maps) | UI work: [SPRITE_SYSTEM_COMPLETE.md](SPRITE_SYSTEM_COMPLETE.md), [WINAMP_SKIN_VARIATIONS.md](WINAMP_SKIN_VARIATIONS.md) |
| **Window Work** | [MULTI_WINDOW_ARCHITECTURE.md](MULTI_WINDOW_ARCHITECTURE.md) | The window's own doc (VIDEO / PLAYLIST / MILKDROP), [WINDOW_FOCUS_ARCHITECTURE.md](WINDOW_FOCUS_ARCHITECTURE.md) |
| **Release Manager** | [RELEASE_BUILD_GUIDE.md](RELEASE_BUILD_GUIDE.md) | (all-in-one guide) |

---

## Test Plan Quick Reference

MacAmp tests use **Swift Testing** (`swift-tools-version: 6.2`, migrated from XCTest) in `Tests/MacAmpTests`, run through the `MacAmpApp` scheme with a single "All" test plan configuration. `project.yml` (XcodeGen) generates the Xcode project.

```bash
brew install xcodegen  # if not installed
xcodegen generate      # generates MacAmpApp.xcodeproj from project.yml
xcodebuild test -scheme MacAmpApp -destination 'platform=macOS' -enableThreadSanitizer YES
```

---

## Complete Documentation Inventory

### Architecture & Design (9 documents, 7,896 lines)

#### **[MACAMP_ARCHITECTURE_GUIDE.md](MACAMP_ARCHITECTURE_GUIDE.md)** ⭐
- **Size**: 155KB, 2,439 lines
- **Last Updated**: 2026-03-25
- **Status**: ✅ AUTHORITATIVE
- **Purpose**: Complete architectural reference for MacAmp
- **Key Sections**:
  - Three-layer architecture (mechanism → bridge → presentation)
  - Unified audio pipeline (local files and streams through AVAudioEngine; video audio through AVPlayer with an `MTAudioProcessingTap` applying EQ/preamp/balance and feeding the visualizer)
  - State management with Swift 6 @Observable
  - Internet radio streaming implementation
  - Component integration maps
  - 20-bar Goertzel-like spectrum analyzer
  - Window snapping + double-size docking pipeline
  - Custom menu patterns (SpriteMenuItem + PlaylistMenuDelegate)
- **When to Read**: Starting development, architectural reviews, major refactoring
- **Related Docs**: IMPLEMENTATION_PATTERNS.md, SPRITE_SYSTEM_COMPLETE.md

#### **[IMPLEMENTATION_PATTERNS.md](IMPLEMENTATION_PATTERNS.md)** ⭐
- **Size**: 146KB, 3,087 lines
- **Last Updated**: 2026-03-25
- **Status**: ✅ AUTHORITATIVE
- **Purpose**: Practical code patterns and best practices
- **Key Sections**:
  - State management patterns (@Observable, @MainActor)
  - UI component patterns (sprites, buttons, sliders)
  - Audio processing patterns (unified pipeline, streaming)
  - Async/await patterns with Swift concurrency
  - Error handling with Result builders
  - Testing patterns (mocks, async tests, test plan commands)
  - Migration guides (ObservableObject → @Observable)
  - Anti-patterns to avoid
- **When to Read**: Before implementing features, code reviews, refactoring
- **Related Docs**: MACAMP_ARCHITECTURE_GUIDE.md

#### **[SPRITE_SYSTEM_COMPLETE.md](SPRITE_SYSTEM_COMPLETE.md)** ⭐
- **Size**: 14KB, 337 lines
- **Last Updated**: 2026-09-25
- **Status**: ✅ AUTHORITATIVE
- **Purpose**: Complete reference for semantic sprite resolution system
- **Key Sections**:
  - Semantic sprite enum and `candidates(for:)` priority lists
  - SpriteResolver implementation and resolution algorithm
  - Fallback generation in SkinManager (default-skin sprites, then transparent)
  - Skin file structure and sprite coordinates (`SkinSprites.swift`)
  - Integration with SwiftUI views (`SimpleSpriteImage`)
  - Testing and validation
- **When to Read**: Working with UI, adding skin support, debugging visuals
- **Related Docs**: WINAMP_SKIN_VARIATIONS.md

#### **[MULTI_WINDOW_ARCHITECTURE.md](MULTI_WINDOW_ARCHITECTURE.md)** ⭐
- **Size**: 16KB, 264 lines
- **Last Updated**: 2026-02-09
- **Status**: ✅ PRODUCTION
- **Purpose**: Complete multi-window system design and implementation
- **Key Sections**:
  - Window hierarchy and ownership
  - Focus management across windows
  - Window grouping and clustering
  - Magnetic snapping coordination
  - Window lifecycle management
  - SwiftUI WindowGroup integration
  - **WindowCoordinator Refactoring (2026-02)**
    - Facade + Composition pattern (1,357 → 223 lines, -84%)
    - 11-file decomposition with dependency matrix
    - Swift 6.2 concurrency patterns
  - Testing and debugging strategies
- **When to Read**: Working with window management, god object refactoring, Swift 6.2 patterns
- **Related Docs**: WINDOW_FOCUS_ARCHITECTURE.md, VIDEO_WINDOW.md, MILKDROP_WINDOW.md

#### **[VIDEO_WINDOW.md](VIDEO_WINDOW.md)** ⭐
- **Size**: 27KB, 537 lines
- **Last Updated**: 2025-11-14
- **Status**: ✅ PRODUCTION
- **Purpose**: Complete video window documentation with chrome system and playback architecture
- **Key Sections**:
  - Window specifications and coordinate system
  - VIDEO.bmp sprite definitions and extraction
  - AVPlayerViewRepresentable integration (`updatesNowPlayingInfoCenter = false`; PlaybackCoordinator owns Now Playing and remote commands)
  - Video audio DSP: EQ/preamp/balance/visualizer via an in-place `MTAudioProcessingTap` on `AVPlayerItem.audioMix` (stereo at the source rate; multichannel downmixed)
  - Chrome components (titlebar, borders, metadata)
  - 1x/2x window resizing implementation
  - Fallback chrome for missing VIDEO.bmp
  - Testing guidelines and future enhancements
- **When to Read**: Working with video playback, implementing window chrome, debugging VIDEO.bmp issues
- **Related Docs**: SPRITE_SYSTEM_COMPLETE.md, WINDOW_FOCUS_ARCHITECTURE.md

#### **[PLAYLIST_WINDOW.md](PLAYLIST_WINDOW.md)** ⭐
- **Size**: 19KB, 376 lines
- **Last Updated**: 2026-03-25
- **Status**: ✅ PRODUCTION
- **Purpose**: Complete playlist window documentation with segment-based resize system
- **Key Sections**:
  - Window specifications and segment grid (25×29px)
  - PlaylistWindowSizeState @Observable model
  - Three-section bottom bar (LEFT/CENTER/RIGHT)
  - List operations (NEW LIST / LOAD LIST / SAVE LIST)
  - Track position display (`trackPositionString`)
  - Resize gesture with AppKit preview overlay
  - Scroll slider with proportional thumb
  - Mini visualizer (when main window shaded)
  - WindowCoordinator bridge methods
  - Size persistence and NSWindow sync
- **When to Read**: Working with playlist, implementing resize, debugging layout issues
- **Related Docs**: VIDEO_WINDOW.md, WINDOW_FOCUS_ARCHITECTURE.md, MULTI_WINDOW_ARCHITECTURE.md

#### **[MILKDROP_WINDOW.md](MILKDROP_WINDOW.md)** ⭐
- **Size**: 38KB, 613 lines
- **Last Updated**: 2026-03-22
- **Status**: ✅ PRODUCTION - Complete with Butterchurn visualization and resize
- **Purpose**: Milkdrop visualization window with Butterchurn.js integration
- **Key Sections**:
  - Window specification and GEN.bmp sprite system
  - **Butterchurn.js Integration** (7 phases, complete)
    - WKUserScript injection for JavaScript libraries
    - Swift→JS audio bridge at 30 FPS
    - ButterchurnPresetManager (cycling, randomization, history)
    - Context menu with NSMenu closure-to-selector bridge
    - Track title interval display (Phase 7)
  - **Window Resizing** ([GEN.bmp Chrome Implementation](MILKDROP_WINDOW.md#4-genbmp-chrome-implementation)) - Segment-based resize with dynamic titlebar
    - MilkdropWindowSizeState @Observable model
    - Dynamic gold filler expansion for titlebars
    - AppKit preview overlay during resize
    - Butterchurn canvas sync on resize
  - Two-piece sprite system for titlebars and letters
  - Chrome rendering with active/inactive states
- **When to Read**: Implementing visualizations, WKWebView JavaScript integration, audio bridging, window resize
- **Related Docs**: SPRITE_SYSTEM_COMPLETE.md, VIDEO_WINDOW.md, WINDOW_FOCUS_ARCHITECTURE.md, PLAYLIST_WINDOW.md

#### **[WINDOW_FOCUS_ARCHITECTURE.md](WINDOW_FOCUS_ARCHITECTURE.md)** ⭐
- **Size**: 6KB, 148 lines
- **Last Updated**: 2026-09-25
- **Status**: ✅ PRODUCTION
- **Purpose**: Window focus state tracking for active/inactive titlebar rendering
- **Key Sections**:
  - WindowFocusState @Observable model
  - WindowFocusDelegate NSWindowDelegate adapter
  - Delegate wiring (`WindowDelegateWiring`) and WindowDelegateMultiplexer
  - View layer usage (per-window flags and titlebar sprites)
  - Adding a new window
- **When to Read**: Implementing window chrome, adding new windows, debugging focus issues
- **Related Docs**: MULTI_WINDOW_ARCHITECTURE.md, VIDEO_WINDOW.md, MILKDROP_WINDOW.md

#### **[CUSTOM_DRAG_FIX.md](CUSTOM_DRAG_FIX.md)**
- **Size**: 4KB, 95 lines
- **Last Updated**: 2026-09-25
- **Status**: ✅ CURRENT
- **Purpose**: Custom titlebar drag without windows repelling each other or clusters breaking during fast drags
- **Key Sections**:
  - Problem analysis: incremental deltas on current positions, dynamic cluster recalculation, missing base boxes
  - Webamp's working pattern (apply the total delta to base boxes captured at drag start)
  - Solution: `DragContext`, `beginCustomDrag` (main drags the cluster; EQ/Playlist detach), `updateCustomDrag` (snaps the cluster bounding box)
  - Verification
- **When to Read**: Implementing custom window dragging, debugging drag issues
- **Related Docs**: MULTI_WINDOW_ARCHITECTURE.md

### Build & Distribution (1 document, 239 lines)

#### **[RELEASE_BUILD_GUIDE.md](RELEASE_BUILD_GUIDE.md)**
- **Size**: 11KB, 239 lines
- **Last Updated**: 2026-09-25
- **Status**: ✅ AUTHORITATIVE
- **Purpose**: Building, signing, notarizing, DMG packaging, and troubleshooting
- **Key Sections**: key settings table (scheme, product, team, notary profile), Prerequisites, Building (Xcode archive and CLI), Notarization, DMG, Verification, Troubleshooting, Code Signing Troubleshooting, Debug vs Release Configuration, Testing a Release Build (`get-task-allow` trap)
- **When to Read**: Cutting a release, signing or notarization failures

### Skin System (1 document, 652 lines)

#### **[WINAMP_SKIN_VARIATIONS.md](WINAMP_SKIN_VARIATIONS.md)**
- **Size**: 5KB, 142 lines
- **Last Updated**: 2026-09-25
- **Status**: ✅ CURRENT
- **Purpose**: Skin format differences (NUMBERS vs NUMS_EX, optional sheets) and how SkinManager handles missing sheets
- **Key Sections**: Two Number Systems, bundled-skin sheet matrix, How MacAmp Handles This, Comparison with Webamp, Fonts vs Sprites
- **When to Read**: A skin renders blank or wrong digits/sprites, adding skin support

---

## Topic Lookup

| Topic | Document | Section |
|-------|----------|---------|
| **@Observable pattern** | IMPLEMENTATION_PATTERNS.md | [State Management Patterns](IMPLEMENTATION_PATTERNS.md#state-management-patterns) |
| **@MainActor usage** | IMPLEMENTATION_PATTERNS.md | [@Observable with @MainActor](IMPLEMENTATION_PATTERNS.md#pattern-observable-with-mainactor), [Strict Concurrency](MACAMP_ARCHITECTURE_GUIDE.md#strict-concurrency) |
| **Action-based bridge pattern** | IMPLEMENTATION_PATTERNS.md | [Action-Based Bridge Pattern](IMPLEMENTATION_PATTERNS.md#pattern-action-based-bridge-pattern) |
| **AudioPlayer decomposition** | MACAMP_ARCHITECTURE_GUIDE.md | [AudioPlayer Decomposition Architecture](MACAMP_ARCHITECTURE_GUIDE.md#audioplayer-decomposition-architecture) |
| **20-bar spectrum analyzer** | MACAMP_ARCHITECTURE_GUIDE.md | [Spectrum Analyzer (20-Bar Goertzel)](MACAMP_ARCHITECTURE_GUIDE.md#spectrum-analyzer-20-bar-goertzel-implementation) |
| **Always On Top (A button)** | MACAMP_ARCHITECTURE_GUIDE.md | [Clutter Bar Buttons](MACAMP_ARCHITECTURE_GUIDE.md#clutter-bar-buttons) |
| **App notarization** | RELEASE_BUILD_GUIDE.md | [Notarization](RELEASE_BUILD_GUIDE.md#notarization) |
| **Audio backend switching** | MACAMP_ARCHITECTURE_GUIDE.md | [The Orchestrator Pattern](MACAMP_ARCHITECTURE_GUIDE.md#the-orchestrator-pattern) |
| **AudioConverterDecoder** | MACAMP_ARCHITECTURE_GUIDE.md | [Stream Decode Pipeline Components](MACAMP_ARCHITECTURE_GUIDE.md#stream-decode-pipeline-components) |
| **AudioFileStreamParser** | MACAMP_ARCHITECTURE_GUIDE.md | [Stream Decode Pipeline Components](MACAMP_ARCHITECTURE_GUIDE.md#stream-decode-pipeline-components) |
| **AVAudioEngine setup** | MACAMP_ARCHITECTURE_GUIDE.md | [AVAudioEngine Graph](MACAMP_ARCHITECTURE_GUIDE.md#avaudioengine-graph-unified-pipeline) |
| **AVAudioSourceNode** | MACAMP_ARCHITECTURE_GUIDE.md | [The Unified Architecture](MACAMP_ARCHITECTURE_GUIDE.md#the-unified-architecture) |
| **Stream decode pipeline** | MACAMP_ARCHITECTURE_GUIDE.md | [Stream Decode Pipeline Components](MACAMP_ARCHITECTURE_GUIDE.md#stream-decode-pipeline-components) |
| **Background I/O fire-and-forget** | IMPLEMENTATION_PATTERNS.md | [Background I/O with @concurrent](IMPLEMENTATION_PATTERNS.md#pattern-background-io-with-concurrent-static-functions-swift-62) |
| **Build configurations** | RELEASE_BUILD_GUIDE.md | [Debug vs Release Configuration](RELEASE_BUILD_GUIDE.md#debug-vs-release-configuration) |
| **Clutter bar buttons** | MACAMP_ARCHITECTURE_GUIDE.md | [Clutter Bar Buttons](MACAMP_ARCHITECTURE_GUIDE.md#clutter-bar-buttons) |
| **Computed forwarding pattern** | IMPLEMENTATION_PATTERNS.md | [Computed Forwarding for API Compatibility](IMPLEMENTATION_PATTERNS.md#pattern-computed-forwarding-for-api-compatibility) |
| **Computed play state (isPlaying/isPaused)** | MACAMP_ARCHITECTURE_GUIDE.md, IMPLEMENTATION_PATTERNS.md | [The Orchestrator Pattern](MACAMP_ARCHITECTURE_GUIDE.md#the-orchestrator-pattern), [Computed Properties](IMPLEMENTATION_PATTERNS.md#pattern-computed-properties-with-dependency-tracking) |
| **Context-aware playlist navigation** | MACAMP_ARCHITECTURE_GUIDE.md | [The Orchestrator Pattern](MACAMP_ARCHITECTURE_GUIDE.md#the-orchestrator-pattern), [Internet Radio Streaming](MACAMP_ARCHITECTURE_GUIDE.md#internet-radio-streaming) |
| **Cross-file SwiftUI extensions (anti-pattern)** | IMPLEMENTATION_PATTERNS.md | [Cross-File SwiftUI Extensions](IMPLEMENTATION_PATTERNS.md#anti-pattern-cross-file-swiftui-extensions-as-view-decomposition) |
| **Code signing errors** | RELEASE_BUILD_GUIDE.md | [Troubleshooting](RELEASE_BUILD_GUIDE.md#troubleshooting), [Code Signing Troubleshooting](RELEASE_BUILD_GUIDE.md#code-signing-troubleshooting) |
| **Component integration** | MACAMP_ARCHITECTURE_GUIDE.md | [Component Integration Maps](MACAMP_ARCHITECTURE_GUIDE.md#component-integration-maps) |
| **Custom menus** | MACAMP_ARCHITECTURE_GUIDE.md | [Sprite-Based Menu System](MACAMP_ARCHITECTURE_GUIDE.md#sprite-based-menu-system) |
| **Double Size (D button)** | MACAMP_ARCHITECTURE_GUIDE.md | [Clutter Bar Buttons](MACAMP_ARCHITECTURE_GUIDE.md#clutter-bar-buttons) |
| **Developer ID setup** | RELEASE_BUILD_GUIDE.md | [Developer ID Certificates](RELEASE_BUILD_GUIDE.md#3-developer-id-certificates) |
| **EQ implementation** | MACAMP_ARCHITECTURE_GUIDE.md | [EQ Implementation](MACAMP_ARCHITECTURE_GUIDE.md#eq-implementation) |
| **EQPresetStore** | MACAMP_ARCHITECTURE_GUIDE.md, IMPLEMENTATION_PATTERNS.md | [EQPresetStore](MACAMP_ARCHITECTURE_GUIDE.md#eqpresetstore-macampappaudioeqpresetstoreswift), [Computed Forwarding](IMPLEMENTATION_PATTERNS.md#pattern-computed-forwarding-for-api-compatibility) |
| **Error handling** | IMPLEMENTATION_PATTERNS.md | [Error Handling Patterns](IMPLEMENTATION_PATTERNS.md#error-handling-patterns) |
| **Fallback sprites** | SPRITE_SYSTEM_COMPLETE.md, WINAMP_SKIN_VARIATIONS.md | [Fallback Generation](SPRITE_SYSTEM_COMPLETE.md#fallback-generation), [How MacAmp Handles This](WINAMP_SKIN_VARIATIONS.md#how-macamp-handles-this) |
| **Goertzel algorithm** | MACAMP_ARCHITECTURE_GUIDE.md | [Spectrum Analyzer (20-Bar Goertzel)](MACAMP_ARCHITECTURE_GUIDE.md#spectrum-analyzer-20-bar-goertzel-implementation) |
| **Hardened runtime** | RELEASE_BUILD_GUIDE.md | Key settings table, [Verification](RELEASE_BUILD_GUIDE.md#verification) |
| **ICY metadata protocol** | MACAMP_ARCHITECTURE_GUIDE.md | [Stream Decode Pipeline Components](MACAMP_ARCHITECTURE_GUIDE.md#stream-decode-pipeline-components) |
| **ICYFramer** | MACAMP_ARCHITECTURE_GUIDE.md | [Stream Decode Pipeline Components](MACAMP_ARCHITECTURE_GUIDE.md#stream-decode-pipeline-components) |
| **Internet radio** | MACAMP_ARCHITECTURE_GUIDE.md | [Internet Radio Streaming](MACAMP_ARCHITECTURE_GUIDE.md#internet-radio-streaming) |
| **Keyboard navigation** | MACAMP_ARCHITECTURE_GUIDE.md | [Sprite-Based Menu System](MACAMP_ARCHITECTURE_GUIDE.md#sprite-based-menu-system) |
| **Keyboard shortcuts** | MACAMP_ARCHITECTURE_GUIDE.md | [Clutter Bar Buttons](MACAMP_ARCHITECTURE_GUIDE.md#clutter-bar-buttons) |
| **M3U/PLS playlist resolution** | MACAMP_ARCHITECTURE_GUIDE.md | [Internet Radio Streaming](MACAMP_ARCHITECTURE_GUIDE.md#internet-radio-streaming) |
| **M3UParser** | MACAMP_ARCHITECTURE_GUIDE.md | [M3U Playlist Parser](MACAMP_ARCHITECTURE_GUIDE.md#m3u-playlist-parser) |
| **Magnetic snapping** | MACAMP_ARCHITECTURE_GUIDE.md | [Window Snap Manager](MACAMP_ARCHITECTURE_GUIDE.md#window-snap-manager) |
| **MetadataLoader** | MACAMP_ARCHITECTURE_GUIDE.md | [MetadataLoader](MACAMP_ARCHITECTURE_GUIDE.md#metadataloader-macampappaudiometadataloaderswift) |
| **Migration guides** | IMPLEMENTATION_PATTERNS.md | [Migration Guides](IMPLEMENTATION_PATTERNS.md#migration-guides) |
| **nonisolated(unsafe) deinit** | IMPLEMENTATION_PATTERNS.md | [isolated deinit for @MainActor Cleanup](IMPLEMENTATION_PATTERNS.md#pattern-isolated-deinit-for-mainactor-cleanup-swift-62) |
| **NUMBERS.bmp format** | WINAMP_SKIN_VARIATIONS.md | [Two Number Systems](WINAMP_SKIN_VARIATIONS.md#two-number-systems) |
| **NUMS_EX.bmp format** | WINAMP_SKIN_VARIATIONS.md | [Two Number Systems](WINAMP_SKIN_VARIATIONS.md#two-number-systems) |
| **onTrackMetadataUpdate callback** | IMPLEMENTATION_PATTERNS.md | [Callback Synchronization](IMPLEMENTATION_PATTERNS.md#pattern-callback-synchronization-for-cross-component-communication) |
| **onPlaylistAdvanceRequest callback** | IMPLEMENTATION_PATTERNS.md | [Callback Synchronization](IMPLEMENTATION_PATTERNS.md#pattern-callback-synchronization-for-cross-component-communication) |
| **Options menu (O button)** | MACAMP_ARCHITECTURE_GUIDE.md | [Clutter Bar Buttons](MACAMP_ARCHITECTURE_GUIDE.md#clutter-bar-buttons) |
| **PlaybackCoordinator** | MACAMP_ARCHITECTURE_GUIDE.md | [The Orchestrator Pattern](MACAMP_ARCHITECTURE_GUIDE.md#the-orchestrator-pattern) |
| **PlaybackCoordinator computed play state** | MACAMP_ARCHITECTURE_GUIDE.md | [The Orchestrator Pattern](MACAMP_ARCHITECTURE_GUIDE.md#the-orchestrator-pattern) |
| **PlaybackCoordinator callback split** | MACAMP_ARCHITECTURE_GUIDE.md, IMPLEMENTATION_PATTERNS.md | [The Orchestrator Pattern](MACAMP_ARCHITECTURE_GUIDE.md#the-orchestrator-pattern), [Callback Synchronization](IMPLEMENTATION_PATTERNS.md#pattern-callback-synchronization-for-cross-component-communication) |
| **PlaylistController** | MACAMP_ARCHITECTURE_GUIDE.md, IMPLEMENTATION_PATTERNS.md | [PlaylistController](MACAMP_ARCHITECTURE_GUIDE.md#playlistcontroller-macampappaudioplaylistcontrollerswift), [Computed Forwarding](IMPLEMENTATION_PATTERNS.md#pattern-computed-forwarding-for-api-compatibility) |
| **Semantic sprites** | SPRITE_SYSTEM_COMPLETE.md | [Semantic Sprite Enum](SPRITE_SYSTEM_COMPLETE.md#semantic-sprite-enum) |
| **Sine wave diagnostic** | BUILDING_RETRO_MACOS_APPS_SKILL.md (skill file, not in docs/) | Lesson #27 |
| **Signing workflow** | RELEASE_BUILD_GUIDE.md | [Code Signing Troubleshooting](RELEASE_BUILD_GUIDE.md#code-signing-troubleshooting) |
| **Skin compatibility** | WINAMP_SKIN_VARIATIONS.md | Full document |
| **Skin file structure** | SPRITE_SYSTEM_COMPLETE.md | [Skin File Structure](SPRITE_SYSTEM_COMPLETE.md#skin-file-structure) |
| **SpriteResolver** | SPRITE_SYSTEM_COMPLETE.md | [SpriteResolver Implementation](SPRITE_SYSTEM_COMPLETE.md#spriteresolver-implementation) |
| **State management** | IMPLEMENTATION_PATTERNS.md | [State Management Patterns](IMPLEMENTATION_PATTERNS.md#state-management-patterns) |
| **Stream bridge (activateStreamBridge)** | MACAMP_ARCHITECTURE_GUIDE.md | [The Unified Architecture](MACAMP_ARCHITECTURE_GUIDE.md#the-unified-architecture) |
| **StreamDecodePipeline** | MACAMP_ARCHITECTURE_GUIDE.md | [Stream Decode Pipeline Components](MACAMP_ARCHITECTURE_GUIDE.md#stream-decode-pipeline-components) |
| **StreamPlayer** | MACAMP_ARCHITECTURE_GUIDE.md | [StreamPlayer Architecture](MACAMP_ARCHITECTURE_GUIDE.md#streamplayer-architecture-unified-pipeline) |
| **Swift 6.2 patterns** | MACAMP_ARCHITECTURE_GUIDE.md | [Modern Swift 6.2 Patterns](MACAMP_ARCHITECTURE_GUIDE.md#modern-swift-62-patterns) |
| **SwiftUI techniques** | MACAMP_ARCHITECTURE_GUIDE.md | [SwiftUI Rendering Techniques](MACAMP_ARCHITECTURE_GUIDE.md#swiftui-rendering-techniques) |
| **Testing patterns** | IMPLEMENTATION_PATTERNS.md | [Testing Patterns](IMPLEMENTATION_PATTERNS.md#testing-patterns) |
| **Test plan configurations** | README.md | Test Plan Quick Reference |
| **Three-layer architecture** | MACAMP_ARCHITECTURE_GUIDE.md | [Three-Layer Architecture](MACAMP_ARCHITECTURE_GUIDE.md#three-layer-architecture-deep-dive) |
| **Thread safety** | IMPLEMENTATION_PATTERNS.md | [Async/Await Patterns](IMPLEMENTATION_PATTERNS.md#asyncawait-patterns) |
| **Time display system** | MACAMP_ARCHITECTURE_GUIDE.md | [Time Display System](MACAMP_ARCHITECTURE_GUIDE.md#time-display-system) |
| **Unified audio pipeline** | MACAMP_ARCHITECTURE_GUIDE.md | [Unified Audio Pipeline Architecture](MACAMP_ARCHITECTURE_GUIDE.md#unified-audio-pipeline-architecture) |
| **Unmanaged pointer pattern** | IMPLEMENTATION_PATTERNS.md | [MTAudioProcessingTap with Unmanaged Context](IMPLEMENTATION_PATTERNS.md#pattern-mtaudioprocessingtap-with-unmanaged-context) |
| **VisualizerFeed (SPSC)** | IMPLEMENTATION_PATTERNS.md, MACAMP_ARCHITECTURE_GUIDE.md | [SPSC Shared Buffer](IMPLEMENTATION_PATTERNS.md#pattern-spsc-shared-buffer-for-audio-to-main-thread-transfer), [Visualizer Pipeline Architecture](MACAMP_ARCHITECTURE_GUIDE.md#visualizer-pipeline-architecture) |
| **SPSC shared buffer pattern** | IMPLEMENTATION_PATTERNS.md | [SPSC Shared Buffer](IMPLEMENTATION_PATTERNS.md#pattern-spsc-shared-buffer-for-audio-to-main-thread-transfer) |
| **Track information (I button)** | MACAMP_ARCHITECTURE_GUIDE.md | [Clutter Bar Buttons](MACAMP_ARCHITECTURE_GUIDE.md#clutter-bar-buttons) |
| **Custom window dragging** | CUSTOM_DRAG_FIX.md | Full document |
| **Dynamic titlebar expansion** | MILKDROP_WINDOW.md | [Titlebar Composition](MILKDROP_WINDOW.md#41-titlebar-composition-7-sections---dynamic) |
| **GEN.bmp sprites** | MILKDROP_WINDOW.md | [Sprite Source](MILKDROP_WINDOW.md#22-sprite-source) |
| **GenWindow** | MILKDROP_WINDOW.md | [GEN.bmp Chrome Implementation](MILKDROP_WINDOW.md#4-genbmp-chrome-implementation) |
| **goldFillerTilesPerSide** | MILKDROP_WINDOW.md | [Titlebar Composition](MILKDROP_WINDOW.md#41-titlebar-composition-7-sections---dynamic) |
| **Milkdrop visualization** | MILKDROP_WINDOW.md | Full document |
| **MILKDROP window resize** | MILKDROP_WINDOW.md | [Resize Gesture](MILKDROP_WINDOW.md#44-resize-gesture) |
| **MilkdropWindowSizeState** | MILKDROP_WINDOW.md | [GEN.bmp Chrome Implementation](MILKDROP_WINDOW.md#4-genbmp-chrome-implementation) |
| **Butterchurn integration** | MILKDROP_WINDOW.md | [Butterchurn Integration](MILKDROP_WINDOW.md#9-butterchurn-integration) |
| **WKUserScript injection** | MILKDROP_WINDOW.md | [WKUserScript Injection Strategy](MILKDROP_WINDOW.md#93-wkuserscript-injection-strategy) |
| **Swift→JS audio bridge** | MILKDROP_WINDOW.md | [Audio Data Pipeline](MILKDROP_WINDOW.md#94-audio-data-pipeline) |
| **ButterchurnBridge** | MILKDROP_WINDOW.md | [Key Implementation Files](MILKDROP_WINDOW.md#92-key-implementation-files) |
| **ButterchurnPresetManager** | MILKDROP_WINDOW.md | [ButterchurnPresetManager](MILKDROP_WINDOW.md#95-butterchurnpresetmanager) |
| **NSMenu closure bridge** | MILKDROP_WINDOW.md | [Context Menu Implementation](MILKDROP_WINDOW.md#96-context-menu-implementation) |
| **callAsyncJavaScript** | MILKDROP_WINDOW.md | [Pitfalls](MILKDROP_WINDOW.md#97-pitfalls) |
| **Track title display** | MILKDROP_WINDOW.md | [Track Title Display](MILKDROP_WINDOW.md#99-track-title-display) |
| **Preset cycling** | MILKDROP_WINDOW.md | [ButterchurnPresetManager](MILKDROP_WINDOW.md#95-butterchurnpresetmanager) |
| **Multi-window architecture** | MULTI_WINDOW_ARCHITECTURE.md | Full document |
| **Multi-window quick start** | MULTI_WINDOW_ARCHITECTURE.md | [Quick Reference](MULTI_WINDOW_ARCHITECTURE.md#quick-reference) |
| **Two-piece sprites** | MILKDROP_WINDOW.md | [Two-Piece Sprite Discovery](MILKDROP_WINDOW.md#5-two-piece-sprite-discovery) |
| **VideoPlaybackController** | MACAMP_ARCHITECTURE_GUIDE.md, IMPLEMENTATION_PATTERNS.md | [VideoPlaybackController](MACAMP_ARCHITECTURE_GUIDE.md#videoplaybackcontroller-macampappaudiovideoplaybackcontrollerswift), [Computed Forwarding](IMPLEMENTATION_PATTERNS.md#pattern-computed-forwarding-for-api-compatibility) |
| **Video Window (V button)** | VIDEO_WINDOW.md | Full document |
| **VIDEO.bmp sprites** | VIDEO_WINDOW.md | [Appendix: Sprite Definitions](VIDEO_WINDOW.md#appendix-sprite-definitions) |
| **Video formats** | VIDEO_WINDOW.md | [Video Playback System](VIDEO_WINDOW.md#video-playback-system) |
| **Video window chrome** | VIDEO_WINDOW.md | [Chrome Components](VIDEO_WINDOW.md#chrome-components) |
| **Video window resizing** | VIDEO_WINDOW.md | [Window Resizing](VIDEO_WINDOW.md#window-resizing) |
| **Video volume sync** | VIDEO_WINDOW.md | [Unified Video Controls](VIDEO_WINDOW.md#unified-video-controls) |
| **Video seek bar** | VIDEO_WINDOW.md | [Unified Video Controls](VIDEO_WINDOW.md#unified-video-controls) |
| **Video time display** | VIDEO_WINDOW.md | [Unified Video Controls](VIDEO_WINDOW.md#unified-video-controls) |
| **VideoWindowSizeState** | VIDEO_WINDOW.md | [VideoWindowSizeState Observable](VIDEO_WINDOW.md#videowindowsizestate-observable) |
| **Size2D quantized resize** | VIDEO_WINDOW.md | [Size2D Model](VIDEO_WINDOW.md#size2d-model) |
| **WindowResizePreviewOverlay** | VIDEO_WINDOW.md | [Preview Overlay (AppKit)](VIDEO_WINDOW.md#preview-overlay-appkit) |
| **Metadata ticker** | VIDEO_WINDOW.md | [Metadata Display](VIDEO_WINDOW.md#metadata-display) |
| **Task { @MainActor in } pattern** | VIDEO_WINDOW.md | [Unified Video Controls](VIDEO_WINDOW.md#unified-video-controls) (time observer) |
| **cleanupVideoPlayer()** | VIDEO_WINDOW.md | [Unified Video Controls](VIDEO_WINDOW.md#unified-video-controls) (cleanup) |
| **currentSeekID invalidation** | VIDEO_WINDOW.md | [Unified Video Controls](VIDEO_WINDOW.md#unified-video-controls) (stale-callback guards) |
| **playbackProgress stored** | VIDEO_WINDOW.md | [Unified Video Controls](VIDEO_WINDOW.md#unified-video-controls) (time observer) |
| **Visualization** | MACAMP_ARCHITECTURE_GUIDE.md | [Visualizer Pipeline Architecture](MACAMP_ARCHITECTURE_GUIDE.md#visualizer-pipeline-architecture) |
| **VisualizerPipeline** | MACAMP_ARCHITECTURE_GUIDE.md, IMPLEMENTATION_PATTERNS.md | [VisualizerPipeline](MACAMP_ARCHITECTURE_GUIDE.md#visualizerpipeline-macampappaudiovisualizerpipelineswift), [Real-Time Buffer Processing](IMPLEMENTATION_PATTERNS.md#pattern-real-time-buffer-processing) |
| **Window clustering** | MACAMP_ARCHITECTURE_GUIDE.md | [Window Snap Manager](MACAMP_ARCHITECTURE_GUIDE.md#window-snap-manager) |
| **Window focus tracking** | WINDOW_FOCUS_ARCHITECTURE.md | Full document |
| **Window hierarchy** | MULTI_WINDOW_ARCHITECTURE.md | [Current MacAmp Architecture](MULTI_WINDOW_ARCHITECTURE.md#current-macamp-architecture) |
| **Window lifecycle** | MACAMP_ARCHITECTURE_GUIDE.md | [Window Lifecycle Management](MACAMP_ARCHITECTURE_GUIDE.md#window-lifecycle-management) |
| **Window management** | MACAMP_ARCHITECTURE_GUIDE.md | [Window Snap Manager](MACAMP_ARCHITECTURE_GUIDE.md#window-snap-manager) |
| **Window ownership** | MULTI_WINDOW_ARCHITECTURE.md | [File Structure and Responsibilities](MULTI_WINDOW_ARCHITECTURE.md#file-structure-and-responsibilities) |
| **Playlist window** | PLAYLIST_WINDOW.md | Full document |
| **Playlist resize** | PLAYLIST_WINDOW.md | [Segment-Based Resize System](PLAYLIST_WINDOW.md#segment-based-resize-system) |
| **PlaylistWindowSizeState** | PLAYLIST_WINDOW.md | [PlaylistWindowSizeState](PLAYLIST_WINDOW.md#playlistwindowsizestate) |
| **Playlist scroll slider** | PLAYLIST_WINDOW.md | [Scroll Slider](PLAYLIST_WINDOW.md#scroll-slider) |
| **Playlist mini visualizer** | PLAYLIST_WINDOW.md | [Mini Visualizer](PLAYLIST_WINDOW.md#mini-visualizer) |
| **Segment-based resize** | PLAYLIST_WINDOW.md | [Segment-Based Resize System](PLAYLIST_WINDOW.md#segment-based-resize-system) |
| **Segment-based resize (MILKDROP)** | MILKDROP_WINDOW.md | [Resize Gesture](MILKDROP_WINDOW.md#44-resize-gesture) |
| **25×29px segments** | PLAYLIST_WINDOW.md | [Window Specifications](PLAYLIST_WINDOW.md#window-specifications) |
| **WindowDragGesture** | CUSTOM_DRAG_FIX.md | [Problem Analysis](CUSTOM_DRAG_FIX.md#problem-analysis) |
| **WindowFocusDelegate** | WINDOW_FOCUS_ARCHITECTURE.md | [WindowFocusDelegate](WINDOW_FOCUS_ARCHITECTURE.md#windowfocusdelegate), [Delegate Wiring](WINDOW_FOCUS_ARCHITECTURE.md#3-delegate-wiring) |
| **WindowFocusState** | WINDOW_FOCUS_ARCHITECTURE.md | [WindowFocusState Model](WINDOW_FOCUS_ARCHITECTURE.md#windowfocusstate-model) |
| **WindowGroup** | MULTI_WINDOW_ARCHITECTURE.md | [Current MacAmp Architecture](MULTI_WINDOW_ARCHITECTURE.md#current-macamp-architecture) (hidden placeholder scene only) |
| **WindowCoordinator / refactoring** | MULTI_WINDOW_ARCHITECTURE.md | [WindowCoordinator Architecture](MULTI_WINDOW_ARCHITECTURE.md#windowcoordinator-architecture) |
| **Facade + Composition pattern** | MULTI_WINDOW_ARCHITECTURE.md | [Architecture Decision: Facade + Composition](MULTI_WINDOW_ARCHITECTURE.md#architecture-decision-facade--composition) |
| **God object decomposition** | MULTI_WINDOW_ARCHITECTURE.md | [Rationale](MULTI_WINDOW_ARCHITECTURE.md#rationale) |
| **Swift 6.2 concurrency** | MULTI_WINDOW_ARCHITECTURE.md | [Swift 6.2 Concurrency Patterns](MULTI_WINDOW_ARCHITECTURE.md#swift-62-concurrency-patterns) |
| **Recursive withObservationTracking** | MULTI_WINDOW_ARCHITECTURE.md | [Recursive withObservationTracking](MULTI_WINDOW_ARCHITECTURE.md#recursive-withobservationtracking) |
| **nonisolated deinit** | MULTI_WINDOW_ARCHITECTURE.md | [isolated deinit](MULTI_WINDOW_ARCHITECTURE.md#isolated-deinit) |
| **Xcode settings** | RELEASE_BUILD_GUIDE.md | [Xcode Configuration](RELEASE_BUILD_GUIDE.md#xcode-configuration) |
| **AudioEngineController** | MACAMP_ARCHITECTURE_GUIDE.md | [AudioPlayer Decomposition Architecture](MACAMP_ARCHITECTURE_GUIDE.md#audioplayer-decomposition-architecture) |
| **StreamTerminationReason** | MACAMP_ARCHITECTURE_GUIDE.md, IMPLEMENTATION_PATTERNS.md | [Auto-Reconnect State Machine](MACAMP_ARCHITECTURE_GUIDE.md#auto-reconnect-state-machine), [Typed Stream Termination Reasons](IMPLEMENTATION_PATTERNS.md#pattern-typed-stream-termination-reasons) |
| **Auto-reconnect / exponential backoff** | MACAMP_ARCHITECTURE_GUIDE.md | [Auto-Reconnect State Machine](MACAMP_ARCHITECTURE_GUIDE.md#auto-reconnect-state-machine) |
| **Stream error display** | MACAMP_ARCHITECTURE_GUIDE.md | [The Orchestrator Pattern](MACAMP_ARCHITECTURE_GUIDE.md#the-orchestrator-pattern) (displayTitle) |
| **XcodeGen resource configuration** | MILKDROP_WINDOW.md | [Key Implementation Files](MILKDROP_WINDOW.md#92-key-implementation-files) |
| **macOS 26 WebContent noise** | MILKDROP_WINDOW.md | [WKWebView Console Errors (Non-Fatal)](MILKDROP_WINDOW.md#111-wkwebview-console-errors-non-fatal) |
| **VBR duration alignment** | IMPLEMENTATION_PATTERNS.md | [Engine File Duration as Authoritative Source](IMPLEMENTATION_PATTERNS.md#pattern-engine-file-duration-as-authoritative-source-vbr) |
| **`os_workgroup` / audio workgroup** | BUILDING_RETRO_MACOS_APPS_SKILL.md | Lesson #33 (os_workgroup) |
| **`Now Playing` / MPNowPlayingInfoCenter** | BUILDING_RETRO_MACOS_APPS_SKILL.md | Lesson #32 (Now Playing) |
| **`Remote commands` / MPRemoteCommandCenter** | BUILDING_RETRO_MACOS_APPS_SKILL.md | Lesson #32 (Now Playing) |
| **Stream elapsed time** | BUILDING_RETRO_MACOS_APPS_SKILL.md | Lesson #34 (Anchor-Based Timer) |
| **Playlist list operations (NEW/LOAD/SAVE)** | PLAYLIST_WINDOW.md | [List Operations](PLAYLIST_WINDOW.md#list-operations-new-list--load-list--save-list) |
| **M3UWriter** | PLAYLIST_WINDOW.md | [List Operations](PLAYLIST_WINDOW.md#list-operations-new-list--load-list--save-list) |
| **QueueConfined protocol** | `MacAmpApp/Audio/QueueConfined.swift` | (code file; no dedicated doc section yet) |
| **TimeFormatting** | `MacAmpApp/Utilities/TimeFormatting.swift` | (code file; no dedicated doc section yet) |
| **MenuActionTarget / MenuItemFactory** | IMPLEMENTATION_PATTERNS.md | [NSMenu Presenter Isolation](IMPLEMENTATION_PATTERNS.md#pattern-nsmenu-presenter-isolation) |
| **WinampAlertHelper** | `MacAmpApp/Utilities/WinampAlertHelper.swift` | (code file; no dedicated doc section yet) |
| **supportsAudioProcessing** | IMPLEMENTATION_PATTERNS.md | [Capability Flag Pattern](IMPLEMENTATION_PATTERNS.md#pattern-capability-flag-pattern) |
| **Video audio DSP / MTAudioProcessingTap** | VIDEO_WINDOW.md, MACAMP_ARCHITECTURE_GUIDE.md | [Video Audio DSP Pipeline](VIDEO_WINDOW.md#video-audio-dsp-pipeline); [AVPlayer-Native Video DSP](MACAMP_ARCHITECTURE_GUIDE.md#avplayer-native-video-dsp); code in `MacAmpApp/Audio/VideoDSP/` |
| **isVisualizerRendering** | PLAYLIST_WINDOW.md | [Mini Visualizer](PLAYLIST_WINDOW.md#mini-visualizer) (visualizer runs for audio and video) |
| **get-task-allow / CODE_SIGN_INJECT_BASE_ENTITLEMENTS** | RELEASE_BUILD_GUIDE.md | [Testing a Release Build](RELEASE_BUILD_GUIDE.md#testing-a-release-build) |

## Common Questions

| Question | Answer |
|----------|--------|
| "How do I add a new UI component?" | [Integration with Views](SPRITE_SYSTEM_COMPLETE.md#integration-with-views) + [UI Component Patterns](IMPLEMENTATION_PATTERNS.md#ui-component-patterns) |
| "Why are there two audio players?" | There is now ONE unified engine path. Both local files and streams route through AVAudioEngine. Video audio plays through AVPlayer, with EQ/preamp/balance and the visualizer applied by an `MTAudioProcessingTap` (`MacAmpApp/Audio/VideoDSP/`). See [Unified Audio Pipeline Architecture](MACAMP_ARCHITECTURE_GUIDE.md#unified-audio-pipeline-architecture) |
| "Does the EQ/visualizer work for video?" | Yes, via the video `MTAudioProcessingTap` (`MacAmpApp/Audio/VideoDSP/`). See VIDEO_WINDOW.md and MACAMP_ARCHITECTURE_GUIDE.md |
| "How does internet radio streaming work now?" | [Stream Decode Pipeline Components](MACAMP_ARCHITECTURE_GUIDE.md#stream-decode-pipeline-components) (custom decode pipeline: ICYFramer → AudioFileStreamParser → AudioConverterDecoder → AVAudioSourceNode) |
| "How to debug audio corruption?" | BUILDING_RETRO_MACOS_APPS_SKILL.md Lesson #27 (sine wave diagnostic test) |
| "How does skin loading work?" | SPRITE_SYSTEM_COMPLETE.md + WINAMP_SKIN_VARIATIONS.md |
| "What's Debug vs Release difference?" | [Debug vs Release Configuration](RELEASE_BUILD_GUIDE.md#debug-vs-release-configuration) |
| "How do I fix code signing errors?" | [Troubleshooting](RELEASE_BUILD_GUIDE.md#troubleshooting) + [Code Signing Troubleshooting](RELEASE_BUILD_GUIDE.md#code-signing-troubleshooting) |
| "What patterns should I follow?" | IMPLEMENTATION_PATTERNS.md |
| "How does PlaybackCoordinator track play state?" | [The Orchestrator Pattern](MACAMP_ARCHITECTURE_GUIDE.md#the-orchestrator-pattern) (computed from active backend) |
| "What replaced externalPlaybackHandler?" | [Callback Synchronization](IMPLEMENTATION_PATTERNS.md#pattern-callback-synchronization-for-cross-component-communication) (split into onTrackMetadataUpdate + onPlaylistAdvanceRequest) |
| "How does playlist navigation work during streams?" | [The Orchestrator Pattern](MACAMP_ARCHITECTURE_GUIDE.md#the-orchestrator-pattern), [Internet Radio Streaming](MACAMP_ARCHITECTURE_GUIDE.md#internet-radio-streaming) (context-aware nextTrack(from:)/previousTrack(from:)) |
| "What's the app architecture?" | [Three-Layer Architecture](MACAMP_ARCHITECTURE_GUIDE.md#three-layer-architecture-deep-dive) |
| "How do I test my changes?" | [Test Plan Quick Reference](#test-plan-quick-reference) + [Testing Patterns](IMPLEMENTATION_PATTERNS.md#testing-patterns) |
| "What Swift 6 features are used?" | [Modern Swift 6.2 Patterns](MACAMP_ARCHITECTURE_GUIDE.md#modern-swift-62-patterns) |
| "How does window snapping work?" | [Window Snap Manager](MACAMP_ARCHITECTURE_GUIDE.md#window-snap-manager) |
| "What's the spectrum analyzer algorithm?" | [Spectrum Analyzer](MACAMP_ARCHITECTURE_GUIDE.md#spectrum-analyzer-20-bar-goertzel-implementation) (20-bar Goertzel) |
| "How does audio data reach the UI thread?" | [SPSC Shared Buffer](IMPLEMENTATION_PATTERNS.md#pattern-spsc-shared-buffer-for-audio-to-main-thread-transfer) (SPSC shared buffer + poll timer) |
| "What are the clutter bar buttons?" | [Clutter Bar Buttons](MACAMP_ARCHITECTURE_GUIDE.md#clutter-bar-buttons) |
| "How do I add clutter bar features?" | [Clutter Bar Buttons](MACAMP_ARCHITECTURE_GUIDE.md#clutter-bar-buttons) |
| "What keyboard shortcuts are available?" | [Clutter Bar Buttons](MACAMP_ARCHITECTURE_GUIDE.md#clutter-bar-buttons) |
| "How does window focus tracking work?" | WINDOW_FOCUS_ARCHITECTURE.md + [Window Focus State Management](MACAMP_ARCHITECTURE_GUIDE.md#window-focus-state-management) |
| "How to make titlebars active/inactive?" | [View Layer Usage](WINDOW_FOCUS_ARCHITECTURE.md#4-view-layer-usage) |
| "How does video playback work?" | [Video Playback System](VIDEO_WINDOW.md#video-playback-system) |
| "How to sync volume with video?" | [Unified Video Controls](VIDEO_WINDOW.md#unified-video-controls) |
| "How to implement video seeking?" | [Unified Video Controls](VIDEO_WINDOW.md#unified-video-controls) |
| "How to resize video window?" | [Size2D Model](VIDEO_WINDOW.md#size2d-model) + [Resize Handle Implementation](VIDEO_WINDOW.md#resize-handle-implementation) |
| "What is Size2D quantized resize?" | [Size2D Model](VIDEO_WINDOW.md#size2d-model) (25×29px segments) |
| "How to use Task { @MainActor in }?" | [Unified Video Controls](VIDEO_WINDOW.md#unified-video-controls) (time observer) |
| "Why must playbackProgress be assigned?" | [Unified Video Controls](VIDEO_WINDOW.md#unified-video-controls) (time observer; stored, not computed) |
| "What video formats are supported?" | [Format Support](VIDEO_WINDOW.md#format-support) |
| "How do I add VIDEO.bmp to a skin?" | [Appendix: Sprite Definitions](VIDEO_WINDOW.md#appendix-sprite-definitions) + WINAMP_SKIN_VARIATIONS.md |
| "How does the Milkdrop window work?" | MILKDROP_WINDOW.md + GEN.bmp sprite system |
| "What is GEN.bmp?" | [Sprite Source](MILKDROP_WINDOW.md#22-sprite-source) |
| "How do two-piece sprites work?" | [Two-Piece Sprite Discovery](MILKDROP_WINDOW.md#5-two-piece-sprite-discovery) |
| "How does multi-window management work?" | MULTI_WINDOW_ARCHITECTURE.md |
| "How do I add a new window?" | [Adding a New Window](MULTI_WINDOW_ARCHITECTURE.md#adding-a-new-window) |
| "Why doesn't WindowDragGesture work?" | [Problem Analysis](CUSTOM_DRAG_FIX.md#problem-analysis) |
| "How does custom window dragging work?" | [Solution](CUSTOM_DRAG_FIX.md#solution) |
| "How does playlist resize work?" | [Segment-Based Resize System](PLAYLIST_WINDOW.md#segment-based-resize-system) |
| "How to implement segment-based resize?" | [Resize Handle Implementation](PLAYLIST_WINDOW.md#resize-handle-implementation) |
| "What is PlaylistWindowSizeState?" | [PlaylistWindowSizeState](PLAYLIST_WINDOW.md#playlistwindowsizestate) |
| "How does playlist scroll slider work?" | [Scroll Slider](PLAYLIST_WINDOW.md#scroll-slider) |
| "When does playlist mini visualizer appear?" | [Mini Visualizer](PLAYLIST_WINDOW.md#mini-visualizer) |
| "How does Butterchurn integration work?" | [Butterchurn Integration](MILKDROP_WINDOW.md#9-butterchurn-integration) |
| "How to load JavaScript in WKWebView?" | [WKUserScript Injection Strategy](MILKDROP_WINDOW.md#93-wkuserscript-injection-strategy) |
| "How to stream audio to JavaScript?" | [Audio Data Pipeline](MILKDROP_WINDOW.md#94-audio-data-pipeline) |
| "How to use NSMenu with closures?" | [Context Menu Implementation](MILKDROP_WINDOW.md#96-context-menu-implementation) |
| "How to manage timers in @Observable?" | [Pitfalls](MILKDROP_WINDOW.md#97-pitfalls) (timers on the main run loop) |
| "How does MILKDROP resize work?" | [Resize Gesture](MILKDROP_WINDOW.md#44-resize-gesture) |
| "What is MilkdropWindowSizeState?" | [GEN.bmp Chrome Implementation](MILKDROP_WINDOW.md#4-genbmp-chrome-implementation) |
| "How does dynamic titlebar expansion work?" | [Titlebar Composition](MILKDROP_WINDOW.md#41-titlebar-composition-7-sections---dynamic) (goldFillerTilesPerSide) |
| "How does stream auto-reconnect work?" | [Auto-Reconnect State Machine](MACAMP_ARCHITECTURE_GUIDE.md#auto-reconnect-state-machine) (exponential backoff with StreamTerminationReason) |
| "What is AudioEngineController?" | [AudioPlayer Decomposition Architecture](MACAMP_ARCHITECTURE_GUIDE.md#audioplayer-decomposition-architecture) (extracted AVAudioEngine lifecycle manager) |
| "Why does Milkdrop show 'loading'?" | [Key Implementation Files](MILKDROP_WINDOW.md#92-key-implementation-files) (XcodeGen resource configuration for Butterchurn JS files) |

---

## Other Directories and Archive

- `docs/context/xcode-testing-context.md` — Xcode testing reference
- `docs/sessions/` — dated session logs
- `docs/xcode-26-reference/` — Apple Xcode 26 reference notes
- `docs/screenshots/` — images used by the top-level README
- `BUILDING_RETRO_MACOS_APPS_SKILL.md` (repo root) — lessons referenced above (e.g. #27 sine-wave diagnostic, #32 Now Playing)
- `docs/archive/` — **local only** (gitignored): 27 superseded or historical docs (~9,300 lines). Useful for why past designs were rejected; `semantic-sprites/skin-download-guide.md` lists test-skin sources.

| Archived | Superseded By |
|----------|---------------|
| ARCHITECTURE_REVELATION.md, BASE_PLAYER_ARCHITECTURE.md | MACAMP_ARCHITECTURE_GUIDE.md |
| SpriteResolver-Architecture.md, SpriteResolver-Implementation-Summary.md, SpriteResolver-Visual-Guide.md, semantic-sprites/ (8 files) | SPRITE_SYSTEM_COMPLETE.md |
| MULTI_WINDOW_RESEARCH_SUMMARY.md | MULTI_WINDOW_ARCHITECTURE.md |
| P0_CODE_SIGNING_FIX_SUMMARY.md | RELEASE_BUILD_GUIDE.md |
| DOCUMENTATION_AUDIT_2025-10-31.md, DOCUMENTATION_COMPLETE_2025-11-01.md, DOCUMENTATION_REVIEW_2025-11-01.md | (past doc reviews) |
| ISSUE_FIXES_2025-10-12.md, title-bar-*.md (3), position-slider-*.md (2), docking-duplication-cleanup.md, winamp-skins-lessons.md, line-removal-report.md | (historical implementation notes) |

CODE_SIGNING_FIX.md, CODE_SIGNING_FIX_DIAGRAM.md, and RELEASE_BUILD_COMPARISON.md were merged into RELEASE_BUILD_GUIDE.md; MULTI_WINDOW_QUICK_START.md (now [Quick Reference](MULTI_WINDOW_ARCHITECTURE.md#quick-reference)) and README_MULTI_WINDOW.md were merged into MULTI_WINDOW_ARCHITECTURE.md.

---

## Documentation Statistics

### Current Active Documentation

```
12 Core Technical Documents
─────────────────────────────
IMPLEMENTATION_PATTERNS.md           3,087 lines  (35%)
MACAMP_ARCHITECTURE_GUIDE.md         2,439 lines  (28%)
MILKDROP_WINDOW.md                     613 lines  (7%)
VIDEO_WINDOW.md                        537 lines  (6%)
README.md (this file)                  534 lines  (6%)
PLAYLIST_WINDOW.md                     376 lines  (4%)
SPRITE_SYSTEM_COMPLETE.md              337 lines  (4%)
MULTI_WINDOW_ARCHITECTURE.md           264 lines  (3%)
RELEASE_BUILD_GUIDE.md                 239 lines  (3%)
WINDOW_FOCUS_ARCHITECTURE.md           148 lines  (2%)
WINAMP_SKIN_VARIATIONS.md              142 lines  (2%)
CUSTOM_DRAG_FIX.md                      95 lines  (1%)
─────────────────────────────
TOTAL:                              8,811 lines
```

### Documentation by Category

- **Architecture & Design**: 88% (16,931 lines)
- **Build & Distribution**: 4% (692 lines)
- **Skin System**: 3% (652 lines)
- **Navigation & Index**: 6% (1,065 lines)

---

## Maintenance Guidelines

| Trigger | Update |
|---------|--------|
| New feature | IMPLEMENTATION_PATTERNS.md (patterns used) |
| Architecture change / component refactor | MACAMP_ARCHITECTURE_GUIDE.md (incl. [Component Integration Maps](MACAMP_ARCHITECTURE_GUIDE.md#component-integration-maps)) |
| Bug fix with a lesson | [Anti-Patterns to Avoid](IMPLEMENTATION_PATTERNS.md#anti-patterns-to-avoid) |
| Build process change | RELEASE_BUILD_GUIDE.md |
| Skin compatibility issue | WINAMP_SKIN_VARIATIONS.md |
| Any of the above | This index: inventory entry, topic lookup, line counts |

- **Accuracy over ambition:** document what the code does now; verify snippets, paths, and commands against the repo.
- **New doc** only for a major system (> 500 lines of code) or a new architectural pattern; otherwise extend an existing doc.
- **Archive** (`docs/archive/`, gitignored) when an implementation or approach is replaced or fully absorbed elsewhere.
- **Every doc:** header (version, date, purpose), TOC if > 200 lines, cross-links to related docs. Describe invariants, not review history.

---

## Version History

- **3.13.0 (2026-09-25):** Pruned this index (removed duplicate category/reading-path/map sections and stale quality metrics); leaner RELEASE_BUILD_GUIDE, SPRITE_SYSTEM_COMPLETE, WINAMP_SKIN_VARIATIONS, WINDOW_FOCUS_ARCHITECTURE, CUSTOM_DRAG_FIX re-verified against code.
- **3.12.0 (2026-09-25):** Documented AVPlayer-native video DSP (`MTAudioProcessingTap`) and fixed stale docs.
- **3.11.0 (2026-03-25):** Merged multi-window quick start and README into MULTI_WINDOW_ARCHITECTURE.md; archived research summary (15 → 12 docs).
- **3.10.0 (2026-03-25):** Merged the code-signing and build-comparison docs into RELEASE_BUILD_GUIDE.md (18 → 15 docs).
- **3.6.0 (2026-02-22):** Swift Testing migration; AudioPlayer and PlaylistWindow decompositions; lock-free ring buffer.
