# Plan: Swift 6 concurrency review (Butterchurn)

1. Confirm the concurrency fix in ButterchurnBridge and identify any Swift 6 risks.
2. Verify WebKit threading expectations for WKScriptMessageHandler and assess MainActor.assumeIsolated usage.
3. Check related files for additional Swift 6 strict concurrency issues.
4. Provide guidance on @preconcurrency import WebKit and duplicate -rpath warning causes.
5. Summarize findings with severity, recommendations, and a grade.
