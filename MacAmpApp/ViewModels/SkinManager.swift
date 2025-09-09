import Foundation
import Combine
import ZIPFoundation
import AppKit
import CoreGraphics // For CGRect
import SwiftUI

// This class is responsible for loading and parsing Winamp skins.
// It will be an ObservableObject so that our SwiftUI views can
// react when a new skin is loaded.
@MainActor
class SkinManager: ObservableObject {

    @Published var currentSkin: Skin?
    @Published var isLoading: Bool = false

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
                    NSLog("❌ MISSING SHEET: \(sheetName).bmp/.png not found in archive")
                    NSLog("   Expected \(sprites.count) sprites from this sheet")
                    // List the missing sprite names for debugging
                    for sprite in sprites.prefix(5) {
                        NSLog("   - Missing sprite: \(sprite.name)")
                    }
                    continue
                }
                var data = Data()
                _ = try archive.extract(entry, consumer: { data.append($0) })
                guard let sheetImage = NSImage(data: data) else {
                    print("❌ FAILED to create image for sheet: \(sheetName)")
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
                        print("     ❌ FAILED to crop \(sprite.name) from \(sheetName) at \(sprite.rect)")
                        // Additional debug info
                        print("       Sheet size: \(sheetImage.size)")
                        print("       Requested rect: \(r)")
                        print("       Rect within bounds: \(r.maxX <= sheetImage.size.width && r.maxY <= sheetImage.size.height)")
                    }
                }
            }
            
            print("=== SPRITE EXTRACTION SUMMARY ===")
            print("Total sprites extracted: \(extractedImages.count)")
            print("Expected sprites: \(sheetsToProcess.values.flatMap{$0}.count)")
            print("Success rate: \(extractedImages.count)/\(sheetsToProcess.values.flatMap{$0}.count)")
            
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
