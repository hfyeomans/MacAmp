import XCTest
@testable import MacAmp

@MainActor
final class AppSettingsTests: XCTestCase {
    func testEnsureSkinsDirectoryCreatesStructure() throws {
        let fileManager = FileManager.default
        let tempBase = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fileManager.createDirectory(at: tempBase, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: tempBase) }

        let skinsDir = try AppSettings.ensureSkinsDirectory(fileManager: fileManager, base: tempBase)
        XCTAssertTrue(fileManager.fileExists(atPath: skinsDir.path))

        let expectedPath = tempBase.appendingPathComponent("MacAmp/Skins")
        XCTAssertEqual(skinsDir.standardizedFileURL.path, expectedPath.standardizedFileURL.path)
    }

    func testEnsureSkinsDirectoryThrowsWhenBaseBlocked() throws {
        let fileManager = FileManager.default
        let tempBase = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fileManager.createDirectory(at: tempBase, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: tempBase) }

        let blockingFile = tempBase.appendingPathComponent("MacAmp")
        try Data().write(to: blockingFile)

        XCTAssertThrowsError(
            try AppSettings.ensureSkinsDirectory(fileManager: fileManager, base: tempBase)
        )
    }
}
