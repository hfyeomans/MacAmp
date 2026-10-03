# Todo: Swift 6.4 / macOS 27 Adoption (S4-1)

Updated: 2026-10-02

Scope, anchors and gating live in `state.md`. Phase 0 may run any time; Phase 2 starts after the Structure Sprint and the owner's sign-off on `plan.md`.

## Phase 0: Research (no code)

- [ ] 0.1 Read the 8 relevant files in the Xcode documentation bundle (list in `research.md`); treat their claims as WWDC25-generation unless a second source confirms macOS 27
- [ ] 0.2 `agy -p` deep research per `research.md` §3 (Swift 6.2 to 6.4 and macOS 26 to 27 deltas, primary sources only)
- [ ] 0.3 WebSearch point lookups for anything 0.2 leaves ambiguous (swift.org release notes, Swift Evolution status)
- [ ] 0.4 Answer (a): Swift 6.4 language-mode changes, including the ADR-3a containment gates and `Atomic`/`Mutex` in `MacAmpApp/Audio/VideoDSP/`
- [ ] 0.5 Answer (b): SwiftUI additions worth adopting under the 1:1 pixel-faithful skin constraint
- [ ] 0.6 Answer (c): macOS 27 AppKit (Liquid Glass), toolbars, WebKit-in-SwiftUI, AVFoundation/`MTAudioProcessingTap` and AVAudioEngine additions and deprecations
- [ ] 0.7 Build the per-subsystem impact matrix
- [ ] 0.8 Recount the macOS 27 deprecations from a build log
- [ ] 0.9 Record open questions for the owner in `research.md`

## Phase 1: Plan

- [ ] 1.1 Write `plan.md`: adopt/defer call per scope item, phases with a kill switch each
- [ ] 1.2 Record D-TARGET27 as ADR-1
- [ ] 1.3 Write the Swift 6.4 language-mode ADR: `SWIFT_VERSION` and tools-version together or staged, rollback path, ADR-3a gates, `Atomic`/`Mutex`, default MainActor isolation; name the manifest that remains after the root `Package.swift` deletion
- [ ] 1.4 Owner sign-off on `plan.md`

## Phase 2: Implementation (after the Structure Sprint; order set by `plan.md`)

- [ ] 2.1 Re-run the TSan baseline at pickup (137 tests / 21 suites on 2026-10-02; commands, including the sandbox variant, in `tasks/_context/state.md` (Process, Verification))
- [ ] 2.2 Replace the macOS 27 deprecations (production and test-only)
- [ ] 2.3 Bump `xcodeVersion` in `project.yml` to 27
- [ ] 2.4 Delete the unused `spriteResolver` environment helpers (with their MARK and `import SwiftUI`), then drop `@unchecked Sendable` from `Skin`
- [ ] 2.5 Fix the LockFreeRingBuffer overrun race (drop-newest or documented accepted loss) and rewrite its doc comment
- [ ] 2.6 Add the overrun-during-read TSan stress test; replace `withKnownIssue` on the "High throughput" test
- [ ] 2.6b One named constant for the StreamPlayer ring capacity (4 sites); unit tests for `activateStreamBridge` / `deactivateStreamBridge`
- [ ] 2.7 Move `ManagedAtomic` to `Synchronization.Atomic` if `plan.md` adopts it, and drop swift-atomics if nothing else needs it
- [ ] 2.8 Fallback: if S3-4 C1 did not, delete root `Package.swift`, `Package.resolved` and the `.swiftlint.yml` exclude, pinning exact package versions in `project.yml` in the same change
- [ ] 2.9 Adopt `Span`/`MutableSpan`/`InlineArray` per `plan.md`
- [ ] 2.10 Evaluate `-strict-memory-safety`
- [ ] 2.11 Strict-concurrency cleanups: P-2, P-3, `nonisolated(unsafe)` x1, `Task.detached` x3 (if SS-7 left them)
- [ ] 2.12 Passthrough guard
- [ ] 2.13 Recheck the NSMenu "Internal inconsistency" warnings on macOS 27
- [ ] 2.15 Apply the language-mode ADR outcome
- [ ] 2.16 Optional: ring-buffer benchmarks
- [ ] 2.17 Per change: `xcodegen generate`, then `xcodebuildmcp macos build` and `test` with `--json '{"extraArgs":["-enableThreadSanitizer","YES"]}'`

## Phase 3: Close-out

- [ ] 3.1 Note in `research.md` any deprecation findings that touch S4-2's code paths
- [ ] 3.2 One exhaustive `/codex:review --base main`; fix what affects correctness; PR; the owner merges
- [ ] 3.3 Close P-2/P-3 in `tasks/done/avplayer-native-video-dsp/placeholder.md` and the S4-1 rows in `tasks/_context/deferred.md`; update `_context`
- [ ] 3.4 `git mv tasks/swift64-macos27-readiness tasks/done/`
