import Testing
import Foundation
@testable import MacAmp

@Suite("EQ Codec")
struct EQCodecTests {
    @Test("EQPreset clamps out-of-range preamp and band values")
    func eqPresetClampsBands() {
        let preset = EQPreset(
            name: "Test",
            preamp: 20,
            bands: Array(repeating: -20, count: 12)
        )
        #expect(preset.preamp == 12)
        #expect(preset.bands.count == 10)
        #expect(preset.bands.allSatisfy { $0 == -12 })
    }

    @Test("EQF parsing rejects empty/short data")
    func eqfParsingRejectsShortData() {
        let data = Data()
        #expect(EQFCodec.parse(data: data) == nil)
    }

    @Test("EQF parsing clamps out-of-range stored values")
    func eqfParsingClampsValues() throws {
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
        let preset = try #require(EQFCodec.parse(data: payload))
        #expect(preset.bandsDB.count == 10)
        #expect(preset.bandsDB.allSatisfy { $0 >= -12 && $0 <= 12 })
        #expect(preset.preampDB <= 12 && preset.preampDB >= -12)
    }
}
