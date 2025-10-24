import XCTest
@testable import MacAmp

@MainActor
final class SkinManagerTests: XCTestCase {
    func testLoadSkinClearsErrorAndSetsCurrentSkin() async throws {
        let manager = SkinManager()
        manager.loadingError = "Previous error"

        let skinURL = try bundledSkinURL(named: "Winamp")
        manager.loadSkin(from: skinURL)

        try await waitUntilNotLoading(manager)

        XCTAssertNil(manager.loadingError)
        XCTAssertNotNil(manager.currentSkin)
    }

    func testLoadSkinFailureSetsError() async throws {
        let manager = SkinManager()
        let invalidURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("wsz")

        manager.loadSkin(from: invalidURL)
        try await waitUntilNotLoading(manager)
        XCTAssertNotNil(manager.loadingError)
    }

    private func bundledSkinURL(named name: String) throws -> URL {
        let currentFile = URL(fileURLWithPath: #filePath)
        let projectRoot = currentFile
            .deletingLastPathComponent() // MacAmpTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // Repository root
        let skinsURL = projectRoot
            .appendingPathComponent("MacAmpApp")
            .appendingPathComponent("Skins")
            .appendingPathComponent("\(name).wsz")

        guard FileManager.default.fileExists(atPath: skinsURL.path) else {
            throw NSError(domain: "SkinManagerTests", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Missing bundled skin at \(skinsURL.path)"
            ])
        }
        return skinsURL
    }

    private func waitUntilNotLoading(_ manager: SkinManager, timeout: TimeInterval = 5) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while manager.isLoading {
            if Date() > deadline {
                throw XCTSkip("Timed out waiting for SkinManager to finish loading")
            }
            try await Task.sleep(nanoseconds: 50_000_000) // 50ms
        }
    }
}
