import AppKit
import Observation

private struct PlaylistAttachmentSnapshot {
    let anchor: WindowKind
    let attachment: PlaylistDockingContext.Attachment
}

// NEW: Video window attachment tracking (same pattern as playlist)
private struct VideoAttachmentSnapshot {
    let anchor: WindowKind
    let attachment: PlaylistDockingContext.Attachment  // Reuse attachment enum
}

private struct PlaylistDockingContext {
    enum Source: CustomStringConvertible {
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

    enum Attachment: CustomStringConvertible {
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

@MainActor
@Observable
final class WindowCoordinator {
    static var shared: WindowCoordinator!  // Initialized in MacAmpApp.init()

    private let mainController: NSWindowController
    private let eqController: NSWindowController
    private let playlistController: NSWindowController
    private let videoController: NSWindowController       // NEW: Video window controller
    private let milkdropController: NSWindowController    // NEW: Milkdrop window controller

    // Store references for observation/state checks
    private let settings: AppSettings
    private let skinManager: SkinManager
    private let windowFocusState: WindowFocusState  // NEW: Window focus tracking

    @ObservationIgnored private var skinPresentationTask: Task<Void, Never>?
    @ObservationIgnored private var alwaysOnTopTask: Task<Void, Never>?
    @ObservationIgnored private var doubleSizeTask: Task<Void, Never>?
    @ObservationIgnored private var persistenceTask: Task<Void, Never>?
    @ObservationIgnored private var videoWindowTask: Task<Void, Never>?  // NEW: Video window observer
    @ObservationIgnored private var milkdropWindowTask: Task<Void, Never>?  // NEW: Milkdrop window observer
    @ObservationIgnored private var videoSizeTask: Task<Void, Never>?  // NEW: Video window size observer
    private var hasPresentedInitialWindows = false
    private var persistenceSuppressionCount = 0
    private var windowKinds: [ObjectIdentifier: WindowKind] = [:]
    private let windowFrameStore = WindowFrameStore()
    private var persistenceDelegate: WindowPersistenceDelegate?
    private var mainFocusDelegate: WindowFocusDelegate?  // NEW: Focus delegates for all windows
    private var eqFocusDelegate: WindowFocusDelegate?
    private var playlistFocusDelegate: WindowFocusDelegate?
    private var videoFocusDelegate: WindowFocusDelegate?
    private var milkdropFocusDelegate: WindowFocusDelegate?
    private var lastPlaylistAttachment: PlaylistAttachmentSnapshot?
    private var lastVideoAttachment: VideoAttachmentSnapshot?  // NEW: Video attachment memory

    // Delegate multiplexers (must store as properties - NSWindow.delegate is weak)
    private var mainDelegateMultiplexer: WindowDelegateMultiplexer?
    private var eqDelegateMultiplexer: WindowDelegateMultiplexer?
    private var playlistDelegateMultiplexer: WindowDelegateMultiplexer?
    private var videoDelegateMultiplexer: WindowDelegateMultiplexer?       // NEW: Video window multiplexer
    private var milkdropDelegateMultiplexer: WindowDelegateMultiplexer?   // NEW: Milkdrop window multiplexer
    private enum LayoutDefaults {
        static let stackX: CGFloat = 100
        static let mainY: CGFloat = 500
        static let playlistMaxHeight: CGFloat = 900
    }

    var mainWindow: NSWindow? { mainController.window }
    var eqWindow: NSWindow? { eqController.window }
    var playlistWindow: NSWindow? { playlistController.window }
    var videoWindow: NSWindow? { videoController.window }           // NEW: Video window accessor
    var milkdropWindow: NSWindow? { milkdropController.window }     // NEW: Milkdrop window accessor

    init(skinManager: SkinManager, audioPlayer: AudioPlayer, dockingController: DockingController, settings: AppSettings, radioLibrary: RadioStationLibrary, playbackCoordinator: PlaybackCoordinator, windowFocusState: WindowFocusState) {
        // Store shared state references
        self.settings = settings
        self.skinManager = skinManager
        self.windowFocusState = windowFocusState

        // Create Main window with environment injection
        mainController = WinampMainWindowController(
            skinManager: skinManager,
            audioPlayer: audioPlayer,
            dockingController: dockingController,
            settings: settings,
            radioLibrary: radioLibrary,
            playbackCoordinator: playbackCoordinator,
            windowFocusState: windowFocusState
        )

        // Create EQ window with environment injection
        eqController = WinampEqualizerWindowController(
            skinManager: skinManager,
            audioPlayer: audioPlayer,
            dockingController: dockingController,
            settings: settings,
            radioLibrary: radioLibrary,
            playbackCoordinator: playbackCoordinator,
            windowFocusState: windowFocusState
        )

        // Create Playlist window with environment injection
        playlistController = WinampPlaylistWindowController(
            skinManager: skinManager,
            audioPlayer: audioPlayer,
            dockingController: dockingController,
            settings: settings,
            radioLibrary: radioLibrary,
            playbackCoordinator: playbackCoordinator,
            windowFocusState: windowFocusState
        )

        // NEW: Create Video window with environment injection
        videoController = WinampVideoWindowController(
            skinManager: skinManager,
            audioPlayer: audioPlayer,
            dockingController: dockingController,
            settings: settings,
            radioLibrary: radioLibrary,
            playbackCoordinator: playbackCoordinator,
            windowFocusState: windowFocusState
        )

        // NEW: Create Milkdrop window with environment injection
        milkdropController = WinampMilkdropWindowController(
            skinManager: skinManager,
            audioPlayer: audioPlayer,
            dockingController: dockingController,
            settings: settings,
            radioLibrary: radioLibrary,
            playbackCoordinator: playbackCoordinator,
            windowFocusState: windowFocusState
        )

        // Configure windows (borderless, transparent titlebar)
        configureWindows()
        mapWindowsToKinds()

        // Set initial window sizes based on current double-size state
        resizeMainAndEQWindows(
            doubled: settings.isDoubleSizeMode,
            animated: false,
            persistResult: false
        )
        debugLogWindowPositions(step: "after initial resizeMainAndEQWindows")

        // Apply persisted positions or fall back to defaults
        applyInitialWindowLayout()
        debugLogWindowPositions(step: "after applying initial window layout")

        // Show windows only after the initial skin has loaded
        presentWindowsWhenReady()
        debugLogWindowPositions(step: "after presentWindowsWhenReady call")

        // CRITICAL FIX #3: Set initial window levels from persisted always-on-top state
        // From UnifiedDockView.swift line 80
        let initialLevel: NSWindow.Level = settings.isAlwaysOnTop ? .floating : .normal
        mainWindow?.level = initialLevel
        eqWindow?.level = initialLevel
        playlistWindow?.level = initialLevel
        videoWindow?.level = initialLevel        // NEW: Include Video window
        milkdropWindow?.level = initialLevel     // NEW: Include Milkdrop window
        debugLogWindowPositions(step: "after initial window level assignment")

        // CRITICAL FIX #3: Observe always-on-top changes
        // From UnifiedDockView.swift lines 65-68
        // Note: AppSettings is @Observable, so we can track changes
        // Using withObservationTracking for reactive updates
        setupAlwaysOnTopObserver()
        debugLogWindowPositions(step: "after setupAlwaysOnTopObserver")

        // Observe for double-size changes
        setupDoubleSizeObserver()
        debugLogWindowPositions(step: "after setupDoubleSizeObserver")

        // Observe for video window visibility changes
        setupVideoWindowObserver()
        debugLogWindowPositions(step: "after setupVideoWindowObserver")

        // Observe for milkdrop window visibility changes
        setupMilkdropWindowObserver()
        debugLogWindowPositions(step: "after setupMilkdropWindowObserver")

        // NOTE: setupVideoSizeObserver removed - Size2D managed by VideoWindowSizeState directly

        // Register windows with WindowSnapManager for magnetic snapping and cluster movement
        if let main = mainWindow {
            WindowSnapManager.shared.register(window: main, kind: .main)
        }
        if let eq = eqWindow {
            WindowSnapManager.shared.register(window: eq, kind: .equalizer)
        }
        if let playlist = playlistWindow {
            WindowSnapManager.shared.register(window: playlist, kind: .playlist)
        }
        // NEW: Register Video and Milkdrop windows
        if let video = videoWindow {
            WindowSnapManager.shared.register(window: video, kind: .video)
        }
        if let milkdrop = milkdropWindow {
            WindowSnapManager.shared.register(window: milkdrop, kind: .milkdrop)
        }
        debugLogWindowPositions(step: "after WindowSnapManager registration")

        // Set up delegate multiplexers (allows multiple delegates per window)

        // Main window multiplexer
        mainDelegateMultiplexer = WindowDelegateMultiplexer()
        mainDelegateMultiplexer?.add(delegate: WindowSnapManager.shared)
        mainWindow?.delegate = mainDelegateMultiplexer

        // EQ window multiplexer
        eqDelegateMultiplexer = WindowDelegateMultiplexer()
        eqDelegateMultiplexer?.add(delegate: WindowSnapManager.shared)
        eqWindow?.delegate = eqDelegateMultiplexer

        // Playlist window multiplexer
        playlistDelegateMultiplexer = WindowDelegateMultiplexer()
        playlistDelegateMultiplexer?.add(delegate: WindowSnapManager.shared)
        playlistWindow?.delegate = playlistDelegateMultiplexer

        // NEW: Video window multiplexer
        videoDelegateMultiplexer = WindowDelegateMultiplexer()
        videoDelegateMultiplexer?.add(delegate: WindowSnapManager.shared)
        videoWindow?.delegate = videoDelegateMultiplexer

        // NEW: Milkdrop window multiplexer
        milkdropDelegateMultiplexer = WindowDelegateMultiplexer()
        milkdropDelegateMultiplexer?.add(delegate: WindowSnapManager.shared)
        milkdropWindow?.delegate = milkdropDelegateMultiplexer

        // Persist window movement/resizes
        persistenceDelegate = WindowPersistenceDelegate(coordinator: self)
        if let persistenceDelegate {
            mainDelegateMultiplexer?.add(delegate: persistenceDelegate)
            eqDelegateMultiplexer?.add(delegate: persistenceDelegate)
            playlistDelegateMultiplexer?.add(delegate: persistenceDelegate)
            videoDelegateMultiplexer?.add(delegate: persistenceDelegate)        // NEW
            milkdropDelegateMultiplexer?.add(delegate: persistenceDelegate)     // NEW
        }

        // Track window focus for active/inactive titlebar sprites
        mainFocusDelegate = WindowFocusDelegate(kind: .main, focusState: windowFocusState)
        eqFocusDelegate = WindowFocusDelegate(kind: .equalizer, focusState: windowFocusState)
        playlistFocusDelegate = WindowFocusDelegate(kind: .playlist, focusState: windowFocusState)
        videoFocusDelegate = WindowFocusDelegate(kind: .video, focusState: windowFocusState)
        milkdropFocusDelegate = WindowFocusDelegate(kind: .milkdrop, focusState: windowFocusState)

        if let mainFocusDelegate {
            mainDelegateMultiplexer?.add(delegate: mainFocusDelegate)
        }
        if let eqFocusDelegate {
            eqDelegateMultiplexer?.add(delegate: eqFocusDelegate)
        }
        if let playlistFocusDelegate {
            playlistDelegateMultiplexer?.add(delegate: playlistFocusDelegate)
        }
        if let videoFocusDelegate {
            videoDelegateMultiplexer?.add(delegate: videoFocusDelegate)
        }
        if let milkdropFocusDelegate {
            milkdropDelegateMultiplexer?.add(delegate: milkdropFocusDelegate)
        }

        debugLogWindowPositions(step: "after delegate multiplexer setup")
    }

    // Always-on-top observer using withObservationTracking for reactive updates
    private func setupAlwaysOnTopObserver() {
        // Cancel any existing observer
        alwaysOnTopTask?.cancel()

        // Use withObservationTracking for reactive updates (no polling)
        alwaysOnTopTask = Task { @MainActor [weak self] in
            guard let self else { return }

            // Recursive observation pattern
            withObservationTracking {
                _ = self.settings.isAlwaysOnTop
            } onChange: {
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.updateWindowLevels(self.settings.isAlwaysOnTop)
                    self.setupAlwaysOnTopObserver()  // Re-establish observer
                }
            }
        }
    }

    deinit {
        skinPresentationTask?.cancel()
        alwaysOnTopTask?.cancel()
        doubleSizeTask?.cancel()
        persistenceTask?.cancel()
        videoWindowTask?.cancel()
        milkdropWindowTask?.cancel()
        videoSizeTask?.cancel()
    }

    // Double-size observer (Main + EQ only, not Playlist)
    private func setupDoubleSizeObserver() {
        // Cancel any existing observer
        doubleSizeTask?.cancel()

        // Use withObservationTracking for reactive updates
        doubleSizeTask = Task { @MainActor [weak self] in
            guard let self else { return }

            // Recursive observation pattern
            withObservationTracking {
                _ = self.settings.isDoubleSizeMode
            } onChange: {
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.resizeMainAndEQWindows(doubled: self.settings.isDoubleSizeMode)
                    self.setupDoubleSizeObserver()  // Re-establish observer
                }
            }
        }
    }

    // Video window visibility observer - honors persisted showVideoWindow state
    private func setupVideoWindowObserver() {
        // Cancel any existing observer
        videoWindowTask?.cancel()

        // Use withObservationTracking for reactive updates
        videoWindowTask = Task { @MainActor [weak self] in
            guard let self else { return }

            // Recursive observation pattern
            withObservationTracking {
                _ = self.settings.showVideoWindow
            } onChange: {
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    // Only show VIDEO window after initial windows are presented
                    if self.settings.showVideoWindow {
                        if self.hasPresentedInitialWindows {
                            self.showVideo()
                        }
                        // If windows not ready yet, setting will be honored in presentInitialWindows()
                    } else {
                        self.hideVideo()
                    }
                    self.setupVideoWindowObserver()  // Re-establish observer
                }
            }
        }
    }

    // Milkdrop window visibility observer - honors persisted showMilkdropWindow state
    private func setupMilkdropWindowObserver() {
        AppLog.debug(.window, "setupMilkdropWindowObserver() called")
        // Cancel any existing observer
        milkdropWindowTask?.cancel()

        // Use withObservationTracking for reactive updates
        milkdropWindowTask = Task { @MainActor [weak self] in
            guard let self else { return }

            // Recursive observation pattern
            withObservationTracking {
                _ = self.settings.showMilkdropWindow
            } onChange: {
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    AppLog.debug(.window, "showMilkdropWindow changed to \(self.settings.showMilkdropWindow)")
                    // Only show Milkdrop window after initial windows are presented
                    if self.settings.showMilkdropWindow {
                        if self.hasPresentedInitialWindows {
                            self.showMilkdrop()
                        }
                        // If windows not ready yet, setting will be honored in presentInitialWindows()
                    } else {
                        self.hideMilkdrop()
                    }
                    self.setupMilkdropWindowObserver()  // Re-establish observer
                }
            }
        }
    }

    // NOTE: setupVideoSizeObserver() and resizeVideoWindow() removed
    // VIDEO window size now managed by VideoWindowSizeState directly
    // Size changes happen through drag gesture or button clicks in VideoWindowChromeView
    // NSWindow frame automatically updates based on SwiftUI .frame() modifier

    private func resizeMainAndEQWindows(doubled: Bool, animated _: Bool = true, persistResult: Bool = true) {
        guard let main = mainWindow, let eq = eqWindow else { return }

        let originalMainFrame = main.frame
        let originalEqFrame = eq.frame
        let originalPlaylistFrame = playlistWindow?.frame
        let playlistSize = originalPlaylistFrame?.size ?? playlistWindow?.frame.size
        let originalVideoFrame = videoWindow?.frame  // NEW: Capture video position
        let videoSize = originalVideoFrame?.size

        let dockingContext = makePlaylistDockingContext(
            mainFrame: originalMainFrame,
            eqFrame: originalEqFrame,
            playlistFrame: originalPlaylistFrame
        )

        // NEW: Detect video window docking
        let videoDockingContext = makeVideoDockingContext(
            mainFrame: originalMainFrame,
            eqFrame: originalEqFrame,
            playlistFrame: originalPlaylistFrame,
            videoFrame: originalVideoFrame
        )

        logDoubleSizeDebug(
            mainFrame: originalMainFrame,
            eqFrame: originalEqFrame,
            playlistFrame: originalPlaylistFrame,
            dockingContext: dockingContext
        )

        let scale: CGFloat = doubled ? 2.0 : 1.0
        var newMainFrame = originalMainFrame
        let newMainSize = CGSize(width: WinampSizes.main.width * scale, height: WinampSizes.main.height * scale)
        let mainDelta = newMainSize.height - newMainFrame.size.height
        newMainFrame.size = newMainSize
        newMainFrame.origin.y -= mainDelta

        var newEqFrame = originalEqFrame
        let newEqSize = CGSize(width: WinampSizes.equalizer.width * scale, height: WinampSizes.equalizer.height * scale)
        newEqFrame.size = newEqSize
        newEqFrame.origin.y = newMainFrame.origin.y - newEqFrame.size.height

        let animationAnchorFrame = dockingContext.flatMap { context in
            anchorFrame(context.anchor, mainFrame: newMainFrame, eqFrame: newEqFrame)
        }

        beginSuppressingPersistence()
        WindowSnapManager.shared.beginProgrammaticAdjustment()

        main.setFrame(newMainFrame, display: true)
        eq.setFrame(newEqFrame, display: true)

        if let context = dockingContext,
           let size = playlistSize,
           let anchorFrame = animationAnchorFrame ?? liveAnchorFrame(context.anchor) ?? anchorFrame(context.anchor, mainFrame: newMainFrame, eqFrame: newEqFrame) {
            movePlaylist(using: context, targetFrame: anchorFrame, playlistSize: size, animated: false)
        }

        // NEW: Move video window if docked
        if let videoContext = videoDockingContext,
           let size = videoSize,
           let anchorFrame = liveAnchorFrame(videoContext.anchor) ?? anchorFrame(videoContext.anchor, mainFrame: newMainFrame, eqFrame: newEqFrame, playlistFrame: playlistWindow?.frame) {
            moveVideoWindow(using: videoContext, targetFrame: anchorFrame, videoSize: size, animated: false)
        }

        logDockingStage(
            "post-resize actual",
            mainFrame: mainWindow?.frame,
            eqFrame: eqWindow?.frame,
            playlistFrame: playlistWindow?.frame
        )

        WindowSnapManager.shared.endProgrammaticAdjustment()
        endSuppressingPersistence()
        if persistResult {
            schedulePersistenceFlush()
        }
    }

    private func makePlaylistDockingContext(mainFrame: NSRect, eqFrame: NSRect, playlistFrame: NSRect?) -> PlaylistDockingContext? {
        guard let playlistFrame else { return nil }

        if let clusterKinds = WindowSnapManager.shared.clusterKinds(containing: .playlist) {
            if clusterKinds.contains(.equalizer),
               let attachment = determineAttachment(anchorFrame: eqFrame, playlistFrame: playlistFrame, strict: false) {
                let snapshot = PlaylistAttachmentSnapshot(anchor: .equalizer, attachment: attachment)
                lastPlaylistAttachment = snapshot
                return PlaylistDockingContext(anchor: .equalizer, attachment: attachment, source: .cluster(clusterKinds))
            }
            if clusterKinds.contains(.main),
               let attachment = determineAttachment(anchorFrame: mainFrame, playlistFrame: playlistFrame, strict: false) {
                let snapshot = PlaylistAttachmentSnapshot(anchor: .main, attachment: attachment)
                lastPlaylistAttachment = snapshot
                return PlaylistDockingContext(anchor: .main, attachment: attachment, source: .cluster(clusterKinds))
            }
            if let snapshot = lastPlaylistAttachment,
               clusterKinds.contains(snapshot.anchor),
               let anchorFrame = anchorFrame(snapshot.anchor, mainFrame: mainFrame, eqFrame: eqFrame),
               attachmentStillEligible(snapshot, anchorFrame: anchorFrame, playlistFrame: playlistFrame) {
                return PlaylistDockingContext(anchor: snapshot.anchor, attachment: snapshot.attachment, source: .memory)
            }
        }

        if let attachment = determineAttachment(anchorFrame: eqFrame, playlistFrame: playlistFrame) {
            let snapshot = PlaylistAttachmentSnapshot(anchor: .equalizer, attachment: attachment)
            lastPlaylistAttachment = snapshot
            return PlaylistDockingContext(anchor: .equalizer, attachment: attachment, source: .heuristic)
        }

        if let attachment = determineAttachment(anchorFrame: mainFrame, playlistFrame: playlistFrame) {
            let snapshot = PlaylistAttachmentSnapshot(anchor: .main, attachment: attachment)
            lastPlaylistAttachment = snapshot
            return PlaylistDockingContext(anchor: .main, attachment: attachment, source: .heuristic)
        }

        if let snapshot = lastPlaylistAttachment,
           let anchorFrame = anchorFrame(snapshot.anchor, mainFrame: mainFrame, eqFrame: eqFrame),
           attachmentStillEligible(snapshot, anchorFrame: anchorFrame, playlistFrame: playlistFrame) {
            return PlaylistDockingContext(anchor: snapshot.anchor, attachment: snapshot.attachment, source: .memory)
        }

        lastPlaylistAttachment = nil
        return nil
    }

    private func determineAttachment(anchorFrame: NSRect, playlistFrame: NSRect, strict: Bool = true) -> PlaylistDockingContext.Attachment? {
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

    private func playlistOrigin(for attachment: PlaylistDockingContext.Attachment, anchorFrame: NSRect, playlistSize: NSSize) -> NSPoint {
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

    private func attachmentStillEligible(_ snapshot: PlaylistAttachmentSnapshot, anchorFrame: NSRect, playlistFrame: NSRect) -> Bool {
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

    private func anchorFrame(_ anchor: WindowKind, mainFrame: NSRect, eqFrame: NSRect, playlistFrame: NSRect? = nil) -> NSRect? {
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

    private func liveAnchorFrame(_ anchor: WindowKind) -> NSRect? {
        switch anchor {
        case .main:
            return mainWindow?.frame
        case .equalizer:
            return eqWindow?.frame
        case .playlist:
            return playlistWindow?.frame
        default:
            return nil
        }
    }

    // NEW: Video window docking (same pattern as playlist)
    private func makeVideoDockingContext(
        mainFrame: NSRect,
        eqFrame: NSRect,
        playlistFrame: NSRect?,
        videoFrame: NSRect?
    ) -> VideoAttachmentSnapshot? {
        guard let videoFrame else { return nil }

        // Try cluster detection first
        if let clusterKinds = WindowSnapManager.shared.clusterKinds(containing: .video) {
            // Prefer playlist as anchor (video typically docks below playlist)
            if let playlistFrame, clusterKinds.contains(.playlist),
               let attachment = determineAttachment(anchorFrame: playlistFrame, playlistFrame: videoFrame, strict: false) {
                return VideoAttachmentSnapshot(anchor: .playlist, attachment: attachment)
            }

            if clusterKinds.contains(.equalizer),
               let attachment = determineAttachment(anchorFrame: eqFrame, playlistFrame: videoFrame, strict: false) {
                return VideoAttachmentSnapshot(anchor: .equalizer, attachment: attachment)
            }

            if clusterKinds.contains(.main),
               let attachment = determineAttachment(anchorFrame: mainFrame, playlistFrame: videoFrame, strict: false) {
                return VideoAttachmentSnapshot(anchor: .main, attachment: attachment)
            }
        }

        return nil
    }

    private func moveVideoWindow(using context: VideoAttachmentSnapshot, targetFrame: NSRect, videoSize: NSSize, animated: Bool) {
        guard let video = videoWindow else { return }
        let origin = playlistOrigin(for: context.attachment, anchorFrame: targetFrame, playlistSize: videoSize)

        if animated {
            video.animator().setFrameOrigin(origin)
        } else {
            video.setFrameOrigin(origin)
        }

        AppLog.debug(.window, "[VIDEO DOCKING] anchor=\(context.anchor): targetOrigin=\(origin), actualFrame=\(video.frame)")
    }

    func updateVideoWindowSize(to pixelSize: CGSize) {
        guard let video = videoWindow else { return }

        var frame = video.frame
        guard frame.size != pixelSize else { return }

        // DIAGNOSTIC: Log frame details to investigate left gap
        AppLog.debug(.window, "[VIDEO RESIZE] Before: Frame: \(frame), Origin: (\(frame.origin.x), \(frame.origin.y)), Size: \(frame.size), ContentView: \(video.contentView?.frame ?? .zero)")

        // Clamp origin to integral coordinates (fixes fractional positioning)
        let topLeft = NSPoint(
            x: round(frame.origin.x),
            y: round(frame.origin.y + frame.size.height)
        )
        frame.size = pixelSize
        frame.origin = NSPoint(x: topLeft.x, y: topLeft.y - pixelSize.height)

        video.setFrame(frame, display: true)

        // DIAGNOSTIC: Log after setFrame
        AppLog.debug(.window, "[VIDEO RESIZE] After: Frame: \(video.frame), Origin: (\(video.frame.origin.x), \(video.frame.origin.y)), Size: \(video.frame.size)")
    }

    // MARK: - Window Visibility Control (AppKit Bridge)
    // These methods encapsulate AppKit calls so SwiftUI views don't directly manipulate NSWindow objects

    /// Minimize the current key window (called from SwiftUI minimize buttons)
    func minimizeKeyWindow() {
        NSApp.keyWindow?.miniaturize(nil)
    }

    /// Close the current key window (called from SwiftUI close buttons)
    func closeKeyWindow() {
        NSApp.keyWindow?.close()
    }

    /// Show the EQ window
    func showEQWindow() {
        eqWindow?.orderFront(nil)
        isEQWindowVisible = true
    }

    /// Hide the EQ window
    func hideEQWindow() {
        eqWindow?.orderOut(nil)
        isEQWindowVisible = false
    }

    /// Toggle EQ window visibility, returns new visibility state
    func toggleEQWindowVisibility() -> Bool {
        guard let eq = eqWindow else { return false }
        if eq.isVisible {
            eq.orderOut(nil)
            isEQWindowVisible = false
            return false
        } else {
            eq.orderFront(nil)
            isEQWindowVisible = true
            return true
        }
    }

    /// Show the Playlist window
    func showPlaylistWindow() {
        playlistWindow?.orderFront(nil)
        isPlaylistWindowVisible = true
    }

    /// Hide the Playlist window
    func hidePlaylistWindow() {
        playlistWindow?.orderOut(nil)
        isPlaylistWindowVisible = false
    }

    /// Toggle Playlist window visibility, returns new visibility state
    func togglePlaylistWindowVisibility() -> Bool {
        guard let playlist = playlistWindow else { return false }
        if playlist.isVisible {
            playlist.orderOut(nil)
            isPlaylistWindowVisible = false
            return false
        } else {
            playlist.orderFront(nil)
            isPlaylistWindowVisible = true
            return true
        }
    }

    /// Observable EQ window visibility state (source of truth for SwiftUI binding)
    var isEQWindowVisible: Bool = false

    /// Observable Playlist window visibility state (source of truth for SwiftUI binding)
    var isPlaylistWindowVisible: Bool = false

    /// Check if EQ window is currently visible (read from NSWindow)
    var isEQWindowCurrentlyVisible: Bool {
        eqWindow?.isVisible ?? false
    }

    /// Check if Playlist window is currently visible (read from NSWindow)
    var isPlaylistWindowCurrentlyVisible: Bool {
        playlistWindow?.isVisible ?? false
    }

    /// Show resize preview overlay for video window (AppKit bridge)
    func showVideoResizePreview(_ overlay: WindowResizePreviewOverlay, previewSize: CGSize) {
        guard let window = videoWindow else { return }
        overlay.show(in: window, previewSize: previewSize)
    }

    /// Hide resize preview overlay for video window (AppKit bridge)
    func hideVideoResizePreview(_ overlay: WindowResizePreviewOverlay) {
        overlay.hide()
    }

    // MARK: - Playlist Resize Coordination (Phase 3)

    /// Show resize preview overlay for playlist window (AppKit bridge)
    func showPlaylistResizePreview(_ overlay: WindowResizePreviewOverlay, previewSize: CGSize) {
        guard let window = playlistWindow else { return }
        overlay.show(in: window, previewSize: previewSize)
    }

    /// Hide resize preview overlay for playlist window (AppKit bridge)
    func hidePlaylistResizePreview(_ overlay: WindowResizePreviewOverlay) {
        overlay.hide()
    }

    /// Update playlist window frame to match new size (AppKit bridge)
    /// Note: Playlist window does NOT use double-size mode (only main/EQ windows scale)
    func updatePlaylistWindowSize(to pixelSize: CGSize) {
        guard let playlist = playlistWindow else { return }

        var frame = playlist.frame
        guard frame.size != pixelSize else { return }

        // Preserve top-left anchor (macOS uses bottom-left origin)
        let topLeft = NSPoint(
            x: round(frame.origin.x),
            y: round(frame.origin.y + frame.size.height)
        )
        frame.size = pixelSize
        frame.origin = NSPoint(x: topLeft.x, y: topLeft.y - pixelSize.height)

        playlist.setFrame(frame, display: true)

        AppLog.debug(.window, "[PLAYLIST RESIZE] size: \(pixelSize), frame: \(frame)")
    }

    private func movePlaylist(using context: PlaylistDockingContext, targetFrame: NSRect, playlistSize: NSSize, animated: Bool) {
        guard let playlist = playlistWindow else { return }
        let origin = playlistOrigin(for: context.attachment, anchorFrame: targetFrame, playlistSize: playlistSize)
        if animated {
            playlist.animator().setFrameOrigin(origin)
        } else {
            playlist.setFrameOrigin(origin)
        }

        let stage = animated ? "playlist move (animated)" : "playlist move"
        AppLog.debug(.window, "[DOCKING] \(stage) anchor=\(context.anchor): targetOrigin=(x: \(origin.x), y: \(origin.y)), actualFrame=\(playlist.frame)")
    }

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

    private func debugLogWindowPositions(step: String) {
        AppLog.debug(.window, step)

        func describe(window: NSWindow?, label: String) {
            guard let window else {
                AppLog.debug(.window, "  \(label): unavailable")
                return
            }
            let frame = window.frame
            AppLog.debug(.window, "  \(label): origin=(x: \(frame.origin.x), y: \(frame.origin.y)) size=(w: \(frame.size.width), h: \(frame.size.height))")
        }

        describe(window: mainWindow, label: "Main")
        describe(window: eqWindow, label: "EQ")
        describe(window: playlistWindow, label: "Playlist")
    }

    private func updateWindowLevels(_ alwaysOnTop: Bool) {
        let level: NSWindow.Level = alwaysOnTop ? .floating : .normal
        mainWindow?.level = level
        eqWindow?.level = level
        playlistWindow?.level = level
        videoWindow?.level = level        // NEW: Include Video window
        milkdropWindow?.level = level     // NEW: Include Milkdrop window
    }

    private var canPresentImmediately: Bool {
        if skinManager.isLoading {
            return false
        }
        if skinManager.currentSkin != nil {
            return true
        }
        return skinManager.loadingError != nil
    }

    private func presentWindowsWhenReady() {
        if canPresentImmediately {
            presentInitialWindows()
            return
        }

        skinPresentationTask?.cancel()
        skinPresentationTask = Task { @MainActor [weak self] in
            guard let self else { return }
            while !self.canPresentImmediately {
                // Check for cancellation to prevent zombie tasks
                if Task.isCancelled { return }
                try? await Task.sleep(for: .milliseconds(50))
            }
            // Final cancellation check before presenting
            if Task.isCancelled { return }
            self.presentInitialWindows()
        }
    }

    private func presentInitialWindows() {
        guard !hasPresentedInitialWindows else { return }
        hasPresentedInitialWindows = true
        NSApp.activate(ignoringOtherApps: true)
        showAllWindows()
    }

    private func configureWindows() {
        // Additional window configuration (windows already created as borderless in controllers)
        [mainWindow, eqWindow, playlistWindow, videoWindow, milkdropWindow].forEach { window in
            window?.level = .normal
            window?.collectionBehavior = [.managed, .participatesInCycle]
        }
    }

    private func setDefaultPositions() {
        // Stack vertically with ZERO spacing (VStack spacing: 0)
        // AppKit origin = bottom-left, so we calculate from top down
        // Main at Y=500, each window positioned directly below the one above
        performWithoutPersistence {
            let x = LayoutDefaults.stackX
            let mainY = LayoutDefaults.mainY

            // Main window
            mainWindow?.setFrameOrigin(NSPoint(x: x, y: mainY))

            // EQ directly below Main
            if let eqHeight = eqWindow?.frame.size.height {
                eqWindow?.setFrameOrigin(NSPoint(x: x, y: mainY - eqHeight))
            }

            // Playlist directly below EQ
            if let eqY = eqWindow?.frame.origin.y,
               let playlistHeight = playlistWindow?.frame.size.height {
                playlistWindow?.setFrameOrigin(NSPoint(x: x, y: eqY - playlistHeight))
            }

            // Video directly below Playlist (if visible)
            if let playlistY = playlistWindow?.frame.origin.y,
               let videoHeight = videoWindow?.frame.size.height {
                videoWindow?.setFrameOrigin(NSPoint(x: x, y: playlistY - videoHeight))
            }

            // Milkdrop directly below Video (if visible)
            if let videoY = videoWindow?.frame.origin.y,
               let milkdropHeight = milkdropWindow?.frame.size.height {
                milkdropWindow?.setFrameOrigin(NSPoint(x: x, y: videoY - milkdropHeight))
            }
        }

        AppLog.debug(.window, "Default positions set (should be touching with 0 spacing):")
        if let main = mainWindow { AppLog.debug(.window, "  Main: \(main.frame)") }
        if let eq = eqWindow { AppLog.debug(.window, "  EQ: \(eq.frame)") }
        if let playlist = playlistWindow { AppLog.debug(.window, "  Playlist: \(playlist.frame)") }
        if let video = videoWindow { AppLog.debug(.window, "  Video: \(video.frame)") }
        if let milkdrop = milkdropWindow { AppLog.debug(.window, "  Milkdrop: \(milkdrop.frame)") }
    }

    /// Reset windows to default vertical stack (for testing double-size docking)
    /// Call this to ensure windows are properly docked before testing
    func resetToDefaultStack() {
        // Disable snap manager during reset
        WindowSnapManager.shared.beginProgrammaticAdjustment()
        beginSuppressingPersistence()

        // Calculate positions based on current window sizes
        guard let main = mainWindow, let eq = eqWindow, let playlist = playlistWindow else {
            WindowSnapManager.shared.endProgrammaticAdjustment()
            endSuppressingPersistence()
            return
        }

        let x = LayoutDefaults.stackX  // Aligned X position

        // Main at top
        var mainFrame = main.frame
        mainFrame.origin = NSPoint(x: x, y: LayoutDefaults.mainY)
        main.setFrame(mainFrame, display: true)

        // EQ directly below Main (zero spacing)
        var eqFrame = eq.frame
        eqFrame.origin = NSPoint(x: x, y: mainFrame.origin.y - eqFrame.size.height)
        eq.setFrame(eqFrame, display: true)

        // Playlist directly below EQ (zero spacing)
        var playlistFrame = playlist.frame
        playlistFrame.origin = NSPoint(x: x, y: eqFrame.origin.y - playlistFrame.size.height)
        playlist.setFrame(playlistFrame, display: true)

        WindowSnapManager.shared.endProgrammaticAdjustment()
        endSuppressingPersistence()
        schedulePersistenceFlush()

        AppLog.debug(.window, "Windows reset to default vertical stack")
        AppLog.debug(.window, "  Main: \(mainFrame)")
        AppLog.debug(.window, "  EQ: \(eqFrame)")
        AppLog.debug(.window, "  Playlist: \(playlistFrame)")
    }

    private func applyInitialWindowLayout() {
        setDefaultPositions()
        _ = applyPersistedWindowPositions()
        persistAllWindowFrames()
    }

    @discardableResult
    private func applyPersistedWindowPositions() -> Bool {
        var applied = false
        performWithoutPersistence {
            if let main = mainWindow,
               let storedMain = windowFrameStore.frame(for: .main) {
                var frame = main.frame
                frame.size = CGSize(
                    width: WinampSizes.main.width * (settings.isDoubleSizeMode ? 2 : 1),
                    height: WinampSizes.main.height * (settings.isDoubleSizeMode ? 2 : 1)
                )
                frame.origin = storedMain.origin
                main.setFrame(frame, display: true)
                applied = true
            }

            if let eq = eqWindow,
               let storedEq = windowFrameStore.frame(for: .equalizer) {
                var frame = eq.frame
                frame.size = CGSize(
                    width: WinampSizes.equalizer.width * (settings.isDoubleSizeMode ? 2 : 1),
                    height: WinampSizes.equalizer.height * (settings.isDoubleSizeMode ? 2 : 1)
                )
                frame.origin = storedEq.origin
                eq.setFrame(frame, display: true)
                applied = true
            }

            if let playlist = playlistWindow,
               var storedPlaylist = windowFrameStore.frame(for: .playlist) {
                storedPlaylist.size.width = WinampSizes.playlistBase.width
                let clampedHeight = max(
                    WinampSizes.playlistBase.height,
                    min(LayoutDefaults.playlistMaxHeight, storedPlaylist.size.height)
                )
                storedPlaylist.size.height = clampedHeight
                playlist.setFrame(storedPlaylist, display: true)
                applied = true
            }

            // NEW: Restore video window position (video doesn't resize, only position)
            if let video = videoWindow,
               let storedVideo = windowFrameStore.frame(for: .video) {
                var frame = video.frame
                frame.origin = storedVideo.origin  // Keep size fixed at 275x232
                video.setFrame(frame, display: true)
                applied = true
            }

            // NEW: Restore milkdrop window position (milkdrop doesn't resize, only position)
            if let milkdrop = milkdropWindow,
               let storedMilkdrop = windowFrameStore.frame(for: .milkdrop) {
                var frame = milkdrop.frame
                frame.origin = storedMilkdrop.origin  // Keep size fixed
                milkdrop.setFrame(frame, display: true)
                applied = true
            }
        }
        return applied
    }

    private func persistAllWindowFrames() {
        if let main = mainWindow {
            windowFrameStore.save(frame: main.frame, for: .main)
        }
        if let eq = eqWindow {
            windowFrameStore.save(frame: eq.frame, for: .equalizer)
        }
        if let playlist = playlistWindow {
            windowFrameStore.save(frame: playlist.frame, for: .playlist)
        }
        // NEW: Persist video and milkdrop windows
        if let video = videoWindow {
            windowFrameStore.save(frame: video.frame, for: .video)
        }
        if let milkdrop = milkdropWindow {
            windowFrameStore.save(frame: milkdrop.frame, for: .milkdrop)
        }
    }

    private func schedulePersistenceFlush() {
        guard persistenceSuppressionCount == 0 else { return }
        persistenceTask?.cancel()
        persistenceTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(150))
            guard let self else { return }
            self.persistAllWindowFrames()
        }
    }

    private func handleWindowGeometryChange(notification: Notification) {
        guard persistenceSuppressionCount == 0 else { return }
        guard let window = notification.object as? NSWindow else { return }
        guard windowKind(for: window) != nil else { return }
        schedulePersistenceFlush()
    }

    private func mapWindowsToKinds() {
        windowKinds.removeAll()
        if let main = mainWindow {
            windowKinds[ObjectIdentifier(main)] = .main
        }
        if let eq = eqWindow {
            windowKinds[ObjectIdentifier(eq)] = .equalizer
        }
        if let playlist = playlistWindow {
            windowKinds[ObjectIdentifier(playlist)] = .playlist
        }
        // NEW: Map video and milkdrop windows
        if let video = videoWindow {
            windowKinds[ObjectIdentifier(video)] = .video
        }
        if let milkdrop = milkdropWindow {
            windowKinds[ObjectIdentifier(milkdrop)] = .milkdrop
        }
    }

    private func windowKind(for window: NSWindow) -> WindowKind? {
        windowKinds[ObjectIdentifier(window)]
    }

    private func beginSuppressingPersistence() {
        persistenceSuppressionCount += 1
    }

    private func endSuppressingPersistence() {
        persistenceSuppressionCount = max(0, persistenceSuppressionCount - 1)
    }

    private func performWithoutPersistence(_ work: () -> Void) {
        beginSuppressingPersistence()
        work()
        endSuppressingPersistence()
    }

    func showAllWindows() {
        mainWindow?.makeKeyAndOrderFront(nil)
        eqWindow?.orderFront(nil)
        playlistWindow?.orderFront(nil)

        // Update observable visibility state
        isEQWindowVisible = true
        isPlaylistWindowVisible = true

        // Show VIDEO/Milkdrop if user had them open previously
        if settings.showVideoWindow {
            videoWindow?.orderFront(nil)
        }
        if settings.showMilkdropWindow {
            milkdropWindow?.orderFront(nil)
        }

        focusAllWindows()
    }

    // Menu command integration
    func showMain() { mainWindow?.makeKeyAndOrderFront(nil) }
    func hideMain() { mainWindow?.orderOut(nil) }
    func showEqualizer() {
        eqWindow?.makeKeyAndOrderFront(nil)
        isEQWindowVisible = true
    }
    func hideEqualizer() {
        eqWindow?.orderOut(nil)
        isEQWindowVisible = false
    }
    func showPlaylist() {
        playlistWindow?.makeKeyAndOrderFront(nil)
        isPlaylistWindowVisible = true
    }
    func hidePlaylist() {
        playlistWindow?.orderOut(nil)
        isPlaylistWindowVisible = false
    }
    // NEW: Video and Milkdrop window show/hide
    func showVideo() {
        AppLog.debug(.window, "showVideo() called")
        videoWindow?.makeKeyAndOrderFront(nil)
    }
    func hideVideo() {
        AppLog.debug(.window, "hideVideo() called")
        videoWindow?.orderOut(nil)
    }
    func showMilkdrop() {
        AppLog.debug(.window, "showMilkdrop() called, window exists: \(milkdropWindow != nil)")
        milkdropWindow?.makeKeyAndOrderFront(nil)
        AppLog.debug(.window, "milkdropWindow.isVisible: \(milkdropWindow?.isVisible ?? false)")
    }
    func hideMilkdrop() {
        AppLog.debug(.window, "hideMilkdrop() called")
        milkdropWindow?.orderOut(nil)
    }

    private func focusAllWindows() {
        [mainWindow, eqWindow, playlistWindow, videoWindow, milkdropWindow].forEach { window in
            if let contentView = window?.contentView {
                window?.makeFirstResponder(contentView)
            }
        }
    }

    private struct PersistedWindowFrame: Codable {
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

    private struct WindowFrameStore {
        private let defaults = UserDefaults.standard
        private let encoder = JSONEncoder()
        private let decoder = JSONDecoder()

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

    @MainActor
    private final class WindowPersistenceDelegate: NSObject, NSWindowDelegate {
        weak var coordinator: WindowCoordinator?

        init(coordinator: WindowCoordinator) {
            self.coordinator = coordinator
        }

        func windowDidMove(_ notification: Notification) {
            coordinator?.handleWindowGeometryChange(notification: notification)
        }

        func windowDidResize(_ notification: Notification) {
            coordinator?.handleWindowGeometryChange(notification: notification)
        }
    }
}

private extension WindowKind {
    var persistenceKey: String {
        switch self {
        case .main: return "main"
        case .playlist: return "playlist"
        case .equalizer: return "equalizer"
        case .video: return "video"           // NEW: Video window persistence key
        case .milkdrop: return "milkdrop"     // NEW: Milkdrop window persistence key
        }
    }
}
