import Testing
import Foundation
@testable import MacAmp

@MainActor
@Suite("DockingController", .tags(.window, .persistence))
struct DockingControllerTests {
    @Test("Persistence roundtrip — toggle playlist saves and rehydrates",
          .timeLimit(.minutes(1)))
    func persistenceRoundtrip() async throws {
        let suiteName = "DockingControllerTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let controller = DockingController(defaults: defaults)
        #expect(!controller.showPlaylist)

        // Use toggleVisibility directly — togglePlaylist() asserts windowCoordinator
        // is injected, which isn't needed for persistence-only testing.
        controller.toggleVisibility(.playlist)

        // Wait for debounce
        try await Task.sleep(nanoseconds: 300_000_000)

        let rehydrated = DockingController(defaults: defaults)
        #expect(rehydrated.showPlaylist)
    }
}
