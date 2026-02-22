import Testing
import AppKit
@testable import MacAmp

@Suite("WindowFrameStore")
struct WindowFrameStoreTests {

    @Test("PersistedWindowFrame roundtrips through JSON encode/decode")
    func persistedWindowFrameRoundtrip() throws {
        let original = NSRect(x: 123.5, y: 456.75, width: 275, height: 116)
        let persisted = PersistedWindowFrame(frame: original)

        let data = try JSONEncoder().encode(persisted)
        let decoded = try JSONDecoder().decode(PersistedWindowFrame.self, from: data)

        let restored = decoded.asRect()
        #expect(abs(restored.origin.x - original.origin.x) < 0.01)
        #expect(abs(restored.origin.y - original.origin.y) < 0.01)
        #expect(abs(restored.size.width - original.size.width) < 0.01)
        #expect(abs(restored.size.height - original.size.height) < 0.01)
    }

    @Test("WindowFrameStore save and load roundtrip")
    func windowFrameStoreSaveAndLoad() throws {
        let suiteName = "WindowFrameStoreTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = WindowFrameStore(defaults: defaults)
        let frame = NSRect(x: 200, y: 300, width: 275, height: 116)

        store.save(frame: frame, for: .main)
        let loaded = try #require(store.frame(for: .main))
        #expect(abs(loaded.origin.x - 200) < 0.01)
        #expect(abs(loaded.origin.y - 300) < 0.01)
        #expect(abs(loaded.size.width - 275) < 0.01)
        #expect(abs(loaded.size.height - 116) < 0.01)
    }

    @Test("WindowFrameStore returns nil for unknown key")
    func windowFrameStoreReturnsNilForUnknownKey() throws {
        let suiteName = "WindowFrameStoreTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = WindowFrameStore(defaults: defaults)
        #expect(store.frame(for: .playlist) == nil)
    }
}
