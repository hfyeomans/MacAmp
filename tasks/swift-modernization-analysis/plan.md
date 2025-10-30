# Swift Modernization Implementation Plan
## MacAmp - macOS 15+ (Sequoia) and macOS 26+ (Tahoe)

**Based on:** research.md analysis
**Target:** Production-ready Swift 6 compatibility
**Timeline:** 4-7 days (3 phases)

---

## PHASE 1: QUICK WINS (Days 1-2)
**Goal:** Immediate visual and UX improvements with low risk

### Task 1.1: Image Interpolation Fix
**Priority:** CRITICAL
**Effort:** 2-3 hours
**Risk:** Very Low

#### Steps:

1. **Create pixel-perfect helper extension**
   - File: `/Users/hank/dev/src/MacAmp/MacAmpApp/Views/Components/SimpleSpriteImage.swift`
   - Add extension after `SimpleSpriteImage` definition

```swift
extension Image {
    /// Apply pixel-perfect rendering for retro sprite graphics
    /// Disables interpolation and anti-aliasing to preserve sharp pixels
    func pixelPerfect() -> some View {
        self
            .interpolation(.none)
            .antialiased(false)
    }
}
```

2. **Fix CRITICAL bug in WinampVolumeSlider.swift**
   - File: `/Users/hank/dev/src/MacAmp/MacAmpApp/Views/Components/WinampVolumeSlider.swift`
   - Find: `.interpolation(.high)` (around line 28 and 151)
   - Replace with: `.pixelPerfect()`

```swift
// BEFORE (Line 28):
Image(nsImage: volumeBg)
    .interpolation(.high)
    .resizable()

// AFTER:
Image(nsImage: volumeBg)
    .resizable()
    .pixelPerfect()
```

3. **Fix SpriteMenuItem.swift** (Menu sprites)
   - File: `/Users/hank/dev/src/MacAmp/MacAmpApp/Views/Components/SpriteMenuItem.swift`
   - Line 125: Add `.pixelPerfect()` after Image creation

```swift
// BEFORE:
Image(nsImage: image)
    .resizable()
    .frame(width: 22, height: 18)

// AFTER:
Image(nsImage: image)
    .resizable()
    .pixelPerfect()
    .frame(width: 22, height: 18)
```

4. **Fix PresetsButton.swift** (EQ presets button)
   - File: `/Users/hank/dev/src/MacAmp/MacAmpApp/Views/PresetsButton.swift`
   - Line 64: Add `.pixelPerfect()`

```swift
// BEFORE:
Image(nsImage: showPopover ? eqPresetsBtnSel : eqPresetsBtn)
    .resizable()
    .frame(width: 44, height: 12)

// AFTER:
Image(nsImage: showPopover ? eqPresetsBtnSel : eqPresetsBtn)
    .resizable()
    .pixelPerfect()
    .frame(width: 44, height: 12)
```

5. **Fix SkinnedText.swift** (Bitmap text)
   - File: `/Users/hank/dev/src/MacAmp/MacAmpApp/Views/SkinnedText.swift`
   - Line 24: Add `.pixelPerfect()`

```swift
// BEFORE:
Image(nsImage: img)

// AFTER:
Image(nsImage: img)
    .pixelPerfect()
```

6. **Fix PlaylistBitmapText.swift** (Playlist text)
   - File: `/Users/hank/dev/src/MacAmp/MacAmpApp/Views/Components/PlaylistBitmapText.swift`
   - Line 39: Add `.pixelPerfect()`

```swift
// BEFORE:
Image(nsImage: img)

// AFTER:
Image(nsImage: img)
    .pixelPerfect()
```

7. **Fix EqGraphView.swift** (Equalizer graphics)
   - File: `/Users/hank/dev/src/MacAmp/MacAmpApp/Views/EqGraphView.swift`
   - Lines 46, 89: Add `.pixelPerfect()`

```swift
// BEFORE (Line 46):
Image(nsImage: background)
    .resizable()
    .frame(width: 113, height: 19)

// AFTER:
Image(nsImage: background)
    .resizable()
    .pixelPerfect()
    .frame(width: 113, height: 19)

// BEFORE (Line 89):
Image(nsImage: preampLine)
    .resizable()
    .frame(width: 14, height: 63)

// AFTER:
Image(nsImage: preampLine)
    .resizable()
    .pixelPerfect()
    .frame(width: 14, height: 63)
```

8. **Investigate SkinnedBanner.swift**
   - File: `/Users/hank/dev/src/MacAmp/MacAmpApp/Views/SkinnedBanner.swift`
   - Line 18: Determine if fill pattern is pixel art
   - If YES: Add `.pixelPerfect()`
   - If NO (smooth gradient): Leave as-is

#### Validation:
- [ ] Build succeeds
- [ ] Run app with Thread Sanitizer: `xcodebuild -enableThreadSanitizer YES ...`
- [ ] Visual QA all windows (main, playlist, equalizer)
- [ ] Verify sprites are sharp (not blurry)
- [ ] Check volume/balance sliders look correct

---

### Task 1.2: @MainActor Annotations
**Priority:** HIGH
**Effort:** 1-2 hours
**Risk:** Low

#### Steps:

1. **Add @MainActor to SpriteMenuItem**
   - File: `/Users/hank/dev/src/MacAmp/MacAmpApp/Views/Components/SpriteMenuItem.swift`
   - Line 48: Add annotation

```swift
// BEFORE:
final class SpriteMenuItem: NSMenuItem {

// AFTER:
@MainActor
final class SpriteMenuItem: NSMenuItem {
```

2. **Optionally add @MainActor to HoverTrackingView (for clarity)**
   - File: Same as above
   - Line 12: Add annotation (though NSView is already implicitly @MainActor)

```swift
// BEFORE:
final class HoverTrackingView: NSView {

// AFTER:
@MainActor
final class HoverTrackingView: NSView {
```

3. **Enable strict concurrency warnings**
   - Open Xcode project settings
   - Build Settings → Swift Compiler - Language
   - Set "Strict Concurrency Checking" to "Targeted" or "Complete"

4. **Fix any new compiler warnings**
   - Review all warnings about cross-actor references
   - Wrap calls in `Task { @MainActor in }` if needed
   - Document any remaining warnings for Phase 2

#### Validation:
- [ ] Build with strict concurrency checking enabled
- [ ] No new concurrency warnings (or document them)
- [ ] All tests pass
- [ ] App runs correctly

---

### Task 1.3: NSMenuDelegate Pattern
**Priority:** HIGH
**Effort:** 3-4 hours
**Risk:** Low

#### Steps:

1. **Create PlaylistMenuDelegate class**
   - Create new file: `/Users/hank/dev/src/MacAmp/MacAmpApp/Views/Components/PlaylistMenuDelegate.swift`

```swift
import AppKit

/// Delegate that manages highlighting for sprite-based menu items
/// Handles both mouse hover and keyboard navigation
@MainActor
final class PlaylistMenuDelegate: NSObject, NSMenuDelegate {
    func menu(_ menu: NSMenu, willHighlight item: NSMenuItem?) {
        // Update all sprite menu items in the menu
        for menuItem in menu.items {
            if let sprite = menuItem as? SpriteMenuItem {
                sprite.isHighlighted = (menuItem === item)
            }
        }
    }
}
```

2. **Refactor SpriteMenuItem - Remove HoverTrackingView**
   - File: `/Users/hank/dev/src/MacAmp/MacAmpApp/Views/Components/SpriteMenuItem.swift`
   - Delete `HoverTrackingView` class (lines 12-45)
   - Simplify `SpriteMenuItem` to use delegate pattern

```swift
@MainActor
final class SpriteMenuItem: NSMenuItem {
    private let normalSpriteName: String
    private let selectedSpriteName: String
    private let skinManager: SkinManager
    private var hostingView: NSHostingView<SpriteMenuItemView>?

    // Public property for delegate to set
    var isHighlighted: Bool = false {
        didSet {
            updateView()
        }
    }

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
        // Create SwiftUI sprite view directly (no tracking container!)
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

// SpriteMenuItemView remains unchanged
struct SpriteMenuItemView: View {
    let normalSprite: String
    let selectedSprite: String
    let isHovered: Bool
    let skinManager: SkinManager

    var body: some View {
        if let image = skinManager.currentSkin?.images[isHovered ? selectedSprite : normalSprite] {
            Image(nsImage: image)
                .resizable()
                .pixelPerfect()
                .frame(width: 22, height: 18)
        } else {
            Color.gray
                .frame(width: 22, height: 18)
        }
    }
}
```

3. **Find all menu creation sites**
   - Use ripgrep: `rg "SpriteMenuItem\(" --type swift`
   - Identify all files that create sprite-based menus
   - Likely locations:
     - WinampPlaylistWindow.swift (ADD, REM, SEL, MISC, LIST buttons)
     - Any other sprite menu code

4. **Update menu creation to use delegate**
   - For each menu that uses SpriteMenuItem:

```swift
// Example pattern:
@MainActor
class PlaylistWindowController {
    private let menuDelegate = PlaylistMenuDelegate()

    private func createPlaylistMenu() -> NSMenu {
        let menu = NSMenu()
        menu.delegate = menuDelegate  // ← ADD THIS

        let addButton = SpriteMenuItem(
            normalSprite: "PLEDIT_ADD_BUTTON",
            selectedSprite: "PLEDIT_ADD_BUTTON_SELECTED",
            skinManager: skinManager,
            action: #selector(addFiles),
            target: self
        )
        menu.addItem(addButton)

        // ... add other items

        return menu
    }
}
```

5. **Update SpriteMenuItemView to use isHighlighted**
   - Change property name from `isHovered` to `isHighlighted` for clarity
   - Update all references

```swift
struct SpriteMenuItemView: View {
    let normalSprite: String
    let selectedSprite: String
    let isHighlighted: Bool  // ← RENAME from isHovered
    let skinManager: SkinManager

    var body: some View {
        if let image = skinManager.currentSkin?.images[isHighlighted ? selectedSprite : normalSprite] {
            // ...
        }
    }
}
```

#### Validation:
- [ ] Build succeeds
- [ ] Menu items highlight on mouse hover
- [ ] Menu items highlight with arrow keys (keyboard navigation)
- [ ] Enter key activates highlighted item
- [ ] VoiceOver reads menu items correctly
- [ ] All menu buttons work (ADD, REM, SEL, MISC, LIST)

---

## PHASE 2: ARCHITECTURE MODERNIZATION (Days 3-5)
**Goal:** Migrate to @Observable for better performance

### Task 2.1: Audit Test Coverage
**Priority:** HIGH
**Effort:** 2 hours
**Risk:** N/A

#### Steps:

1. **Run existing test suite**
   - `xcodebuild test -scheme MacAmp -enableThreadSanitizer YES`
   - Document pass/fail status

2. **Identify untested state-dependent views**
   - List all views using `@EnvironmentObject var skinManager`
   - List all views using `@EnvironmentObject var audioPlayer`
   - Cross-reference with test coverage

3. **Write missing tests (if needed)**
   - Focus on views that will change during @Observable migration
   - Priority: Main window, Playlist window, Equalizer window

#### Deliverables:
- [ ] Test coverage report
- [ ] List of high-risk views (no tests)
- [ ] New tests for critical paths

---

### Task 2.2: Migrate SkinManager to @Observable
**Priority:** HIGH
**Effort:** 4-6 hours
**Risk:** Medium

#### Steps:

1. **Update SkinManager class**
   - File: `/Users/hank/dev/src/MacAmp/MacAmpApp/ViewModels/SkinManager.swift`

```swift
// BEFORE:
@MainActor
class SkinManager: ObservableObject {
    @Published var currentSkin: Skin?
    @Published var isLoading: Bool = false
    @Published var availableSkins: [SkinMetadata] = []
    @Published var loadingError: String? = nil

    nonisolated init() { }

    private var loadGeneration = UUID()
}

// AFTER:
import Observation

@Observable
@MainActor
final class SkinManager {
    var currentSkin: Skin?
    var isLoading: Bool = false
    var availableSkins: [SkinMetadata] = []
    var loadingError: String? = nil

    // Use @ObservationIgnored for properties that should NOT trigger updates
    @ObservationIgnored private var loadGeneration = UUID()

    init() { }
}
```

2. **Update all view injection points**
   - Search: `rg "@ObservedObject var skinManager" --type swift`
   - Search: `rg "@EnvironmentObject var skinManager" --type swift`
   - Search: `rg "\.environmentObject\(skinManager\)" --type swift`

**Pattern 1: Commands (SkinsCommands.swift)**
```swift
// BEFORE:
struct SkinsCommands: Commands {
    @ObservedObject var skinManager: SkinManager
}

// AFTER:
struct SkinsCommands: Commands {
    @Bindable var skinManager: SkinManager  // Use @Bindable for two-way binding
}
```

**Pattern 2: SwiftUI Views (WinampPlaylistWindow.swift, etc.)**
```swift
// BEFORE:
struct WinampPlaylistWindow: View {
    @EnvironmentObject var skinManager: SkinManager
}

// AFTER:
struct WinampPlaylistWindow: View {
    @Environment(SkinManager.self) var skinManager
}
```

**Pattern 3: App Root (MacAmpApp.swift)**
```swift
// BEFORE:
@main
struct MacAmpApp: App {
    @StateObject private var skinManager = SkinManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(skinManager)
        }
    }
}

// AFTER:
@main
struct MacAmpApp: App {
    @State private var skinManager = SkinManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(skinManager)  // Use .environment() not .environmentObject()
        }
    }
}
```

3. **Handle Combine publishers (if any)**
   - Search: `rg "\$skinManager" --type swift`
   - If found, refactor to use `withObservationTracking`

```swift
// BEFORE:
skinManager.$currentSkin
    .sink { skin in
        // React to skin changes
    }

// AFTER (if needed in AppKit code):
func observeSkinChanges() {
    withObservationTracking {
        _ = skinManager.currentSkin
    } onChange: {
        Task { @MainActor in
            // React to skin changes
            self.observeSkinChanges()  // Re-register
        }
    }
}
```

4. **Update tests**
   - File: `/Users/hank/dev/src/MacAmp/Tests/MacAmpTests/SkinManagerTests.swift`

```swift
// BEFORE:
class SkinManagerTests: XCTestCase {
    var skinManager: SkinManager!

    override func setUp() {
        skinManager = SkinManager()
    }
}

// AFTER:
@MainActor
class SkinManagerTests: XCTestCase {
    var skinManager: SkinManager!

    override func setUp() async throws {
        skinManager = SkinManager()
    }
}
```

#### Validation:
- [ ] Build succeeds
- [ ] All tests pass
- [ ] Skin switching works
- [ ] Skin import works
- [ ] All views update when skin changes
- [ ] No visual regressions

---

### Task 2.3: Migrate AudioPlayer to @Observable
**Priority:** HIGH
**Effort:** 6-8 hours
**Risk:** Medium

#### Steps:

Same pattern as SkinManager, but more complex (more @Published properties)

1. **Update AudioPlayer class**
   - File: `/Users/hank/dev/src/MacAmp/MacAmpApp/Audio/AudioPlayer.swift`

```swift
// BEFORE:
@MainActor
class AudioPlayer: ObservableObject {
    @Published var useSpectrumVisualizer: Bool = true
    @Published var state: PlaybackState = .idle
    @Published var playlist: [Track] = []
    @Published var currentTrackIndex: Int? = nil
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var volume: Float = 1.0
    @Published var balance: Float = 0.0
    @Published var isShuffleEnabled: Bool = false
    @Published var repeatMode: RepeatMode = .off
    @Published var eqEnabled: Bool = false
    @Published var preamp: Int = 0
    @Published var eqBands: [Int] = Array(repeating: 0, count: 10)
    // ... and more
}

// AFTER:
import Observation

@Observable
@MainActor
final class AudioPlayer {
    var useSpectrumVisualizer: Bool = true
    var state: PlaybackState = .idle
    var playlist: [Track] = []
    var currentTrackIndex: Int? = nil
    var currentTime: Double = 0
    var duration: Double = 0
    var volume: Float = 1.0
    var balance: Float = 0.0
    var isShuffleEnabled: Bool = false
    var repeatMode: RepeatMode = .off
    var eqEnabled: Bool = false
    var preamp: Int = 0
    var eqBands: [Int] = Array(repeating: 0, count: 10)

    // Properties that should NOT trigger updates:
    @ObservationIgnored private let audioEngine = AVAudioEngine()
    @ObservationIgnored private let playerNode = AVAudioPlayerNode()
    @ObservationIgnored private let eqNode = AVAudioUnitEQ(numberOfBands: 10)
    @ObservationIgnored private var audioFile: AVAudioFile?
    @ObservationIgnored private var progressTimer: Timer?
}
```

2. **Update all audioPlayer injection points**
   - Same pattern as SkinManager
   - Search and replace across all files

3. **Update tests**
   - File: `/Users/hank/dev/src/MacAmp/Tests/MacAmpTests/AudioPlayerStateTests.swift`
   - Add `@MainActor` to test classes

#### Validation:
- [ ] Build succeeds
- [ ] All tests pass
- [ ] Playback works
- [ ] Volume/balance controls work
- [ ] Equalizer works
- [ ] Playlist operations work
- [ ] Time display updates
- [ ] Visualizer works

---

### Task 2.4: Performance Validation
**Priority:** MEDIUM
**Effort:** 2-3 hours
**Risk:** Low

#### Steps:

1. **Profile with Instruments**
   - Run Time Profiler
   - Compare before/after @Observable migration
   - Look for reduced view updates

2. **Test scrolling performance**
   - Large playlist (1000+ tracks)
   - Smooth scrolling?
   - CPU usage?

3. **Test skin switching**
   - Does it feel faster?
   - Any UI lag?

#### Success Criteria:
- [ ] No performance regressions
- [ ] Ideally 10-20% fewer view updates
- [ ] Smooth 60fps scrolling in playlist

---

## PHASE 3: POLISH (Optional - Day 6-7)
**Goal:** Nice-to-have improvements

### Task 3.1: Async File Panel Wrappers (Optional)
**Priority:** LOW
**Effort:** 2-3 hours
**Risk:** Very Low

Only implement if:
- You add complex file selection logic
- Multiple file pickers need standardization
- SwiftUI .fileImporter doesn't work for your use case

#### Steps:

1. **Create NSOpenPanel extension**
   - File: `/Users/hank/dev/src/MacAmp/MacAmpApp/Utilities/NSOpenPanel+Async.swift`

```swift
import AppKit
import UniformTypeIdentifiers

extension NSOpenPanel {
    @MainActor
    static func selectSkinFile() async -> URL? {
        let panel = NSOpenPanel()
        panel.title = "Select Winamp Skin"
        panel.message = "Choose a .wsz skin file to import"
        panel.allowsMultipleSelection = false
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

    @MainActor
    static func selectAudioFiles() async -> [URL]? {
        let panel = NSOpenPanel()
        panel.title = "Add Files to Playlist"
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.audio, .mp3, .wav]

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
}
```

2. **Update SkinsCommands.swift**

```swift
// BEFORE:
private func openSkinFilePicker() {
    let panel = NSOpenPanel()
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

#### Validation:
- [ ] Skin import works
- [ ] File selection works
- [ ] Cancel button works

**NOTE:** Current callback pattern is fine. Only implement if it adds value.

---

## ROLLBACK PLAN

If any phase fails:

### Rollback Phase 1:
```bash
git revert <commit-hash>  # Revert interpolation changes
git revert <commit-hash>  # Revert @MainActor changes
git revert <commit-hash>  # Revert NSMenuDelegate changes
```

### Rollback Phase 2:
```bash
git revert <commit-hash>  # Revert @Observable migration
```

All changes are in separate commits for easy rollback.

---

## SUCCESS CRITERIA

### Phase 1 Complete:
- [ ] All sprites render sharp (pixel-perfect)
- [ ] No concurrency warnings with strict checking enabled
- [ ] Menu keyboard navigation works
- [ ] All tests pass
- [ ] App runs without Thread Sanitizer errors

### Phase 2 Complete:
- [ ] SkinManager uses @Observable
- [ ] AudioPlayer uses @Observable
- [ ] All views updated to new injection pattern
- [ ] All tests pass
- [ ] Performance validated (no regressions)
- [ ] Full QA pass (all features work)

### Phase 3 Complete (Optional):
- [ ] Async file pickers (if implemented)
- [ ] Code cleanup
- [ ] Documentation updates

---

## DOCUMENTATION UPDATES

After completion:

1. Update README.md
   - Document Swift 6 compatibility
   - Note macOS 15+/26+ target

2. Update CONTRIBUTING.md (if exists)
   - Add @Observable usage guidelines
   - Add @MainActor annotation guidelines
   - Add pixel-perfect image rendering guidelines

3. Add inline comments
   - Document why @ObservationIgnored is used
   - Document NSMenuDelegate pattern
