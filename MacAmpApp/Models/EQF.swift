import Foundation

struct EqfPreset: Codable, Sendable {
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
        var index = 0
        let bytes = [UInt8](data)
        let minimumLength = header.count + 4 + nameFieldLength + presetValueCount
        guard bytes.count >= minimumLength else { return nil }

        let headerBytes = Array(bytes[index..<index + header.count])
        guard String(bytes: headerBytes, encoding: .ascii) == header else { return nil }
        index += header.count

        // Skip <ctrl-z>!-- marker
        index += 4
        guard index + nameFieldLength + presetValueCount <= bytes.count else { return nil }

        let nameSlice = bytes[index..<index + nameFieldLength]
        let name: String?
        if let zeroIndex = nameSlice.firstIndex(of: 0) {
            let nameBytes = Array(nameSlice.prefix(upTo: zeroIndex))
            name = String(bytes: nameBytes, encoding: .ascii)
        } else {
            name = String(bytes: nameSlice, encoding: .ascii)
        }
        index += nameFieldLength

        guard index + presetValueCount <= bytes.count else { return nil }

        var values: [Int] = []
        values.reserveCapacity(presetValueCount)
        for offset in 0..<presetValueCount {
            let stored = Int(bytes[index + offset])
            let decoded = 64 - stored
            values.append(decoded)
        }
        index += presetValueCount

        guard values.count == presetValueCount else { return nil }

        values = values.map { min(max($0, 1), 64) }

        func valueToDB(_ value: Int) -> Float {
            let clamped = min(max(value, 1), 64)
            let percent = Float(clamped - 1) / 63.0
            let db = percent * 24.0 - 12.0
            return min(max(db, -12.0), 12.0)
        }

        let bandsDB = values.prefix(10).map { valueToDB($0) }
        guard values.indices.contains(10) else { return nil }
        let preampDB = valueToDB(values[10])
        return EqfPreset(name: name, preampDB: preampDB, bandsDB: bandsDB)
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
