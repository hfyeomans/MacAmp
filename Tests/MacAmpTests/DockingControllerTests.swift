import XCTest
@testable import MacAmp

@MainActor
final class DockingControllerTests: XCTestCase {
    func testPersistenceRoundtrip() async throws {
        let suiteName = "DockingControllerTests-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw XCTSkip("Unable to create test suite defaults")
        }
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let controller = DockingController(defaults: defaults)
        XCTAssertFalse(controller.showPlaylist)

        controller.togglePlaylist()

        try await waitForDebounce()

        let rehydrated = DockingController(defaults: defaults)
        XCTAssertTrue(rehydrated.showPlaylist)
    }

    private func waitForDebounce() async throws {
        try await Task.sleep(nanoseconds: 300_000_000) // 0.3s
    }
}
