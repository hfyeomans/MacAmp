## Scope

Evaluate what it would take to make MacAmp an iOS project. Research only. No app code changes.

## High-level conclusion

MacAmp is not currently an iOS/iPadOS app with minor platform shims. It is a macOS app whose core playback logic is surrounded by a substantial AppKit and multi-window shell.

An iPadOS version is feasible, but it would be a selective port plus product redesign, not a straight target flip.

## Local codebase findings

### Build configuration

- `project.yml` defines only a macOS application target with macOS 15.0 deployment. No iOS or iPadOS target exists.
- `Package.swift` also declares only `.macOS("26.0")`.

### Product shape

- App startup explicitly initializes a `WindowCoordinator` that owns multiple `NSWindow` instances for main, EQ, playlist, video, and Milkdrop windows.
- The SwiftUI `App` scene is a placeholder shell; the real UI is driven through AppKit windows.
- The project heavily relies on window-level behaviors that are specific to macOS desktop affordances:
  - borderless windows
  - floating levels
  - title bar removal
  - custom drag regions
  - docking/snap behavior between independent windows
  - separate resize-preview overlay windows

### AppKit surface area

Quick inventory from source search:

- `41` Swift files import `AppKit`
- `6` files reference `NSWindowController`
- `6` files reference `NSMenu`
- `7` files reference `NSImage`
- `4` files use `WKWebView`
- `3` files use `AVPlayerView`

This is a strong signal that the app is only partially SwiftUI-portable today.

### What is relatively portable

- Playback core built on `AVFoundation`/`AVAudioEngine`
- Stream decode pipeline using `AudioFileStream`, `AudioConverter`, and the lock-free ring buffer
- Playlist / playback coordination logic
- M3U parsing/writing and general model/controller logic not tied to AppKit
- Much of the pixel-positioned SwiftUI layout logic, once detached from AppKit-specific wrappers

### What is not portable as-is

- `WindowCoordinator`, `Windows/`, `WindowResizePreviewOverlay`, `WindowSnapManager`, and related AppKit window orchestration
- `NSViewRepresentable` wrappers that would need `UIViewRepresentable` or `UIViewControllerRepresentable`
- File picking/saving flows built around `NSOpenPanel` and `NSSavePanel`
- Menu flows built around `Commands` + `NSMenu`
- Skin/image model using `NSImage` and `NSCursor`
- Alert and prompt flows using `NSAlert`
- App lifecycle assumptions based on desktop windows rather than an iPad scene hierarchy

## iPadOS-specific reading

Current Apple guidance confirms that modern iPadOS now supports:

- multiple windows for SwiftUI apps
- app menu bars on iPad
- a new windowing system in iPadOS 26

That means the target platform can support a multi-window iPad experience in principle, but UIKit/SwiftUI scene windows on iPad are not the same thing as manually managed `NSWindow` clusters on macOS. The current MacAmp architecture would need to be re-expressed in iPad scene/window APIs rather than carried over directly.

## Feature-by-feature portability assessment

### 1. Audio playback core

Portability: high

- `AVAudioEngine`, `AVAudioPlayerNode`, `AVAudioSourceNode`, `AVAudioUnitEQ`, and `MediaPlayer`-based now-playing support all point toward an iOS/iPadOS-capable playback core.
- Main missing iOS work is audio-session management:
  - configure `AVAudioSession`
  - support interruptions / route changes
  - background audio mode if playback should continue when backgrounded
  - validate AirPlay behavior under iOS routing rules

### 2. Streaming stack

Portability: medium-high

- The custom stream path should be portable in principle because it is based on Core Audio / AVFoundation / URLSession.
- Risk areas:
  - workgroup integration may need platform validation on iOS/iPadOS
  - power/background behavior differs from macOS
  - buffering and reconnect policy should be retuned for mobile networking

### 3. Main Winamp chrome

Portability: medium

- The actual sprite-based SwiftUI composition can be ported.
- However, current interactions assume mouse, pointer, title bar dragging, and desktop window controls.
- On iPad, this would need touch-first interaction design and likely a different surface model.

### 4. Playlist / EQ / auxiliary windows

Portability: medium-low if preserving current UX exactly

- iPadOS 26 supports more advanced windowing than older iPadOS releases, so an iPad-first multiwindow version is more realistic than before.
- But the macOS implementation is built around explicit `NSWindow` ownership and geometric docking. That exact approach does not port.
- Likely redesign:
  - use SwiftUI scenes / windows for major surfaces
  - rethink docking and snap coupling
  - decide whether playlist/EQ remain separate windows or become panes/sheets/inspector-style UI

### 5. Video window

Portability: medium

- Current wrapper uses `AVPlayerView` via `NSViewRepresentable`, which is macOS-specific.
- On iPadOS/iOS, Apple’s recommended UI choices are `AVPlayerViewController`, `VideoPlayer`, or a custom `AVPlayerLayer` host.
- The custom Winamp chrome around video is portable conceptually, but the hosting implementation must change.

### 6. Milkdrop / Butterchurn

Portability: medium-low

- `WKWebView` exists on iPadOS/iOS, and the JS bridge model is plausible.
- The current wrapper is macOS-only (`NSViewRepresentable`) and some supporting assumptions are desktop-specific.
- Performance, memory pressure, touch interactions, and WebGL/WASM behavior on iPad hardware would need fresh validation.

### 7. Skin system

Portability: medium-low

- Archive parsing and text parsing are portable.
- The in-memory skin representation is not: it stores `NSImage` and `NSCursor`.
- A shared cross-platform skin model would need either:
  - an abstract image/cursor layer, or
  - separate AppKit/UIKit representations (`NSImage` vs `UIImage`, cursors omitted or redesigned on touch devices)

### 8. Commands, menus, file import/export

Portability: low as implemented

- Current flows use `NSOpenPanel`, `NSSavePanel`, `NSAlert`, and `NSMenu`.
- On iPadOS/iOS these should move to:
  - `fileImporter` / `UIDocumentPickerViewController`
  - `fileExporter`
  - SwiftUI alerts / confirmation dialogs / sheets
  - iPadOS 26 menu bar integrations where useful

## Practical migration options

### Option A: iPad-first companion app

Lowest risk and highest chance of shipping.

- Reuse playback/streaming/business logic
- Build a new iPadOS scene architecture
- Start with one main window and optional auxiliary windows only where justified
- Add modern iPadOS 26 features intentionally instead of preserving desktop metaphors verbatim

### Option B: shared cross-platform app target

Higher long-term value, higher upfront refactor cost.

- Extract shared core modules:
  - audio
  - streaming
  - playlist/model layer
  - skin parsing
- Build platform adapters:
  - macOS: existing AppKit shell
  - iPadOS/iOS: new UIKit/SwiftUI shell

### Option C: “same app on iPad” literal port

Least realistic.

- The exact current five-window, borderless, docked desktop metaphor is too coupled to AppKit.
- Achieving something visually similar on iPadOS 26 is possible in places, but not as a mechanical port.

## Estimated effort

### Rough order of magnitude

- Basic iPad audio player using shared playback core: moderate project
- Faithful Winamp-style iPad app with skins, playlist, EQ, streams, and video: substantial project
- Near-feature-parity iPad app including multiwindow desktop-like behavior and Butterchurn: large project

### Main cost drivers

- Untangling `AppKit` from models and controllers
- Replacing `NSWindow` architecture with iPad scene/window architecture
- Rebuilding import/export, menus, and alert flows
- Reworking image/cursor abstractions
- Revalidating audio session/background/route behavior on mobile

## Bottom line

If the goal is “put MacAmp on iPad,” the right plan is:

1. keep the audio/streaming engine and shared logic,
2. build a new iPadOS shell,
3. redesign the desktop window model for iPadOS 26 rather than trying to preserve it literally.

If the goal is “make this exact macOS app compile for iPad,” the answer is no without major architectural work.

## Sources

### Local code

- `project.yml`
- `Package.swift`
- `MacAmpApp/MacAmpApp.swift`
- `MacAmpApp/ViewModels/WindowCoordinator.swift`
- `MacAmpApp/Utilities/WinampWindowConfigurator.swift`
- `MacAmpApp/Utilities/WindowResizePreviewOverlay.swift`
- `MacAmpApp/Models/Skin.swift`
- `MacAmpApp/ViewModels/SkinManager.swift`
- `MacAmpApp/AppCommands.swift`
- `MacAmpApp/Views/PlaylistWindowActions.swift`
- `MacAmpApp/Views/Windows/AVPlayerViewRepresentable.swift`
- `MacAmpApp/Views/Windows/ButterchurnWebView.swift`
- `MacAmpApp/Audio/AudioEngineController.swift`
- `MacAmpApp/Audio/AudioPlayer.swift`
- `MacAmpApp/Audio/PlaybackCoordinator.swift`

### External references

- Apple: What’s new in iPadOS 26
- Apple: Build for iPadOS
- Apple: Bringing multiple windows to your SwiftUI app
- Apple: `fileImporter`
- Apple: `VideoPlayer`
- Apple: `AVPlayer`
- Apple: Audio Session Programming Guide / `AVAudioSession`
