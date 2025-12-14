import Foundation
import Combine
import ZIPFoundation
import AppKit
import CoreGraphics // For CGRect
import SwiftUI
import UserNotifications
import Observation

private struct SkinArchivePayload {
    let sheets: [String: Data]
    let pledit: Data?
    let viscolor: Data?
}

private enum SkinArchiveLoader {
    static func load(from url: URL, expectedSheets: Set<String>) throws -> SkinArchivePayload {
        let archive = try Archive(url: url, accessMode: .read)

        var sheetData: [String: Data] = [:]
        var pleditData: Data?
        var viscolorData: Data?

        for entry in archive {
            let normalizedName = normalize(entry.path)

            if normalizedName == "pledit.txt" {
                pleditData = try extract(entry: entry, from: archive)
                continue
            }

            if normalizedName == "viscolor.txt" {
                viscolorData = try extract(entry: entry, from: archive)
                continue
            }

            guard let baseName = sheetBaseName(from: normalizedName) else { continue }
            if !expectedSheets.contains(baseName) { continue }
            sheetData[baseName] = try extract(entry: entry, from: archive)
        }

        return SkinArchivePayload(
            sheets: sheetData,
            pledit: pleditData,
            viscolor: viscolorData
        )
    }

    private static func extract(entry: Entry, from archive: Archive) throws -> Data {
        var data = Data(capacity: Int(entry.uncompressedSize))
        _ = try archive.extract(entry) { chunk in
            data.append(chunk)
        }
        return data
    }

    private static func normalize(_ path: String) -> String {
        let lower = path.lowercased()
        if let lastSlash = lower.split(separator: "/").last {
            return String(lastSlash.split(separator: "\\").last ?? lastSlash)
        }
        return lower
    }

    private static func sheetBaseName(from fileName: String) -> String? {
        if fileName.hasSuffix(".bmp") {
            return String(fileName.dropLast(4))
        }
        if fileName.hasSuffix(".png") {
            return String(fileName.dropLast(4))
        }
        return nil
    }
}

private enum SkinImportError: LocalizedError {
    case unsupportedExtension(String)
    case remoteURL
    case oversizedFile
    case directoryCreationFailed(String)
    case copyFailed(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedExtension(let ext):
            return "Unsupported skin file type: .\(ext). Please import a .wsz or .zip file."
        case .remoteURL:
            return "Only local skin files can be imported."
        case .oversizedFile:
            return "Skin file is larger than the 50 MB limit."
        case .directoryCreationFailed(let message):
            return "Unable to access the skins directory: \(message)"
        case .copyFailed(let message):
            return "Failed to copy skin: \(message)"
        }
    }
}

// This class is responsible for loading and parsing Winamp skins.
// It will be an ObservableObject so that our SwiftUI views can
// react when a new skin is loaded.
@Observable
@MainActor
final class SkinManager {

    var currentSkin: Skin?
    var isLoading: Bool = false
    var availableSkins: [SkinMetadata] = []
    var loadingError: String? = nil

    // Default skin (Winamp.wsz) - loaded once, used as fallback for missing sprites
    @ObservationIgnored private var defaultSkin: Skin?

    init() {
        // Scan will happen on first access since we're @MainActor
    }

    /// Load default Winamp skin for fallback sprites
    /// MUST run synchronously before loading other skins
    private func loadDefaultSkinIfNeeded() {
        AppLog.debug(.skin, "loadDefaultSkinIfNeeded() called")

        guard defaultSkin == nil else {
            AppLog.debug(.skin, "Default skin already loaded")
            return
        }

        AppLog.debug(.skin, "Looking for bundled Winamp skin for default fallback...")
        AppLog.debug(.skin, "SkinMetadata.bundledSkins count: \(SkinMetadata.bundledSkins.count)")

        // Find bundled Winamp.wsz
        guard let winampSkin = SkinMetadata.bundledSkins.first(where: { $0.id == "bundled:Winamp" }) else {
            AppLog.warn(.skin, "Default Winamp skin not found in bundle - no fallback available. Available: \(SkinMetadata.bundledSkins.map { $0.id })")
            return
        }

        AppLog.debug(.skin, "Loading default skin (Winamp.wsz) for fallback sprites from: \(winampSkin.url.path)")

        do {
            let expectedSheets = Set(SkinSprites.defaultSprites.sheets.keys.map { $0.lowercased() })
            let payload = try SkinArchiveLoader.load(from: winampSkin.url, expectedSheets: expectedSheets)

            AppLog.debug(.skin, "Default skin archive loaded, parsing sprites...")

            // Parse default skin sprites using same pipeline
            let skin = try parseDefaultSkin(payload: payload, sourceURL: winampSkin.url)
            defaultSkin = skin

            AppLog.info(.skin, "Default skin loaded successfully! Sheets: \(skin.loadedSheets.sorted().joined(separator: ", ")), VIDEO sprites: \(skin.images.keys.filter { $0.hasPrefix("VIDEO_") }.count)")
        } catch {
            AppLog.error(.skin, "Failed to load default skin: \(error)")
        }
    }

    /// Parse default skin payload (simplified version of applySkinPayload)
    private func parseDefaultSkin(payload: SkinArchivePayload, sourceURL: URL) throws -> Skin {
        var extractedImages: [String: NSImage] = [:]
        var loadedSheets: Set<String> = []
        let sheetsToProcess = SkinSprites.defaultSprites.sheets

        for (sheetName, sprites) in sheetsToProcess {
            guard let data = payload.sheets[sheetName.lowercased()],
                  let sheetImage = NSImage(data: data) else {
                continue  // Skip missing sheets in default skin
            }

            loadedSheets.insert(sheetName)

            for sprite in sprites {
                if let croppedImage = sheetImage.cropped(to: sprite.rect) {
                    extractedImages[sprite.name] = croppedImage
                }
            }
        }

        // Parse PLEDIT for playlist style
        let playlistStyle: PlaylistStyle
        if let pleditData = payload.pledit, let parsed = PLEditParser.parse(from: pleditData) {
            playlistStyle = parsed
        } else {
            // Default Winamp classic playlist colors
            playlistStyle = PlaylistStyle(
                normalTextColor: Color.green,
                currentTextColor: Color.white,
                backgroundColor: Color.black,
                selectedBackgroundColor: Color.blue,
                fontName: nil
            )
        }

        // Parse visualizer colors
        let visualizerColors: [Color]
        if let visData = payload.viscolor, let colors = VisColorParser.parse(from: visData) {
            visualizerColors = colors
        } else {
            // Default visualizer colors (24 colors)
            visualizerColors = (0..<24).map { _ in Color.green }
        }

        return Skin(
            visualizerColors: visualizerColors,
            playlistStyle: playlistStyle,
            images: extractedImages,
            cursors: [:],
            loadedSheets: loadedSheets
        )
    }

    @ObservationIgnored private var loadGeneration = UUID()
    private static let allowedSkinExtensions: Set<String> = ["wsz", "zip"]
    private static let maxImportSizeBytes = 50 * 1024 * 1024

    // MARK: - Skin Discovery

    /// Scans for all available skins (bundled + user directory)
    func scanAvailableSkins() {
        var skins: [SkinMetadata] = []

        // Add bundled skins
        let bundled = SkinMetadata.bundledSkins
        skins.append(contentsOf: bundled)

        // Create set of bundled filenames to avoid duplicates
        let bundledFilenames = Set(bundled.map { $0.url.deletingPathExtension().lastPathComponent })

        // Scan user skins directory
        do {
            let userSkinsDir = try AppSettings.userSkinsDirectory()
            let userSkinFiles = try FileManager.default.contentsOfDirectory(
                at: userSkinsDir,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )
            for fileURL in userSkinFiles where fileURL.pathExtension.lowercased() == "wsz" {
                let skinFilename = fileURL.deletingPathExtension().lastPathComponent

                // Skip if this skin is already bundled (avoid duplicates)
                if bundledFilenames.contains(skinFilename) {
                    AppLog.debug(.skin, "Skipping duplicate: \(skinFilename) (already bundled)")
                    continue
                }

                let skinID = "user:\(skinFilename)"
                skins.append(SkinMetadata(
                    id: skinID,
                    name: skinFilename,
                    url: fileURL,
                    source: .user
                ))
            }
        } catch {
            AppLog.error(.skin, "Failed to access user skins directory: \(error.localizedDescription)")
            if loadingError == nil {
                loadingError = "Unable to access user skins directory: \(error.localizedDescription)"
            }
        }

        self.availableSkins = skins
        AppLog.info(.skin, "Discovered \(skins.count) skins")
        for skin in skins {
            AppLog.debug(.skin, "  - \(skin.id): \(skin.name) (\(skin.source))")
        }
    }

    // MARK: - Skin Switching

    /// Switch to a different skin by identifier
    func switchToSkin(identifier: String) {
        guard let skinMetadata = availableSkins.first(where: { $0.id == identifier }) else {
            loadingError = "Skin not found: \(identifier)"
            AppLog.error(.skin, "Skin not found: \(identifier)")
            return
        }

        AppLog.info(.skin, "Switching to skin: \(skinMetadata.name)")
        loadingError = nil
        loadSkin(from: skinMetadata.url)

        // Save selection to UserDefaults
        AppSettings.instance().selectedSkinIdentifier = identifier
    }

    /// Load the initial skin (from UserDefaults or default to "bundled:Winamp")
    func loadInitialSkin() {
        // First, load default skin for fallback sprites (all BMPs)
        loadDefaultSkinIfNeeded()

        // Then discover all available skins
        scanAvailableSkins()

        let selectedID = AppSettings.instance().selectedSkinIdentifier ?? "bundled:Winamp"
        AppLog.info(.skin, "Loading initial skin: \(selectedID)")
        switchToSkin(identifier: selectedID)
    }

    // MARK: - Skin Import

    /// Import a skin from an external URL (copies to user skins directory)
    func importSkin(from sourceURL: URL) async {
        let fileManager = FileManager.default
        let fallbackName = sourceURL.deletingPathExtension().lastPathComponent

        do {
            let validatedSource = try validateImportURL(sourceURL)
            let skinName = validatedSource.deletingPathExtension().lastPathComponent
            let destinationDirectory: URL
            do {
                destinationDirectory = try AppSettings.userSkinsDirectory()
            } catch {
                throw SkinImportError.directoryCreationFailed(error.localizedDescription)
            }
            let destinationURL = destinationDirectory.appendingPathComponent(validatedSource.lastPathComponent)
            try ensureDestination(destinationURL, isWithin: destinationDirectory)

            if fileManager.fileExists(atPath: destinationURL.path) {
                let response = await presentReplacementPrompt(for: skinName)
                if response == .alertSecondButtonReturn {
                    return
                }
                try fileManager.removeItem(at: destinationURL)
            }

            do {
                try fileManager.copyItem(at: validatedSource, to: destinationURL)
            } catch {
                throw SkinImportError.copyFailed(error.localizedDescription)
            }

            AppLog.info(.skin, "Imported skin: \(skinName) to \(destinationURL.path)")
            loadingError = nil

            scanAvailableSkins()
            let newSkinID = "user:\(skinName)"
            switchToSkin(identifier: newSkinID)
            showNotification(title: "Skin Imported", message: "\(skinName) has been imported successfully.")
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            AppLog.error(.skin, "Failed to import skin: \(message)")
            loadingError = message
            await presentImportFailureAlert(for: fallbackName, message: message)
        }
    }

    private func validateImportURL(_ url: URL) throws -> URL {
        guard url.isFileURL else { throw SkinImportError.remoteURL }
        let standardized = url.standardizedFileURL
        let ext = standardized.pathExtension.lowercased()
        guard Self.allowedSkinExtensions.contains(ext) else {
            throw SkinImportError.unsupportedExtension(ext.isEmpty ? "unknown" : ext)
        }

        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: standardized.path)
            if let fileSize = attributes[.size] as? NSNumber,
               fileSize.intValue > Self.maxImportSizeBytes {
                throw SkinImportError.oversizedFile
            }
        } catch {
            throw SkinImportError.copyFailed(error.localizedDescription)
        }

        return standardized
    }

    private func ensureDestination(_ destination: URL, isWithin base: URL) throws {
        let resolvedDestination = destination.standardizedFileURL
        let resolvedBase = base.standardizedFileURL
        guard resolvedDestination.path.hasPrefix(resolvedBase.path) else {
            throw SkinImportError.copyFailed("Resolved path escapes user skins directory.")
        }
    }

    private func presentReplacementPrompt(for skinName: String) async -> NSApplication.ModalResponse {
        let alert = NSAlert()
        alert.messageText = "Skin Already Exists"
        alert.informativeText = "A skin named \"\(skinName)\" already exists. Do you want to replace it?"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Replace")
        alert.addButton(withTitle: "Cancel")

        if let window = NSApp.keyWindow ?? NSApp.windows.first {
            return await alert.beginSheetModal(for: window)
        } else {
            return alert.runModal()
        }
    }

    private func presentImportFailureAlert(for skinName: String, message: String) async {
        let alertMessage = "Could not import \"\(skinName)\": \(message)"
        _ = await presentAlert(
            title: "Import Failed",
            message: alertMessage,
            style: .critical
        )
    }

    @discardableResult
    private func presentAlert(title: String, message: String, style: NSAlert.Style) async -> NSApplication.ModalResponse {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = style
        alert.addButton(withTitle: "OK")

        if let window = NSApp.keyWindow ?? NSApp.windows.first {
            return await alert.beginSheetModal(for: window)
        } else {
            return alert.runModal()
        }
    }

    /// Show a system notification using modern UserNotifications framework
    /// Falls back to NSAlert if bundle identifier is not configured (Xcode debug builds)
    private func showNotification(title: String, message: String) {
        // Check if bundle identifier exists before using UNUserNotificationCenter
        // UNUserNotificationCenter requires a valid bundle identifier and crashes if nil
        guard Bundle.main.bundleIdentifier != nil else {
            AppLog.warn(.skin, "Bundle identifier is nil, falling back to NSAlert for notification")
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
                AppLog.error(.skin, "Failed to show notification: \(error.localizedDescription)")
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

    // MARK: - Background Preprocessing

    /// Preprocess MAIN_WINDOW_BACKGROUND to black out static digit positions
    /// Some skins (e.g., Internet Archive) have "00:00" baked into MAIN.BMP
    /// We black out ONLY the 4 digit areas (9×13 each), keeping the ":" visible
    ///
    /// Time display coordinates: (39, 26) from top-left
    /// Digit positions (relative to 39, 26):
    /// - Minute tens: x:6, y:0 → absolute (45, 26)
    /// - Minute ones: x:17, y:0 → absolute (56, 26)
    /// - Colon: x:28, y:3 → absolute (67, 29) ← NOT masked!
    /// - Second tens: x:35, y:0 → absolute (74, 26)
    /// - Second ones: x:46, y:0 → absolute (85, 26)
    private func preprocessMainBackground(_ image: NSImage) -> NSImage {
        let size = image.size
        let processedImage = NSImage(size: size)

        processedImage.lockFocus()

        // Draw original image
        image.draw(at: .zero, from: NSRect(origin: .zero, size: size), operation: .copy, fraction: 1.0)

        // Black out digit areas using TWO BLOCKS (leaving colon gap)
        // CRITICAL: NSImage uses BOTTOM-LEFT origin, SwiftUI uses TOP-LEFT
        // Time display is at (39, 26) from top-left in SwiftUI
        // Digits are offset within that: x:6, x:17, [colon at x:28], x:35, x:46
        // Absolute positions: 39+6=45, 39+17=56, 39+28=67, 39+35=74, 39+46=85

        // Flip y: imageHeight is 116, time display starts at y:26 from top
        // NSImage bottom-left: y = 116 - 26 - 13 = 77
        let timeDisplayY = size.height - 26 - 13

        NSColor.black.setFill()

        // MINUTES BLOCK: x:45 to x:66 (both minute digits: 45-54, 56-65)
        // Start at 45 (minute-tens), width 22 to cover up to x:67 (before colon)
        NSRect(x: 45, y: timeDisplayY, width: 22, height: 13).fill()

        // COLON GAP: x:67-72 is LEFT UNTOUCHED

        // SECONDS BLOCK: x:74 to x:97 (both second digits: 74-83, 85-94)
        // Start at 74 (second-tens), width 24 to cover both second digits completely
        // Extended by 2px to ensure rightmost digit is fully covered
        NSRect(x: 74, y: timeDisplayY, width: 24, height: 13).fill()

        processedImage.unlockFocus()

        AppLog.debug(.skin, "Preprocessed MAIN_WINDOW_BACKGROUND: 2 blocks (24×14) leaving colon gap at y:\(timeDisplayY)")
        return processedImage
    }

    // MARK: - Fallback Sprite Generation

    /// Get sprites from default Winamp skin for a missing sheet
    /// Returns sprites from Winamp.wsz if available, nil otherwise
    private func fallbackSpritesFromDefaultSkin(sheet sheetName: String, sprites: [Sprite]) -> [String: NSImage]? {
        guard let defaultSkin = defaultSkin else { return nil }
        guard defaultSkin.loadedSheets.contains(sheetName) else { return nil }

        var fallbackSprites: [String: NSImage] = [:]
        for sprite in sprites {
            if let defaultImage = defaultSkin.images[sprite.name] {
                fallbackSprites[sprite.name] = defaultImage
            }
        }

        return fallbackSprites.isEmpty ? nil : fallbackSprites
    }

    /// Create a transparent fallback image for a missing sprite
    /// - Parameter spriteName: Name of the missing sprite
    /// - Returns: A transparent NSImage with appropriate dimensions, or a default size if dimensions unknown
    private func createFallbackSprite(named spriteName: String) -> NSImage {
        // Try to get dimensions from sprite definitions
        let size: CGSize
        if let definedSize = SkinSprites.defaultSprites.dimensions(forSprite: spriteName) {
            size = definedSize
            AppLog.debug(.skin, "Creating fallback for '\(spriteName)' with defined size: \(definedSize.width)x\(definedSize.height)")
        } else {
            // Use a reasonable default size for unknown sprites
            size = CGSize(width: 16, height: 16)
            AppLog.debug(.skin, "Creating fallback for '\(spriteName)' with default size: 16x16 (no definition found)")
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

        AppLog.debug(.skin, "Sheet '\(sheetName)' is missing - generating \(sprites.count) fallback sprites")

        for sprite in sprites {
            let fallbackImage = createFallbackSprite(named: sprite.name)
            fallbacks[sprite.name] = fallbackImage
        }

        return fallbacks
    }

    // MARK: - Existing Methods

    func loadSkin(from url: URL) {
        AppLog.info(.skin, "Loading skin from \(url.path)")
        loadingError = nil
        isLoading = true
        let generation = UUID()
        loadGeneration = generation

        var expectedSheets = Set(SkinSprites.defaultSprites.sheets.keys.map { $0.lowercased() })
        expectedSheets.insert("nums_ex")
        // VIDEO now in SkinSprites.defaultSprites - no need to insert manually

        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let payload = try await Task.detached(priority: .userInitiated) {
                    try SkinArchiveLoader.load(from: url, expectedSheets: expectedSheets)
                }.value
                guard self.loadGeneration == generation else { return }
                try self.applySkinPayload(payload, sourceURL: url)
                self.loadingError = nil
            } catch {
                guard self.loadGeneration == generation else { return }
                if error is CancellationError { return }
                self.loadingError = SkinManager.describeLoadError(error, url: url)
            }
            if self.loadGeneration == generation {
                self.isLoading = false
            }
        }
    }

    private func applySkinPayload(_ payload: SkinArchivePayload, sourceURL: URL) throws {
        var extractedImages: [String: NSImage] = [:]
        var loadedSheets: Set<String> = []  // Track which sheets actually loaded
        var sheetsToProcess = SkinSprites.defaultSprites.sheets

        if payload.sheets.keys.contains("nums_ex") {
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
            AppLog.debug(.skin, "OPTIONAL: Found NUMS_EX sprites in archive")
        } else {
            AppLog.debug(.skin, "NUMS_EX sprites not present in archive")
        }

        AppLog.debug(.skin, "Processing \(sheetsToProcess.count) sheets")
        for (sheetName, sprites) in sheetsToProcess {
            AppLog.debug(.skin, "Processing sheet: \(sheetName)")
            guard let data = payload.sheets[sheetName.lowercased()] else {
                AppLog.warn(.skin, "Missing sheet data: \(sheetName)")

                // Try to use default skin sprites first (all BMPs from Winamp.wsz)
                if let defaultSprites = fallbackSpritesFromDefaultSkin(sheet: sheetName, sprites: sprites) {
                    AppLog.debug(.skin, "Using default Winamp skin sprites for \(sheetName)")
                    for (name, image) in defaultSprites {
                        extractedImages[name] = image
                    }
                } else {
                    // Last resort: transparent fallback
                    let fallbackSprites = createFallbackSprites(forSheet: sheetName, sprites: sprites)
                    for (name, image) in fallbackSprites {
                        extractedImages[name] = image
                    }
                }
                // Don't add to loadedSheets - using fallback
                continue
            }

            guard let sheetImage = NSImage(data: data) else {
                AppLog.error(.skin, "Failed to decode image data for sheet: \(sheetName)")
                let fallbackSprites = createFallbackSprites(forSheet: sheetName, sprites: sprites)
                for (name, image) in fallbackSprites {
                    extractedImages[name] = image
                }
                // Don't add to loadedSheets - using fallback
                continue
            }

            // Sheet loaded successfully - track it
            loadedSheets.insert(sheetName)

            AppLog.debug(.skin, "Sheet \(sheetName) decoded (\(Int(sheetImage.size.width))x\(Int(sheetImage.size.height))), extracting \(sprites.count) sprites")

            for sprite in sprites {
                let rect = sprite.rect
                if let croppedImage = sheetImage.cropped(to: rect) {
                    var finalImage = croppedImage
                    if sprite.name == "MAIN_WINDOW_BACKGROUND" {
                        finalImage = preprocessMainBackground(croppedImage)
                    }
                    extractedImages[sprite.name] = finalImage
                } else {
                    AppLog.warn(.skin, "Failed to crop \(sprite.name) from \(sheetName) at \(rect)")
                    let fallbackImage = createFallbackSprite(named: sprite.name)
                    extractedImages[sprite.name] = fallbackImage
                    AppLog.debug(.skin, "Generated fallback sprite for '\(sprite.name)'")
                }
            }
        }

        // VIDEO.bmp now handled by standard extraction loop (defined in SkinSprites.swift)
        // No special handling needed

        var aliasCount = 0
        if extractedImages["MAIN_VOLUME_THUMB"] == nil, let selected = extractedImages["MAIN_VOLUME_THUMB_SELECTED"] {
            AppLog.debug(.skin, "Creating alias: MAIN_VOLUME_THUMB_SELECTED → MAIN_VOLUME_THUMB")
            extractedImages["MAIN_VOLUME_THUMB"] = selected
            aliasCount += 1
        }
        if extractedImages["MAIN_BALANCE_THUMB"] == nil, let selected = extractedImages["MAIN_BALANCE_THUMB_ACTIVE"] {
            AppLog.debug(.skin, "Creating alias: MAIN_BALANCE_THUMB_ACTIVE → MAIN_BALANCE_THUMB")
            extractedImages["MAIN_BALANCE_THUMB"] = selected
            aliasCount += 1
        }
        if extractedImages["EQ_SLIDER_THUMB"] == nil, let selected = extractedImages["EQ_SLIDER_THUMB_SELECTED"] {
            AppLog.debug(.skin, "Creating alias: EQ_SLIDER_THUMB_SELECTED → EQ_SLIDER_THUMB")
            extractedImages["EQ_SLIDER_THUMB"] = selected
            aliasCount += 1
        }
        if aliasCount > 0 {
            AppLog.info(.skin, "Created \(aliasCount) slider sprite aliases")
        }

        let expectedCount = sheetsToProcess.values.flatMap { $0 }.count
        let extractedCount = extractedImages.count
        AppLog.debug(.skin, "=== SPRITE EXTRACTION SUMMARY ===")
        AppLog.debug(.skin, "Total sprites available: \(extractedCount)")
        AppLog.debug(.skin, "Expected sprites: \(expectedCount)")
        if extractedCount < expectedCount {
            AppLog.warn(.skin, "Some sprites are using transparent fallbacks due to missing/corrupted sheets")
        } else {
            AppLog.info(.skin, "All sprites loaded successfully!")
        }

        var playlistStyle = PlaylistStyle(
            normalTextColor: .white,
            currentTextColor: .white,
            backgroundColor: .black,
            selectedBackgroundColor: Color(red: 0, green: 0, blue: 0.776),
            fontName: nil
        )
        if let pleditData = payload.pledit, let parsed = PLEditParser.parse(from: pleditData) {
            playlistStyle = parsed
        }

        var visualizerColors: [Color] = []
        if let visData = payload.viscolor, let colors = VisColorParser.parse(from: visData) {
            visualizerColors = colors
        }

        // VIDEO.bmp sprites now handled by standard extraction loop (like PLEDIT)
        // No special parsing needed - defined in SkinSprites.swift
        let newSkin = Skin(
            visualizerColors: visualizerColors,
            playlistStyle: playlistStyle,
            images: extractedImages,  // Now includes VIDEO_* sprite keys
            cursors: [:],
            loadedSheets: loadedSheets  // Track which sheets actually loaded
        )

        currentSkin = newSkin
        AppLog.info(.skin, "Skin loaded successfully from \(sourceURL.lastPathComponent)")
    }

    private static func describeLoadError(_ error: Error, url: URL) -> String {
        if let localized = error as? LocalizedError, let description = localized.errorDescription {
            return description
        }
        if error is Archive.ArchiveError {
            return "Skin archive is unreadable or corrupted."
        }
        return "Failed to load skin \(url.lastPathComponent): \(error.localizedDescription)"
    }
}
