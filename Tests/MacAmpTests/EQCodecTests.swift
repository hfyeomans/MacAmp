import AVFoundation
import Testing
import Foundation
@testable import MacAmp

@Suite("EQ Codec", .tags(.audio, .parsing))
struct EQCodecTests {
    // MARK: - Band Configuration Guard

    @Test("EQ band frequencies match Winamp 2.x/3.x internal values")
    @MainActor func eqBandFrequenciesMatchWinamp() {
        let eq = EqualizerController()
        let expectedFreqs: [Float] = [70, 180, 320, 600, 1000, 3000, 6000, 12000, 14000, 16000]

        #expect(eq.eqNode.bands.count == 10)
        for (i, band) in eq.eqNode.bands.enumerated() {
            #expect(band.frequency == expectedFreqs[i], "Band \(i) frequency: expected \(expectedFreqs[i]), got \(band.frequency)")
        }
    }

    @Test("EQ band filter types: shelf endpoints, parametric middle")
    @MainActor func eqBandFilterTypes() {
        let eq = EqualizerController()

        #expect(eq.eqNode.bands[0].filterType == .lowShelf, "Band 0 should be lowShelf")
        for i in 1..<9 {
            #expect(eq.eqNode.bands[i].filterType == .parametric, "Band \(i) should be parametric")
        }
        #expect(eq.eqNode.bands[9].filterType == .highShelf, "Band 9 should be highShelf")
    }

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
