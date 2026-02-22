import Testing
import Foundation
@testable import MacAmp

@MainActor
@Suite("AppSettings", .tags(.persistence))
struct AppSettingsTests {
    @Test("ensureSkinsDirectory creates expected directory structure")
    func ensureSkinsDirectoryCreatesStructure() throws {
        let fileManager = FileManager.default
        let tempBase = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fileManager.createDirectory(at: tempBase, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: tempBase) }

        let skinsDir = try AppSettings.ensureSkinsDirectory(fileManager: fileManager, base: tempBase)
        #expect(fileManager.fileExists(atPath: skinsDir.path))

        let expectedPath = tempBase.appendingPathComponent("MacAmp/Skins")
        #expect(skinsDir.standardizedFileURL.path == expectedPath.standardizedFileURL.path)
    }

    @Test("ensureSkinsDirectory throws when base path is blocked by a file")
    func ensureSkinsDirectoryThrowsWhenBaseBlocked() throws {
        let fileManager = FileManager.default
        let tempBase = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fileManager.createDirectory(at: tempBase, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: tempBase) }

        let blockingFile = tempBase.appendingPathComponent("MacAmp")
        try Data().write(to: blockingFile)

        #expect(throws: (any Error).self) {
            try AppSettings.ensureSkinsDirectory(fileManager: fileManager, base: tempBase)
        }
    }
}
