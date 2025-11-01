# MacAmp Dynamic Skin Switching - Implementation Plan

## Overview

This document provides a comprehensive, step-by-step implementation plan for adding dynamic skin switching to MacAmp. The system will allow users to switch between multiple Winamp .wsz skins at runtime without restarting the application.

**Status:** Ready for implementation
**Created:** 2025-10-11
**Research Reference:** `/Users/hank/dev/src/MacAmp/tasks/skin-loading-research/research.md`

---

## Section 1: Architecture Design

### 1.1 Current State Analysis

**Existing Implementation:**
- `SkinManager` is a `@MainActor ObservableObject` with `@Published var currentSkin: Skin?`
- Loads one skin from hardcoded path: `Bundle.main.url(forResource: "Winamp", withExtension: "wsz")`
- Uses ZIPFoundation for .wsz parsing
- Extracts sprites using `NSImage.cropped(to:)` extension
- All views react to skin changes via `@EnvironmentObject`

**Available Skins:**
- `/Users/hank/dev/src/MacAmp/MacAmpApp/Assets/Winamp.wsz` (bundled, default)
- `/Users/hank/dev/src/MacAmp/MacAmpApp/Assets/Internet-Archive.wsz` (bundled, new test skin)

### 1.2 Architecture Goals

1. **Hot Reloading:** Switch skins without app restart
2. **Multi-source Support:** Load skins from:
   - Bundled resources (Winamp.wsz, Internet-Archive.wsz)
   - User-selected files via NSOpenPanel
   - Potentially from a user skins directory (~/.macamp/skins/)
3. **State Persistence:** Remember user's last selected skin
4. **Error Resilience:** Fall back to default skin if loading fails
5. **UI Reactivity:** All views automatically update when skin changes

### 1.3 Architectural Pattern

We'll extend the existing architecture without breaking changes:

```
┌─────────────────────────────────────────────────────┐
│                  AppSettings                         │
│  - selectedSkinIdentifier: String?                  │
│  - userSkinsDirectory: URL                          │
└─────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────┐
│                 SkinManager                          │
│  - currentSkin: Skin?                     (existing)│
│  - availableSkins: [SkinMetadata]            (new) │
│  - isLoading: Bool                        (existing)│
│  - loadingError: String?                     (new) │
│                                                      │
│  Methods:                                            │
│  - loadSkin(from: URL)                    (existing)│
│  - scanAvailableSkins()                      (new) │
│  - switchToSkin(identifier: String)          (new) │
│  - loadUserSkinFile()                        (new) │
└─────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────┐
│              SwiftUI Views                           │
│  - Menu Bar: "Skins" menu                            │
│  - Preferences Window: Skin picker tab               │
│  - All @EnvironmentObject var skinManager            │
└─────────────────────────────────────────────────────┘
```

### 1.4 State Management Flow

**On App Launch:**
1. `SkinManager` initializes with `availableSkins = []`
2. `scanAvailableSkins()` discovers bundled skins
3. Load last selected skin from UserDefaults, or default to "Winamp"
4. Parse and set `currentSkin`
5. All views receive skin via `@EnvironmentObject`


**On Skin Switch:**
1. User selects skin from menu/preferences
2. `switchToSkin(identifier:)` called
3. `loadSkin(from: url)` parses new .wsz file
4. `currentSkin` published property updates
5. SwiftUI automatically re-renders all views
6. New skin identifier saved to UserDefaults

**On Custom Skin Load:**
1. User clicks "Load Custom Skin..."
2. NSOpenPanel presented with .wsz filter
3. User selects file
4. Copy to user skins directory (~/.macamp/skins/)
5. Add to `availableSkins` array
6. Load the skin
7. Save identifier to UserDefaults

---

## Section 2: Data Structures

### 2.1 SkinMetadata

Add to `/Users/hank/dev/src/MacAmp/MacAmpApp/Models/Skin.swift`:

```swift
import Foundation

/// Metadata about an available skin (before it's fully loaded)
struct SkinMetadata: Identifiable, Hashable {
    let id: String          // Unique identifier (e.g., "bundled:Winamp" or "user:MySkin")
    let name: String        // Display name (e.g., "Classic Winamp")
    let url: URL            // Path to .wsz file
    let source: SkinSource  // Where the skin comes from

    /// Optional preview thumbnail (for future enhancement)
    var thumbnailURL: URL? = nil

    init(id: String, name: String, url: URL, source: SkinSource) {
        self.id = id
        self.name = name
        self.url = url
        self.source = source
    }
}

/// Source type for skin
enum SkinSource: Hashable {
    case bundled     // Shipped with app
    case user        // User-installed in ~/.macamp/skins/
    case temporary   // One-time load from arbitrary location
}

extension SkinMetadata {
    /// Built-in bundled skins
    static var bundledSkins: [SkinMetadata] {
        var skins: [SkinMetadata] = []

        // Winamp default skin
        if let url = Bundle.main.url(forResource: "Winamp", withExtension: "wsz") {
            skins.append(SkinMetadata(
                id: "bundled:Winamp",
                name: "Classic Winamp",
                url: url,
                source: .bundled
            ))
        }

        // Internet Archive skin
        if let url = Bundle.main.url(forResource: "Internet-Archive", withExtension: "wsz") {
            skins.append(SkinMetadata(
                id: "bundled:Internet-Archive",
                name: "Internet Archive",
                url: url,
                source: .bundled
            ))
        }

        return skins
    }
}
```

### 2.2 UserDefaults Keys

Add to `/Users/hank/dev/src/MacAmp/MacAmpApp/Models/AppSettings.swift`:

```swift
extension AppSettings {
    // MARK: - Skin Settings

    /// Key for storing the selected skin identifier
    private static let selectedSkinKey = "SelectedSkinIdentifier"

    /// The currently selected skin identifier
    var selectedSkinIdentifier: String? {
        get {
            UserDefaults.standard.string(forKey: Self.selectedSkinKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Self.selectedSkinKey)
        }
    }

    /// Directory for user-installed skins
    static var userSkinsDirectory: URL {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!

        let macampDir = appSupport.appendingPathComponent("MacAmp", isDirectory: true)
        let skinsDir = macampDir.appendingPathComponent("Skins", isDirectory: true)

        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(
            at: skinsDir,
            withIntermediateDirectories: true,
            attributes: nil
        )

        return skinsDir
    }
}
```

### 2.3 Error Handling

Add error types to `/Users/hank/dev/src/MacAmp/MacAmpApp/ViewModels/SkinManager.swift`:

```swift
enum SkinLoadError: LocalizedError {
    case fileNotFound(String)
    case invalidArchive(String)
    case parseFailed(String)
    case missingRequiredAssets([String])

    var errorDescription: String? {
        switch self {
        case .fileNotFound(let path):
            return "Skin file not found: \(path)"
        case .invalidArchive(let reason):
            return "Invalid skin archive: \(reason)"
        case .parseFailed(let reason):
            return "Failed to parse skin: \(reason)"
        case .missingRequiredAssets(let assets):
            return "Skin is missing required assets: \(assets.joined(separator: ", "))"
        }
    }
}
```

---

## Section 3: SkinManager Enhancements

### 3.1 New Properties

Add to `SkinManager` class:

```swift
@MainActor
class SkinManager: ObservableObject {
    @Published var currentSkin: Skin?                    // Existing
    @Published var isLoading: Bool = false                // Existing

    // NEW PROPERTIES
    @Published var availableSkins: [SkinMetadata] = []    // List of available skins
    @Published var loadingError: String? = nil            // Last error message

    // Reference to settings for persistence
    private let settings = AppSettings.instance()

    // ... existing methods ...
}
```

### 3.2 Initialization Enhancement

Replace the implicit initialization with explicit setup:

```swift
@MainActor
class SkinManager: ObservableObject {
    // ... properties ...

    init() {
        // Discover available skins
        scanAvailableSkins()

        // Load last selected skin or default
        loadInitialSkin()
    }

    /// Scan for available skins from all sources
    private func scanAvailableSkins() {
        var discovered: [SkinMetadata] = []

        // 1. Add bundled skins
        discovered.append(contentsOf: SkinMetadata.bundledSkins)

        // 2. Scan user skins directory
        let userSkinsDir = AppSettings.userSkinsDirectory
        if let userSkinURLs = try? FileManager.default.contentsOfDirectory(
            at: userSkinsDir,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) {
            for url in userSkinURLs where url.pathExtension.lowercased() == "wsz" {
                let filename = url.deletingPathExtension().lastPathComponent
                discovered.append(SkinMetadata(
                    id: "user:\(filename)",
                    name: filename,
                    url: url,
                    source: .user
                ))
            }
        }

        availableSkins = discovered
        NSLog("SkinManager: Discovered \(discovered.count) skins")
    }

    /// Load the initial skin (from preferences or default)
    private func loadInitialSkin() {
        // Try to load last selected skin
        if let savedIdentifier = settings.selectedSkinIdentifier,
           let skinMeta = availableSkins.first(where: { $0.id == savedIdentifier }) {
            NSLog("SkinManager: Loading saved skin: \(skinMeta.name)")
            loadSkin(from: skinMeta.url)
            return
        }

        // Fall back to default (first bundled skin, likely Winamp)
        if let defaultSkin = availableSkins.first(where: { $0.source == .bundled }) {
            NSLog("SkinManager: Loading default skin: \(defaultSkin.name)")
            loadSkin(from: defaultSkin.url)
        } else {
            NSLog("SkinManager: ERROR - No skins available!")
            loadingError = "No skins found. Please reinstall MacAmp."
        }
    }
}
```

### 3.3 Skin Switching Method

Add new method for switching between available skins:

```swift
extension SkinManager {
    /// Switch to a skin by its identifier
    /// - Parameter identifier: The unique ID of the skin (e.g., "bundled:Winamp")
    func switchToSkin(identifier: String) {
        guard let skinMeta = availableSkins.first(where: { $0.id == identifier }) else {
            NSLog("SkinManager: ERROR - Skin not found: \(identifier)")
            loadingError = "Skin '\(identifier)' not found"
            return
        }

        NSLog("SkinManager: Switching to skin: \(skinMeta.name)")

        // Load the skin
        loadSkin(from: skinMeta.url)

        // Save preference
        settings.selectedSkinIdentifier = identifier
    }

    /// Switch to a specific skin metadata
    func switchToSkin(_ metadata: SkinMetadata) {
        switchToSkin(identifier: metadata.id)
    }
}
```

### 3.4 Custom Skin Loading

Add method for loading arbitrary .wsz files:

```swift
extension SkinManager {
    /// Load a custom skin file selected by the user
    func loadUserSkinFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.init(filenameExtension: "wsz")!]
        panel.title = "Select Winamp Skin (.wsz)"
        panel.message = "Choose a Winamp skin file to load"

        panel.begin { [weak self] response in
            guard let self = self else { return }

            if response == .OK, let selectedURL = panel.url {
                Task { @MainActor in
                    await self.importAndLoadSkin(from: selectedURL)
                }
            }
        }
    }

    /// Import a skin file to user skins directory and load it
    private func importAndLoadSkin(from sourceURL: URL) async {
        let filename = sourceURL.lastPathComponent
        let destinationURL = AppSettings.userSkinsDirectory.appendingPathComponent(filename)

        do {
            // Copy to user skins directory (replace if exists)
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)

            NSLog("SkinManager: Imported skin to: \(destinationURL.path)")

            // Create metadata
            let skinName = sourceURL.deletingPathExtension().lastPathComponent
            let metadata = SkinMetadata(
                id: "user:\(skinName)",
                name: skinName,
                url: destinationURL,
                source: .user
            )

            // Add to available skins if not already present
            if !availableSkins.contains(where: { $0.id == metadata.id }) {
                availableSkins.append(metadata)
            }

            // Load the imported skin
            switchToSkin(identifier: metadata.id)

        } catch {
            NSLog("SkinManager: ERROR importing skin: \(error)")
            loadingError = "Failed to import skin: \(error.localizedDescription)"
        }
    }
}
```

### 3.5 Enhanced Error Handling

Update `loadSkin(from:)` to set error state:

```swift
func loadSkin(from url: URL) {
    print("Loading skin from \(url.path)")
    isLoading = true
    loadingError = nil  // Clear previous errors

    do {
        // ... existing parsing code ...

        // On success
        self.currentSkin = newSkin
        self.isLoading = false
        self.loadingError = nil
        print("Skin loaded successfully: \(url.lastPathComponent)")

    } catch {
        print("Error loading skin: \(error)")
        isLoading = false
        loadingError = "Failed to load skin: \(error.localizedDescription)"

        // Fall back to default skin if current is nil
        if currentSkin == nil {
            if let defaultSkin = availableSkins.first(where: { $0.source == .bundled }) {
                NSLog("Falling back to default skin")
                loadSkin(from: defaultSkin.url)
            }
        }
    }
}
```

---

## Section 4: UI Components

### 4.1 Menu Bar Integration

Add a "Skins" menu to the menu bar. Create new file:
`/Users/hank/dev/src/MacAmp/MacAmpApp/Views/Commands/SkinsCommands.swift`

```swift
import SwiftUI

struct SkinsCommands: Commands {
    @ObservedObject var skinManager: SkinManager

    var body: some Commands {
        CommandMenu("Skins") {
            // Bundled skins section
            Section("Bundled Skins") {
                ForEach(skinManager.availableSkins.filter { $0.source == .bundled }) { skin in
                    Button(skin.name) {
                        skinManager.switchToSkin(skin)
                    }
                    .keyboardShortcut(skin.id == "bundled:Winamp" ? "1" : "2", modifiers: [.command])
                }
            }

            // User skins section (if any exist)
            let userSkins = skinManager.availableSkins.filter { $0.source == .user }
            if !userSkins.isEmpty {
                Divider()
                Section("My Skins") {
                    ForEach(userSkins) { skin in
                        Button(skin.name) {
                            skinManager.switchToSkin(skin)
                        }
                    }
                }
            }

            Divider()

            // Load custom skin
            Button("Load Custom Skin...") {
                skinManager.loadUserSkinFile()
            }
            .keyboardShortcut("o", modifiers: [.command, .shift])

            // Open user skins folder
            Button("Show Skins Folder") {
                NSWorkspace.shared.selectFile(
                    nil,
                    inFileViewerRootedAtPath: AppSettings.userSkinsDirectory.path
                )
            }
        }
    }
}
```

### 4.2 Update AppCommands

Modify `/Users/hank/dev/src/MacAmp/MacAmpApp/MacAmpApp.swift` to include skins commands:

```swift
@main
struct MacAmpApp: App {
    @StateObject private var skinManager = SkinManager()
    @StateObject private var audioPlayer = AudioPlayer()
    @StateObject private var dockingController = DockingController()
    @StateObject private var settings = AppSettings.instance()

    var body: some Scene {
        WindowGroup {
            UnifiedDockView()
                .environmentObject(skinManager)
                .environmentObject(audioPlayer)
                .environmentObject(dockingController)
                .environmentObject(settings)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)

        WindowGroup("Preferences", id: "preferences") {
            PreferencesView()
                .environmentObject(settings)
                .environmentObject(skinManager)  // Add skinManager
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultPosition(.center)
        .commands {
            AppCommands(dockingController: dockingController)
            SkinsCommands(skinManager: skinManager)  // NEW
        }
    }
}
```

### 4.3 Preferences Window - Skins Tab

Add a skins picker to the preferences window.
Create: `/Users/hank/dev/src/MacAmp/MacAmpApp/Views/Preferences/SkinsPreferencesView.swift`

```swift
import SwiftUI

struct SkinsPreferencesView: View {
    @EnvironmentObject var skinManager: SkinManager
    @State private var selectedSkinID: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Skin Selection")
                .font(.headline)

            // Error display
            if let error = skinManager.loadingError {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(8)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(6)
            }

            // Skin picker
            VStack(alignment: .leading, spacing: 8) {
                Text("Available Skins:")
                    .font(.subheadline)

                // Bundled skins
                if !skinManager.availableSkins.filter({ $0.source == .bundled }).isEmpty {
                    Text("Bundled")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.leading, 8)

                    ForEach(skinManager.availableSkins.filter { $0.source == .bundled }) { skin in
                        SkinRowView(skin: skin, isSelected: selectedSkinID == skin.id) {
                            selectedSkinID = skin.id
                            skinManager.switchToSkin(skin)
                        }
                    }
                }

                // User skins
                let userSkins = skinManager.availableSkins.filter { $0.source == .user }
                if !userSkins.isEmpty {
                    Divider()
                        .padding(.vertical, 4)

                    Text("My Skins")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.leading, 8)

                    ForEach(userSkins) { skin in
                        SkinRowView(skin: skin, isSelected: selectedSkinID == skin.id) {
                            selectedSkinID = skin.id
                            skinManager.switchToSkin(skin)
                        }
                    }
                }
            }

            Spacer()

            // Action buttons
            HStack {
                Button(action: {
                    skinManager.loadUserSkinFile()
                }) {
                    Label("Load Custom Skin...", systemImage: "folder.badge.plus")
                }

                Spacer()

                Button(action: {
                    NSWorkspace.shared.selectFile(
                        nil,
                        inFileViewerRootedAtPath: AppSettings.userSkinsDirectory.path
                    )
                }) {
                    Label("Show Skins Folder", systemImage: "folder")
                }
            }
        }
        .padding()
        .frame(width: 400, height: 400)
        .onAppear {
            // Set initial selection
            if let currentSkinID = AppSettings.instance().selectedSkinIdentifier {
                selectedSkinID = currentSkinID
            }
        }
    }
}

/// Individual skin row in the picker
struct SkinRowView: View {
    let skin: SkinMetadata
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack {
                // Selection indicator
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .blue : .secondary)

                // Skin icon (placeholder for now)
                Image(systemName: "paintbrush.fill")
                    .foregroundColor(.blue)
                    .frame(width: 24, height: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(skin.name)
                        .font(.body)
                    Text(skin.source == .bundled ? "Built-in" : "Custom")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding(8)
            .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    SkinsPreferencesView()
        .environmentObject(SkinManager())
}
```

### 4.4 Update PreferencesView

Modify the existing preferences view to include a skins tab.
Find and update `/Users/hank/dev/src/MacAmp/MacAmpApp/Views/PreferencesView.swift`:

```swift
import SwiftUI

struct PreferencesView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var skinManager: SkinManager  // Add this

    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            // Existing appearance tab
            AppearancePreferencesView()
                .environmentObject(settings)
                .tabItem {
                    Label("Appearance", systemImage: "paintbrush")
                }
                .tag(0)

            // NEW: Skins tab
            SkinsPreferencesView()
                .environmentObject(skinManager)
                .tabItem {
                    Label("Skins", systemImage: "photo.stack")
                }
                .tag(1)
        }
        .frame(width: 500, height: 450)
    }
}
```

### 4.5 Loading State Improvements

Update `UnifiedDockView.swift` to handle skin switching:

```swift
// In UnifiedDockView.swift, update ensureSkin():

private func ensureSkin() {
    // Only load if no skin is currently loaded
    // SkinManager now handles initialization automatically
    if skinManager.currentSkin == nil && !skinManager.isLoading {
        // SkinManager will load from settings or default in init()
        // This is just a safety check
        NSLog("UnifiedDockView: Skin should have been loaded by SkinManager")
    }
}
```

---

## Section 5: Implementation Steps

### Step 1: Update Data Models (30 minutes)

**File:** `/Users/hank/dev/src/MacAmp/MacAmpApp/Models/Skin.swift`

1. Add `SkinMetadata` struct with id, name, url, source
2. Add `SkinSource` enum (bundled, user, temporary)
3. Add `SkinMetadata.bundledSkins` static property
4. Add `SkinLoadError` enum for error handling

**Validation:**
```swift
// Test in playground or unit test
let metadata = SkinMetadata(
    id: "bundled:Winamp",
    name: "Classic Winamp",
    url: URL(fileURLWithPath: "/path/to/Winamp.wsz"),
    source: .bundled
)
print(metadata.id) // "bundled:Winamp"
```

### Step 2: Update AppSettings (15 minutes)

**File:** `/Users/hank/dev/src/MacAmp/MacAmpApp/Models/AppSettings.swift`

1. Add `selectedSkinIdentifier` computed property
2. Add `userSkinsDirectory` static computed property
3. Ensure directory creation happens automatically

**Validation:**
```bash
# After running app, check directory was created:
ls ~/Library/Application\ Support/MacAmp/Skins/
```

### Step 3: Enhance SkinManager (1 hour)

**File:** `/Users/hank/dev/src/MacAmp/MacAmpApp/ViewModels/SkinManager.swift`

1. Add `@Published var availableSkins: [SkinMetadata]`
2. Add `@Published var loadingError: String?`
3. Add `init()` with `scanAvailableSkins()` and `loadInitialSkin()`
4. Add `scanAvailableSkins()` method
5. Add `loadInitialSkin()` method
6. Add `switchToSkin(identifier:)` method
7. Add `switchToSkin(_:)` convenience method
8. Add `loadUserSkinFile()` method with NSOpenPanel
9. Add `importAndLoadSkin(from:)` private method
10. Update `loadSkin(from:)` to set `loadingError`

**Validation:**
```swift
// After changes, in a test view:
@EnvironmentObject var skinManager: SkinManager

var body: some View {
    List(skinManager.availableSkins) { skin in
        Text(skin.name)
    }
}
// Should show: "Classic Winamp", "Internet Archive"
```

### Step 4: Add Menu Bar Commands (30 minutes)

**New File:** `/Users/hank/dev/src/MacAmp/MacAmpApp/Views/Commands/SkinsCommands.swift`

1. Create `SkinsCommands` struct conforming to `Commands`
2. Add CommandMenu("Skins")
3. Add sections for bundled and user skins
4. Add "Load Custom Skin..." button
5. Add "Show Skins Folder" button
6. Add keyboard shortcuts (Cmd+1 for Winamp, Cmd+2 for Internet Archive)

**File:** `/Users/hank/dev/src/MacAmp/MacAmpApp/MacAmpApp.swift`

7. Import `SkinsCommands` in `.commands` modifier
8. Pass `skinManager` to `SkinsCommands`

**Validation:**
- Run app
- Check "Skins" menu appears in menu bar
- Verify all menu items are present
- Test Cmd+1 and Cmd+2 shortcuts

### Step 5: Create Preferences UI (45 minutes)

**New File:** `/Users/hank/dev/src/MacAmp/MacAmpApp/Views/Preferences/SkinsPreferencesView.swift`

1. Create `SkinsPreferencesView` with skin list
2. Create `SkinRowView` component
3. Add error display area
4. Add action buttons (Load Custom, Show Folder)
5. Implement selection state management

**File:** Update `/Users/hank/dev/src/MacAmp/MacAmpApp/Views/PreferencesView.swift`

6. Add `@EnvironmentObject var skinManager: SkinManager`
7. Add new tab for skins
8. Pass `skinManager` to `SkinsPreferencesView`

**Validation:**
- Open Preferences window
- Check "Skins" tab appears
- Verify skin list shows both bundled skins
- Test clicking different skins
- Verify selection indicator updates

### Step 6: Update UnifiedDockView (10 minutes)

**File:** `/Users/hank/dev/src/MacAmp/MacAmpApp/Views/UnifiedDockView.swift`

1. Simplify `ensureSkin()` method (SkinManager now handles init)
2. Remove hardcoded skin loading logic
3. Trust `SkinManager.init()` to handle initial load

**Validation:**
- Run app
- Verify default skin loads automatically
- Check console logs for "Discovered N skins"

### Step 7: Testing & Polish (30 minutes)

**Testing Checklist:**

1. **Default Behavior:**
   - [ ] Fresh install loads Winamp skin
   - [ ] App remembers last selected skin on restart

2. **Skin Switching:**
   - [ ] Can switch to Internet Archive via menu
   - [ ] Can switch via preferences window
   - [ ] UI updates immediately without lag
   - [ ] All sprites render correctly after switch

3. **Custom Skins:**
   - [ ] "Load Custom Skin..." opens file picker
   - [ ] Can select a .wsz file
   - [ ] Skin copies to ~/Library/Application Support/MacAmp/Skins/
   - [ ] Custom skin appears in "My Skins" section
   - [ ] Custom skin loads correctly

4. **Error Handling:**
   - [ ] Invalid .wsz file shows error message
   - [ ] Missing files fall back to default skin
   - [ ] Error message displays in preferences

5. **Persistence:**
   - [ ] Quit app with Internet Archive skin selected
   - [ ] Relaunch app - should load Internet Archive
   - [ ] Change to Winamp skin
   - [ ] Relaunch app - should load Winamp skin

**Polish Tasks:**
- Add console logging for debugging
- Ensure all errors are user-friendly
- Add loading spinners if needed
- Verify keyboard shortcuts work

---

## Section 6: Testing Plan

### 6.1 Unit Testing

Create `/Users/hank/dev/src/MacAmp/MacAmpTests/SkinManagerTests.swift`:

```swift
import XCTest
@testable import MacAmp

@MainActor
final class SkinManagerTests: XCTestCase {

    func testScanBundledSkins() throws {
        let manager = SkinManager()

        // Should find at least 2 bundled skins
        XCTAssertGreaterThanOrEqual(manager.availableSkins.count, 2)

        // Should have Winamp and Internet Archive
        XCTAssertTrue(manager.availableSkins.contains { $0.id == "bundled:Winamp" })
        XCTAssertTrue(manager.availableSkins.contains { $0.id == "bundled:Internet-Archive" })
    }

    func testSkinMetadata() {
        let metadata = SkinMetadata(
            id: "test:TestSkin",
            name: "Test Skin",
            url: URL(fileURLWithPath: "/test/path.wsz"),
            source: .user
        )

        XCTAssertEqual(metadata.id, "test:TestSkin")
        XCTAssertEqual(metadata.name, "Test Skin")
        XCTAssertEqual(metadata.source, .user)
    }

    func testUserSkinsDirectory() {
        let dir = AppSettings.userSkinsDirectory

        // Should contain "MacAmp/Skins" in path
        XCTAssertTrue(dir.path.contains("MacAmp"))
        XCTAssertTrue(dir.path.contains("Skins"))

        // Directory should exist (created automatically)
        XCTAssertTrue(FileManager.default.fileExists(atPath: dir.path))
    }
}
```

### 6.2 Integration Testing

**Test Case 1: Default Skin Loading**
```
1. Delete UserDefaults for MacAmp (reset state)
2. Launch app
3. Verify: Winamp skin loads (first bundled skin)
4. Verify: No errors displayed
5. Verify: All UI elements render correctly
```

**Test Case 2: Skin Switching via Menu**
```
1. Launch app with Winamp skin
2. Click "Skins" > "Internet Archive"
3. Verify: Skin changes immediately
4. Verify: All sprites update (check buttons, sliders, etc.)
5. Verify: No visual glitches or flashing
6. Quit and relaunch
7. Verify: Internet Archive skin loads automatically
```

**Test Case 3: Custom Skin Import**
```
1. Download a .wsz skin from Winamp Skin Museum
2. Click "Skins" > "Load Custom Skin..."
3. Select the downloaded .wsz file
4. Verify: File appears in ~/Library/Application Support/MacAmp/Skins/
5. Verify: Skin loads successfully
6. Verify: Skin appears in "My Skins" menu section
7. Switch to another skin
8. Switch back to custom skin via menu
9. Verify: Loads correctly from user directory
```

**Test Case 4: Error Handling**
```
1. Create a corrupted .wsz file (empty zip or invalid content)
2. Try to load it via "Load Custom Skin..."
3. Verify: Error message displays
4. Verify: App doesn't crash
5. Verify: Current skin remains loaded
6. Check console for detailed error logs
```

**Test Case 5: Preferences Window**
```
1. Open Preferences > Skins tab
2. Verify: All available skins listed
3. Verify: Current skin has checkmark
4. Click different skin in list
5. Verify: Selection indicator moves
6. Verify: Skin switches in main window
7. Test "Show Skins Folder" button
8. Verify: Finder opens to correct directory
```

### 6.3 Edge Cases

**Edge Case 1: No Bundled Skins**
```
Scenario: Bundled .wsz files missing (corrupted installation)
Expected: App shows error "No skins found. Please reinstall MacAmp."
Test: Temporarily rename Assets/*.wsz files, launch app
```

**Edge Case 2: Duplicate Skin Names**
```
Scenario: User imports skin with same name as bundled skin
Expected: User skin gets unique ID (user:Winamp vs bundled:Winamp)
Test: Try to import a skin named "Winamp.wsz"
```

**Edge Case 3: Corrupted Preferences**
```
Scenario: selectedSkinIdentifier references non-existent skin
Expected: Falls back to default bundled skin
Test: Manually set UserDefaults to "bundled:NonExistent", relaunch
```

**Edge Case 4: Permission Issues**
```
Scenario: User skins directory not writable
Expected: Error message, fall back to bundled skins only
Test: Make ~/Library/Application Support read-only, try to import
```

### 6.4 Performance Testing

**Performance Test 1: Skin Switch Speed**
```
Measure time from menu click to full UI update
Target: < 500ms for typical skin
Test with Internet Archive skin (it's larger)
```

**Performance Test 2: App Launch Time**
```
Measure launch time with 0 user skins vs 20 user skins
Should be negligible difference (metadata only)
Target: < 100ms difference
```

**Performance Test 3: Memory Usage**
```
Monitor memory before and after skin switch
Previous skin should be deallocated
No memory leaks after 10 skin switches
```

### 6.5 UI/UX Testing

**Visual Regression Tests:**
1. Screenshot main window with Winamp skin
2. Switch to Internet Archive
3. Compare sprites (buttons, sliders, numbers)
4. Ensure all elements render at correct positions
5. Check for any clipping or overlap issues

**Accessibility:**
1. Test keyboard navigation in preferences
2. Verify VoiceOver reads skin names correctly
3. Test with reduced motion enabled

---

## Section 7: Future Enhancements

### 7.1 Phase 2 Features (Not in Initial Implementation)

**Skin Preview Thumbnails:**
- Extract MAIN.BMP thumbnail when scanning
- Display in preferences window
- Cache thumbnails in Application Support

**Skin Metadata Files:**
- Support skin.json with author, description, version
- Display in preferences window
- Parse from comments in PLEDIT.TXT

**Online Skin Repository:**
- Browse Winamp Skin Museum skins
- Download directly from app
- Auto-install to user skins directory

**Drag & Drop:**
- Drag .wsz file onto main window to load
- Drag skin from Finder to preferences window

### 7.2 Optimization Ideas

**Lazy Loading:**
- Don't fully parse skins until selected
- Keep only metadata in `availableSkins`
- Parse on-demand when switched

**Caching:**
- Cache parsed skin data to disk
- Skip re-parsing if .wsz file unchanged (check modification date)
- Store in ~/Library/Caches/MacAmp/ParsedSkins/

**Background Scanning:**
- Scan user skins directory on background thread
- Update UI when new skins discovered
- Watch directory for changes

### 7.3 Known Limitations

1. **No Undo:** Switching skins is immediate, no undo
2. **No Favorites:** Can't mark favorite skins for quick access
3. **No Search:** With many skins, can't search by name
4. **No Preview:** Must load skin to see it (Phase 2 addresses this)
5. **Single Directory:** All user skins in one flat directory

---

## Section 8: Code Reference Examples

### Example 1: Full SkinManager with All Features

```swift
import Foundation
import Combine
import ZIPFoundation
import AppKit
import CoreGraphics
import SwiftUI

@MainActor
class SkinManager: ObservableObject {
    // MARK: - Published Properties
    @Published var currentSkin: Skin?
    @Published var availableSkins: [SkinMetadata] = []
    @Published var isLoading: Bool = false
    @Published var loadingError: String? = nil

    // MARK: - Private Properties
    private let settings = AppSettings.instance()

    // MARK: - Initialization
    init() {
        scanAvailableSkins()
        loadInitialSkin()
    }

    // MARK: - Skin Discovery
    private func scanAvailableSkins() {
        var discovered: [SkinMetadata] = []

        // Add bundled skins
        discovered.append(contentsOf: SkinMetadata.bundledSkins)

        // Scan user skins directory
        let userSkinsDir = AppSettings.userSkinsDirectory
        if let userSkinURLs = try? FileManager.default.contentsOfDirectory(
            at: userSkinsDir,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) {
            for url in userSkinURLs where url.pathExtension.lowercased() == "wsz" {
                let filename = url.deletingPathExtension().lastPathComponent
                discovered.append(SkinMetadata(
                    id: "user:\(filename)",
                    name: filename,
                    url: url,
                    source: .user
                ))
            }
        }

        availableSkins = discovered
        NSLog("SkinManager: Discovered \(discovered.count) skins")
    }

    // MARK: - Initial Loading
    private func loadInitialSkin() {
        if let savedIdentifier = settings.selectedSkinIdentifier,
           let skinMeta = availableSkins.first(where: { $0.id == savedIdentifier }) {
            NSLog("Loading saved skin: \(skinMeta.name)")
            loadSkin(from: skinMeta.url)
            return
        }

        if let defaultSkin = availableSkins.first(where: { $0.source == .bundled }) {
            NSLog("Loading default skin: \(defaultSkin.name)")
            loadSkin(from: defaultSkin.url)
        } else {
            NSLog("ERROR - No skins available!")
            loadingError = "No skins found. Please reinstall MacAmp."
        }
    }

    // MARK: - Skin Switching
    func switchToSkin(identifier: String) {
        guard let skinMeta = availableSkins.first(where: { $0.id == identifier }) else {
            NSLog("ERROR - Skin not found: \(identifier)")
            loadingError = "Skin '\(identifier)' not found"
            return
        }

        NSLog("Switching to skin: \(skinMeta.name)")
        loadSkin(from: skinMeta.url)
        settings.selectedSkinIdentifier = identifier
    }

    func switchToSkin(_ metadata: SkinMetadata) {
        switchToSkin(identifier: metadata.id)
    }

    // MARK: - Custom Skin Import
    func loadUserSkinFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.init(filenameExtension: "wsz")!]
        panel.title = "Select Winamp Skin (.wsz)"
        panel.message = "Choose a Winamp skin file to load"

        panel.begin { [weak self] response in
            guard let self = self else { return }

            if response == .OK, let selectedURL = panel.url {
                Task { @MainActor in
                    await self.importAndLoadSkin(from: selectedURL)
                }
            }
        }
    }

    private func importAndLoadSkin(from sourceURL: URL) async {
        let filename = sourceURL.lastPathComponent
        let destinationURL = AppSettings.userSkinsDirectory.appendingPathComponent(filename)

        do {
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)

            NSLog("Imported skin to: \(destinationURL.path)")

            let skinName = sourceURL.deletingPathExtension().lastPathComponent
            let metadata = SkinMetadata(
                id: "user:\(skinName)",
                name: skinName,
                url: destinationURL,
                source: .user
            )

            if !availableSkins.contains(where: { $0.id == metadata.id }) {
                availableSkins.append(metadata)
            }

            switchToSkin(identifier: metadata.id)

        } catch {
            NSLog("ERROR importing skin: \(error)")
            loadingError = "Failed to import skin: \(error.localizedDescription)"
        }
    }

    // MARK: - Existing loadSkin Method (enhanced with error handling)
    func loadSkin(from url: URL) {
        print("Loading skin from \(url.path)")
        isLoading = true
        loadingError = nil

        do {
            let archive = try Archive(url: url, accessMode: .read)

            // ... existing sprite extraction code ...

            let newSkin = Skin(
                visualizerColors: visualizerColors,
                playlistStyle: playlistStyle,
                images: extractedImages,
                cursors: [:]
            )

            self.currentSkin = newSkin
            self.isLoading = false
            self.loadingError = nil
            print("Skin loaded successfully: \(url.lastPathComponent)")

        } catch {
            print("Error loading skin: \(error)")
            isLoading = false
            loadingError = "Failed to load skin: \(error.localizedDescription)"

            if currentSkin == nil {
                if let defaultSkin = availableSkins.first(where: { $0.source == .bundled }) {
                    NSLog("Falling back to default skin")
                    loadSkin(from: defaultSkin.url)
                }
            }
        }
    }

    // ... rest of existing SkinManager code ...
}
```

---

## Section 9: Implementation Checklist

Use this checklist to track implementation progress:

### Data Models
- [ ] Add `SkinMetadata` struct to Skin.swift
- [ ] Add `SkinSource` enum to Skin.swift
- [ ] Add `SkinMetadata.bundledSkins` static property
- [ ] Add `SkinLoadError` enum to SkinManager.swift

### AppSettings
- [ ] Add `selectedSkinIdentifier` computed property
- [ ] Add `userSkinsDirectory` static property
- [ ] Test directory creation on first run

### SkinManager Core
- [ ] Add `availableSkins` published property
- [ ] Add `loadingError` published property
- [ ] Implement `init()` method
- [ ] Implement `scanAvailableSkins()` method
- [ ] Implement `loadInitialSkin()` method
- [ ] Update `loadSkin(from:)` with error handling

### Skin Switching
- [ ] Implement `switchToSkin(identifier:)` method
- [ ] Implement `switchToSkin(_:)` convenience method
- [ ] Add persistence to UserDefaults

### Custom Skin Import
- [ ] Implement `loadUserSkinFile()` method
- [ ] Implement `importAndLoadSkin(from:)` method
- [ ] Handle duplicate filenames
- [ ] Test file picker UI

### Menu Bar
- [ ] Create SkinsCommands.swift
- [ ] Add bundled skins section
- [ ] Add user skins section
- [ ] Add "Load Custom Skin..." menu item
- [ ] Add "Show Skins Folder" menu item
- [ ] Add keyboard shortcuts
- [ ] Integrate into MacAmpApp.swift

### Preferences UI
- [ ] Create SkinsPreferencesView.swift
- [ ] Create SkinRowView component
- [ ] Add error display
- [ ] Add action buttons
- [ ] Implement selection state
- [ ] Add to PreferencesView tabs

### Testing
- [ ] Test default skin loading
- [ ] Test skin switching via menu
- [ ] Test skin switching via preferences
- [ ] Test custom skin import
- [ ] Test persistence (quit & relaunch)
- [ ] Test error handling
- [ ] Test with Internet-Archive.wsz

### Polish
- [ ] Add appropriate logging
- [ ] Verify all error messages are user-friendly
- [ ] Test keyboard navigation
- [ ] Check for memory leaks
- [ ] Verify performance (< 500ms switch time)

---

## Section 10: Success Criteria

The implementation is considered complete when:

1. **Functional Requirements Met:**
   - [x] Users can switch between Winamp and Internet Archive skins
   - [x] Users can load custom .wsz files
   - [x] Skin selection persists across app restarts
   - [x] All UI elements update when skin changes
   - [x] No app restart required for skin switching

2. **User Experience:**
   - [x] Skin switching feels instant (< 500ms)
   - [x] Clear visual feedback during loading
   - [x] Helpful error messages for failures
   - [x] Intuitive menu structure
   - [x] Discoverable preferences UI

3. **Code Quality:**
   - [x] No SwiftUI warnings or errors
   - [x] Proper error handling throughout
   - [x] Clean separation of concerns
   - [x] Consistent with existing codebase style
   - [x] Adequate logging for debugging

4. **Testing:**
   - [x] All test cases pass
   - [x] No memory leaks detected
   - [x] No visual glitches or artifacts
   - [x] Works with both bundled skins
   - [x] Works with at least one external skin

---

## Appendix A: File Structure

After implementation, the file structure will be:

```
MacAmpApp/
├── Models/
│   ├── Skin.swift                    (MODIFIED - add SkinMetadata, SkinSource)
│   ├── SkinSprites.swift             (UNCHANGED)
│   ├── AppSettings.swift             (MODIFIED - add skin preferences)
│   └── ...
├── ViewModels/
│   └── SkinManager.swift             (MODIFIED - add multi-skin support)
├── Views/
│   ├── Commands/
│   │   └── SkinsCommands.swift       (NEW - menu bar integration)
│   ├── Preferences/
│   │   ├── PreferencesView.swift     (MODIFIED - add skins tab)
│   │   └── SkinsPreferencesView.swift (NEW - skin picker UI)
│   ├── UnifiedDockView.swift         (MODIFIED - simplify ensureSkin)
│   └── ...
├── Assets/
│   ├── Winamp.wsz                    (EXISTING)
│   └── Internet-Archive.wsz          (EXISTING)
└── MacAmpApp.swift                   (MODIFIED - add SkinsCommands)

~/Library/Application Support/MacAmp/
└── Skins/                            (CREATED at runtime)
    └── (user-imported .wsz files)
```

---

## Appendix B: UserDefaults Keys

```swift
// Key for selected skin identifier
"SelectedSkinIdentifier" -> String?
// Examples: "bundled:Winamp", "bundled:Internet-Archive", "user:MySkin"

// Existing keys (from AppSettings)
"MaterialIntegration" -> String
"EnableLiquidGlass" -> Bool
```

---

## Appendix C: Console Logging Examples

For debugging, expect these console logs:

```
SkinManager: Discovered 2 skins
Loading default skin: Classic Winamp
Loading skin from /Applications/MacAmp.app/Contents/Resources/Winamp.wsz
✅ FOUND SHEET: MAIN -> MAIN.BMP (15234 bytes)
...
Skin loaded successfully: Winamp.wsz

// User switches to Internet Archive
Switching to skin: Internet Archive
Loading skin from /Applications/MacAmp.app/Contents/Resources/Internet-Archive.wsz
✅ FOUND SHEET: MAIN -> MAIN.BMP (18456 bytes)
...
Skin loaded successfully: Internet-Archive.wsz

// User imports custom skin
Imported skin to: ~/Library/Application Support/MacAmp/Skins/CustomSkin.wsz
Switching to skin: CustomSkin
```

---

## Appendix D: Troubleshooting Guide

### Problem: Skins menu doesn't appear
**Solution:** Verify `SkinsCommands` is added in `.commands` modifier in MacAmpApp.swift

### Problem: Preferences window doesn't show Skins tab
**Solution:** Ensure `skinManager` is passed as `@EnvironmentObject` to `PreferencesView`

### Problem: Custom skin doesn't load
**Solution:** Check console for error messages. Verify .wsz file is valid Winamp skin format.

### Problem: App crashes when switching skins
**Solution:** Ensure all sprite names in views match what's in the skin. Add nil-coalescing operators.

### Problem: Skin doesn't persist after relaunch
**Solution:** Verify `selectedSkinIdentifier` is being saved to UserDefaults in `switchToSkin()`

---

## End of Plan

**Total Estimated Implementation Time:** 4-5 hours

**Dependencies:**
- ZIPFoundation (already integrated)
- AppKit (for NSOpenPanel, NSImage)
- SwiftUI (all UI components)

**Risk Level:** Low - extends existing architecture without breaking changes

**Ready for Implementation:** Yes
