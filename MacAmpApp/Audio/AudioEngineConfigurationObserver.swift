@preconcurrency import AVFoundation

/// Observes `AVAudioEngineConfigurationChange` notifications and debounces bursts.
///
/// Output-route changes (Control Center, AirPlay, HDMI hot-plug, sleep/wake) can
/// fire 2–3 notifications within <100 ms. This collapses each burst into a single
/// will/did pair: `onWillReconfigure` fires at burst start (so AudioPlayer can arm
/// seek guards and snapshot transient state before the rewire), and
/// `onDidReconfigure` fires once after a 150 ms quiet window (so AudioEngineController
/// can rewire the graph for the new output device and AudioPlayer can resume from
/// the saved position).
///
/// **Pairing contract (important):** `onDidReconfigure` is NOT guaranteed to fire after
/// `onWillReconfigure` if `stop()` or `deinit` interrupts the debounce window. Callers
/// MUST clear any transient state armed in `onWillReconfigure` (seek guards, completion
/// flags) via their own teardown paths — do not assume strict will/did symmetry on
/// observer shutdown. During normal route changes the pair is balanced; only on
/// observer teardown is `did` skipped.
///
/// Notifications arrive on an arbitrary thread; consumed via the modern
/// `NotificationCenter.notifications(named:object:)` AsyncSequence so delivery to
/// the @MainActor-isolated watch task is automatic — no manual `Task { @MainActor in }`
/// bridging.
@MainActor
final class AudioEngineConfigurationObserver {
    private let engine: AVAudioEngine
    private var watchTask: Task<Void, Never>?
    private var debounceTask: Task<Void, Never>?

    /// Debounce window. 150 ms is enough to absorb the 2–3 notification burst that
    /// Control Center / AirPlay route changes fire while still feeling immediate.
    private static let debounceWindow: Duration = .milliseconds(150)

    /// Fired once at the START of a burst, before any rewire. Capture transient state
    /// (currentTime, playback flags) here so the did-handler can restore it.
    var onWillReconfigure: (@MainActor () -> Void)?
    /// Fired once at the END of a burst (after the quiet window). Re-apply
    /// volume/balance, reschedule the player, refresh the stream workgroup.
    var onDidReconfigure: (@MainActor () -> Void)?

    init(engine: AVAudioEngine) {
        self.engine = engine
    }

    isolated deinit {
        watchTask?.cancel()
        debounceTask?.cancel()
    }

    /// Idempotent — repeat calls are no-ops while already watching.
    func start() {
        guard watchTask == nil else { return }
        let stream = NotificationCenter.default.notifications(
            named: .AVAudioEngineConfigurationChange,
            object: engine
        )
        watchTask = Task { @MainActor [weak self] in
            for await _ in stream {
                self?.handleConfigurationChange()
            }
        }
    }

    /// Idempotent — repeat calls are no-ops while not watching.
    func stop() {
        watchTask?.cancel()
        watchTask = nil
        debounceTask?.cancel()
        debounceTask = nil
    }

    private func handleConfigurationChange() {
        // First notification of a new burst → arm guards immediately so AudioPlayer
        // can filter the stale completion that the impending engine restart will fire.
        if debounceTask == nil {
            onWillReconfigure?()
        }
        // Re-entrancy guard: if `onWillReconfigure` synchronously called `stop()`, the
        // watch task is now cancelled. Do not resurrect the observer by scheduling a
        // fresh debounce. (Documented contract: `did` is not guaranteed after `will`
        // on stop/deinit; the caller must clean up its own state.)
        guard watchTask != nil else { return }
        // Each new notification supersedes any in-flight debounce — the latest
        // arrival resets the quiet window.
        debounceTask?.cancel()
        debounceTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: Self.debounceWindow)
            guard let self, !Task.isCancelled else { return }
            self.debounceTask = nil
            self.onDidReconfigure?()
        }
    }
}
