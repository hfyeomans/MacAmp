import Foundation
import SwiftUI

enum PLEditParser {
    static func parse(from data: Data) -> PlaylistStyle? {
        guard let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .windowsCP1252) else {
            return nil
        }
        // Find [Text] section and parse key=value lines
        var inTextSection = false
        var values: [String: String] = [:]
        for rawLine in text.replacingOccurrences(of: "\r", with: "").components(separatedBy: "\n") {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix(";") { continue }
            if line.hasPrefix("[") && line.hasSuffix("]") {
                inTextSection = (line.lowercased() == "[text]")
                continue
            }
            guard inTextSection else { continue }
            if let eq = line.firstIndex(of: "=") {
                let key = String(line[..<eq]).trimmingCharacters(in: .whitespaces)
                let val = String(line[line.index(after: eq)...]).trimmingCharacters(in: .whitespaces)
                values[key.lowercased()] = val
            }
        }

        func color(from hex: String?, fallback: Color) -> Color {
            guard let hex = hex else { return fallback }
            return Color(hexString: hex) ?? fallback
        }

        let style = PlaylistStyle(
            normalTextColor: color(from: values["normal"], fallback: .white),
            currentTextColor: color(from: values["current"], fallback: .white),
            backgroundColor: color(from: values["normalbg"], fallback: .black),
            selectedBackgroundColor: color(from: values["selectedbg"], fallback: Color(red: 0, green: 0, blue: 0.776)),
            fontName: values["font"]
        )
        return style
    }
}

private extension Color {
    init?(rgb: (r: CGFloat, g: CGFloat, b: CGFloat)) {
        self = Color(.sRGB, red: Double(rgb.r), green: Double(rgb.g), blue: Double(rgb.b), opacity: 1.0)
    }

    init?(hexString: String) {
        var s = hexString.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let val = UInt32(s, radix: 16) else { return nil }
        let r = CGFloat((val >> 16) & 0xFF) / 255.0
        let g = CGFloat((val >> 8) & 0xFF) / 255.0
        let b = CGFloat(val & 0xFF) / 255.0
        self.init(rgb: (r, g, b))
    }
}

