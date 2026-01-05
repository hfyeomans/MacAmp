import Foundation
import WebKit
import Observation

/// Bridge between Swift and Butterchurn JavaScript visualization
/// Handles WKScriptMessageHandler for JS→Swift communication and
/// evaluateJavaScript for Swift→JS communication
///
/// Phase 1: Handles ready/loadFailed messages from bridge.js
/// Phase 3: 30 FPS audio data updates with pause/resume on playback state
/// Phase 4: Preset management via ButterchurnPresetManager
@MainActor
@Observable
final class ButterchurnBridge: NSObject, WKScriptMessageHandler {
    /// WebView reference (weak to prevent retain cycle)
    weak var webView: WKWebView?

    /// Whether Butterchurn has initialized successfully
    var isReady: Bool = false

    /// Number of presets available
    var presetCount: Int = 0

    /// List of preset names
    var presetNames: [String] = []

    /// Error message if initialization failed
    var errorMessage: String?

    /// Callback when presets are loaded (for ButterchurnPresetManager)
    var onPresetsLoaded: (([String]) -> Void)?

    // MARK: - Phase 3 Properties

    @ObservationIgnored private var updateTimer: Timer?
    @ObservationIgnored private weak var audioPlayer: AudioPlayer?

    /// Tracks whether the JS render loop is active (pause when no audio)
    @ObservationIgnored private var isVisualizationActive: Bool = true

    // MARK: - WKScriptMessageHandler

    nonisolated func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        // Dispatch to main actor for @Observable state updates
        Task { @MainActor in
            self.handleMessage(message)
        }
    }

    private func handleMessage(_ message: WKScriptMessage) {
        guard let dict = message.body as? [String: Any],
              let type = dict["type"] as? String else {
            AppLog.warn(.general, "[ButterchurnBridge] Invalid message format")
            return
        }

        switch type {
        case "ready":
            isReady = true
            errorMessage = nil
            presetCount = dict["presetCount"] as? Int ?? 0
            presetNames = dict["presetNames"] as? [String] ?? []
            AppLog.info(.general, "[ButterchurnBridge] Ready! \(presetCount) presets available")
            startAudioUpdates()
            // Notify preset manager
            onPresetsLoaded?(presetNames)

        case "loadFailed":
            isReady = false
            errorMessage = dict["error"] as? String ?? "Unknown error"
            presetCount = 0
            presetNames = []
            AppLog.error(.general, "[ButterchurnBridge] Load failed: \(errorMessage ?? "unknown")")

        default:
            AppLog.warn(.general, "[ButterchurnBridge] Unknown message type: \(type)")
            break
        }
    }

    // MARK: - Cleanup

    /// Called from ButterchurnWebView.dismantleNSView
    func cleanup() {
        stopAudioUpdates()
        webView = nil
    }

    private func stopAudioUpdates() {
        updateTimer?.invalidate()
        updateTimer = nil
    }

    // MARK: - Phase 3: Audio Updates

    /// Configure with AudioPlayer for audio data
    func configure(audioPlayer: AudioPlayer) {
        self.audioPlayer = audioPlayer
    }

    /// Start sending audio data at 30 FPS
    private func startAudioUpdates() {
        // Don't start if already running
        guard updateTimer == nil else { return }

        // 30 FPS = 1/30 second interval (~33ms)
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.sendAudioFrame()
            }
        }
        AppLog.info(.general, "[ButterchurnBridge] Started 30 FPS audio updates")
    }

    /// Push current audio frame to JavaScript
    private func sendAudioFrame() {
        guard let webView = webView else { return }

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

        // Build JavaScript call - use JSON encoding for arrays
        let js = "window.macampButterchurn?.setAudioData(\(spectrumInts), \(frame.waveform));"
        webView.evaluateJavaScript(js, completionHandler: nil)
    }

    // MARK: - Phase 4: Preset Control

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

    // MARK: - Phase 5: Track Title

    /// Show track title animation in Butterchurn
    func showTrackTitle(_ title: String) {
        guard isReady, let webView = webView else { return }

        let escaped = title
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
        let js = "window.macampButterchurn?.showTrackTitle('\(escaped)');"
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
