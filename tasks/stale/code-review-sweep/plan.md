# Plan - Code Review Sweep

1) Sweep code for comments or debug statements referencing Oracle/phase/test scaffolding; reword or remove while preserving important rationale. Gate or remove unnecessary debug logging, especially stray prints.  
2) Validate comment quality around drag/visibility toggles and window controllers, replacing slang with concise, descriptive notes; ensure no stale TODOs/rookie notes remain.  
3) Perform a targeted code review focused on Swift 6/SwiftUI macOS 15+/26+ adherence (state isolation, @MainActor usage, window management patterns), then document findings in `code_review.md`.
