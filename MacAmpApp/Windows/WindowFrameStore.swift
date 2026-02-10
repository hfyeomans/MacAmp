import AppKit

struct PersistedWindowFrame: Codable, Sendable {
    let originX: Double
    let originY: Double
    let width: Double
    let height: Double

    init(frame: NSRect) {
        originX = Double(frame.origin.x)
        originY = Double(frame.origin.y)
        width = Double(frame.size.width)
        height = Double(frame.size.height)
    }

    func asRect() -> NSRect {
        NSRect(
            x: CGFloat(originX),
            y: CGFloat(originY),
            width: CGFloat(width),
            height: CGFloat(height)
        )
    }
}

struct WindowFrameStore {
    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func frame(for kind: WindowKind) -> NSRect? {
        guard let data = defaults.data(forKey: key(for: kind)),
              let record = try? decoder.decode(PersistedWindowFrame.self, from: data) else {
            return nil
        }
        return record.asRect()
    }

    func save(frame: NSRect, for kind: WindowKind) {
        let record = PersistedWindowFrame(frame: frame)
        if let data = try? encoder.encode(record) {
            defaults.set(data, forKey: key(for: kind))
        }
    }

    private func key(for kind: WindowKind) -> String {
        "WindowFrame.\(kind.persistenceKey)"
    }
}

extension WindowKind {
    var persistenceKey: String {
        switch self {
        case .main: return "main"
        case .playlist: return "playlist"
        case .equalizer: return "equalizer"
        case .video: return "video"
        case .milkdrop: return "milkdrop"
        }
    }
}
