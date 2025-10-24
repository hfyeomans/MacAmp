import XCTest
@testable import MacAmp

final class EQCodecTests: XCTestCase {
    func testEQPresetClampsBands() {
        let preset = EQPreset(
            name: "Test",
            preamp: 20,
            bands: Array(repeating: -20, count: 12)
        )
        XCTAssertEqual(preset.preamp, 12)
        XCTAssertEqual(preset.bands.count, 10)
        XCTAssertTrue(preset.bands.allSatisfy { $0 == -12 })
    }

    func testEQFParsingRejectsShortData() {
        let data = Data()
        XCTAssertNil(EQFCodec.parse(data: data))
    }

    func testEQFParsingClampsValues() throws {
        var payload = Data()
        payload.append(contentsOf: Array("Winamp EQ library file v1.1".utf8))
        payload.append(26)
        payload.append(contentsOf: Array("!--".utf8))
        var nameField = Array("Test".utf8)
        nameField += Array(repeating: UInt8(0), count: 257 - nameField.count)
        payload.append(contentsOf: nameField)
        // Preamp + 10 bands, with deliberately out-of-range stored values
        for _ in 0..<11 {
            payload.append(UInt8(255))
        }
        let preset = EQFCodec.parse(data: payload)
        XCTAssertNotNil(preset)
        XCTAssertEqual(preset?.bandsDB.count, 10)
        XCTAssertTrue(preset?.bandsDB.allSatisfy { $0 >= -12 && $0 <= 12 } ?? false)
        XCTAssertTrue((preset?.preampDB ?? 0) <= 12 && (preset?.preampDB ?? 0) >= -12)
    }
}
