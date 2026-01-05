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

    /// Coordinator holds references for cleanup and handles JS console logging
    class Coordinator: NSObject, WKScriptMessageHandler {
        weak var bridge: ButterchurnBridge?

        init(bridge: ButterchurnBridge) {
            self.bridge = bridge
            super.init()
        }

        // DEBUG: Capture JavaScript console.log messages
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "consoleLog" {
                AppLog.debug(.general, "[JS Console] \(message.body)")
            }
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

        // DEBUG: Register console log handler and inject console override
        userContentController.add(context.coordinator, name: "consoleLog")
        let consoleOverride = """
        (function() {
            var originalLog = console.log;
            var originalError = console.error;
            var originalWarn = console.warn;
            console.log = function() {
                var msg = Array.prototype.slice.call(arguments).map(function(a) {
                    return typeof a === 'object' ? JSON.stringify(a) : String(a);
                }).join(' ');
                if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.consoleLog) {
                    window.webkit.messageHandlers.consoleLog.postMessage('[LOG] ' + msg);
                }
                originalLog.apply(console, arguments);
            };
            console.error = function() {
                var msg = Array.prototype.slice.call(arguments).map(function(a) {
                    return typeof a === 'object' ? JSON.stringify(a) : String(a);
                }).join(' ');
                if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.consoleLog) {
                    window.webkit.messageHandlers.consoleLog.postMessage('[ERROR] ' + msg);
                }
                originalError.apply(console, arguments);
            };
            console.warn = function() {
                var msg = Array.prototype.slice.call(arguments).map(function(a) {
                    return typeof a === 'object' ? JSON.stringify(a) : String(a);
                }).join(' ');
                if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.consoleLog) {
                    window.webkit.messageHandlers.consoleLog.postMessage('[WARN] ' + msg);
                }
                originalWarn.apply(console, arguments);
            };
            // Also catch uncaught errors
            window.onerror = function(msg, url, line, col, error) {
                if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.consoleLog) {
                    window.webkit.messageHandlers.consoleLog.postMessage('[UNCAUGHT] ' + msg + ' at ' + url + ':' + line + ':' + col);
                }
                return false;
            };
        })();
        """
        userContentController.addUserScript(WKUserScript(
            source: consoleOverride,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        ))

        config.userContentController = userContentController

        // Preferences for WebGL/WASM support
        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = true
        config.defaultWebpagePreferences = prefs

        // WKPreferences for additional JavaScript features
        let wkPrefs = WKPreferences()
        wkPrefs.javaScriptCanOpenWindowsAutomatically = false
        // Enable developer extras for Web Inspector debugging
        wkPrefs.setValue(true, forKey: "developerExtrasEnabled")
        config.preferences = wkPrefs

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")  // Transparent background

        // Enable Web Inspector for debugging (macOS 13.3+)
        if #available(macOS 13.3, *) {
            webView.isInspectable = true
        }

        AppLog.debug(.general, "[ButterchurnWebView] WebView created, isInspectable: \(webView.isInspectable)")

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
        // CRITICAL: Remove handlers to prevent retain cycle
        // WKUserContentController retains message handlers
        nsView.configuration.userContentController.removeScriptMessageHandler(forName: "butterchurn")
        nsView.configuration.userContentController.removeScriptMessageHandler(forName: "consoleLog")

        // Cleanup bridge state
        coordinator.bridge?.cleanup()
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

        AppLog.debug(.general, "[ButterchurnWebView] Loaded \(name).js (\(js.count) chars)")

        // Apply wrappers based on file type
        switch name {
        case "butterchurn.min":
            // butterchurn.min.js uses ES module export: export{qt as default}
            // Convert to window.butterchurn global by wrapping in function that captures export
            let wrapped = wrapESModuleAsGlobal(js, globalName: "butterchurn")
            AppLog.debug(.general, "[ButterchurnWebView] Wrapped butterchurn.min.js (\(wrapped.count) chars)")
            return wrapped

        case "butterchurnPresets.min":
            // butterchurnPresets.min.js uses UMD but exports as 'minimal'
            // Run the JS then alias window.minimal → window.butterchurnPresets
            let wrapped = js + "\nconsole.log('[MacAmp] butterchurnPresets loaded, aliasing minimal to butterchurnPresets');\nwindow.butterchurnPresets = window.minimal;\nconsole.log('[MacAmp] window.butterchurnPresets:', typeof window.butterchurnPresets);\n"
            return wrapped

        default:
            return js
        }
    }

    /// Wrap ES module code to export as window global
    /// Converts `export{X as default}` to `window.globalName = X`
    private func wrapESModuleAsGlobal(_ js: String, globalName: String) -> String {
        // Strategy: Replace the ES module export with a window assignment
        // The butterchurn.min.js ends with: export{qt as default}
        // We need to capture 'qt' and assign it to window.butterchurn

        // First, try to find and replace the export statement
        // Pattern: export{IDENTIFIER as default}
        if let range = js.range(of: #"export\{(\w+)\s+as\s+default\}"#, options: .regularExpression) {
            // Extract the identifier being exported
            let exportStatement = String(js[range])
            AppLog.debug(.general, "[ButterchurnWebView] Found export statement: '\(exportStatement)'")

            if let identifierMatch = exportStatement.range(of: #"\{(\w+)"#, options: .regularExpression) {
                let identifier = exportStatement[identifierMatch]
                    .dropFirst() // Remove '{'
                    .prefix(while: { $0.isLetter || $0.isNumber || $0 == "_" })

                AppLog.debug(.general, "[ButterchurnWebView] Extracted identifier: '\(identifier)'")

                // Replace export with window assignment
                var modifiedJS = js
                let replacement = "window.\(globalName) = \(identifier); console.log('[MacAmp] Assigned window.\(globalName) =', typeof window.\(globalName));"
                modifiedJS.replaceSubrange(range, with: replacement)

                AppLog.debug(.general, "[ButterchurnWebView] Replaced export with: '\(replacement)'")
                return modifiedJS
            }
        }

        AppLog.warn(.general, "[ButterchurnWebView] Export pattern not found, using fallback wrapper")

        // Fallback: Wrap entire script in IIFE that captures exports
        // This handles cases where the pattern matching fails
        return """
        console.log('[MacAmp] Using fallback ES module wrapper for \(globalName)');
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
            console.log('[MacAmp] Fallback wrapper: window.\(globalName) =', typeof window.\(globalName));
            if (__originalExport) {
                Object.defineProperty(window, 'exports', __originalExport);
            } else {
                delete window.exports;
            }
        })();
        """
    }
}
