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

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject {}

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

        // Preferences for WebGL/WASM support
        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = true
        config.defaultWebpagePreferences = prefs

        // WKPreferences for JavaScript features
        let wkPrefs = WKPreferences()
        wkPrefs.javaScriptCanOpenWindowsAutomatically = false
        wkPrefs.setValue(true, forKey: "developerExtrasEnabled")
        config.preferences = wkPrefs

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")  // Transparent background

        // Enable Web Inspector for debugging (macOS 13.3+)
        if #available(macOS 13.3, *) {
            webView.isInspectable = true
        }

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
                    * { margin: 0; padding: 0; box-sizing: border-box; }
                    html, body { width: 100%; height: 100%; }
                    body { background: #000; overflow: hidden; }
                    canvas { display: block; width: 100%; height: 100%; position: absolute; top: 0; left: 0; }
                    #fallback { display: none; color: #0f0; font-family: monospace;
                                text-align: center; padding-top: 40%; font-size: 12px; }
                </style>
            </head>
            <body>
                <canvas id="canvas"></canvas>
                <div id="fallback">Butterchurn unavailable</div>
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
        nsView.configuration.userContentController.removeScriptMessageHandler(forName: "butterchurn")
    }

    /// Load JavaScript file from bundle as String
    /// Applies necessary wrappers for ES module → global variable conversion
    private func loadBundleJS(_ name: String) -> String {
        guard let url = Bundle.main.url(forResource: name, withExtension: "js", subdirectory: "Butterchurn") else {
            AppLog.error(.general, "[ButterchurnWebView] Bundle URL not found for \(name).js")
            return "console.error('[MacAmp] Bundle URL not found for \(name).js');"
        }

        guard let js = try? String(contentsOf: url, encoding: .utf8) else {
            AppLog.error(.general, "[ButterchurnWebView] Failed to read \(name).js from \(url)")
            return "console.error('[MacAmp] Failed to read \(name).js');"
        }

        // Apply wrappers based on file type
        switch name {
        case "butterchurn.min":
            // butterchurn.min.js uses ES module export: export{qt as default}
            // Convert to window.butterchurn global
            return wrapESModuleAsGlobal(js, globalName: "butterchurn")

        case "butterchurnPresets.min":
            // butterchurnPresets.min.js uses UMD but exports as 'minimal'
            // Alias window.minimal → window.butterchurnPresets
            return js + "\nwindow.butterchurnPresets = window.minimal;\n"

        default:
            return js
        }
    }

    /// Wrap ES module code to export as window global
    /// Converts `export{X as default}` to `window.globalName = X`
    private func wrapESModuleAsGlobal(_ js: String, globalName: String) -> String {
        // Replace ES module export with window assignment
        // Pattern: export{IDENTIFIER as default}
        if let range = js.range(of: #"export\{(\w+)\s+as\s+default\}"#, options: .regularExpression) {
            let exportStatement = String(js[range])

            if let identifierMatch = exportStatement.range(of: #"\{(\w+)"#, options: .regularExpression) {
                let identifier = exportStatement[identifierMatch]
                    .dropFirst() // Remove '{'
                    .prefix(while: { $0.isLetter || $0.isNumber || $0 == "_" })

                var modifiedJS = js
                modifiedJS.replaceSubrange(range, with: "window.\(globalName) = \(identifier);")
                return modifiedJS
            }
        }

        // Fallback: Wrap entire script in IIFE that captures exports
        return """
        (function() {
            var __exports = {};
            var __originalExport = Object.getOwnPropertyDescriptor(window, 'exports');
            Object.defineProperty(window, 'exports', {
                get: function() { return __exports; },
                set: function(v) { __exports = v; },
                configurable: true
            });
            \(js)
            window.\(globalName) = __exports.default || __exports;
            if (__originalExport) {
                Object.defineProperty(window, 'exports', __originalExport);
            } else {
                delete window.exports;
            }
        })();
        """
    }
}
