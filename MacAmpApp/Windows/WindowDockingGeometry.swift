import AppKit

/// Pure geometry calculations for window docking.
/// All methods are static and take NSRect inputs — no mutable state, no actor isolation needed.
nonisolated struct WindowDockingGeometry {

    static func determineAttachment(
        anchorFrame: NSRect,
        playlistFrame: NSRect,
        strict: Bool = true
    ) -> PlaylistDockingContext.Attachment? {
        let tolerance = SnapUtils.SNAP_DISTANCE

        var candidates: [(distance: CGFloat, attachment: PlaylistDockingContext.Attachment)] = []

        func overlapsX() -> Bool {
            playlistFrame.minX <= anchorFrame.maxX + tolerance && anchorFrame.minX <= playlistFrame.maxX + tolerance
        }

        func overlapsY() -> Bool {
            playlistFrame.minY <= anchorFrame.maxY + tolerance && anchorFrame.minY <= playlistFrame.maxY + tolerance
        }

        func consider(distance: CGFloat, attachment: PlaylistDockingContext.Attachment) {
            if strict {
                if distance <= tolerance {
                    candidates.append((distance, attachment))
                }
            } else {
                candidates.append((distance, attachment))
            }
        }

        if overlapsX() {
            let playlistTop = playlistFrame.maxY
            let anchorBottom = anchorFrame.minY
            consider(distance: abs(playlistTop - anchorBottom), attachment: .below(xOffset: playlistFrame.origin.x - anchorFrame.origin.x))

            let playlistBottom = playlistFrame.minY
            let anchorTop = anchorFrame.maxY
            consider(distance: abs(playlistBottom - anchorTop), attachment: .above(xOffset: playlistFrame.origin.x - anchorFrame.origin.x))
        }

        if overlapsY() {
            let playlistRight = playlistFrame.maxX
            let anchorLeft = anchorFrame.minX
            consider(distance: abs(playlistRight - anchorLeft), attachment: .left(yOffset: playlistFrame.origin.y - anchorFrame.origin.y))

            let playlistLeft = playlistFrame.minX
            let anchorRight = anchorFrame.maxX
            consider(distance: abs(playlistLeft - anchorRight), attachment: .right(yOffset: playlistFrame.origin.y - anchorFrame.origin.y))
        }

        return candidates.min(by: { $0.distance < $1.distance })?.attachment
    }

    static func playlistOrigin(
        for attachment: PlaylistDockingContext.Attachment,
        anchorFrame: NSRect,
        playlistSize: NSSize
    ) -> NSPoint {
        switch attachment {
        case .below(let xOffset):
            return NSPoint(x: anchorFrame.origin.x + xOffset, y: anchorFrame.origin.y - playlistSize.height)
        case .above(let xOffset):
            return NSPoint(x: anchorFrame.origin.x + xOffset, y: anchorFrame.origin.y + anchorFrame.size.height)
        case .left(let yOffset):
            return NSPoint(x: anchorFrame.origin.x - playlistSize.width, y: anchorFrame.origin.y + yOffset)
        case .right(let yOffset):
            return NSPoint(x: anchorFrame.origin.x + anchorFrame.size.width, y: anchorFrame.origin.y + yOffset)
        }
    }

    static func attachmentStillEligible(
        _ snapshot: PlaylistAttachmentSnapshot,
        anchorFrame: NSRect,
        playlistFrame: NSRect
    ) -> Bool {
        let expected = playlistOrigin(for: snapshot.attachment, anchorFrame: anchorFrame, playlistSize: playlistFrame.size)
        let dx = abs(playlistFrame.origin.x - expected.x)
        let dy = abs(playlistFrame.origin.y - expected.y)
        let tolerance = SnapUtils.SNAP_DISTANCE

        switch snapshot.attachment {
        case .below, .above:
            return dx <= tolerance && dy <= anchorFrame.size.height + tolerance
        case .left, .right:
            return dy <= tolerance && dx <= playlistFrame.size.width + tolerance
        }
    }

    static func anchorFrame(
        _ anchor: WindowKind,
        mainFrame: NSRect,
        eqFrame: NSRect,
        playlistFrame: NSRect? = nil
    ) -> NSRect? {
        switch anchor {
        case .main:
            return mainFrame
        case .equalizer:
            return eqFrame
        case .playlist:
            return playlistFrame
        default:
            return nil
        }
    }
}
