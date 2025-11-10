import AppKit
import Observation  // ORACLE CODE QUALITY: Required for @Observable

private struct PlaylistDockingSnapshot {
    let playlistFrame: NSRect
    let eqFrame: NSRect
    let horizontalOverlap: Bool
    let horizontalDelta: CGFloat
    let verticalDelta: CGFloat
    let tolerance: CGFloat

    var isDocked: Bool { horizontalOverlap && verticalDelta < tolerance }
}

@MainActor
@Observable
final class WindowCoordinator {
    static var shared: WindowCoordinator!  // Initialized in MacAmpApp.init()

    private let mainController: NSWindowController
    private let eqController: NSWindowController
    private let playlistController: NSWindowController

    // Store references for observation/state checks
    private let settings: AppSettings
    private let skinManager: SkinManager

    @ObservationIgnored private var skinPresentationTask: Task<Void, Never>?
    @ObservationIgnored private var alwaysOnTopTask: Task<Void, Never>?
    @ObservationIgnored private var doubleSizeTask: Task<Void, Never>?
    @ObservationIgnored private var persistenceTask: Task<Void, Never>?
    private var hasPresentedInitialWindows = false
    private var persistenceSuppressionCount = 0
    private var windowKinds: [ObjectIdentifier: WindowKind] = [:]
    private let windowFrameStore = WindowFrameStore()
    private var persistenceDelegate: WindowPersistenceDelegate?

    // PHASE 3: Delegate multiplexers (must store as properties - NSWindow.delegate is weak!)
    private var mainDelegateMultiplexer: WindowDelegateMultiplexer?
    private var eqDelegateMultiplexer: WindowDelegateMultiplexer?
    private var playlistDelegateMultiplexer: WindowDelegateMultiplexer?
    private enum LayoutDefaults {
        static let stackX: CGFloat = 100
        static let mainY: CGFloat = 500
        static let playlistMaxHeight: CGFloat = 900
    }

    var mainWindow: NSWindow? { mainController.window }
    var eqWindow: NSWindow? { eqController.window }
    var playlistWindow: NSWindow? { playlistController.window }

    init(skinManager: SkinManager, audioPlayer: AudioPlayer, dockingController: DockingController, settings: AppSettings, radioLibrary: RadioStationLibrary, playbackCoordinator: PlaybackCoordinator) {
        // Store shared state references
        self.settings = settings
        self.skinManager = skinManager

        // Create Main window with environment injection
        mainController = WinampMainWindowController(
            skinManager: skinManager,
            audioPlayer: audioPlayer,
            dockingController: dockingController,
            settings: settings,
            radioLibrary: radioLibrary,
            playbackCoordinator: playbackCoordinator
        )

        // Create EQ window with environment injection
        eqController = WinampEqualizerWindowController(
            skinManager: skinManager,
            audioPlayer: audioPlayer,
            dockingController: dockingController,
            settings: settings,
            radioLibrary: radioLibrary,
            playbackCoordinator: playbackCoordinator
        )

        // Create Playlist window with environment injection
        playlistController = WinampPlaylistWindowController(
            skinManager: skinManager,
            audioPlayer: audioPlayer,
            dockingController: dockingController,
            settings: settings,
            radioLibrary: radioLibrary,
            playbackCoordinator: playbackCoordinator
        )

        // Configure windows (borderless, transparent titlebar)
        configureWindows()
        mapWindowsToKinds()

        // PHASE 4: Set initial window sizes based on current double-size state
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
        debugLogWindowPositions(step: "after initial window level assignment")

        // CRITICAL FIX #3: Observe always-on-top changes
        // From UnifiedDockView.swift lines 65-68
        // Note: AppSettings is @Observable, so we can track changes
        // Using withObservationTracking for reactive updates
        setupAlwaysOnTopObserver()
        debugLogWindowPositions(step: "after setupAlwaysOnTopObserver")

        // PHASE 4: Observe for double-size changes
        setupDoubleSizeObserver()
        debugLogWindowPositions(step: "after setupDoubleSizeObserver")

        // PHASE 2: Register windows with WindowSnapManager
        // WindowSnapManager provides:
        // - 15px magnetic snapping
        // - Cluster detection (group movement)
        // - Screen edge snapping
        // - Multi-monitor support
        // NOTE: register() no longer sets window.delegate (Phase 3 uses multiplexer)
        if let main = mainWindow {
            WindowSnapManager.shared.register(window: main, kind: .main)
        }
        if let eq = eqWindow {
            WindowSnapManager.shared.register(window: eq, kind: .equalizer)
        }
        if let playlist = playlistWindow {
            WindowSnapManager.shared.register(window: playlist, kind: .playlist)
        }
        debugLogWindowPositions(step: "after WindowSnapManager registration")

        // PHASE 3: Set up delegate multiplexers
        // Multiplexer pattern allows multiple delegates per window
        // WindowSnapManager is first delegate, can add more later (resize, close, focus handlers)
        // CRITICAL: Must store multiplexers as properties - NSWindow.delegate is weak!

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

        // Persist window movement/resizes
        persistenceDelegate = WindowPersistenceDelegate(coordinator: self)
        if let persistenceDelegate {
            mainDelegateMultiplexer?.add(delegate: persistenceDelegate)
            eqDelegateMultiplexer?.add(delegate: persistenceDelegate)
            playlistDelegateMultiplexer?.add(delegate: persistenceDelegate)
        }

        debugLogWindowPositions(step: "after delegate multiplexer setup")
    }

    // CRITICAL FIX #3: Always-on-top observer (Oracle P1 fix - no memory leak)
    // Migrated from UnifiedDockView.swift lines 65-68
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
    }

    // PHASE 4: Double-size observer (Main + EQ only, not Playlist)
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

    private func resizeMainAndEQWindows(doubled: Bool, animated: Bool = true, persistResult: Bool = true) {
        // PHASE 4: Main + EQ double, Playlist stays docked if attached
        // Gemini + Oracle pattern: Check docking BEFORE resize, synchronize animations
        guard let main = mainWindow, let eq = eqWindow else { return }

        // Get original frames BEFORE any calculations
        let originalMainFrame = main.frame
        let originalEqFrame = eq.frame
        let originalPlaylistFrame = playlistWindow?.frame

        // Check if playlist is docked to EQ *before* the resize (Gemini fix)
        let dockingSnapshot = originalPlaylistFrame.map { plFrame in
            makePlaylistDockingSnapshot(playlistFrame: plFrame, eqFrame: originalEqFrame)
        }
        let isPlaylistDocked = dockingSnapshot?.isDocked ?? false

        logDoubleSizeDebug(
            mainFrame: originalMainFrame,
            eqFrame: originalEqFrame,
            playlistFrame: originalPlaylistFrame,
            dockingSnapshot: dockingSnapshot
        )

        // Calculate new sizes
        let scale: CGFloat = doubled ? 2.0 : 1.0
        let mainSize = CGSize(
            width: WinampSizes.main.width * scale,
            height: WinampSizes.main.height * scale
        )
        let eqSize = CGSize(
            width: WinampSizes.equalizer.width * scale,
            height: WinampSizes.equalizer.height * scale
        )

        // Calculate new Main frame (top-aligned: title bar stays fixed)
        var newMainFrame = originalMainFrame
        let mainDelta = mainSize.height - newMainFrame.size.height
        newMainFrame.size = mainSize
        newMainFrame.origin.y -= mainDelta  // Grows downward from fixed top

        // Calculate new EQ frame (stacked directly below Main - Oracle fix)
        var newEqFrame = originalEqFrame
        newEqFrame.size = eqSize
        newEqFrame.origin.y = newMainFrame.origin.y - newEqFrame.size.height  // Zero spacing

        // CRITICAL: Disable WindowSnapManager during resize to prevent cascade effects
        // Gemini research: setFrame() triggers windowDidMove, causing unwanted snapping
        beginSuppressingPersistence()
        WindowSnapManager.shared.beginProgrammaticAdjustment()

        let finishAdjustment: () -> Void = { [weak self] in
            WindowSnapManager.shared.endProgrammaticAdjustment()
            self?.endSuppressingPersistence()
            if persistResult {
                self?.schedulePersistenceFlush()
            }
        }

        if animated {
            // Gemini fix: Group animations to prevent visual tearing/overlap
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.2  // Match SwiftUI .animation() duration
                context.allowsImplicitAnimation = true

                // Apply new frames using animator proxy for synchronized updates
                main.animator().setFrame(newMainFrame, display: true)
                eq.animator().setFrame(newEqFrame, display: true)

                // If playlist was docked, move it to stay attached to EQ's new position
                if isPlaylistDocked, let playlist = playlistWindow, var plFrame = originalPlaylistFrame {
                    plFrame.origin.y = newEqFrame.origin.y - plFrame.size.height
                    playlist.animator().setFrame(plFrame, display: true)
                }
            }, completionHandler: {
                finishAdjustment()
            })
        } else {
            main.setFrame(newMainFrame, display: true)
            eq.setFrame(newEqFrame, display: true)

            if isPlaylistDocked, let playlist = playlistWindow, var plFrame = originalPlaylistFrame {
                plFrame.origin.y = newEqFrame.origin.y - plFrame.size.height
                playlist.setFrame(plFrame, display: true)
            }

            finishAdjustment()
        }
    }

    private func makePlaylistDockingSnapshot(playlistFrame: NSRect, eqFrame: NSRect) -> PlaylistDockingSnapshot {
        let tolerance = SnapUtils.SNAP_DISTANCE
        let playlistLeft = playlistFrame.minX
        let playlistRight = playlistFrame.maxX
        let eqLeft = eqFrame.minX
        let eqRight = eqFrame.maxX
        let overlapsX = playlistLeft <= eqRight + tolerance && eqLeft <= playlistRight + tolerance

        let horizontalDelta: CGFloat
        if overlapsX {
            horizontalDelta = 0
        } else if playlistRight < eqLeft {
            horizontalDelta = eqLeft - playlistRight
        } else if eqRight < playlistLeft {
            horizontalDelta = playlistLeft - eqRight
        } else {
            horizontalDelta = 0
        }

        let playlistTop = playlistFrame.maxY
        let eqBottom = eqFrame.minY
        let verticalDelta = abs(eqBottom - playlistTop)

        return PlaylistDockingSnapshot(
            playlistFrame: playlistFrame,
            eqFrame: eqFrame,
            horizontalOverlap: overlapsX,
            horizontalDelta: horizontalDelta,
            verticalDelta: verticalDelta,
            tolerance: tolerance
        )
    }

    private func logDoubleSizeDebug(
        mainFrame: NSRect,
        eqFrame: NSRect,
        playlistFrame: NSRect?,
        dockingSnapshot: PlaylistDockingSnapshot?
    ) {
        guard settings.windowDebugLoggingEnabled else { return }
        print("=== DOUBLE-SIZE DEBUG ===")
        print("Main frame: \(mainFrame)")
        print("EQ frame: \(eqFrame)")
        print("Playlist frame: \(String(describing: playlistFrame))")

        guard let snapshot = dockingSnapshot else {
            print("Docking detection: playlist window unavailable")
            return
        }

        print("Docking detection:")
        print("  playlistTop: \(snapshot.playlistFrame.maxY)")
        print("  eqBottom: \(snapshot.eqFrame.minY)")
        print("  horizontalOverlap: \(snapshot.horizontalOverlap) (delta: \(snapshot.horizontalDelta))")
        print("  verticalDelta: \(snapshot.verticalDelta) vs tolerance: \(snapshot.tolerance)")
        print("  isPlaylistDocked: \(snapshot.isDocked)")
    }

    private func debugLogWindowPositions(step: String) {
        guard settings.windowDebugLoggingEnabled else { return }
        print("🔍 \(step)")

        func describe(window: NSWindow?, label: String) {
            guard let window else {
                print("  \(label): unavailable")
                return
            }
            let frame = window.frame
            print("  \(label): origin=(x: \(frame.origin.x), y: \(frame.origin.y)) size=(w: \(frame.size.width), h: \(frame.size.height))")
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
        // ORACLE NOTE: Windows already created as borderless in controllers
        // No additional style mask changes needed here
        // This method can be removed or used for other window setup

        // Optional: Additional window configuration
        [mainWindow, eqWindow, playlistWindow].forEach { window in
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
        }

        if settings.windowDebugLoggingEnabled {
            print("✅ Default positions set (should be touching with 0 spacing):")
            if let main = mainWindow { print("  Main: \(main.frame)") }
            if let eq = eqWindow { print("  EQ: \(eq.frame)") }
            if let playlist = playlistWindow { print("  Playlist: \(playlist.frame)") }
        }
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

        if settings.windowDebugLoggingEnabled {
            print("✅ Windows reset to default vertical stack")
            print("  Main: \(mainFrame)")
            print("  EQ: \(eqFrame)")
            print("  Playlist: \(playlistFrame)")
        }
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
        focusAllWindows()
    }

    // Menu command integration
    func showMain() { mainWindow?.makeKeyAndOrderFront(nil) }
    func hideMain() { mainWindow?.orderOut(nil) }
    func showEqualizer() { eqWindow?.makeKeyAndOrderFront(nil) }
    func hideEqualizer() { eqWindow?.orderOut(nil) }
    func showPlaylist() { playlistWindow?.makeKeyAndOrderFront(nil) }
    func hidePlaylist() { playlistWindow?.orderOut(nil) }

    private func focusAllWindows() {
        [mainWindow, eqWindow, playlistWindow].forEach { window in
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
        }
    }
}
