import Foundation

/// Represents an EQ preset with values for all 10 bands + preamp
struct EQPreset: Codable, Identifiable, Sendable {
    let id: UUID
    let name: String
    let preamp: Float  // -12.0 to +12.0 dB
    let bands: [Float] // 10 bands: -12.0 to +12.0 dB each

    init(id: UUID = UUID(), name: String, preamp: Float, bands: [Float]) {
        self.id = id
        self.name = name
        self.preamp = EQPreset.clamp(db: preamp)
        if bands.count == 10 {
            self.bands = bands.map { EQPreset.clamp(db: $0) }
        } else {
            var filled = Array(repeating: 0.0 as Float, count: 10)
            for (index, value) in bands.enumerated().prefix(10) {
                filled[index] = EQPreset.clamp(db: value)
            }
            self.bands = filled
        }
    }

    /// Create from Winamp 0-63 values (Winamp format compatibility)
    init(name: String, winampValues: [Int]) {
        self.id = UUID()
        self.name = name

        // Winamp uses 0-63 range where 33 = 0dB (center)
        // Convert: winampValue -> (winampValue - 33) * (24/63) -> -12 to +12 dB
        func winampToDb(_ value: Int) -> Float {
            let db = Float(value - 33) * (24.0 / 63.0)
            return EQPreset.clamp(db: db)
        }

        // First value is preamp, rest are 10 bands
        if let first = winampValues.first {
            self.preamp = winampToDb(first)
        } else {
            self.preamp = 0
        }
        let bandValues = winampValues.dropFirst().map { winampToDb($0) }
        if bandValues.count == 10 {
            self.bands = bandValues
        } else {
            var filled = Array(repeating: 0.0 as Float, count: 10)
            for (index, value) in bandValues.enumerated().prefix(10) {
                filled[index] = value
            }
            self.bands = filled
        }
    }

    private static func clamp(db: Float) -> Float {
        return min(max(db, -12.0), 12.0)
    }
}

/// Built-in EQ presets (from Winamp default presets)
extension EQPreset {
    static let builtIn: [EQPreset] = [
        // Classical: Boost highs for clarity
        EQPreset(name: "Classical", winampValues: [33, 33, 33, 33, 33, 33, 33, 20, 20, 20, 16]),

        // Club: Mid-bass boost
        EQPreset(name: "Club", winampValues: [33, 33, 33, 38, 42, 42, 42, 38, 33, 33, 33]),

        // Dance: Heavy bass, reduced mids
        EQPreset(name: "Dance", winampValues: [33, 48, 44, 36, 32, 32, 22, 20, 20, 32, 32]),

        // Laptop speakers/headphones: V-shaped curve
        EQPreset(name: "Laptop speakers/headphones", winampValues: [33, 40, 50, 41, 26, 28, 35, 40, 48, 53, 56]),

        // Large hall: Room compensation
        EQPreset(name: "Large hall", winampValues: [33, 49, 49, 42, 42, 33, 24, 24, 24, 33, 33]),

        // Party: Bass and treble boost
        EQPreset(name: "Party", winampValues: [33, 44, 44, 33, 33, 33, 33, 33, 33, 44, 44]),

        // Pop: Vocal presence
        EQPreset(name: "Pop", winampValues: [33, 29, 40, 44, 45, 41, 30, 28, 28, 29, 29]),

        // Reggae: Mid-bass emphasis
        EQPreset(name: "Reggae", winampValues: [33, 33, 33, 31, 22, 33, 43, 43, 33, 33, 33]),

        // Rock: Guitar frequencies
        EQPreset(name: "Rock", winampValues: [33, 45, 40, 23, 19, 26, 39, 47, 50, 50, 50]),

        // Soft: Smooth highs
        EQPreset(name: "Soft", winampValues: [33, 40, 35, 30, 28, 30, 39, 46, 48, 50, 52]),

        // Ska: Upbeat mix
        EQPreset(name: "Ska", winampValues: [33, 28, 24, 25, 31, 39, 42, 47, 48, 50, 48]),

        // Full Bass: Maximum low end
        EQPreset(name: "Full Bass", winampValues: [33, 48, 48, 48, 42, 35, 25, 18, 15, 14, 14]),

        // Soft Rock: Balanced warmth
        EQPreset(name: "Soft Rock", winampValues: [33, 39, 39, 36, 31, 25, 23, 26, 31, 37, 47]),

        // Full Treble: Maximum high end
        EQPreset(name: "Full Treble", winampValues: [33, 16, 16, 16, 25, 37, 50, 58, 58, 58, 60]),

        // Full Bass & Treble: V-shaped
        EQPreset(name: "Full Bass & Treble", winampValues: [33, 44, 42, 33, 20, 24, 35, 46, 50, 52, 52]),

        // Live: Concert hall simulation
        EQPreset(name: "Live", winampValues: [33, 24, 33, 39, 41, 42, 42, 39, 37, 37, 36]),

        // Techno: Electronic music
        EQPreset(name: "Techno", winampValues: [33, 45, 42, 33, 23, 24, 33, 45, 48, 48, 47])
    ]

    /// Flat preset (all values at 0dB)
    static let flat = EQPreset(
        name: "Flat",
        preamp: 0.0,
        bands: Array(repeating: 0.0, count: 10)
    )
}
