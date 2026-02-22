import Testing
import Foundation
@testable import MacAmp

@MainActor
@Suite("DockingController")
struct DockingControllerTests {
    @Test("Persistence roundtrip — toggle playlist saves and rehydrates")
    func persistenceRoundtrip() async throws {
        let suiteName = "DockingControllerTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let controller = DockingController(defaults: defaults)
        #expect(!controller.showPlaylist)

        controller.togglePlaylist()

        // Wait for debounce
        try await Task.sleep(nanoseconds: 300_000_000)

        let rehydrated = DockingController(defaults: defaults)
        #expect(rehydrated.showPlaylist)
    }
}
