import AppKit

/// Keeps MacAmp's windows reachable across sleep/wake and display changes (docs/MULTI_WINDOW_ARCHITECTURE.md).
@MainActor
final class WindowScreenGuard {
    enum Defaults {
        /// Quiet period after the last screen event before settling.
        static let screenSettleDelay: Double = 1.0
        /// Minimum time after wake before settling; bridges the lull before the real screen returns.
        static let wakeSettleWindow: Double = 3.0
        static let screenSettleDelayKey = "screenSettleDelay"
        static let wakeSettleWindowKey = "wakeSettleWindow"
    }

    private let registry: WindowRegistry
    private let persistence: WindowFramePersistence
    private var observations: [(center: NotificationCenter, token: NotificationCenter.ObservationToken)] = []
    private var snapshot: [WindowKind: NSRect]?
    /// Display frames (by `CGDirectDisplayID`) the current layout's coordinates belong to.
    private var displays: [CGDirectDisplayID: CGRect] = [:]
    private var snapshotDisplays: [CGDirectDisplayID: CGRect] = [:]
    private var wakeDeadline: ContinuousClock.Instant?
    private var isAsleep = false
    private var settleTask: Task<Void, Never>?

    private var settleDelay: Duration { .seconds(Self.seconds(Defaults.screenSettleDelayKey, Defaults.screenSettleDelay)) }
    private var wakeWindow: Duration { .seconds(Self.seconds(Defaults.wakeSettleWindowKey, Defaults.wakeSettleWindow)) }

    init(registry: WindowRegistry, persistence: WindowFramePersistence) {
        self.registry = registry
        self.persistence = persistence
    }

    func start() {
        displays = Self.currentDisplays()
        let app = NotificationCenter.default
        observations.append((app, app.addObserver(of: NSApplication.self, for: .didChangeScreenParameters) { [weak self] _ in
            self?.screensChanged()
        }))
        let workspace = NSWorkspace.shared.notificationCenter
        observations.append((workspace, workspace.addObserver(of: NSWorkspace.shared, for: .willSleep) { [weak self] _ in
            self?.willSleep()
        }))
        observations.append((workspace, workspace.addObserver(of: NSWorkspace.shared, for: .didWake) { [weak self] _ in
            self?.didWake()
        }))
    }

    func stop() {
        for observation in observations { observation.center.removeObserver(observation.token) }
        observations.removeAll()
        settleTask?.cancel()
        if snapshot != nil { endTransition() }
    }

    /// Moves each docked group (and each lone window) back onto a screen as a unit.
    func clampOnScreen() {
        var frames: [WindowKind: CGRect] = [:]
        var visible: Set<WindowKind> = []
        registry.forEachWindow { window, kind in
            frames[kind] = window.frame
            if window.isVisible { visible.insert(kind) }
        }
        let groups = DockGraph.clusters(boxes: frames.mapValues(DockGraph.box(for:)))
        let moved = ScreenClamp.clamp(groups: groups, frames: frames, visible: visible,
                                      visibleFrames: NSScreen.screens.map(\.visibleFrame))
        guard !moved.isEmpty else { return }
        WindowSnapManager.shared.beginProgrammaticAdjustment()
        persistence.beginSuppressingPersistence()
        for (kind, frame) in moved { registry.window(for: kind)?.setFrameOrigin(frame.origin) }
        persistence.endSuppressingPersistence()
        WindowSnapManager.shared.endProgrammaticAdjustment()
    }

    // MARK: - Transitions

    /// `fromSavedLayout`: an awake display change may have moved windows before it's reported.
    private func beginTransition(fromSavedLayout: Bool = false) {
        guard snapshot == nil else { return }
        persistence.cancelPendingFlush()
        var frames: [WindowKind: NSRect] = [:]
        registry.forEachWindow { window, kind in
            frames[kind] = (fromSavedLayout ? persistence.savedFrame(for: kind) : nil) ?? window.frame
        }
        snapshot = frames
        snapshotDisplays = displays
        persistence.beginSuppressingPersistence()
        WindowSnapManager.shared.beginProgrammaticAdjustment()
    }

    private func screensChanged() {
        beginTransition(fromSavedLayout: true)
        if !isAsleep { scheduleSettle() }
    }

    /// No settle may be pending between sleep and wake; didWake reschedules.
    private func willSleep() {
        isAsleep = true
        settleTask?.cancel()
        settleTask = nil
        wakeDeadline = nil
        beginTransition()
    }

    private func didWake() {
        isAsleep = false
        beginTransition()
        wakeDeadline = .now + wakeWindow
        scheduleSettle()
    }

    private func scheduleSettle() {
        settleTask?.cancel()
        settleTask = Task { [weak self] in
            guard let delay = self?.settleDelay else { return }
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            if let deadline = self?.wakeDeadline, deadline > .now {
                try? await Task.sleep(until: deadline, clock: .continuous)
                guard !Task.isCancelled else { return }
            }
            self?.settle()
        }
    }

    private func settle() {
        let current = Self.currentDisplays()
        let displayAdded = !Set(current.keys).isSubset(of: Set(snapshotDisplays.keys))
        if let snapshot {
            // Docked groups are rigid across any transition; only their position may change.
            let groups = DockGraph.clusters(boxes: snapshot.mapValues(DockGraph.box(for:)))
            let restored: [WindowKind: CGRect]
            if displayAdded {
                var now: [WindowKind: CGRect] = [:]
                var visible: Set<WindowKind> = []
                registry.forEachWindow { window, kind in
                    now[kind] = window.frame
                    if window.isVisible { visible.insert(kind) }
                }
                restored = ScreenClamp.rigid(groups: groups, snapshot: snapshot, current: now) { group in
                    Self.anchorOrder.first { group.contains($0) && visible.contains($0) }
                        ?? Self.anchorOrder.first { group.contains($0) }
                }
            } else {
                restored = ScreenClamp.translate(groups: groups, frames: snapshot,
                                                 from: snapshotDisplays, to: current)
            }
            registry.forEachWindow { window, kind in
                guard let saved = restored[kind] else { return }
                // Top-anchored: keep the saved top edge even if the height changed meanwhile.
                window.setFrameOrigin(NSPoint(x: saved.minX, y: saved.maxY - window.frame.height))
            }
        }
        wakeDeadline = nil
        clampOnScreen()
        endTransition()
        displays = current
        persistence.persistAllWindowFrames()
    }

    private func endTransition() {
        snapshot = nil
        persistence.endSuppressingPersistence()
        WindowSnapManager.shared.endProgrammaticAdjustment()
    }

    /// Anchor priority: the first visible member wins, else the first member.
    private static let anchorOrder: [WindowKind] = [.main, .equalizer, .playlist, .video, .milkdrop]

    private static func currentDisplays() -> [CGDirectDisplayID: CGRect] {
        var result: [CGDirectDisplayID: CGRect] = [:]
        for screen in NSScreen.screens {
            if let id = screen.cgDirectDisplayID { result[id] = screen.frame }
        }
        return result
    }

    private static func seconds(_ key: String, _ fallback: Double) -> Double {
        let value = UserDefaults.standard.double(forKey: key)
        return value > 0 ? value : fallback
    }
}
