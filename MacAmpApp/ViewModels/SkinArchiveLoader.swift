import Foundation
@preconcurrency import ZIPFoundation

struct SkinArchivePayload {
    let sheets: [String: Data]
    let pledit: Data?
    let viscolor: Data?
}

enum SkinArchiveLoader {
    /// Async wrapper for off-MainActor skin loading (Swift 6.2 @concurrent)
    @concurrent
    static func loadAsync(from url: URL, expectedSheets: Set<String>) async throws -> SkinArchivePayload {
        try load(from: url, expectedSheets: expectedSheets)
    }

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
