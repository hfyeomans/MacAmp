import Foundation
import WebKit
import Observation

/// Bridge between Swift and Butterchurn JavaScript visualization
/// Handles WKScriptMessageHandler for JS→Swift communication and
/// evaluateJavaScript for Swift→JS communication
///
/// Responsibilities:
/// - Handles ready/loadFailed messages from bridge.js
/// - 30 FPS audio data updates with pause/resume on playback state
/// - Preset management via ButterchurnPresetManager
@MainActor
@Observable
final class ButterchurnBridge: NSObject, WKScriptMessageHandler {
    /// WebView reference (weak to prevent retain cycle)
    @ObservationIgnored weak var webView: WKWebView?

    /// Whether Butterchurn has initialized successfully
    var isReady: Bool = false

    /// Number of presets available
    var presetCount: Int = 0

    /// List of preset names
    var presetNames: [String] = []

    /// Error message if initialization failed
    var errorMessage: String?

    /// Callback when presets are loaded (for ButterchurnPresetManager)
    @ObservationIgnored var onPresetsLoaded: (([String]) -> Void)?

    /// Weak reference to preset manager for cleanup coordination
    @ObservationIgnored weak var presetManager: ButterchurnPresetManager?

    // MARK: - Audio Update Properties

    /// Async task for 30 FPS audio updates (replaces Timer for cleaner cancellation)
    @ObservationIgnored private var audioUpdateTask: Task<Void, Never>?
    @ObservationIgnored private weak var audioPlayer: AudioPlayer?

    /// Tracks whether the JS render loop is active (pause when no audio)
    @ObservationIgnored private var isVisualizationActive: Bool = true

    // MARK: - WKScriptMessageHandler

    /// Sendable struct for parsing WKScriptMessage before crossing actor boundary
    private struct ParsedMessage: Sendable {
        let type: String
        let presetCount: Int
        let presetNames: [String]
        let error: String?
    }

    nonisolated func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        // WebKit guarantees this delegate is called on main thread
        // Use assumeIsolated to satisfy Swift 6 strict concurrency
        MainActor.assumeIsolated {
            guard let dict = message.body as? [String: Any],
                  let type = dict["type"] as? String else {
                AppLog.warn(.general, "[ButterchurnBridge] Invalid message format")
                return
            }

            self.handleMessage(ParsedMessage(
                type: type,
                presetCount: dict["presetCount"] as? Int ?? 0,
                presetNames: dict["presetNames"] as? [String] ?? [],
                error: dict["error"] as? String
            ))
        }
    }

    private func handleMessage(_ message: ParsedMessage) {
        switch message.type {
        case "ready":
            isReady = true
            errorMessage = nil
            presetCount = message.presetCount
            presetNames = message.presetNames
            AppLog.info(.general, "[ButterchurnBridge] Ready! \(presetCount) presets available")
            startAudioUpdates()
            // Notify preset manager
            onPresetsLoaded?(presetNames)

        case "loadFailed":
            markLoadFailed(message.error ?? "Unknown error")

        default:
            AppLog.warn(.general, "[ButterchurnBridge] Unknown message type: \(message.type)")
            break
        }
    }

    // MARK: - Failure Handling

    /// Centralized failure handler - stops updates and sets error state
    func markLoadFailed(_ message: String) {
        isReady = false
        errorMessage = message
        presetCount = 0
        presetNames = []
        stopAudioUpdates()
        AppLog.error(.general, "[ButterchurnBridge] Load failed: \(message)")
    }

    // MARK: - Cleanup

    /// Called from ButterchurnWebView.dismantleNSView
    func cleanup() {
        stopAudioUpdates()
        presetManager?.cleanup()
        webView = nil
    }

    private func stopAudioUpdates() {
        audioUpdateTask?.cancel()
        audioUpdateTask = nil
    }

    // MARK: - Audio Updates

    /// Configure with AudioPlayer for audio data
    func configure(audioPlayer: AudioPlayer) {
        self.audioPlayer = audioPlayer
    }

    /// Start sending audio data at 30 FPS using async Task loop
    private func startAudioUpdates() {
        // Don't start if already running
        guard audioUpdateTask == nil else { return }

        // 30 FPS = ~33ms interval using async Task (cleaner cancellation, less jitter)
        // Task runs on MainActor since sendAudioFrame() is MainActor-isolated
        audioUpdateTask = Task { @MainActor [weak self] in
            AppLog.info(.general, "[ButterchurnBridge] Started 30 FPS audio updates")
            while !Task.isCancelled {
                self?.sendAudioFrame()
                try? await Task.sleep(nanoseconds: 33_333_333) // ~30 FPS
            }
            AppLog.info(.general, "[ButterchurnBridge] Stopped audio updates")
        }
    }

    /// Push current audio frame to JavaScript
    private func sendAudioFrame() {
        // Guard both isReady and webView to prevent calls to dead/failed WebView
        guard isReady, let webView = webView else { return }

        // Get audio data from AudioPlayer (nil if not playing local audio)
        guard let frame = audioPlayer?.snapshotButterchurnFrame() else {
            // Not playing - pause visualization to freeze the display
            if isVisualizationActive {
                isVisualizationActive = false
                webView.evaluateJavaScript("window.macampButterchurn?.stop();", completionHandler: nil)
            }
            return
        }

        // Resume visualization if it was paused
        if !isVisualizationActive {
            isVisualizationActive = true
            webView.evaluateJavaScript("window.macampButterchurn?.start();", completionHandler: nil)
        }

        // Convert spectrum from Float (0-1) to Int (0-255) for JS Uint8Array compatibility
        // Waveform stays as Float (-1 to 1) for JS Float32Array
        let spectrumInts = frame.spectrum.map { Int(min(255, max(0, $0 * 255))) }

        // Use callAsyncJavaScript with typed arguments (avoids per-frame string interpolation)
        webView.callAsyncJavaScript(
            "window.macampButterchurn?.setAudioData(spectrum, waveform);",
            arguments: ["spectrum": spectrumInts, "waveform": frame.waveform],
            in: nil,
            in: .page,
            completionHandler: nil
        )
    }

    // MARK: - Preset Control

    /// Load preset at index with transition
    /// - Parameters:
    ///   - index: Preset index (0-based)
    ///   - transition: Transition duration in seconds (default: 2.7)
    func loadPreset(at index: Int, transition: Double = 2.7) {
        guard isReady, let webView = webView else { return }
        guard index >= 0, index < presetCount else { return }

        let js = "window.macampButterchurn?.loadPreset(\(index), \(transition));"
        webView.evaluateJavaScript(js, completionHandler: nil)
    }

    // MARK: - Track Title

    /// Show track title animation in Butterchurn
    func showTrackTitle(_ title: String) {
        guard isReady, let webView = webView else { return }

        // Use JSON encoding to safely escape all special characters (newlines, quotes, Unicode)
        guard let jsonData = try? JSONEncoder().encode(title),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return
        }
        let js = "window.macampButterchurn?.showTrackTitle(\(jsonString));"
        webView.evaluateJavaScript(js, completionHandler: nil)
    }

    // MARK: - Rendering Control

    /// Pause visualization rendering (window minimized)
    func pauseRendering() {
        guard isReady, let webView = webView else { return }
        webView.evaluateJavaScript("window.macampButterchurn?.stop();", completionHandler: nil)
    }

    /// Resume visualization rendering (window restored)
    func resumeRendering() {
        guard isReady, let webView = webView else { return }
        webView.evaluateJavaScript("window.macampButterchurn?.start();", completionHandler: nil)
    }
}
