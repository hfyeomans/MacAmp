# Swift Modernization Code Examples
## Ready-to-use code snippets for MacAmp

---

## 1. PIXEL-PERFECT IMAGE EXTENSION

**File:** `/Users/hank/dev/src/MacAmp/MacAmpApp/Views/Components/SimpleSpriteImage.swift`
**Add after SimpleSpriteImage definition (around line 106)**

```swift
// MARK: - Pixel Perfect Rendering Extension

extension Image {
    /// Apply pixel-perfect rendering for retro sprite graphics
    /// Disables interpolation and anti-aliasing to preserve sharp, blocky pixels
    ///
    /// Usage:
    /// ```swift
    /// Image(nsImage: spriteImage)
    ///     .resizable()
    ///     .pixelPerfect()
    ///     .frame(width: 22, height: 18)
    /// ```
    ///
    /// - Returns: Image view with interpolation disabled and anti-aliasing disabled
    func pixelPerfect() -> some View {
        self
            .interpolation(.none)
            .antialiased(false)
    }
}
```

---

## 2. PLAYLIST MENU DELEGATE

**File:** `/Users/hank/dev/src/MacAmp/MacAmpApp/Views/Components/PlaylistMenuDelegate.swift` (NEW FILE)

```swift
//
//  PlaylistMenuDelegate.swift
//  MacAmp
//
//  Delegate for sprite-based menu items with keyboard navigation support
//

import AppKit

/// Delegate that manages highlighting for sprite-based menu items
/// Handles both mouse hover and keyboard navigation automatically
///
/// Usage:
/// ```swift
/// let menu = NSMenu()
/// let delegate = PlaylistMenuDelegate()
/// menu.delegate = delegate
///
/// let addButton = SpriteMenuItem(
///     normalSprite: "PLEDIT_ADD_BUTTON",
///     selectedSprite: "PLEDIT_ADD_BUTTON_SELECTED",
///     skinManager: skinManager,
///     action: #selector(addFiles),
///     target: self
/// )
/// menu.addItem(addButton)
/// ```
@MainActor
final class PlaylistMenuDelegate: NSObject, NSMenuDelegate {
    /// Called when a menu item is about to be highlighted (mouse or keyboard)
    /// Updates all SpriteMenuItem instances to show correct highlight state
    func menu(_ menu: NSMenu, willHighlight item: NSMenuItem?) {
        // Iterate through all menu items
        for menuItem in menu.items {
            // Only update SpriteMenuItem instances
            if let sprite = menuItem as? SpriteMenuItem {
                // Highlight if this is the item being hovered/selected
                sprite.isHighlighted = (menuItem === item)
            }
        }
    }

    /// Optional: Called when menu is about to open
    /// Can be used for dynamic menu setup if needed
    func menuWillOpen(_ menu: NSMenu) {
        // Reset all items to non-highlighted state
        for menuItem in menu.items {
            if let sprite = menuItem as? SpriteMenuItem {
                sprite.isHighlighted = false
            }
        }
    }
}
```

---

## 3. REFACTORED SPRITEMENUITEM (WITHOUT HOVERTRACKINGVIEW)

**File:** `/Users/hank/dev/src/MacAmp/MacAmpApp/Views/Components/SpriteMenuItem.swift`
**REPLACE ENTIRE FILE**

```swift
//
//  SpriteMenuItem.swift
//  MacAmp
//
//  Sprite-based menu items with keyboard navigation support via NSMenuDelegate
//

import SwiftUI
import AppKit

/// Custom NSMenuItem that displays a sprite and swaps to selected sprite on highlight
/// Highlighting is managed by PlaylistMenuDelegate for both mouse and keyboard navigation
@MainActor
final class SpriteMenuItem: NSMenuItem {
    private let normalSpriteName: String
    private let selectedSpriteName: String
    private let skinManager: SkinManager
    private var hostingView: NSHostingView<SpriteMenuItemView>?

    /// Highlight state set by NSMenuDelegate
    /// When true, displays selectedSprite; when false, displays normalSprite
    var isHighlighted: Bool = false {
        didSet {
            updateView()
        }
    }

    /// Initialize a sprite-based menu item
    /// - Parameters:
    ///   - normalSprite: Sprite name for normal state
    ///   - selectedSprite: Sprite name for highlighted/selected state
    ///   - skinManager: SkinManager to load sprites from
    ///   - action: Selector to call when item is clicked
    ///   - target: Target object for the action
    init(normalSprite: String, selectedSprite: String, skinManager: SkinManager, action: Selector?, target: AnyObject?) {
        self.normalSpriteName = normalSprite
        self.selectedSpriteName = selectedSprite
        self.skinManager = skinManager

        super.init(title: "", action: action, keyEquivalent: "")
        self.target = target

        setupView()
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    private func setupView() {
        // Create SwiftUI sprite view directly (no tracking container needed!)
        let spriteView = SpriteMenuItemView(
            normalSprite: normalSpriteName,
            selectedSprite: selectedSpriteName,
            isHighlighted: isHighlighted,
            skinManager: skinManager
        )

        let hosting = NSHostingView(rootView: spriteView)
        hosting.frame = NSRect(x: 0, y: 0, width: 22, height: 18)

        self.view = hosting
        self.hostingView = hosting
    }

    private func updateView() {
        guard let hostingView = hostingView else { return }

        let updatedView = SpriteMenuItemView(
            normalSprite: normalSpriteName,
            selectedSprite: selectedSpriteName,
            isHighlighted: isHighlighted,
            skinManager: skinManager
        )

        hostingView.rootView = updatedView
    }
}

/// SwiftUI view that renders a sprite, swapping between normal and highlighted states
struct SpriteMenuItemView: View {
    let normalSprite: String
    let selectedSprite: String
    let isHighlighted: Bool
    let skinManager: SkinManager

    var body: some View {
        if let image = skinManager.currentSkin?.images[isHighlighted ? selectedSprite : normalSprite] {
            Image(nsImage: image)
                .resizable()
                .pixelPerfect()  // ← NEW: Pixel-perfect rendering
                .frame(width: 22, height: 18)
        } else {
            // Fallback if sprite not found
            Color.gray
                .frame(width: 22, height: 18)
        }
    }
}
```

---

## 4. MENU CREATION WITH DELEGATE

**Example usage pattern:**

```swift
@MainActor
class PlaylistViewController {
    private let skinManager: SkinManager
    private let menuDelegate = PlaylistMenuDelegate()

    func createAddButtonMenu() -> NSMenu {
        let menu = NSMenu()
        menu.delegate = menuDelegate  // ← Set delegate for keyboard support

        // Add sprite menu items
        let addFilesItem = SpriteMenuItem(
            normalSprite: "PLEDIT_ADD_FILE",
            selectedSprite: "PLEDIT_ADD_FILE_SELECTED",
            skinManager: skinManager,
            action: #selector(addFiles),
            target: self
        )
        menu.addItem(addFilesItem)

        let addFolderItem = SpriteMenuItem(
            normalSprite: "PLEDIT_ADD_DIR",
            selectedSprite: "PLEDIT_ADD_DIR_SELECTED",
            skinManager: skinManager,
            action: #selector(addFolder),
            target: self
        )
        menu.addItem(addFolderItem)

        let addURLItem = SpriteMenuItem(
            normalSprite: "PLEDIT_ADD_URL",
            selectedSprite: "PLEDIT_ADD_URL_SELECTED",
            skinManager: skinManager,
            action: #selector(addURL),
            target: self
        )
        menu.addItem(addURLItem)

        return menu
    }

    @objc private func addFiles() {
        // Implementation
    }

    @objc private func addFolder() {
        // Implementation
    }

    @objc private func addURL() {
        // Implementation
    }
}
```

---

## 5. @OBSERVABLE SKINMANAGER MIGRATION

**File:** `/Users/hank/dev/src/MacAmp/MacAmpApp/ViewModels/SkinManager.swift`
**Changes to apply:**

```swift
// ADD THIS IMPORT at top of file:
import Observation

// CHANGE class declaration from:
@MainActor
class SkinManager: ObservableObject {

// TO:
@Observable
@MainActor
final class SkinManager {

// REMOVE @Published from all properties:
// BEFORE:
@Published var currentSkin: Skin?
@Published var isLoading: Bool = false
@Published var availableSkins: [SkinMetadata] = []
@Published var loadingError: String? = nil

// AFTER:
var currentSkin: Skin?
var isLoading: Bool = false
var availableSkins: [SkinMetadata] = []
var loadingError: String? = nil

// ADD @ObservationIgnored to internal state:
@ObservationIgnored private var loadGeneration = UUID()
@ObservationIgnored private static let allowedSkinExtensions: Set<String> = ["wsz", "zip"]
@ObservationIgnored private static let maxImportSizeBytes = 50 * 1024 * 1024

// CHANGE init from:
nonisolated init() {
    // Scan will happen on first access since we're @MainActor
}

// TO:
init() {
    // Initialization code
}
```

---

## 6. VIEW INJECTION PATTERN CHANGES

### Pattern 1: Commands (SkinsCommands.swift)

```swift
// BEFORE:
struct SkinsCommands: Commands {
    @ObservedObject var skinManager: SkinManager

    var body: some Commands {
        // ...
    }
}

// AFTER:
struct SkinsCommands: Commands {
    @Bindable var skinManager: SkinManager  // Use @Bindable for two-way binding

    var body: some Commands {
        // ...
    }
}
```

### Pattern 2: SwiftUI Views (WinampPlaylistWindow.swift, etc.)

```swift
// BEFORE:
struct WinampPlaylistWindow: View {
    @EnvironmentObject var skinManager: SkinManager
    @EnvironmentObject var audioPlayer: AudioPlayer

    var body: some View {
        // ...
    }
}

// AFTER:
struct WinampPlaylistWindow: View {
    @Environment(SkinManager.self) var skinManager
    @Environment(AudioPlayer.self) var audioPlayer

    var body: some View {
        // ...
    }
}
```

### Pattern 3: App Root (MacAmpApp.swift)

```swift
// BEFORE:
@main
struct MacAmpApp: App {
    @StateObject private var skinManager = SkinManager()
    @StateObject private var audioPlayer = AudioPlayer()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(skinManager)
                .environmentObject(audioPlayer)
        }
        .commands {
            SkinsCommands(skinManager: skinManager)
        }
    }
}

// AFTER:
@main
struct MacAmpApp: App {
    @State private var skinManager = SkinManager()
    @State private var audioPlayer = AudioPlayer()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(skinManager)
                .environment(audioPlayer)
        }
        .commands {
            SkinsCommands(skinManager: skinManager)
        }
    }
}
```

---

## 7. AUDIOPLAYER @OBSERVABLE MIGRATION

**File:** `/Users/hank/dev/src/MacAmp/MacAmpApp/Audio/AudioPlayer.swift`

```swift
// ADD IMPORT:
import Observation

// CHANGE class declaration:
// BEFORE:
@MainActor
class AudioPlayer: ObservableObject {

// AFTER:
@Observable
@MainActor
final class AudioPlayer {

// REMOVE @Published from all public properties:
// BEFORE:
@Published var useSpectrumVisualizer: Bool = true
@Published var state: PlaybackState = .idle
@Published var playlist: [Track] = []
@Published var currentTrackIndex: Int? = nil
@Published var currentTime: Double = 0
@Published var duration: Double = 0
@Published var volume: Float = 1.0
@Published var balance: Float = 0.0
// ... etc

// AFTER:
var useSpectrumVisualizer: Bool = true
var state: PlaybackState = .idle
var playlist: [Track] = []
var currentTrackIndex: Int? = nil
var currentTime: Double = 0
var duration: Double = 0
var volume: Float = 1.0
var balance: Float = 0.0
// ... etc

// ADD @ObservationIgnored to private implementation details:
@ObservationIgnored private let audioEngine = AVAudioEngine()
@ObservationIgnored private let playerNode = AVAudioPlayerNode()
@ObservationIgnored private let eqNode = AVAudioUnitEQ(numberOfBands: 10)
@ObservationIgnored private var audioFile: AVAudioFile?
@ObservationIgnored private var progressTimer: Timer?
@ObservationIgnored private var playheadOffset: Double = 0
@ObservationIgnored private var visualizerTapInstalled = false
@ObservationIgnored private var visualizerPeaks: [Float] = Array(repeating: 0.0, count: 20)
@ObservationIgnored private var lastUpdateTime: CFAbsoluteTime = CFAbsoluteTimeGetCurrent()
```

---

## 8. TEST UPDATES FOR @OBSERVABLE

**File:** `/Users/hank/dev/src/MacAmp/Tests/MacAmpTests/SkinManagerTests.swift`

```swift
// BEFORE:
import XCTest
@testable import MacAmp

class SkinManagerTests: XCTestCase {
    var skinManager: SkinManager!

    override func setUp() {
        super.setUp()
        skinManager = SkinManager()
    }

    func testSkinLoading() {
        // Test code
    }
}

// AFTER:
import XCTest
@testable import MacAmp

@MainActor
class SkinManagerTests: XCTestCase {
    var skinManager: SkinManager!

    override func setUp() async throws {
        try await super.setUp()
        skinManager = SkinManager()
    }

    func testSkinLoading() async {
        // Test code
    }
}
```

---

## 9. ASYNC FILE PANEL (OPTIONAL)

**File:** `/Users/hank/dev/src/MacAmp/MacAmpApp/Utilities/NSOpenPanel+Async.swift` (NEW FILE)

```swift
//
//  NSOpenPanel+Async.swift
//  MacAmp
//
//  Async wrappers for NSOpenPanel file selection
//

import AppKit
import UniformTypeIdentifiers

extension NSOpenPanel {
    /// Select a single Winamp skin file (.wsz)
    @MainActor
    static func selectSkinFile() async -> URL? {
        let panel = NSOpenPanel()
        panel.title = "Select Winamp Skin"
        panel.message = "Choose a .wsz skin file to import"
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [UTType(filenameExtension: "wsz")].compactMap { $0 }

        return await withCheckedContinuation { continuation in
            panel.begin { response in
                if response == .OK, let url = panel.url {
                    continuation.resume(returning: url)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    /// Select multiple audio files for playlist
    @MainActor
    static func selectAudioFiles() async -> [URL]? {
        let panel = NSOpenPanel()
        panel.title = "Add Files to Playlist"
        panel.message = "Choose audio files to add"
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.audio, .mp3, .wav, .aiff, .m4a]

        return await withCheckedContinuation { continuation in
            panel.begin { response in
                if response == .OK {
                    continuation.resume(returning: panel.urls)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    /// Select a directory
    @MainActor
    static func selectDirectory(title: String = "Select Folder") async -> URL? {
        let panel = NSOpenPanel()
        panel.title = title
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false

        return await withCheckedContinuation { continuation in
            panel.begin { response in
                if response == .OK, let url = panel.url {
                    continuation.resume(returning: url)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}

extension NSSavePanel {
    /// Save EQF preset file
    @MainActor
    static func saveEQFPreset(defaultName: String = "preset.eqf") async -> URL? {
        let panel = NSSavePanel()
        panel.title = "Save Equalizer Preset"
        panel.nameFieldStringValue = defaultName
        panel.allowedContentTypes = [UTType(filenameExtension: "eqf")].compactMap { $0 }

        return await withCheckedContinuation { continuation in
            panel.begin { response in
                if response == .OK, let url = panel.url {
                    continuation.resume(returning: url)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}
```

**Usage in SkinsCommands.swift:**

```swift
// BEFORE:
private func openSkinFilePicker() {
    let panel = NSOpenPanel()
    panel.title = "Select Winamp Skin"
    panel.message = "Choose a .wsz skin file to import"
    panel.allowsMultipleSelection = false
    panel.canChooseDirectories = false
    panel.canChooseFiles = true
    panel.allowedContentTypes = [UTType(filenameExtension: "wsz")].compactMap { $0 }

    panel.begin { response in
        guard response == .OK, let url = panel.url else { return }

        Task { @MainActor in
            await skinManager.importSkin(from: url)
        }
    }
}

// AFTER:
private func openSkinFilePicker() {
    Task {
        if let url = await NSOpenPanel.selectSkinFile() {
            await skinManager.importSkin(from: url)
        }
    }
}
```

---

## 10. XCODE BUILD SETTINGS

**Enable Strict Concurrency Checking:**

1. Open Xcode project
2. Select target: MacAmp
3. Build Settings tab
4. Search: "concurrency"
5. Set "Strict Concurrency Checking" to **"Complete"**

**Enable Thread Sanitizer for testing:**

```bash
# Command line build with Thread Sanitizer
xcodebuild \
  -scheme MacAmp \
  -enableThreadSanitizer YES \
  build test

# Or use the Xcode scheme editor:
# Edit Scheme → Test → Diagnostics → Thread Sanitizer (check)
```

---

## 11. GIT COMMIT STRATEGY

**Recommended commit sequence:**

```bash
# Phase 1 commits
git add MacAmpApp/Views/Components/SimpleSpriteImage.swift
git commit -m "feat: Add pixelPerfect() extension for retro sprite rendering"

git add MacAmpApp/Views/Components/*.swift MacAmpApp/Views/*.swift
git commit -m "feat: Apply pixel-perfect rendering to all sprites"

git add MacAmpApp/Views/Components/SpriteMenuItem.swift
git commit -m "feat: Add @MainActor to SpriteMenuItem for concurrency safety"

git add MacAmpApp/Views/Components/PlaylistMenuDelegate.swift
git commit -m "feat: Add NSMenuDelegate for keyboard navigation support"

git add MacAmpApp/Views/Components/SpriteMenuItem.swift
git commit -m "refactor: Simplify SpriteMenuItem using NSMenuDelegate pattern"

# Phase 2 commits
git add MacAmpApp/ViewModels/SkinManager.swift
git commit -m "refactor: Migrate SkinManager to @Observable framework"

git add MacAmpApp/Views/*.swift MacAmpApp/*.swift
git commit -m "refactor: Update view injection for @Observable SkinManager"

git add Tests/MacAmpTests/SkinManagerTests.swift
git commit -m "test: Update SkinManager tests for @Observable"

git add MacAmpApp/Audio/AudioPlayer.swift
git commit -m "refactor: Migrate AudioPlayer to @Observable framework"

git add MacAmpApp/Views/*.swift
git commit -m "refactor: Update view injection for @Observable AudioPlayer"

git add Tests/MacAmpTests/*Tests.swift
git commit -m "test: Update all tests for @Observable migration"
```

Each commit is atomic and can be reverted independently if needed.
