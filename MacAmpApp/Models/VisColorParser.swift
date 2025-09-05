import Foundation
import SwiftUI

enum VisColorParser {
    static func parse(from data: Data) -> [Color]? {
        guard let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .windowsCP1252) else {
            return nil
        }
        var colors: [Color] = []
        for raw in text.replacingOccurrences(of: "\r", with: "").components(separatedBy: "\n") {
            let line = raw.split(separator: "/").first.map(String.init) ?? raw // strip comments
            let parts = line.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            if parts.count >= 3, let r = Double(parts[0]), let g = Double(parts[1]), let b = Double(parts[2]) {
                let color = Color(.sRGB, red: r/255.0, green: g/255.0, blue: b/255.0, opacity: 1)
                colors.append(color)
            }
        }
        return colors.isEmpty ? nil : colors
    }
}

