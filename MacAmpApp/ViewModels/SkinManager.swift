import Foundation
import Combine
import ZIPFoundation
import AppKit
import CoreGraphics // For CGRect
import SwiftUI
import UserNotifications

// This class is responsible for loading and parsing Winamp skins.
// It will be an ObservableObject so that our SwiftUI views can
// react when a new skin is loaded.
@MainActor
class SkinManager: ObservableObject {

    @Published var currentSkin: Skin?
    @Published var isLoading: Bool = false
    @Published var availableSkins: [SkinMetadata] = []
    @Published var loadingError: String? = nil

    nonisolated init() {
        // Scan will happen on first access since we're @MainActor
    }

    // MARK: - Skin Discovery

    /// Scans for all available skins (bundled + user directory)
    func scanAvailableSkins() {
        var skins: [SkinMetadata] = []

        // Add bundled skins
        skins.append(contentsOf: SkinMetadata.bundledSkins)

        // Scan user skins directory
        let userSkinsDir = AppSettings.userSkinsDirectory
        if let userSkinFiles = try? FileManager.default.contentsOfDirectory(
            at: userSkinsDir,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) {
            for fileURL in userSkinFiles where fileURL.pathExtension.lowercased() == "wsz" {
                let skinName = fileURL.deletingPathExtension().lastPathComponent
                let skinID = "user:\(skinName)"
                skins.append(SkinMetadata(
                    id: skinID,
                    name: skinName,
                    url: fileURL,
                    source: .user
                ))
            }
        }

        self.availableSkins = skins
        NSLog("📦 SkinManager: Discovered \(skins.count) skins")
        for skin in skins {
            NSLog("   - \(skin.id): \(skin.name) (\(skin.source))")
        }
    }

    // MARK: - Skin Switching

    /// Switch to a different skin by identifier
    func switchToSkin(identifier: String) {
        guard let skinMetadata = availableSkins.first(where: { $0.id == identifier }) else {
            loadingError = "Skin not found: \(identifier)"
            NSLog("❌ SkinManager: Skin not found: \(identifier)")
            return
        }

        NSLog("🎨 SkinManager: Switching to skin: \(skinMetadata.name)")
        loadSkin(from: skinMetadata.url)

        // Save selection to UserDefaults
        AppSettings.instance().selectedSkinIdentifier = identifier
    }

    /// Load the initial skin (from UserDefaults or default to "bundled:Winamp")
    func loadInitialSkin() {
        // First, discover all available skins
        scanAvailableSkins()

        let selectedID = AppSettings.instance().selectedSkinIdentifier ?? "bundled:Winamp"
        NSLog("🔄 SkinManager: Loading initial skin: \(selectedID)")
        switchToSkin(identifier: selectedID)
    }

    // MARK: - Skin Import

    /// Import a skin from an external URL (copies to user skins directory)
    func importSkin(from sourceURL: URL) async {
        let fileManager = FileManager.default
        let skinName = sourceURL.deletingPathExtension().lastPathComponent
        let destinationURL = AppSettings.userSkinsDirectory.appendingPathComponent(sourceURL.lastPathComponent)

        do {
            // Check if file already exists
            if fileManager.fileExists(atPath: destinationURL.path) {
                // Show alert and ask to replace
                let alert = NSAlert()
                alert.messageText = "Skin Already Exists"
                alert.informativeText = "A skin named \"\(skinName)\" already exists. Do you want to replace it?"
                alert.alertStyle = .warning
                alert.addButton(withTitle: "Replace")
                alert.addButton(withTitle: "Cancel")

                let response = await alert.beginSheetModal(for: NSApp.keyWindow ?? NSApp.windows.first!)
                if response == .alertSecondButtonReturn {
                    return // User cancelled
                }

                // Remove existing file
                try fileManager.removeItem(at: destinationURL)
            }

            // Copy the file
            try fileManager.copyItem(at: sourceURL, to: destinationURL)
            NSLog("✅ Imported skin: \(skinName) to \(destinationURL.path)")

            // Refresh available skins
            scanAvailableSkins()

            // Switch to the newly imported skin
            let newSkinID = "user:\(skinName)"
            switchToSkin(identifier: newSkinID)

            // Show success notification
            showNotification(title: "Skin Imported", message: "\(skinName) has been imported successfully.")

        } catch {
            NSLog("❌ Failed to import skin: \(error.localizedDescription)")
            loadingError = "Failed to import skin: \(error.localizedDescription)"

            // Show error alert
            let alert = NSAlert()
            alert.messageText = "Import Failed"
            alert.informativeText = "Could not import \"\(skinName)\": \(error.localizedDescription)"
            alert.alertStyle = .critical
            alert.addButton(withTitle: "OK")
            await alert.beginSheetModal(for: NSApp.keyWindow ?? NSApp.windows.first!)
        }
    }

    /// Show a system notification using modern UserNotifications framework
    /// Falls back to NSAlert if bundle identifier is not configured (Xcode debug builds)
    private func showNotification(title: String, message: String) {
        // Check if bundle identifier exists before using UNUserNotificationCenter
        // UNUserNotificationCenter requires a valid bundle identifier and crashes if nil
        guard Bundle.main.bundleIdentifier != nil else {
            NSLog("⚠️ Bundle identifier is nil, falling back to NSAlert for notification")
            showNotificationAlert(title: title, message: message)
            return
        }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = message
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil // Deliver immediately
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                NSLog("❌ Failed to show notification: \(error.localizedDescription)")
                // Fall back to alert on error
                Task { @MainActor in
                    self.showNotificationAlert(title: title, message: message)
                }
            }
        }
    }

    /// Fallback notification method using NSAlert when UNUserNotificationCenter is unavailable
    private func showNotificationAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")

        // Show as floating alert without blocking
        if let window = NSApp.keyWindow ?? NSApp.windows.first {
            alert.beginSheetModal(for: window) { _ in }
        } else {
            alert.runModal()
        }
    }

    // MARK: - Fallback Sprite Generation

    /// Create a transparent fallback image for a missing sprite
    /// - Parameter spriteName: Name of the missing sprite
    /// - Returns: A transparent NSImage with appropriate dimensions, or a default size if dimensions unknown
    private func createFallbackSprite(named spriteName: String) -> NSImage {
        // Try to get dimensions from sprite definitions
        let size: CGSize
        if let definedSize = SkinSprites.defaultSprites.dimensions(forSprite: spriteName) {
            size = definedSize
            NSLog("⚠️ Creating fallback for '\(spriteName)' with defined size: \(definedSize.width)x\(definedSize.height)")
        } else {
            // Use a reasonable default size for unknown sprites
            size = CGSize(width: 16, height: 16)
            NSLog("⚠️ Creating fallback for '\(spriteName)' with default size: 16x16 (no definition found)")
        }

        // Create a transparent image
        let image = NSImage(size: size)
        image.lockFocus()

        // Fill with transparent color
        NSColor.clear.setFill()
        NSRect(origin: .zero, size: size).fill()

        image.unlockFocus()

        return image
    }

    /// Generate fallback sprites for all missing sprites from a sheet
    /// - Parameters:
    ///   - sheetName: Name of the missing sheet
    ///   - sprites: Array of sprite definitions that should have been in the sheet
    /// - Returns: Dictionary mapping sprite names to fallback images
    private func createFallbackSprites(forSheet sheetName: String, sprites: [Sprite]) -> [String: NSImage] {
        var fallbacks: [String: NSImage] = [:]

        NSLog("⚠️ Sheet '\(sheetName)' is missing - generating \(sprites.count) fallback sprites")

        for sprite in sprites {
            let fallbackImage = createFallbackSprite(named: sprite.name)
            fallbacks[sprite.name] = fallbackImage
        }

        return fallbacks
    }

    // MARK: - Existing Methods

    // Try to find an entry for a given sheet name (case-insensitive), supporting .bmp and .png
    private func findSheetEntry(in archive: Archive, baseName: String) -> Entry? {
        let lowerBase = baseName.lowercased()
        var lastMatch: Entry?
        NSLog("  findSheetEntry: Looking for \(baseName) (lowercased: \(lowerBase))")
        for entry in archive {
            let lowerPath = entry.path.lowercased()
            let afterSlash = lowerPath.components(separatedBy: "/").last ?? lowerPath
            let file = afterSlash.components(separatedBy: "\\").last ?? afterSlash
            if file == "\(lowerBase).bmp" || file == "\(lowerBase).png" {
                NSLog("  ✅ FOUND MATCH: \(entry.path) for \(baseName)")
                lastMatch = entry
            }
        }
        if lastMatch == nil {
            NSLog("  ❌ NO MATCH FOUND for \(baseName)")
        }
        return lastMatch
    }

    // Find a case-insensitive text entry (e.g., PLEDIT.TXT)
    private func findTextEntry(in archive: Archive, fileName: String) -> Entry? {
        let lowerTarget = fileName.lowercased()
        var lastMatch: Entry?
        for entry in archive {
            let lowerPath = entry.path.lowercased()
            let afterSlash = lowerPath.components(separatedBy: "/").last ?? lowerPath
            let file = afterSlash.components(separatedBy: "\\").last ?? afterSlash
            if file == lowerTarget {
                lastMatch = entry
            }
        }
        return lastMatch
    }

    func loadSkin(from url: URL) {
        print("Loading skin from \(url.path)")
        isLoading = true

        do {
            let archive = try Archive(url: url, accessMode: .read)

            // 1. Extract and slice images per sheet
            var extractedImages: [String: NSImage] = [:]
            
            // DEBUG: List all available files in the archive
            NSLog("=== SPRITE DEBUG: Archive Contents ===")
            for entry in archive {
                NSLog("  Available file: \(entry.path)")
            }
            NSLog("========================================")
            
            // First, build the list of available sheets including optional ones
            var sheetsToProcess = SkinSprites.defaultSprites.sheets
            
            // Add NUMS_EX sprites if the file exists in the archive
            if findSheetEntry(in: archive, baseName: "NUMS_EX") != nil {
                sheetsToProcess["NUMS_EX"] = [
                    Sprite(name: "NO_MINUS_SIGN_EX", x: 90, y: 0, width: 9, height: 13),
                    Sprite(name: "MINUS_SIGN_EX", x: 99, y: 0, width: 9, height: 13),
                    Sprite(name: "DIGIT_0_EX", x: 0, y: 0, width: 9, height: 13),
                    Sprite(name: "DIGIT_1_EX", x: 9, y: 0, width: 9, height: 13),
                    Sprite(name: "DIGIT_2_EX", x: 18, y: 0, width: 9, height: 13),
                    Sprite(name: "DIGIT_3_EX", x: 27, y: 0, width: 9, height: 13),
                    Sprite(name: "DIGIT_4_EX", x: 36, y: 0, width: 9, height: 13),
                    Sprite(name: "DIGIT_5_EX", x: 45, y: 0, width: 9, height: 13),
                    Sprite(name: "DIGIT_6_EX", x: 54, y: 0, width: 9, height: 13),
                    Sprite(name: "DIGIT_7_EX", x: 63, y: 0, width: 9, height: 13),
                    Sprite(name: "DIGIT_8_EX", x: 72, y: 0, width: 9, height: 13),
                    Sprite(name: "DIGIT_9_EX", x: 81, y: 0, width: 9, height: 13),
                ]
                NSLog("✅ OPTIONAL: Found NUMS_EX.BMP - adding extended digit sprites")
            } else {
                NSLog("ℹ️ INFO: NUMS_EX.BMP not found (normal for many skins)")
            }
            
            NSLog("=== PROCESSING \(sheetsToProcess.count) SHEETS ===")
            for (sheetName, sprites) in sheetsToProcess {
                NSLog("🔍 Looking for sheet: \(sheetName)")
                guard let entry = findSheetEntry(in: archive, baseName: sheetName) else {
                    NSLog("⚠️ MISSING SHEET: \(sheetName).bmp/.png not found in archive")
                    NSLog("   Expected \(sprites.count) sprites from this sheet")
                    // List the missing sprite names for debugging
                    for sprite in sprites.prefix(5) {
                        NSLog("   - Missing sprite: \(sprite.name)")
                    }

                    // Generate fallback sprites for this missing sheet
                    let fallbackSprites = createFallbackSprites(forSheet: sheetName, sprites: sprites)
                    for (name, image) in fallbackSprites {
                        extractedImages[name] = image
                    }

                    continue
                }
                var data = Data()
                _ = try archive.extract(entry, consumer: { data.append($0) })
                guard let sheetImage = NSImage(data: data) else {
                    NSLog("❌ FAILED to create image for sheet: \(sheetName)")
                    // Generate fallbacks for this corrupted sheet
                    let fallbackSprites = createFallbackSprites(forSheet: sheetName, sprites: sprites)
                    for (name, image) in fallbackSprites {
                        extractedImages[name] = image
                    }
                    continue
                }
                
                print("✅ FOUND SHEET: \(sheetName) -> \(entry.path) (\(data.count) bytes)")
                print("   Sheet size: \(sheetImage.size.width)x\(sheetImage.size.height)")
                print("   Extracting \(sprites.count) sprites:")

                for sprite in sprites {
                    // The sprites are defined with top-left origin, same as NSImage
                    // No coordinate correction needed - use rect directly
                    let r = sprite.rect
                    if let croppedImage = sheetImage.cropped(to: r) {
                        extractedImages[sprite.name] = croppedImage
                        print("     ✅ \(sprite.name) at \(sprite.rect)")
                    } else {
                        NSLog("     ⚠️ FAILED to crop \(sprite.name) from \(sheetName) at \(sprite.rect)")
                        NSLog("       Sheet size: \(sheetImage.size)")
                        NSLog("       Requested rect: \(r)")
                        NSLog("       Rect within bounds: \(r.maxX <= sheetImage.size.width && r.maxY <= sheetImage.size.height)")

                        // Generate a fallback sprite for this failed crop
                        let fallbackImage = createFallbackSprite(named: sprite.name)
                        extractedImages[sprite.name] = fallbackImage
                        NSLog("       Generated fallback sprite for '\(sprite.name)'")
                    }
                }
            }

            // MARK: - Smart Sprite Aliasing
            // Create aliases for sprite variants to ensure view compatibility
            // Different skins use different naming conventions (_EX variants, _SELECTED only, etc.)

            var aliasCount = 0

            // NUMBERS → NUMS_EX aliasing
            // If NUMS_EX exists but NUMBERS doesn't, create aliases so views work without modification
            if extractedImages["DIGIT_0"] == nil && extractedImages["DIGIT_0_EX"] != nil {
                NSLog("🔄 Creating sprite aliases: NUMS_EX → NUMBERS (for view compatibility)")
                for i in 0...9 {
                    if extractedImages["DIGIT_\(i)"] == nil, let exDigit = extractedImages["DIGIT_\(i)_EX"] {
                        extractedImages["DIGIT_\(i)"] = exDigit
                        aliasCount += 1
                    }
                }
                if extractedImages["MINUS_SIGN"] == nil, let exMinus = extractedImages["MINUS_SIGN_EX"] {
                    extractedImages["MINUS_SIGN"] = exMinus
                    aliasCount += 1
                }
                if extractedImages["NO_MINUS_SIGN"] == nil, let exNoMinus = extractedImages["NO_MINUS_SIGN_EX"] {
                    extractedImages["NO_MINUS_SIGN"] = exNoMinus
                    aliasCount += 1
                }
                NSLog("✅ Created \(aliasCount) digit sprite aliases")
                aliasCount = 0
            }

            // VOLUME THUMB aliasing
            // Use SELECTED variant as fallback for normal state
            if extractedImages["MAIN_VOLUME_THUMB"] == nil, let selected = extractedImages["MAIN_VOLUME_THUMB_SELECTED"] {
                NSLog("🔄 Creating alias: MAIN_VOLUME_THUMB_SELECTED → MAIN_VOLUME_THUMB")
                extractedImages["MAIN_VOLUME_THUMB"] = selected
                aliasCount += 1
            }

            // BALANCE THUMB aliasing
            if extractedImages["MAIN_BALANCE_THUMB"] == nil, let selected = extractedImages["MAIN_BALANCE_THUMB_ACTIVE"] {
                NSLog("🔄 Creating alias: MAIN_BALANCE_THUMB_ACTIVE → MAIN_BALANCE_THUMB")
                extractedImages["MAIN_BALANCE_THUMB"] = selected
                aliasCount += 1
            }

            // EQ SLIDER THUMB aliasing
            if extractedImages["EQ_SLIDER_THUMB"] == nil, let selected = extractedImages["EQ_SLIDER_THUMB_SELECTED"] {
                NSLog("🔄 Creating alias: EQ_SLIDER_THUMB_SELECTED → EQ_SLIDER_THUMB")
                extractedImages["EQ_SLIDER_THUMB"] = selected
                aliasCount += 1
            }

            if aliasCount > 0 {
                NSLog("✅ Created \(aliasCount) slider sprite aliases")
            }

            let expectedCount = sheetsToProcess.values.flatMap{$0}.count
            let extractedCount = extractedImages.count
            NSLog("=== SPRITE EXTRACTION SUMMARY ===")
            NSLog("Total sprites available: \(extractedCount)")
            NSLog("Expected sprites: \(expectedCount)")
            if extractedCount < expectedCount {
                NSLog("⚠️ Note: Some sprites are using transparent fallbacks due to missing/corrupted sheets")
            } else {
                NSLog("✅ All sprites loaded successfully!")
            }
            
            // List all extracted sprite names for debugging
            let sortedNames = extractedImages.keys.sorted()
            print("Extracted sprite names:")
            for name in sortedNames {
                print("  - \(name)")
            }
            print("==================================")

            // 2. Parse PLEDIT.TXT if present
            var playlistStyle: PlaylistStyle = PlaylistStyle(
                normalTextColor: .white,
                currentTextColor: .white,
                backgroundColor: .black,
                selectedBackgroundColor: Color(red: 0, green: 0, blue: 0.776),
                fontName: nil
            )
            if let pleditEntry = findTextEntry(in: archive, fileName: "pledit.txt") {
                var pleditData = Data()
                _ = try archive.extract(pleditEntry, consumer: { pleditData.append($0) })
                if let parsed = PLEditParser.parse(from: pleditData) {
                    playlistStyle = parsed
                }
            }

            // 2b. Parse VISCOLOR.TXT if present
            var visualizerColors: [Color] = []
            if let visEntry = findTextEntry(in: archive, fileName: "viscolor.txt") {
                var visData = Data()
                _ = try archive.extract(visEntry, consumer: { visData.append($0) })
                if let colors = VisColorParser.parse(from: visData) {
                    visualizerColors = colors
                }
            }

            // 3. Create the Skin object
            let newSkin = Skin(
                visualizerColors: visualizerColors,
                playlistStyle: playlistStyle,
                images: extractedImages,
                cursors: [:] // TODO: Parse cursors
            )

            // Set the skin immediately - this is synchronous
            self.currentSkin = newSkin
            self.isLoading = false
            print("Skin loaded and set to currentSkin.")

        } catch {
            print("Error loading skin: \(error)")
            if let data = try? Data(contentsOf: url) {
                print("Skin bytes: \(data.count)")
            }
            isLoading = false
        }
    }
}
