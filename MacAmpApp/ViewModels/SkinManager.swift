import Foundation
@preconcurrency import ZIPFoundation
import AppKit
import SwiftUI
import Observation

// This class is responsible for loading and parsing Winamp skins.
// It will be an ObservableObject so that our SwiftUI views can
// react when a new skin is loaded.
@Observable
@MainActor
// swiftlint:disable:next type_body_length
final class SkinManager {

    var currentSkin: Skin?
    var isLoading: Bool = false
    var availableSkins: [SkinMetadata] = []
    var loadingError: String?

    // Default skin payload - ZIP data kept in memory (~200 KB) for on-demand fallback extraction
    @ObservationIgnored private var defaultSkinPayload: SkinArchivePayload?
    // Cache of sprites already extracted from default skin (populated lazily per-sheet)
    @ObservationIgnored private var defaultSkinSpriteCache: [String: NSImage] = [:]
    // Track which sheets have been extracted from the default payload
    @ObservationIgnored private var defaultSkinExtractedSheets: Set<String> = []

    init() {
        // Scan will happen on first access since we're @MainActor
    }

    /// Load default Winamp skin payload (ZIP data only, ~200 KB)
    /// Sprites are extracted lazily on demand when needed for fallback resolution.
    private func loadDefaultSkinIfNeeded() {
        guard defaultSkinPayload == nil else { return }

        guard let winampSkin = SkinMetadata.bundledSkins.first(where: { $0.id == "bundled:Winamp" }) else {
            AppLog.warn(.skin, "Default Winamp skin not found in bundle - no fallback available")
            return
        }

        do {
            let expectedSheets = Set(SkinSprites.defaultSprites.sheets.keys.map { $0.lowercased() })
            let payload = try SkinArchiveLoader.load(from: winampSkin.url, expectedSheets: expectedSheets)
            defaultSkinPayload = payload
            AppLog.info(.skin, "Default skin payload loaded (~\(payload.sheets.values.reduce(0) { $0 + $1.count } / 1024) KB)")
        } catch {
            AppLog.error(.skin, "Failed to load default skin payload: \(error)")
        }
    }

    /// Fully parse default skin payload into a Skin object.
    /// Used only when the default skin IS the selected skin (Task #4 optimization).
    private func parseDefaultSkinFully(payload: SkinArchivePayload) -> Skin {
        var extractedImages: [String: NSImage] = [:]
        var loadedSheets: Set<String> = []
        let sheetsToProcess = SkinSprites.defaultSprites.sheets

        for (sheetName, sprites) in sheetsToProcess {
            guard let data = payload.sheets[sheetName.lowercased()],
                  let sheetImage = NSImage(data: data) else {
                continue
            }

            loadedSheets.insert(sheetName)
            extractedImages.merge(Self.extractSprites(from: sheetImage, sprites: sprites)) { _, new in new }
        }

        // Also populate the sprite cache so fallback lookups are instant
        defaultSkinSpriteCache = extractedImages
        defaultSkinExtractedSheets = loadedSheets

        let playlistStyle = Self.parsePlaylistStyle(from: payload.pledit, fallback: .winampDefault)
        let visualizerColors = Self.parseVisualizerColors(from: payload.viscolor, fallback: Self.defaultVisualizerColors)

        return Skin(
            visualizerColors: visualizerColors,
            playlistStyle: playlistStyle,
            images: extractedImages,
            cursors: [:],
            loadedSheets: loadedSheets
        )
    }

    @ObservationIgnored private var loadGeneration = UUID()

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

        // If selected skin IS the default Winamp skin, parse the already-loaded payload
        // instead of re-extracting the ZIP (avoids double skin load peak memory spike)
        if selectedID == "bundled:Winamp", let payload = defaultSkinPayload {
            AppLog.info(.skin, "Selected skin is default Winamp - parsing from already-loaded payload")
            currentSkin = parseDefaultSkinFully(payload: payload)
            isLoading = false
            return
        }

        switchToSkin(identifier: selectedID)
    }


    // MARK: - Fallback Sprite Generation

    /// Get sprites from default Winamp skin for a missing sheet.
    /// Extracts on-demand from the stored payload and caches results.
    private func fallbackSpritesFromDefaultSkin(sheet sheetName: String, sprites: [Sprite]) -> [String: NSImage]? {
        guard let payload = defaultSkinPayload else { return nil }

        // If this sheet hasn't been extracted yet, do it now and cache
        if !defaultSkinExtractedSheets.contains(sheetName) {
            guard let data = payload.sheets[sheetName.lowercased()],
                  let sheetImage = NSImage(data: data) else {
                return nil
            }
            defaultSkinExtractedSheets.insert(sheetName)
            defaultSkinSpriteCache.merge(Self.extractSprites(from: sheetImage, sprites: sprites)) { _, new in new }
        }

        var fallbackSprites: [String: NSImage] = [:]
        for sprite in sprites {
            if let cached = defaultSkinSpriteCache[sprite.name] {
                fallbackSprites[sprite.name] = cached
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
        defer { image.unlockFocus() }

        // Fill with transparent color
        NSColor.clear.setFill()
        NSRect(origin: .zero, size: size).fill()

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
                let payload = try await SkinArchiveLoader.loadAsync(from: url, expectedSheets: expectedSheets)
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

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    private func applySkinPayload(_ payload: SkinArchivePayload, sourceURL: URL) throws {
        var extractedImages: [String: NSImage] = [:]
        var loadedSheets: Set<String> = []  // Track which sheets actually loaded
        var sheetsToProcess = SkinSprites.defaultSprites.sheets

        if payload.sheets.keys.contains("nums_ex") {
            sheetsToProcess["NUMS_EX"] = SkinSprites.numsExSprites
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
                    extractedImages.merge(defaultSprites) { _, new in new }
                } else {
                    // Last resort: transparent fallback
                    extractedImages.merge(createFallbackSprites(forSheet: sheetName, sprites: sprites)) { _, new in new }
                }
                // Don't add to loadedSheets - using fallback
                continue
            }

            guard let sheetImage = NSImage(data: data) else {
                AppLog.error(.skin, "Failed to decode image data for sheet: \(sheetName)")
                extractedImages.merge(createFallbackSprites(forSheet: sheetName, sprites: sprites)) { _, new in new }
                // Don't add to loadedSheets - using fallback
                continue
            }

            // Sheet loaded successfully - track it
            loadedSheets.insert(sheetName)

            AppLog.debug(.skin, "Sheet \(sheetName) decoded (\(Int(sheetImage.size.width))x\(Int(sheetImage.size.height))), extracting \(sprites.count) sprites")

            for sprite in sprites {
                autoreleasepool {
                    let rect = sprite.rect
                    if let croppedImage = sheetImage.cropped(to: rect) {
                        extractedImages[sprite.name] = croppedImage
                    } else {
                        AppLog.warn(.skin, "Failed to crop \(sprite.name) from \(sheetName) at \(rect)")
                        let fallbackImage = createFallbackSprite(named: sprite.name)
                        extractedImages[sprite.name] = fallbackImage
                        AppLog.debug(.skin, "Generated fallback sprite for '\(sprite.name)'")
                    }
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

        let playlistStyle = Self.parsePlaylistStyle(from: payload.pledit, fallback: .pleditParserDefault)
        let visualizerColors = Self.parseVisualizerColors(from: payload.viscolor, fallback: [])

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

    // MARK: - Shared Parsing Helpers

    /// Winamp 2.x default visualizer colors (24 green entries, used when viscolor.txt is missing).
    private static let defaultVisualizerColors: [Color] = (0..<24).map { _ in Color.green }

    /// Parse playlist style from pledit.txt data, falling back to provided default.
    /// Default skin uses .winampDefault (green text); custom skins use PLEditParser's own fallbacks (white text).
    private static func parsePlaylistStyle(from pleditData: Data?, fallback: PlaylistStyle) -> PlaylistStyle {
        if let data = pleditData, let parsed = PLEditParser.parse(from: data) {
            return parsed
        }
        return fallback
    }

    /// Parse visualizer colors from viscolor.txt data, falling back to provided default.
    /// Default skin uses 24-green palette; custom skins fall back to empty (VisualizerView handles missing colors).
    private static func parseVisualizerColors(from viscolorData: Data?, fallback: [Color]) -> [Color] {
        if let data = viscolorData, let colors = VisColorParser.parse(from: data) {
            return colors
        }
        return fallback
    }

    /// Extract sprites from a sheet image into a dictionary, silently skipping failures.
    private static func extractSprites(from sheetImage: NSImage, sprites: [Sprite]) -> [String: NSImage] {
        var images: [String: NSImage] = [:]
        for sprite in sprites {
            autoreleasepool {
                if let croppedImage = sheetImage.cropped(to: sprite.rect) {
                    images[sprite.name] = croppedImage
                }
            }
        }
        return images
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
