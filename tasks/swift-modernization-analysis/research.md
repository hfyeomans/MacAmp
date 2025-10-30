# Swift Modernization Analysis for MacAmp
## macOS 15+ (Sequoia) and macOS 26+ (Tahoe) Compatibility Assessment

**Project Context:**
- MacAmp: Retro Winamp clone built with SwiftUI + AppKit integration
- Target: macOS 15+ (Sequoia) and macOS 26+ (Tahoe)
- Current Architecture: ObservableObject-based state management, custom NSMenuItem/NSView subclasses
- Testing Environment: macOS 26.1 (Build 25B5072a)

**Research Date:** 2025-10-28

---

## EXECUTIVE SUMMARY

| Recommendation | Validity | macOS 15 Status | macOS 26 Status | Priority | Migration |
|---------------|----------|-----------------|-----------------|----------|-----------|
| Swift 6 Strict Concurrency (@MainActor) | **Recommended** | Stable | Enhanced | **HIGH** | Easy |
| Async File Panel Pattern | **Optional** | Stable | Stable | MEDIUM | Easy |
| @Observable Migration | **Recommended** | Stable | Enhanced | **HIGH** | Medium |
| NSMenuDelegate for Hover | **Recommended** | Stable | Stable | **HIGH** | Easy |
| Image Interpolation (.none) | **Required** | Stable | Stable | **HIGH** | Easy |

---

## 1. SWIFT 6 STRICT CONCURRENCY (@MainActor)

### Validity Assessment: **RECOMMENDED**

**macOS 15 Status:** Stable - Swift 6 concurrency features are production-ready
**macOS 26 Status:** Enhanced - Strict concurrency checking enabled by default

### Benefits

1. **Compile-time data race detection** - Catch concurrency bugs before runtime
2. **Region-based isolation** - Reduces boilerplate for thread-safe code
3. **Better IDE integration** - Improved autocomplete and error messages
4. **Future-proof** - Required pattern for Swift 6+ compatibility

### Current State Analysis

**Already Using @MainActor:**
```swift
// SkinManager.swift (Line 101-102)
@MainActor
class SkinManager: ObservableObject {
```

```swift
// AudioPlayer.swift (Line 88-89)
@MainActor
class AudioPlayer: ObservableObject {
```

**Missing @MainActor Annotations:**
```swift
// SpriteMenuItem.swift (Line 12)
final class HoverTrackingView: NSView {
    // NOT annotated - but NSView inherits from NSResponder (implicitly @MainActor)
}

// SpriteMenuItem.swift (Line 48)
final class SpriteMenuItem: NSMenuItem {
    // NOT annotated - NSMenuItem does NOT inherit from NSResponder
    // NEEDS EXPLICIT @MainActor
}
```

### Gotchas for MacAmp

1. **NSView Subclasses:**
   - `HoverTrackingView` inherits from `NSResponder` → **already @MainActor implicitly**
   - No annotation needed, but adding it is harmless for clarity

2. **NSMenuItem Subclasses:**
   - `SpriteMenuItem` does NOT inherit from `NSResponder`
   - **MUST add @MainActor** if it updates UI or interacts with views
   - Currently accesses `NSHostingView` (line 52, 103, 112) → needs @MainActor

3. **Breaking Changes:**
   - Adding @MainActor may expose existing concurrency violations
   - Expect compiler warnings about cross-actor references
   - May need to wrap some calls in `Task { @MainActor in }`

### Recommendation: **HIGH PRIORITY - IMPLEMENT**

**Action Items:**
1. Add `@MainActor` to `SpriteMenuItem` class
2. Review all NSMenuItem subclasses for UI interactions
3. Enable strict concurrency warnings in build settings
4. Add `@MainActor` to any custom classes managing UI state

**Code Example for MacAmp:**
```swift
// SpriteMenuItem.swift - ADD THIS
@MainActor
final class SpriteMenuItem: NSMenuItem {
    private let normalSpriteName: String
    private let selectedSpriteName: String
    private let skinManager: SkinManager  // Now safe - both on MainActor
    // ... rest of implementation
}

// HoverTrackingView.swift - OPTIONAL (already implicit, but good for clarity)
@MainActor
final class HoverTrackingView: NSView {
    var onHoverChanged: ((Bool) -> Void)?
    weak var menuItem: NSMenuItem?
    // ... rest of implementation
}
```

**Migration Complexity:** Easy - Add annotations, fix compiler warnings

---

## 2. ASYNC FILE PANEL PATTERN

### Validity Assessment: **OPTIONAL (SwiftUI fileImporter preferred)**

**macOS 15 Status:** Stable - Both patterns work
**macOS 26 Status:** Stable - No changes

### Benefits

1. **Modern async/await syntax** - Cleaner than callback-based code
2. **Better error handling** - Can use try/catch with async functions
3. **SwiftUI integration** - fileImporter is declarative and type-safe

### Current State Analysis

**Current Pattern (callback-based):**
```swift
// SkinsCommands.swift (Line 92-108)
private func openSkinFilePicker() {
    let panel = NSOpenPanel()
    panel.title = "Select Winamp Skin"
    panel.allowsMultipleSelection = false
    panel.begin { response in
        guard response == .OK, let url = panel.url else { return }

        Task { @MainActor in
            await skinManager.importSkin(from: url)
        }
    }
}
```

**Used in multiple places:**
- `SkinsCommands.swift` (line 92) - Import skin file
- `PresetsButton.swift` (line 22-34) - Choose EQF folder
- `PresetsButton.swift` (line 115-127) - Load EQF file
- `PresetsButton.swift` (line 129-143) - Save EQF file

### Two Recommended Patterns

#### Pattern A: SwiftUI `.fileImporter` (BEST for new code)

**Pros:**
- Declarative, type-safe
- Automatic state binding
- Better SwiftUI integration
- Handles presentation logic automatically

**Cons:**
- Requires SwiftUI view context
- Less customization than NSOpenPanel

**Example for MacAmp:**
```swift
struct SkinsCommands: Commands {
    @ObservedObject var skinManager: SkinManager
    @State private var showingImporter = false

    var body: some Commands {
        CommandMenu("Skins") {
            Button("Import Skin File...") {
                showingImporter = true
            }
            .keyboardShortcut("o", modifiers: [.command, .shift])
            .fileImporter(
                isPresented: $showingImporter,
                allowedContentTypes: [UTType(filenameExtension: "wsz")].compactMap { $0 },
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        Task { await skinManager.importSkin(from: url) }
                    }
                case .failure(let error):
                    skinManager.loadingError = "Import failed: \(error.localizedDescription)"
                }
            }
        }
    }
}
```

#### Pattern B: NSOpenPanel async wrapper (for AppKit customization)

**Pros:**
- Works in non-SwiftUI contexts
- Full NSOpenPanel customization
- Maintains panel.title, accessory views, etc.

**Cons:**
- More boilerplate
- Manual error handling

**Example for MacAmp:**
```swift
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
}

// Usage in SkinsCommands:
Button("Import Skin File...") {
    Task {
        if let url = await NSOpenPanel.selectSkinFile() {
            await skinManager.importSkin(from: url)
        }
    }
}
```

### Recommendation: **MEDIUM PRIORITY - OPTIONAL**

**Current code is fine.** The existing callback pattern works correctly. Async wrappers provide minimal benefit since:
1. Already using `Task { @MainActor in }` for async integration
2. No complex async chains that would benefit from async/await
3. SwiftUI fileImporter doesn't work well in `Commands` context

**Action Items:**
- Keep existing NSOpenPanel.begin pattern for now
- Consider async wrapper IF you add complex file selection logic
- Use `.fileImporter` for any new SwiftUI-native views (not Commands)

**Migration Complexity:** Easy - But low ROI for current codebase

---

## 3. OBSERVATION FRAMEWORK MIGRATION (@Observable)

### Validity Assessment: **RECOMMENDED**

**macOS 15 Status:** Stable - Production-ready
**macOS 26 Status:** Enhanced - Standard approach for state management

### Benefits

1. **More granular updates** - SwiftUI only re-renders views that access changed properties
2. **Less boilerplate** - No need for @Published on every property
3. **Better performance** - Automatic dependency tracking reduces unnecessary renders
4. **Type safety** - Compile-time checking of property access
5. **Future-proof** - Observation is the modern SwiftUI state pattern

### Current State Analysis

**Current ObservableObject Usage:**
```swift
// SkinManager.swift (Line 101-107)
@MainActor
class SkinManager: ObservableObject {
    @Published var currentSkin: Skin?
    @Published var isLoading: Bool = false
    @Published var availableSkins: [SkinMetadata] = []
    @Published var loadingError: String? = nil
}

// AudioPlayer.swift (Line 88-89)
@MainActor
class AudioPlayer: ObservableObject {
    @Published var useSpectrumVisualizer: Bool = true
    @Published var state: PlaybackState = .idle
    @Published var playlist: [Track] = []
    // ... many more @Published properties
}
```

**View injection patterns:**
```swift
// SkinsCommands.swift (Line 7)
@ObservedObject var skinManager: SkinManager

// WinampPlaylistWindow.swift
@EnvironmentObject var audioPlayer: AudioPlayer
@EnvironmentObject var skinManager: SkinManager
```

### Migration Path

#### Step 1: Replace ObservableObject with @Observable
```swift
// OLD (SkinManager.swift)
@MainActor
class SkinManager: ObservableObject {
    @Published var currentSkin: Skin?
    @Published var isLoading: Bool = false
    @Published var availableSkins: [SkinMetadata] = []
    @Published var loadingError: String? = nil
}

// NEW
@Observable
@MainActor
final class SkinManager {
    var currentSkin: Skin?
    var isLoading: Bool = false
    var availableSkins: [SkinMetadata] = []
    var loadingError: String? = nil

    // For properties that should NOT trigger updates:
    @ObservationIgnored private var loadGeneration = UUID()
}
```

#### Step 2: Update View Injection

```swift
// OLD pattern (Commands)
struct SkinsCommands: Commands {
    @ObservedObject var skinManager: SkinManager
}

// NEW pattern - @Bindable for two-way binding
struct SkinsCommands: Commands {
    @Bindable var skinManager: SkinManager
}

// OR if read-only:
struct SkinsCommands: Commands {
    let skinManager: SkinManager
}
```

```swift
// OLD pattern (SwiftUI views)
struct WinampPlaylistWindow: View {
    @EnvironmentObject var skinManager: SkinManager
    @EnvironmentObject var audioPlayer: AudioPlayer
}

// NEW pattern - Environment macro
struct WinampPlaylistWindow: View {
    @Environment(SkinManager.self) var skinManager
    @Environment(AudioPlayer.self) var audioPlayer
}
```

```swift
// OLD pattern (App root)
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

// NEW pattern
@main
struct MacAmpApp: App {
    @State private var skinManager = SkinManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(skinManager)
        }
    }
}
```

### AppKit Integration Considerations

**CRITICAL:** @Observable works perfectly with SwiftUI but requires manual observation in AppKit code.

**Current AppKit integration:**
```swift
// SpriteMenuItem.swift (Line 52, 84, 109)
final class SpriteMenuItem: NSMenuItem {
    private let skinManager: SkinManager  // Holds reference

    // SwiftUI view that accesses skinManager.currentSkin
    let spriteView = SpriteMenuItemView(
        normalSprite: normalSpriteName,
        selectedSprite: selectedSpriteName,
        isHovered: isHovered,
        skinManager: skinManager  // Passed to SwiftUI
    )
}
```

**This pattern STILL WORKS with @Observable** because:
- SpriteMenuItemView is SwiftUI → automatic observation
- NSHostingView bridges SwiftUI's observation to AppKit
- No manual observation needed

**If you need observation in pure AppKit code:**
```swift
@MainActor
final class SpriteMenuItem: NSMenuItem {
    private let skinManager: SkinManager

    private func observeSkinChanges() {
        withObservationTracking {
            // Access properties you want to observe
            _ = skinManager.currentSkin
        } onChange: {
            // This closure called when currentSkin changes
            Task { @MainActor in
                self.updateView()
                self.observeSkinChanges() // Re-register observation
            }
        }
    }
}
```

### Breaking Changes

1. **@Published → var**
   - Remove all `@Published` wrappers
   - Properties are automatically observable

2. **@ObservedObject → @Bindable or let**
   - Use `@Bindable` if you need two-way binding
   - Use `let` for read-only access

3. **@StateObject → @State**
   - Replace `@StateObject` with `@State`

4. **@EnvironmentObject → @Environment**
   - Replace `.environmentObject(foo)` with `.environment(foo)`
   - Replace `@EnvironmentObject var foo: Foo` with `@Environment(Foo.self) var foo`

5. **Combine Publishers**
   - If you're using `$property.sink {}`, you'll need to refactor
   - @Observable doesn't provide publishers
   - Use `withObservationTracking` for custom observation

### Risks

1. **Test Coverage Required**
   - ALL views must be tested after migration
   - Playlist, equalizer, main window, skin selection

2. **Combine Integration**
   - Check if any code uses `objectWillChange` publisher
   - Search for `$skinManager` or `$audioPlayer` property access

3. **Performance**
   - Initially may see different render patterns
   - Should improve after SwiftUI optimizes observation

### Recommendation: **HIGH PRIORITY - IMPLEMENT AFTER TESTING**

**Action Items:**
1. **Research Phase (Done)** ✅
2. **Test Current Coverage** - Ensure tests exist for all state-dependent views
3. **Migration Phase:**
   - Start with `SkinManager` (fewer @Published properties)
   - Update all view injection points
   - Test thoroughly
   - Migrate `AudioPlayer` second
4. **Validation Phase:**
   - Run full app test suite
   - Manual QA of all features
   - Performance profiling

**Migration Complexity:** Medium
- Code changes are mechanical (search/replace)
- Testing is critical (touches ALL UI)
- Rollback is easy (just revert commits)

---

## 4. NSMENUDELEGATE FOR HOVER HANDLING

### Validity Assessment: **RECOMMENDED**

**macOS 15 Status:** Stable - Standard pattern
**macOS 26 Status:** Stable - No changes

### Benefits

1. **Keyboard navigation support** - Handles both mouse AND keyboard automatically
2. **System integration** - Works with VoiceOver and accessibility features
3. **Less code** - No manual tracking area management
4. **More reliable** - System calls delegate, you don't manage lifecycle

### Current State Analysis

**Current Pattern (NSTrackingArea in custom view):**
```swift
// SpriteMenuItem.swift (Line 12-45)
final class HoverTrackingView: NSView {
    var onHoverChanged: ((Bool) -> Void)?
    weak var menuItem: NSMenuItem?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach { removeTrackingArea($0) }

        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
    }

    override func mouseEntered(with event: NSEvent) {
        onHoverChanged?(true)
    }

    override func mouseExited(with event: NSEvent) {
        onHoverChanged?(false)
    }

    // Manual click forwarding required
    override func mouseDown(with event: NSEvent) {
        if let menuItem = menuItem,
           let action = menuItem.action,
           let target = menuItem.target {
            NSApp.sendAction(action, to: target, from: menuItem)
        }
        menuItem?.menu?.cancelTracking()
    }
}
```

**Problem:** This approach:
- Only works with mouse (NOT keyboard navigation)
- Doesn't integrate with VoiceOver
- Requires manual click forwarding
- Needs tracking area lifecycle management

### Recommended Pattern (NSMenuDelegate)

**NEW: Much cleaner and more reliable:**
```swift
// Remove HoverTrackingView entirely
// Simplify SpriteMenuItem

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

        self.view = hosting  // Set view directly, no container
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

// NEW: Menu delegate handles ALL highlighting
@MainActor
final class PlaylistMenuDelegate: NSObject, NSMenuDelegate {
    func menu(_ menu: NSMenu, willHighlight item: NSMenuItem?) {
        // Update ALL sprite menu items in the menu
        for menuItem in menu.items {
            if let sprite = menuItem as? SpriteMenuItem {
                sprite.isHighlighted = (menuItem === item)
            }
        }
    }
}

// Usage in your menu creation code:
let menu = NSMenu()
let delegate = PlaylistMenuDelegate()
menu.delegate = delegate

// Add sprite menu items
let addButton = SpriteMenuItem(
    normalSprite: "PLEDIT_ADD_BUTTON",
    selectedSprite: "PLEDIT_ADD_BUTTON_SELECTED",
    skinManager: skinManager,
    action: #selector(addFiles),
    target: self
)
menu.addItem(addButton)
```

### What Changes

**Before (current):**
- `HoverTrackingView` manages mouse tracking
- Manual `mouseEntered`/`mouseExited` events
- Manual click forwarding
- No keyboard support

**After (recommended):**
- System manages highlighting via delegate
- `menu(_:willHighlight:)` called for mouse AND keyboard
- Built-in click handling (no forwarding needed)
- Full keyboard navigation support
- VoiceOver compatibility

### Testing Keyboard Navigation

After migration, test:
1. Open menu with mouse → sprites highlight on hover ✅
2. Open menu with keyboard (F10 or Ctrl+F2) → sprites highlight with arrow keys ✅
3. Press Enter to activate highlighted item ✅
4. VoiceOver announces sprite menu items correctly ✅

### Where to Apply This

Search for menu creation code in MacAmp:
```bash
# Find all menu creation
rg "NSMenu\(\)" --type swift
```

**Likely locations:**
- Playlist window menu buttons (ADD, REM, SEL, MISC, LIST)
- Main window context menus
- Any other sprite-based menus

### Recommendation: **HIGH PRIORITY - IMPLEMENT**

**Action Items:**
1. Create `PlaylistMenuDelegate` class
2. Refactor `SpriteMenuItem` to remove `HoverTrackingView`
3. Set delegate on all menus using sprite items
4. Test mouse and keyboard navigation
5. Remove old `HoverTrackingView` class

**Migration Complexity:** Easy
- Net REDUCTION in code (remove HoverTrackingView)
- Cleaner architecture
- Better accessibility

---

## 5. IMAGE INTERPOLATION FOR PIXEL ART

### Validity Assessment: **REQUIRED**

**macOS 15 Status:** Stable - Essential for pixel art
**macOS 26 Status:** Stable - No changes

### Benefits

1. **Pixel-perfect rendering** - Sharp, blocky pixels (no blur)
2. **Authentic retro aesthetic** - Preserves Winamp's visual style
3. **Performance improvement** - GPU does less work
4. **Integer scaling support** - Clean 2x/3x scaling

### Current State Analysis

**Already Using .interpolation(.none):**
```swift
// SimpleSpriteImage.swift (Line 54-60) ✅ CORRECT
Image(nsImage: image)
    .interpolation(.none)
    .antialiased(false)
    .resizable()
    .aspectRatio(contentMode: .fill)
    .frame(width: width, height: height)
    .clipped()
```

**NOT Using .interpolation(.none):**

1. **SpriteMenuItem.swift (Line 125)** - Menu sprites
```swift
// WRONG
Image(nsImage: image)
    .resizable()
    .frame(width: 22, height: 18)
```

2. **SkinnedBanner.swift (Line 18-20)** - Title bar fill pattern
```swift
// MAYBE WRONG (depends if it's pixel art)
Image(nsImage: img)
    .resizable(resizingMode: .tile)
    .frame(height: height)
```

3. **PresetsButton.swift (Line 64-66)** - EQ presets button
```swift
// WRONG
Image(nsImage: showPopover ? eqPresetsBtnSel : eqPresetsBtn)
    .resizable()
    .frame(width: 44, height: 12)
```

4. **SkinnedText.swift (Line 24)** - Bitmap text characters
```swift
// WRONG (no .resizable() so no interpolation setting)
Image(nsImage: img)
```

5. **WinampVolumeSlider.swift (Line 28, 151)** - Volume/balance backgrounds
```swift
// WRONG
Image(nsImage: volumeBg)
    .interpolation(.high)  // EXPLICITLY USING HIGH! BAD!
```

6. **PlaylistBitmapText.swift (Line 39)** - Playlist text characters
```swift
// WRONG
Image(nsImage: img)
```

7. **EqGraphView.swift (Line 46, 89)** - Equalizer background and lines
```swift
// WRONG
Image(nsImage: background)
    .resizable()
```

### Where to Apply

**Apply to ALL Winamp skin sprites:**
- Main window buttons
- Playlist window buttons
- Equalizer buttons and backgrounds
- Volume/balance slider backgrounds
- Digit displays
- Text characters (bitmap fonts)
- Window backgrounds
- Menu sprites

**DO NOT apply to:**
- System SF Symbols (e.g., `Image(systemName: "folder")`)
- Modern macOS UI elements
- Smooth graphics (if any)

### Recommended Pattern

```swift
// For all skin sprites - use this helper
extension Image {
    func pixelPerfect() -> some View {
        self
            .interpolation(.none)
            .antialiased(false)
    }
}

// Usage:
Image(nsImage: spriteImage)
    .resizable()
    .pixelPerfect()
    .frame(width: 22, height: 18)
```

### Performance Implications

**Positive Impact:**
- Disabling interpolation = less GPU work
- Typically 5-10% faster rendering for many small sprites
- Negligible difference for single images
- Cumulative benefit for 100+ sprites on screen

**Best Practices:**
1. Use integer scaling when possible (2x, 3x, not 2.5x)
2. Frame size should be exact sprite size or integer multiple
3. Avoid non-integer scaling (causes distortion even without interpolation)

### Recommendation: **HIGH PRIORITY - IMPLEMENT IMMEDIATELY**

**Action Items:**
1. **Create extension** for `.pixelPerfect()` modifier
2. **Fix WinampVolumeSlider.swift** - Remove `.interpolation(.high)`!
3. **Add to all sprite Image views:**
   - SpriteMenuItem.swift (line 125)
   - PresetsButton.swift (line 64)
   - SkinnedText.swift (line 24)
   - PlaylistBitmapText.swift (line 39)
   - EqGraphView.swift (lines 46, 89)
4. **Review SkinnedBanner.swift** - Determine if fill pattern is pixel art
5. **Test visual quality** - Verify all sprites render sharp

**Migration Complexity:** Easy - Add 2 lines to each Image view

**CRITICAL FIX:**
```swift
// WinampVolumeSlider.swift - CHANGE THIS IMMEDIATELY
// OLD (Line 28):
Image(nsImage: volumeBg)
    .interpolation(.high)  // ❌ MAKES PIXEL ART BLURRY!

// NEW:
Image(nsImage: volumeBg)
    .interpolation(.none)
    .antialiased(false)
```

---

## IMPLEMENTATION ROADMAP

### Phase 1: Quick Wins (1-2 days)
**Priority: HIGH - Immediate visual/UX improvements**

1. **Image Interpolation** ✅
   - Add `.pixelPerfect()` extension
   - Fix all sprite Image views
   - Fix WinampVolumeSlider.swift critical bug
   - Visual QA all windows

2. **@MainActor Annotations** ✅
   - Add to SpriteMenuItem
   - Enable concurrency warnings
   - Fix any new warnings

3. **NSMenuDelegate Pattern** ✅
   - Create PlaylistMenuDelegate
   - Refactor SpriteMenuItem (remove HoverTrackingView)
   - Test keyboard navigation

### Phase 2: Architecture Modernization (3-5 days)
**Priority: HIGH - Future-proofing**

1. **@Observable Migration**
   - Audit current test coverage
   - Migrate SkinManager first
   - Update all view injection points
   - Full testing pass
   - Migrate AudioPlayer second
   - Full testing pass
   - Performance validation

### Phase 3: Polish (Optional)
**Priority: MEDIUM - Nice to have**

1. **Async File Panels**
   - Only if you add complex file selection logic
   - Consider SwiftUI .fileImporter for new views
   - Current pattern is fine

---

## RISKS AND MITIGATION

### Risk 1: @Observable Migration Breaks UI
**Likelihood:** Medium
**Impact:** High
**Mitigation:**
- Complete test coverage before migration
- Migrate one manager at a time
- Keep git commits atomic for easy rollback

### Risk 2: @MainActor Exposes Concurrency Bugs
**Likelihood:** Low
**Impact:** Medium
**Mitigation:**
- Already using @MainActor on managers
- AppKit classes implicitly @MainActor
- Fix any new warnings incrementally

### Risk 3: NSMenuDelegate Changes Menu Behavior
**Likelihood:** Low
**Impact:** Low
**Mitigation:**
- System-standard pattern (low risk)
- Test mouse + keyboard thoroughly
- Easy rollback if issues

---

## TESTING CHECKLIST

### Pre-Migration Testing
- [ ] All windows open correctly
- [ ] All menu buttons work (ADD, REM, SEL, MISC, LIST)
- [ ] Skin switching works
- [ ] Playlist operations work
- [ ] Equalizer works
- [ ] Keyboard shortcuts work

### Post-Migration Testing
- [ ] Re-run all pre-migration tests
- [ ] Keyboard menu navigation (arrow keys)
- [ ] VoiceOver accessibility
- [ ] Performance profiling (Instruments)
- [ ] Thread safety validation (Thread Sanitizer)

---

## CONCLUSION

**Recommended Implementation Order:**
1. **Image Interpolation** (Phase 1) - Immediate visual improvement
2. **@MainActor** (Phase 1) - Future-proofing + safety
3. **NSMenuDelegate** (Phase 1) - Better UX + accessibility
4. **@Observable** (Phase 2) - Performance + modern architecture
5. **Async File Panels** (Phase 3 / Optional) - Low ROI for current code

**Total Effort Estimate:** 4-7 days for Phases 1-2

**Risk Level:** Low (all changes are additive and reversible)

**ROI:** High (better performance, accessibility, future Swift compatibility)
