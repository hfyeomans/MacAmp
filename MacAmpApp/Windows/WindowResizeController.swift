import AppKit

/// Manages window resize operations, docking-aware layout, and resize preview overlays.
@MainActor
final class WindowResizeController {
    private let registry: WindowRegistry
    private let persistence: WindowFramePersistence
    private var lastPlaylistAttachment: PlaylistAttachmentSnapshot?
    private var lastVideoAttachment: VideoAttachmentSnapshot?

    init(registry: WindowRegistry, persistence: WindowFramePersistence) {
        self.registry = registry
        self.persistence = persistence
    }

    // MARK: - Double-Size Resize

    func resizeMainAndEQWindows(doubled: Bool, animated _: Bool = true, persistResult: Bool = true) {
        guard let main = registry.mainWindow, let eq = registry.eqWindow else { return }

        let originalMainFrame = main.frame
        let originalEqFrame = eq.frame
        let originalPlaylistFrame = registry.playlistWindow?.frame
        let playlistSize = originalPlaylistFrame?.size ?? registry.playlistWindow?.frame.size
        let originalVideoFrame = registry.videoWindow?.frame
        let videoSize = originalVideoFrame?.size

        let dockingContext = makePlaylistDockingContext(
            mainFrame: originalMainFrame, eqFrame: originalEqFrame, playlistFrame: originalPlaylistFrame
        )
        let videoDockingContext = makeVideoDockingContext(
            mainFrame: originalMainFrame, eqFrame: originalEqFrame,
            playlistFrame: originalPlaylistFrame, videoFrame: originalVideoFrame
        )

        logDoubleSizeDebug(
            mainFrame: originalMainFrame, eqFrame: originalEqFrame,
            playlistFrame: originalPlaylistFrame, dockingContext: dockingContext
        )

        let scale: CGFloat = doubled ? 2.0 : 1.0
        let newMainFrame = scaledMainFrame(from: originalMainFrame, scale: scale)
        let newEqFrame = scaledEQFrame(from: originalEqFrame, scale: scale, belowMain: newMainFrame)
        let animationAnchorFrame = dockingContext.flatMap { context in
            WindowDockingGeometry.anchorFrame(context.anchor, mainFrame: newMainFrame, eqFrame: newEqFrame)
        }

        persistence.beginSuppressingPersistence()
        WindowSnapManager.shared.beginProgrammaticAdjustment()

        main.setFrame(newMainFrame, display: true)
        eq.setFrame(newEqFrame, display: true)

        if let context = dockingContext, let size = playlistSize,
           let anchor = animationAnchorFrame ?? registry.liveAnchorFrame(context.anchor)
            ?? WindowDockingGeometry.anchorFrame(context.anchor, mainFrame: newMainFrame, eqFrame: newEqFrame) {
            movePlaylist(using: context, targetFrame: anchor, playlistSize: size, animated: false)
        }
        if let videoCtx = videoDockingContext, let size = videoSize,
           let anchor = registry.liveAnchorFrame(videoCtx.anchor)
            ?? WindowDockingGeometry.anchorFrame(videoCtx.anchor, mainFrame: newMainFrame, eqFrame: newEqFrame, playlistFrame: registry.playlistWindow?.frame) {
            moveVideoWindow(using: videoCtx, targetFrame: anchor, videoSize: size, animated: false)
        }

        logDockingStage(
            "post-resize actual",
            mainFrame: registry.mainWindow?.frame,
            eqFrame: registry.eqWindow?.frame,
            playlistFrame: registry.playlistWindow?.frame
        )

        WindowSnapManager.shared.endProgrammaticAdjustment()
        persistence.endSuppressingPersistence()
        if persistResult {
            persistence.schedulePersistenceFlush()
        }
    }

    private func scaledMainFrame(from original: NSRect, scale: CGFloat) -> NSRect {
        var frame = original
        let newSize = CGSize(width: WinampSizes.main.width * scale, height: WinampSizes.main.height * scale)
        let delta = newSize.height - frame.size.height
        frame.size = newSize
        frame.origin.y -= delta
        return frame
    }

    private func scaledEQFrame(from original: NSRect, scale: CGFloat, belowMain mainFrame: NSRect) -> NSRect {
        var frame = original
        frame.size = CGSize(width: WinampSizes.equalizer.width * scale, height: WinampSizes.equalizer.height * scale)
        frame.origin.y = mainFrame.origin.y - frame.size.height
        return frame
    }

    // MARK: - Docking Context

    func makePlaylistDockingContext(mainFrame: NSRect, eqFrame: NSRect, playlistFrame: NSRect?) -> PlaylistDockingContext? {
        guard let playlistFrame else { return nil }

        if let clusterKinds = WindowSnapManager.shared.clusterKinds(containing: .playlist) {
            if clusterKinds.contains(.equalizer),
               let attachment = WindowDockingGeometry.determineAttachment(anchorFrame: eqFrame, playlistFrame: playlistFrame, strict: false) {
                let snapshot = PlaylistAttachmentSnapshot(anchor: .equalizer, attachment: attachment)
                lastPlaylistAttachment = snapshot
                return PlaylistDockingContext(anchor: .equalizer, attachment: attachment, source: .cluster(clusterKinds))
            }
            if clusterKinds.contains(.main),
               let attachment = WindowDockingGeometry.determineAttachment(anchorFrame: mainFrame, playlistFrame: playlistFrame, strict: false) {
                let snapshot = PlaylistAttachmentSnapshot(anchor: .main, attachment: attachment)
                lastPlaylistAttachment = snapshot
                return PlaylistDockingContext(anchor: .main, attachment: attachment, source: .cluster(clusterKinds))
            }
            if let snapshot = lastPlaylistAttachment,
               clusterKinds.contains(snapshot.anchor),
               let anchorFrame = WindowDockingGeometry.anchorFrame(snapshot.anchor, mainFrame: mainFrame, eqFrame: eqFrame),
               WindowDockingGeometry.attachmentStillEligible(snapshot, anchorFrame: anchorFrame, playlistFrame: playlistFrame) {
                return PlaylistDockingContext(anchor: snapshot.anchor, attachment: snapshot.attachment, source: .memory)
            }
        }

        if let attachment = WindowDockingGeometry.determineAttachment(anchorFrame: eqFrame, playlistFrame: playlistFrame) {
            let snapshot = PlaylistAttachmentSnapshot(anchor: .equalizer, attachment: attachment)
            lastPlaylistAttachment = snapshot
            return PlaylistDockingContext(anchor: .equalizer, attachment: attachment, source: .heuristic)
        }

        if let attachment = WindowDockingGeometry.determineAttachment(anchorFrame: mainFrame, playlistFrame: playlistFrame) {
            let snapshot = PlaylistAttachmentSnapshot(anchor: .main, attachment: attachment)
            lastPlaylistAttachment = snapshot
            return PlaylistDockingContext(anchor: .main, attachment: attachment, source: .heuristic)
        }

        if let snapshot = lastPlaylistAttachment,
           let anchorFrame = WindowDockingGeometry.anchorFrame(snapshot.anchor, mainFrame: mainFrame, eqFrame: eqFrame),
           WindowDockingGeometry.attachmentStillEligible(snapshot, anchorFrame: anchorFrame, playlistFrame: playlistFrame) {
            return PlaylistDockingContext(anchor: snapshot.anchor, attachment: snapshot.attachment, source: .memory)
        }

        lastPlaylistAttachment = nil
        return nil
    }

    func makeVideoDockingContext(
        mainFrame: NSRect,
        eqFrame: NSRect,
        playlistFrame: NSRect?,
        videoFrame: NSRect?
    ) -> VideoAttachmentSnapshot? {
        guard let videoFrame else { return nil }

        if let clusterKinds = WindowSnapManager.shared.clusterKinds(containing: .video) {
            if let playlistFrame, clusterKinds.contains(.playlist),
               let attachment = WindowDockingGeometry.determineAttachment(anchorFrame: playlistFrame, playlistFrame: videoFrame, strict: false) {
                return VideoAttachmentSnapshot(anchor: .playlist, attachment: attachment)
            }

            if clusterKinds.contains(.equalizer),
               let attachment = WindowDockingGeometry.determineAttachment(anchorFrame: eqFrame, playlistFrame: videoFrame, strict: false) {
                return VideoAttachmentSnapshot(anchor: .equalizer, attachment: attachment)
            }

            if clusterKinds.contains(.main),
               let attachment = WindowDockingGeometry.determineAttachment(anchorFrame: mainFrame, playlistFrame: videoFrame, strict: false) {
                return VideoAttachmentSnapshot(anchor: .main, attachment: attachment)
            }
        }

        return nil
    }

    // MARK: - Window Movement

    func movePlaylist(using context: PlaylistDockingContext, targetFrame: NSRect, playlistSize: NSSize, animated: Bool) {
        guard let playlist = registry.playlistWindow else { return }
        let origin = WindowDockingGeometry.playlistOrigin(for: context.attachment, anchorFrame: targetFrame, playlistSize: playlistSize)
        if animated {
            playlist.animator().setFrameOrigin(origin)
        } else {
            playlist.setFrameOrigin(origin)
        }

        let stage = animated ? "playlist move (animated)" : "playlist move"
        AppLog.debug(.window, "[DOCKING] \(stage) anchor=\(context.anchor): targetOrigin=(x: \(origin.x), y: \(origin.y)), actualFrame=\(playlist.frame)")
    }

    func moveVideoWindow(using context: VideoAttachmentSnapshot, targetFrame: NSRect, videoSize: NSSize, animated: Bool) {
        guard let video = registry.videoWindow else { return }
        let origin = WindowDockingGeometry.playlistOrigin(for: context.attachment, anchorFrame: targetFrame, playlistSize: videoSize)

        if animated {
            video.animator().setFrameOrigin(origin)
        } else {
            video.setFrameOrigin(origin)
        }

        AppLog.debug(.window, "[VIDEO DOCKING] anchor=\(context.anchor): targetOrigin=\(origin), actualFrame=\(video.frame)")
    }

    // MARK: - Window Size Updates

    func updateVideoWindowSize(to pixelSize: CGSize) {
        guard let video = registry.videoWindow else { return }

        var frame = video.frame
        guard frame.size != pixelSize else { return }

        AppLog.debug(.window, "[VIDEO RESIZE] Before: Frame: \(frame), Origin: (\(frame.origin.x), \(frame.origin.y)), Size: \(frame.size), ContentView: \(video.contentView?.frame ?? .zero)")

        let topLeft = NSPoint(
            x: round(frame.origin.x),
            y: round(frame.origin.y + frame.size.height)
        )
        frame.size = pixelSize
        frame.origin = NSPoint(x: topLeft.x, y: topLeft.y - pixelSize.height)

        video.setFrame(frame, display: true)

        AppLog.debug(.window, "[VIDEO RESIZE] After: Frame: \(video.frame), Origin: (\(video.frame.origin.x), \(video.frame.origin.y)), Size: \(video.frame.size)")
    }

    func updateMilkdropWindowSize(to pixelSize: CGSize) {
        guard let milkdrop = registry.milkdropWindow else { return }

        var frame = milkdrop.frame
        guard frame.size != pixelSize else { return }

        let roundedSize = CGSize(
            width: round(pixelSize.width),
            height: round(pixelSize.height)
        )

        let topLeft = NSPoint(
            x: round(frame.origin.x),
            y: round(frame.origin.y + frame.size.height)
        )
        frame.size = roundedSize
        frame.origin = NSPoint(x: topLeft.x, y: topLeft.y - roundedSize.height)

        milkdrop.setFrame(frame, display: true)

        AppLog.debug(.window, "[MILKDROP RESIZE] size: \(roundedSize), frame: \(frame)")
    }

    func updatePlaylistWindowSize(to pixelSize: CGSize) {
        guard let playlist = registry.playlistWindow else { return }

        var frame = playlist.frame
        guard frame.size != pixelSize else { return }

        let topLeft = NSPoint(
            x: round(frame.origin.x),
            y: round(frame.origin.y + frame.size.height)
        )
        frame.size = pixelSize
        frame.origin = NSPoint(x: topLeft.x, y: topLeft.y - pixelSize.height)

        playlist.setFrame(frame, display: true)

        AppLog.debug(.window, "[PLAYLIST RESIZE] size: \(pixelSize), frame: \(frame)")
    }

    // MARK: - Resize Preview Overlays

    func showVideoResizePreview(_ overlay: WindowResizePreviewOverlay, previewSize: CGSize) {
        guard let window = registry.videoWindow else { return }
        overlay.show(in: window, previewSize: previewSize)
    }

    func hideVideoResizePreview(_ overlay: WindowResizePreviewOverlay) {
        overlay.hide()
    }

    func showPlaylistResizePreview(_ overlay: WindowResizePreviewOverlay, previewSize: CGSize) {
        guard let window = registry.playlistWindow else { return }
        overlay.show(in: window, previewSize: previewSize)
    }

    func hidePlaylistResizePreview(_ overlay: WindowResizePreviewOverlay) {
        overlay.hide()
    }

    // MARK: - Debug Logging

    private func logDoubleSizeDebug(
        mainFrame: NSRect,
        eqFrame: NSRect,
        playlistFrame: NSRect?,
        dockingContext: PlaylistDockingContext?
    ) {
        AppLog.debug(.window, "=== DOUBLE-SIZE DEBUG ===")
        AppLog.debug(.window, "Main frame: \(mainFrame)")
        AppLog.debug(.window, "EQ frame: \(eqFrame)")
        AppLog.debug(.window, "Playlist frame: \(String(describing: playlistFrame))")
        if let context = dockingContext {
            AppLog.debug(.window, "[DOCKING] source: \(context.source.description), anchor=\(context.anchor), attachment=\(context.attachment.description)")
            AppLog.debug(.window, "Action: Playlist WILL move with EQ (cluster-locked)")
        } else if playlistFrame == nil {
            AppLog.debug(.window, "Docking detection: playlist window unavailable")
        } else {
            AppLog.debug(.window, "Action: Playlist stays independent (no docking context)")
        }
    }

    private func logDockingStage(
        _ stage: String,
        mainFrame: NSRect?,
        eqFrame: NSRect?,
        playlistFrame: NSRect?
    ) {
        AppLog.debug(.window, "[DOCKING] \(stage): main=\(String(describing: mainFrame)), eq=\(String(describing: eqFrame)), playlist=\(String(describing: playlistFrame))")
    }
}
