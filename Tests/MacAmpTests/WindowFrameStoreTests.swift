import XCTest
@testable import MacAmp

final class WindowFrameStoreTests: XCTestCase {

    func testPersistedWindowFrameRoundtrip() throws {
        let original = NSRect(x: 123.5, y: 456.75, width: 275, height: 116)
        let persisted = PersistedWindowFrame(frame: original)

        let encoder = JSONEncoder()
        let data = try encoder.encode(persisted)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(PersistedWindowFrame.self, from: data)

        let restored = decoded.asRect()
        XCTAssertEqual(restored.origin.x, original.origin.x, accuracy: 0.01)
        XCTAssertEqual(restored.origin.y, original.origin.y, accuracy: 0.01)
        XCTAssertEqual(restored.size.width, original.size.width, accuracy: 0.01)
        XCTAssertEqual(restored.size.height, original.size.height, accuracy: 0.01)
    }

    func testWindowFrameStoreSaveAndLoad() throws {
        let suiteName = "WindowFrameStoreTests-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw XCTSkip("Unable to create test suite defaults")
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = WindowFrameStore(defaults: defaults)
        let frame = NSRect(x: 200, y: 300, width: 275, height: 116)

        store.save(frame: frame, for: .main)
        let loaded = store.frame(for: .main)

        let unwrapped = try XCTUnwrap(loaded)
        XCTAssertEqual(unwrapped.origin.x, 200, accuracy: 0.01)
        XCTAssertEqual(unwrapped.origin.y, 300, accuracy: 0.01)
        XCTAssertEqual(unwrapped.size.width, 275, accuracy: 0.01)
        XCTAssertEqual(unwrapped.size.height, 116, accuracy: 0.01)
    }

    func testWindowFrameStoreReturnsNilForUnknownKey() {
        let suiteName = "WindowFrameStoreTests-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else { return }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = WindowFrameStore(defaults: defaults)
        XCTAssertNil(store.frame(for: .playlist))
    }
}
