# Placeholders: AVPlayer-Native Video DSP

> **Task:** `tasks/avplayer-native-video-dsp/`
> **Status:** Active during Phase 2+.

Per project convention (`/Users/hank/.claude/CLAUDE.md` — "Placeholders" section), no `// TODO` comments are allowed in production code. Anything that's stubbed/deferred during implementation must be documented here with: file:line, purpose, status, and action.

---

## P-1 — `BiquadCoefficientSet` empty struct stub

- **File:** `MacAmpApp/Audio/VideoDSP/BiquadCoefficientSet.swift`
- **Phase:** 2
- **Purpose:** Forced by Swift's access-control rules — `VideoTapContext.coefficientSetPointer: Atomic<UnsafePointer<BiquadCoefficientSet>?>` and `installCoefficientSet(_:)` need a non-fileprivate type. Empty internal stub created in Phase 2 so the field/method can be `internal`. The two coefficient blocks (`coefficientBlockA/B`) are allocated against this stub's stride (1 byte for an empty struct).
- **Status:** Active
- **Action (Phase 3):** Replace the empty struct with the real `struct BiquadCoefficientSet { let bands: (BiquadCoefs ×10) }` per plan §6 Phase 3 §3.1. The field declarations on `VideoTapContext` and the `init`/`deinit` allocation pattern stay unchanged because the type name is preserved.

---

## P-2 — Mirror reflection coverage gap on `~Copyable` fields

- **File:** `Tests/MacAmpTests/VideoTapSendableContractTests.swift` (Test 3a)
- **Phase:** 2
- **Purpose:** Plan ADR-3a Gate 3a envisioned `Mirror` reflection catching all type-shape violations on `VideoTapContext` stored fields. In Swift 6, `Synchronization.Atomic<T>` and `Synchronization.Mutex<T>` are `~Copyable`; `Mirror.Child.value: Any` requires `Copyable`, so `~Copyable` fields reflect as `Void` (`()`) and cannot be inspected. The test now skips `Void`-typed children with an inline comment explaining the gap. Atomic/Mutex remain safe by construction (the stdlib wrappers carry the thread-safety contract), and Test 3b's source-level regex enforces the `var` mutability rule. The remaining gap — a future `let foo: SomeNonCopyableType` that is not actually atomic — is gated only by the file header contract (Gate 1) plus code review.
- **Status:** Documented limitation; not a bug
- **Action:** Note for Oracle pre-PR review. If Oracle prefers stricter coverage, options are: (a) extend Test 3b to also gate `let` declarations against an allowlist of `RenderThreadSafe`-conforming type prefixes, or (b) source-parse a complete field inventory and cross-check against the conformance list in `RenderThreadSafe.swift`. Both add brittleness; the current trade-off accepts the gap.

---

## P-3 — `@preconcurrency import AVFoundation` in `VideoTap.swift`

- **File:** `MacAmpApp/Audio/VideoDSP/VideoTap.swift:1`
- **Phase:** 2
- **Purpose:** `VideoTap.attach(to:context:)` calls `try await playerItem.asset.loadTracks(withMediaType: .audio)`. Under Swift 6 strict concurrency, `AVAsset` is not yet annotated `Sendable`, so the value cannot cross the `await` boundary out of the `@MainActor`-isolated function. `@preconcurrency` downgrades the diagnostic, matching the existing project pattern in `MacAmpApp/Audio/AudioEngineConfigurationObserver.swift`.
- **Status:** Acceptable workaround
- **Action:** Drop `@preconcurrency` whenever AVFoundation receives proper `Sendable` annotations for `AVAsset`. Until then, retain the import attribute and document at the call site.
