import AppKit
import Observation

@MainActor
@Observable
// swiftlint:disable:next type_body_length
final class WindowCoordinator {
    // swiftlint:disable:next implicitly_unwrapped_optional
    static var shared: WindowCoordinator!  // Initialized in MacAmpApp.init()

    let registry: WindowRegistry
    // Store references for observation/state checks
    private let settings: AppSettings
    private let skinManager: SkinManager
    private let windowFocusState: WindowFocusState
    @ObservationIgnored private var skinPresentationTask: Task<Void, Never>?
    @ObservationIgnored private var alwaysOnTopTask: Task<Void, Never>?
    @ObservationIgnored private var doubleSizeTask: Task<Void, Never>?
    let framePersistence: WindowFramePersistence
    let visibility: WindowVisibilityController
    let resizeController: WindowResizeController
    @ObservationIgnored private var videoWindowTask: Task<Void, Never>?
    @ObservationIgnored private var milkdropWindowTask: Task<Void, Never>?
    @ObservationIgnored private var videoSizeTask: Task<Void, Never>?
    private var hasPresentedInitialWindows = false
    // swiftlint:disable weak_delegate
    private var mainFocusDelegate: WindowFocusDelegate?
    private var eqFocusDelegate: WindowFocusDelegate?
    private var playlistFocusDelegate: WindowFocusDelegate?
    private var videoFocusDelegate: WindowFocusDelegate?
    private var milkdropFocusDelegate: WindowFocusDelegate?
    // swiftlint:enable weak_delegate
    // Delegate multiplexers (must store as properties - NSWindow.delegate is weak)
    private var mainDelegateMultiplexer: WindowDelegateMultiplexer?
    private var eqDelegateMultiplexer: WindowDelegateMultiplexer?
    private var playlistDelegateMultiplexer: WindowDelegateMultiplexer?
    private var videoDelegateMultiplexer: WindowDelegateMultiplexer?
    private var milkdropDelegateMultiplexer: WindowDelegateMultiplexer?
    private enum LayoutDefaults {
        static let stackX: CGFloat = 100
        static let mainY: CGFloat = 500
    }

    var mainWindow: NSWindow? { registry.mainWindow }
    var eqWindow: NSWindow? { registry.eqWindow }
    var playlistWindow: NSWindow? { registry.playlistWindow }
    var videoWindow: NSWindow? { registry.videoWindow }
    var milkdropWindow: NSWindow? { registry.milkdropWindow }
    // swiftlint:disable:next function_body_length
    init(skinManager: SkinManager, audioPlayer: AudioPlayer, dockingController: DockingController, settings: AppSettings, radioLibrary: RadioStationLibrary, playbackCoordinator: PlaybackCoordinator, windowFocusState: WindowFocusState) {
        // Store shared state references
        self.settings = settings
        self.skinManager = skinManager
        self.windowFocusState = windowFocusState

        // Create all window controllers and wrap in registry
        registry = WindowRegistry(
            mainController: WinampMainWindowController(
                skinManager: skinManager, audioPlayer: audioPlayer,
                dockingController: dockingController, settings: settings,
                radioLibrary: radioLibrary, playbackCoordinator: playbackCoordinator,
                windowFocusState: windowFocusState
            ),
            eqController: WinampEqualizerWindowController(
                skinManager: skinManager, audioPlayer: audioPlayer,
                dockingController: dockingController, settings: settings,
                radioLibrary: radioLibrary, playbackCoordinator: playbackCoordinator,
                windowFocusState: windowFocusState
            ),
            playlistController: WinampPlaylistWindowController(
                skinManager: skinManager, audioPlayer: audioPlayer,
                dockingController: dockingController, settings: settings,
                radioLibrary: radioLibrary, playbackCoordinator: playbackCoordinator,
                windowFocusState: windowFocusState
            ),
            videoController: WinampVideoWindowController(
                skinManager: skinManager, audioPlayer: audioPlayer,
                dockingController: dockingController, settings: settings,
                radioLibrary: radioLibrary, playbackCoordinator: playbackCoordinator,
                windowFocusState: windowFocusState
            ),
            milkdropController: WinampMilkdropWindowController(
                skinManager: skinManager, audioPlayer: audioPlayer,
                dockingController: dockingController, settings: settings,
                radioLibrary: radioLibrary, playbackCoordinator: playbackCoordinator,
                windowFocusState: windowFocusState
            )
        )

        // Create persistence controller
        framePersistence = WindowFramePersistence(registry: registry, settings: settings)

        // Create visibility controller
        visibility = WindowVisibilityController(registry: registry, settings: settings)

        // Create resize controller
        resizeController = WindowResizeController(registry: registry, persistence: framePersistence)

        // Configure windows (borderless, transparent titlebar)
        configureWindows()

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

        // Set initial window levels from persisted always-on-top state
        let initialLevel: NSWindow.Level = settings.isAlwaysOnTop ? .floating : .normal
        mainWindow?.level = initialLevel
        eqWindow?.level = initialLevel
        playlistWindow?.level = initialLevel
        videoWindow?.level = initialLevel
        milkdropWindow?.level = initialLevel
        debugLogWindowPositions(step: "after initial window level assignment")

        // Observe always-on-top changes
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

         videoDelegateMultiplexer = WindowDelegateMultiplexer()
        videoDelegateMultiplexer?.add(delegate: WindowSnapManager.shared)
        videoWindow?.delegate = videoDelegateMultiplexer

             milkdropDelegateMultiplexer = WindowDelegateMultiplexer()
        milkdropDelegateMultiplexer?.add(delegate: WindowSnapManager.shared)
        milkdropWindow?.delegate = milkdropDelegateMultiplexer

        // Persist window movement/resizes
        if let delegate = framePersistence.persistenceDelegate {
            mainDelegateMultiplexer?.add(delegate: delegate)
            eqDelegateMultiplexer?.add(delegate: delegate)
            playlistDelegateMultiplexer?.add(delegate: delegate)
            videoDelegateMultiplexer?.add(delegate: delegate)
            milkdropDelegateMultiplexer?.add(delegate: delegate)
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

    // MARK: - Window Resize (forwarded to WindowResizeController)

    private func resizeMainAndEQWindows(doubled: Bool, animated: Bool = true, persistResult: Bool = true) {
        resizeController.resizeMainAndEQWindows(doubled: doubled, animated: animated, persistResult: persistResult)
    }

    func updateVideoWindowSize(to pixelSize: CGSize) { resizeController.updateVideoWindowSize(to: pixelSize) }
    func updateMilkdropWindowSize(to pixelSize: CGSize) { resizeController.updateMilkdropWindowSize(to: pixelSize) }
    func updatePlaylistWindowSize(to pixelSize: CGSize) { resizeController.updatePlaylistWindowSize(to: pixelSize) }

    func showVideoResizePreview(_ overlay: WindowResizePreviewOverlay, previewSize: CGSize) {
        resizeController.showVideoResizePreview(overlay, previewSize: previewSize)
    }

    func hideVideoResizePreview(_ overlay: WindowResizePreviewOverlay) {
        resizeController.hideVideoResizePreview(overlay)
    }

    func showPlaylistResizePreview(_ overlay: WindowResizePreviewOverlay, previewSize: CGSize) {
        resizeController.showPlaylistResizePreview(overlay, previewSize: previewSize)
    }

    func hidePlaylistResizePreview(_ overlay: WindowResizePreviewOverlay) {
        resizeController.hidePlaylistResizePreview(overlay)
    }

    // MARK: - Window Visibility (forwarded to WindowVisibilityController)

    func minimizeKeyWindow() { visibility.minimizeKeyWindow() }
    func closeKeyWindow() { visibility.closeKeyWindow() }
    func showEQWindow() { visibility.showEQWindow() }
    func hideEQWindow() { visibility.hideEQWindow() }
    func toggleEQWindowVisibility() -> Bool { visibility.toggleEQWindowVisibility() }
    func showPlaylistWindow() { visibility.showPlaylistWindow() }
    func hidePlaylistWindow() { visibility.hidePlaylistWindow() }
    func togglePlaylistWindowVisibility() -> Bool { visibility.togglePlaylistWindowVisibility() }

    var isEQWindowVisible: Bool {
        get { visibility.isEQWindowVisible }
        set { visibility.isEQWindowVisible = newValue }
    }

    var isPlaylistWindowVisible: Bool {
        get { visibility.isPlaylistWindowVisible }
        set { visibility.isPlaylistWindowVisible = newValue }
    }

    var isEQWindowCurrentlyVisible: Bool { visibility.isEQWindowCurrentlyVisible }
    var isPlaylistWindowCurrentlyVisible: Bool { visibility.isPlaylistWindowCurrentlyVisible }

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
        videoWindow?.level = level
        milkdropWindow?.level = level
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
        framePersistence.applyPersistedWindowPositions()
    }

    private func persistAllWindowFrames() {
        framePersistence.persistAllWindowFrames()
    }

    private func schedulePersistenceFlush() {
        framePersistence.schedulePersistenceFlush()
    }

    private func windowKind(for window: NSWindow) -> WindowKind? {
        registry.windowKind(for: window)
    }

    private func beginSuppressingPersistence() {
        framePersistence.beginSuppressingPersistence()
    }

    private func endSuppressingPersistence() {
        framePersistence.endSuppressingPersistence()
    }

    private func performWithoutPersistence(_ work: () -> Void) {
        framePersistence.performWithoutPersistence(work)
    }

    func showAllWindows() { visibility.showAllWindows() }
    func showMain() { visibility.showMain() }
    func hideMain() { visibility.hideMain() }
    func showEqualizer() { visibility.showEqualizer() }
    func hideEqualizer() { visibility.hideEqualizer() }
    func showPlaylist() { visibility.showPlaylist() }
    func hidePlaylist() { visibility.hidePlaylist() }
    func showVideo() { visibility.showVideo() }
    func hideVideo() { visibility.hideVideo() }
    func showMilkdrop() { visibility.showMilkdrop() }
    func hideMilkdrop() { visibility.hideMilkdrop() }
}
