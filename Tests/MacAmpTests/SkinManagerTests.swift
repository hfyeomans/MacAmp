import Testing
import Foundation
@testable import MacAmp

@MainActor
@Suite("SkinManager")
struct SkinManagerTests {
    @Test("loadSkin clears error and sets currentSkin on success")
    func loadSkinClearsErrorAndSetsCurrentSkin() async throws {
        let manager = SkinManager()
        manager.loadingError = "Previous error"

        let skinURL = try bundledSkinURL(named: "Winamp")
        manager.loadSkin(from: skinURL)

        try await waitUntilNotLoading(manager)

        #expect(manager.loadingError == nil)
        #expect(manager.currentSkin != nil)
    }

    @Test("loadSkin sets error for invalid skin URL")
    func loadSkinFailureSetsError() async throws {
        let manager = SkinManager()
        let invalidURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("wsz")

        manager.loadSkin(from: invalidURL)
        try await waitUntilNotLoading(manager)
        #expect(manager.loadingError != nil)
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
            throw SkinNotFoundError(path: skinsURL.path)
        }
        return skinsURL
    }

    private func waitUntilNotLoading(_ manager: SkinManager, timeout: TimeInterval = 5) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while manager.isLoading {
            if Date() > deadline {
                Issue.record("Timed out waiting for SkinManager to finish loading")
                return
            }
            try await Task.sleep(nanoseconds: 50_000_000) // 50ms
        }
    }
}

private struct SkinNotFoundError: Error, CustomStringConvertible {
    let path: String
    var description: String { "Missing bundled skin at \(path)" }
}
