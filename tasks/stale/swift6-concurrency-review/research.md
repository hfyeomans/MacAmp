# Research: Swift 6 concurrency review (Butterchurn)

## Context
- Files: MacAmpApp/ViewModels/ButterchurnBridge.swift, MacAmpApp/Views/Windows/ButterchurnWebView.swift, MacAmpApp/Windows/WinampMilkdropWindowController.swift
- Issue: Swift 6 strict concurrency error for WKScriptMessageHandler access to WKScriptMessage.body
- Fix applied: @preconcurrency import WebKit; MainActor.assumeIsolated wrapper in userContentController(_:didReceive:)

## Findings
- ButterchurnBridge is @MainActor; userContentController is marked nonisolated to satisfy the WKScriptMessageHandler requirement.
- WKScriptMessage.body is main-actor isolated in Swift 6 WebKit overlays; accessing it from a nonisolated method requires main-actor context.
- MainActor.assumeIsolated is synchronous and assumes current execution is on the main actor; it does not hop to the main actor.
- WebKit APIs (WKWebView/WKUserContentController) are main-thread only per Apple docs; SwiftUI creates/dismantles views on main actor.
- @preconcurrency import WebKit suppresses concurrency checking for WebKit types and may mask other issues.
- Duplicate -rpath warnings typically come from LD_RUNPATH_SEARCH_PATHS having the same entry twice (project + target or xcconfig override).
