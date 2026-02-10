import AppKit

struct PlaylistAttachmentSnapshot: Sendable {
    let anchor: WindowKind
    let attachment: PlaylistDockingContext.Attachment
}

struct VideoAttachmentSnapshot: Sendable {
    let anchor: WindowKind
    let attachment: PlaylistDockingContext.Attachment
}

struct PlaylistDockingContext: Sendable {
    enum Source: CustomStringConvertible, Sendable {
        case cluster(Set<WindowKind>)
        case heuristic
        case memory

        var description: String {
            switch self {
            case .cluster(let kinds):
                return "cluster=" + kinds.map { "\($0)" }.sorted().joined(separator: ",")
            case .heuristic:
                return "heuristic"
            case .memory:
                return "memory"
            }
        }
    }

    enum Attachment: CustomStringConvertible, Sendable {
        case below(xOffset: CGFloat)
        case above(xOffset: CGFloat)
        case left(yOffset: CGFloat)
        case right(yOffset: CGFloat)

        var description: String {
            switch self {
            case .below(let offset): return ".below(xOffset: \(offset))"
            case .above(let offset): return ".above(xOffset: \(offset))"
            case .left(let offset): return ".left(yOffset: \(offset))"
            case .right(let offset): return ".right(yOffset: \(offset))"
            }
        }
    }

    let anchor: WindowKind
    let attachment: Attachment
    let source: Source
}
