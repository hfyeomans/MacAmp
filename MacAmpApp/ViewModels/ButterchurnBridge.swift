import Foundation
import WebKit
import Observation

/// Bridge between Swift and Butterchurn JavaScript visualization
/// Handles WKScriptMessageHandler for JS→Swift communication and
/// evaluateJavaScript for Swift→JS communication
///
/// Phase 1: Handles ready/loadFailed messages from bridge.js
/// Phase 3: Will add 30 FPS audio data updates
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

    // MARK: - Phase 3 Properties (stubbed for now)

    @ObservationIgnored private var updateTimer: Timer?
    @ObservationIgnored private weak var audioPlayer: AnyObject?  // Will be AudioPlayer

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
            return
        }

        switch type {
        case "ready":
            isReady = true
            errorMessage = nil
            presetCount = dict["presetCount"] as? Int ?? 0
            presetNames = dict["presetNames"] as? [String] ?? []
            // Phase 3: Will start audio updates here

        case "loadFailed":
            isReady = false
            errorMessage = dict["error"] as? String ?? "Unknown error"
            presetCount = 0
            presetNames = []

        default:
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

    // MARK: - Phase 3: Audio Updates (stubbed)

    /// Configure with AudioPlayer for audio data (Phase 3)
    func configure(audioPlayer: AnyObject) {
        self.audioPlayer = audioPlayer
    }

    /// Start sending audio data at 30 FPS (Phase 3)
    func startAudioUpdates() {
        // Will be implemented in Phase 3
    }

    // MARK: - Phase 5: Track Title (stubbed)

    /// Show track title animation in Butterchurn (Phase 5)
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
