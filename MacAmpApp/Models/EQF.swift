import Foundation

struct EqfPreset: Codable {
    var name: String?
    var preampDB: Float // dB in range [-12, 12]
    var bandsDB: [Float] // 10 values (Winamp centers), dB in range [-12, 12]
}

enum EQFCodec {
    private static let header = "Winamp EQ library file v1.1"
    private static let nameFieldLength = 257 // bytes, null-terminated
    // Order expected by Winamp
    private static let presetValueCount = 11 // 10 bands + preamp

    static func parse(data: Data) -> EqfPreset? {
        var i = 0
        let bytes = [UInt8](data)
        guard bytes.count >= header.count + 4 + nameFieldLength + presetValueCount else { return nil }
        // Header
        let headerBytes = Array(bytes[i..<i+header.count])
        guard String(bytes: headerBytes, encoding: .ascii) == header else { return nil }
        i += header.count
        // Skip <ctrl-z>!--
        i += 4
        guard i + nameFieldLength + presetValueCount <= bytes.count else { return nil }
        // Name (null-terminated within 257 bytes)
        let nameSlice = bytes[i..<i+nameFieldLength]
        if let zeroIndex = nameSlice.firstIndex(of: 0) {
            let nameBytes = Array(nameSlice.prefix(upTo: zeroIndex))
            let name = String(bytes: nameBytes, encoding: .ascii)
            // Advance to end of fixed field
            i += nameFieldLength
            // Values are stored as bytes: stored = 64 - value(1..64)
            guard i + presetValueCount <= bytes.count else { return nil }
            var values: [Int] = []
            for _ in 0..<presetValueCount {
                values.append(Int(64) - Int(bytes[i]))
                i += 1
            }
            // Clamp 1..64
            values = values.map { max(1, min(64, $0)) }
            // Convert to percent 0..100 then to dB [-12, 12]
            func valueToDB(_ v: Int) -> Float {
                let percent = Float(v - 1) / 63.0 * 100.0
                return (percent / 100.0) * 24.0 - 12.0
            }
            let bandsDB = values.prefix(10).map { valueToDB($0) }
            let preampDB = valueToDB(values[10])
            return EqfPreset(name: name, preampDB: preampDB, bandsDB: bandsDB)
        } else {
            return nil
        }
    }

    static func serialize(_ preset: EqfPreset) -> Data? {
        var buffer: [UInt8] = []
        // Header
        buffer.append(contentsOf: Array(header.utf8))
        // Control-Z + "!--"
        buffer.append(26)
        buffer.append(contentsOf: Array("!--".utf8))
        // Name
        let name = preset.name ?? "Preset"
        let nameBytes = Array(name.utf8)
        var k = 0
        for b in nameBytes.prefix(nameFieldLength) { buffer.append(b); k += 1 }
        // Pad with zeros
        while k < nameFieldLength { buffer.append(0); k += 1 }
        // Values: convert dB -> percent -> 1..64 -> stored byte (64 - value)
        func dbToValue(_ db: Float) -> Int {
            let percent = ((db + 12.0) / 24.0) * 100.0
            let val = Int(round((percent / 100.0) * 63.0 + 1.0))
            return max(1, min(64, val))
        }
        let allDB = preset.bandsDB.prefix(10) + [preset.preampDB]
        for db in allDB {
            let v = dbToValue(db)
            let stored = UInt8(max(0, min(255, 64 - v)))
            buffer.append(stored)
        }
        return Data(buffer)
    }
}
