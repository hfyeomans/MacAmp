import SwiftUI
import WebKit

/// NSViewRepresentable wrapper for WKWebView hosting Butterchurn visualization
///
/// Script Injection Strategy:
/// 1. butterchurn.min.js at .atDocumentStart (defines butterchurn global)
/// 2. butterchurnPresets.min.js at .atDocumentStart (defines butterchurnPresets global)
/// 3. bridge.js at .atDocumentEnd (after DOM ready, initializes visualization)
///
/// This bypasses WKWebView's file:// script loading restriction by injecting
/// JavaScript as strings via WKUserScript.
struct ButterchurnWebView: NSViewRepresentable {
    /// Bridge for JS communication (passed from environment)
    let bridge: ButterchurnBridge

    /// Coordinator holds references for cleanup
    class Coordinator {
        weak var bridge: ButterchurnBridge?

        init(bridge: ButterchurnBridge) {
            self.bridge = bridge
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(bridge: bridge)
    }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let userContentController = WKUserContentController()

        // Load JS from bundle as strings
        let butterchurnJS = loadBundleJS("butterchurn.min")
        let presetsJS = loadBundleJS("butterchurnPresets.min")
        let bridgeJS = loadBundleJS("bridge")

        // Inject libraries at document start (before HTML parses)
        userContentController.addUserScript(WKUserScript(
            source: butterchurnJS,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        ))
        userContentController.addUserScript(WKUserScript(
            source: presetsJS,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        ))

        // Inject bridge at document end (after DOM ready)
        userContentController.addUserScript(WKUserScript(
            source: bridgeJS,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        ))

        // Register message handler for JS→Swift communication
        userContentController.add(bridge, name: "butterchurn")

        config.userContentController = userContentController

        // Preferences for WebGL support
        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = true
        config.defaultWebpagePreferences = prefs

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")  // Transparent background

        // Store webView reference in bridge for Swift→JS communication
        bridge.webView = webView

        // Load minimal HTML that provides canvas element
        if let htmlURL = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "Butterchurn") {
            webView.loadFileURL(htmlURL, allowingReadAccessTo: htmlURL.deletingLastPathComponent())
        } else {
            // Fallback: load inline HTML if bundle resource not found
            let fallbackHTML = """
            <!DOCTYPE html>
            <html>
            <head>
                <meta charset="utf-8">
                <style>
                    * { margin: 0; padding: 0; }
                    body { background: #000; overflow: hidden; }
                    canvas { display: block; width: 100%; height: 100%; }
                    #fallback { display: block; color: #0f0; font-family: monospace;
                                text-align: center; padding-top: 40%; font-size: 12px; }
                </style>
            </head>
            <body>
                <canvas id="canvas"></canvas>
                <div id="fallback">Butterchurn loading...</div>
            </body>
            </html>
            """
            webView.loadHTMLString(fallbackHTML, baseURL: nil)
        }

        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        // No updates needed - WebView manages its own state
    }

    static func dismantleNSView(_ nsView: WKWebView, coordinator: Coordinator) {
        // CRITICAL: Remove handler to prevent retain cycle
        // WKUserContentController retains message handlers
        nsView.configuration.userContentController.removeScriptMessageHandler(forName: "butterchurn")

        // Cleanup bridge state
        coordinator.bridge?.cleanup()
    }

    /// Load JavaScript file from bundle as String
    private func loadBundleJS(_ name: String) -> String {
        guard let url = Bundle.main.url(forResource: name, withExtension: "js", subdirectory: "Butterchurn"),
              let js = try? String(contentsOf: url, encoding: .utf8) else {
            // Return error logging if file not found
            return "console.error('[MacAmp] Failed to load \(name).js from bundle');"
        }
        return js
    }
}
