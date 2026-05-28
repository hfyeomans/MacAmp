# Placeholders: AVPlayer-Native Video DSP

> **Task:** `tasks/avplayer-native-video-dsp/`
> **Status:** Active during Phase 2+.

Per project convention (`/Users/hank/.claude/CLAUDE.md` — "Placeholders" section), no `// TODO` comments are allowed in production code. Anything that's stubbed/deferred during implementation must be documented here with: file:line, purpose, status, and action.

---

## P-1 — `BiquadCoefficientSet` empty struct stub

- **File:** `MacAmpApp/Audio/VideoDSP/BiquadCoefficientSet.swift`
- **Phase:** 2
- **Purpose:** Forced by Swift's access-control rules — `VideoTapContext.coefficientSetPointer: Atomic<UnsafePointer<BiquadCoefficientSet>?>` (a module-internal field) needs a non-fileprivate type. Empty internal stub created in Phase 2 so the field is `internal`. The two coefficient blocks (`coefficientBlockA/B`) are allocated against this stub's stride (1 byte for an empty struct). Phase 2 has NO writer or reader for the pointer (the install method was withdrawn pre-merge per P-4); the pointer stays nil throughout Phase 2 and `tapProcess` never reads it.
- **Status:** Active
- **Action (Phase 3):** Replace the empty struct with the real `struct BiquadCoefficientSet { let bands: (BiquadCoefs ×10) }` per plan §6 Phase 3 §3.1. The field declaration on `VideoTapContext` and the `init`/`deinit` allocation pattern stay unchanged because the type name is preserved. Phase 3 must ALSO design and add the install method per P-4 (the prior naive A/B-swap design was withdrawn).

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
- **Purpose:** `VideoTap.buildAudioMix(...)` is `@MainActor`-isolated and is called from a Task that has previously awaited `asset.loadTracks(...)` (the await happens in the AudioPlayer-side closure). Under Swift 6 strict concurrency, `AVAsset` is not yet annotated `Sendable`, so values cannot cross some of these await boundaries cleanly. `@preconcurrency` downgrades the diagnostic, matching the existing project pattern in `MacAmpApp/Audio/AudioEngineConfigurationObserver.swift`.
- **Status:** Acceptable workaround
- **Action:** Drop `@preconcurrency` whenever AVFoundation receives proper `Sendable` annotations for `AVAsset`. Until then, retain the import attribute and document at the call site.

---

## P-5 — `VideoPlaybackController.player` observation regression (resolved)

- **File:** `MacAmpApp/Audio/VideoPlaybackController.swift`
- **Phase:** 2 (post-revision regression caught during user smoke testing 2026-05-02)
- **Symptom:** Video playback produced audio but the video window stayed on "No video loaded" — view never re-rendered to reveal the new AVPlayer.
- **Root cause:** `VideoPlaybackController.player` was annotated `@ObservationIgnored`. Pre-Phase-2 `loadVideo` was synchronous: by the time `currentMediaType` change triggered a view re-render, `player` was already non-nil and the view's single re-render picked it up. Phase 2's Option C refactor moved `loadVideo` into a `Task` so player assignment now happens AFTER the synchronous `currentMediaType` change. With `@ObservationIgnored`, no observable property changed when the Task assigned `player = newPlayer`, so the view never re-rendered to switch from the placeholder to the player.
- **Fix:** dropped `@ObservationIgnored` from `player`. The other ignored fields on `VideoPlaybackController` (`endObserver`, `timeObserver`, `metadataTask`) remain ignored — they are real housekeeping that should NOT trigger view re-renders. `player` was conflating those housekeeping cases with a load-bearing view dependency.
- **Status:** RESOLVED (commit pending). Field doc on `player` now explicitly notes it is observed.
- **Test gap:** the existing `VideoTapLifecycleTests` exercise `VideoPlaybackController.loadVideo` directly and verify `controller.player` is/isn't assigned, but they cannot test "the SwiftUI view re-renders." That coverage stays in the manual smoke test (todo 2.39). If we ever automate it, the surface to assert against is `Mirror(reflecting: VideoPlaybackController()).children` — verify `player` shows up as a non-Void reflected child (`@ObservationIgnored` would hide it from observation tracking).

---

## P-4 — ADR-4 double-buffer coefficient hand-off needs redesign before Phase 3 reads coefficients

- **Files:** `MacAmpApp/Audio/VideoDSP/VideoTapContext.swift` (alloc/dealloc still in place; install method withdrawn for Phase 2); `tasks/avplayer-native-video-dsp/plan.md` ADR-4 needs amendment in Phase 3.
- **Phase:** Phase 2 finding; resolution required by Phase 3.
- **Purpose:** Oracle review of Phase 2 (gpt-5.5, 2026-05-02, score 8/10 REVISE) flagged that the naive A/B swap from ADR-4 is not race-safe in practice. Sequence: render thread loads pointer → P=A → starts processing using A. Main thread installs new coefficients into B and swaps pointer → P=B. Main thread installs again — picks A as the "inactive" block (since current is B) and writes to A while render thread is STILL reading A (its initial load happened before any of this). Result: render reads partially-overwritten A. Acquire/release ordering does not fix the pointee-lifetime race. Latent in Phase 2 because `tapProcess` does not yet read coefficients, but the scaffold encoded the unsafe invariant — `installCoefficientSet` was withdrawn before Phase 2 close to avoid making the racy contract reusable.
- **Status:** Open architectural decision; must be resolved BEFORE `tapProcess` reads coefficients (Phase 3 gate).
- **Action (Phase 3):** Pick one of: (1) triple-buffer + atomic "in-use" counter to mark which slot the render thread is currently reading; (2) RCU-style allocate-fresh-each-install + deferred free of retired buffers (e.g. Hazard Pointers, epoch-based reclamation); (3) `Synchronization.Mutex<BiquadCoefficientSet>` with `withLockIfAvailable` on the render thread (skip-update on contention). Update plan.md ADR-4 with the chosen scheme + rationale; re-run Oracle review on the redesign before implementation.

---

## P-6 — Video→audio transition does not auto-play (requires manual Next/forward)

- **File:** `MacAmpApp/Audio/AudioPlayer.swift` — `playTrack` media-switch path (`.video → .audio`): cleanup at lines 490-494, then `loadAudioFile` (line 505) + `play()` (line ~516).
- **Phase:** Phase 2 finding, discovered during the todo 2.40 leak check (2026-05-28).
- **Symptom:** After playing a video, loading an audio track does NOT auto-play — the user must hit Next/forward to start audio. Audio-only → audio-only transitions auto-play normally.
- **Suspected cause (unconfirmed):** the `.video → .audio` cleanup (`invalidateInFlightVideoLoad` + `pauseAndDetachVideoTapIfNeeded` + `videoPlaybackController.cleanup()`) likely leaves transport state such that the `play()` at line ~516 no-ops; or `loadAudioFile` is async and the immediate `play()` races ahead of the engine being ready. Needs end-to-end diagnosis (instrument both the media-switch decision and the engine-ready state, per the pipeline-diagnosis discipline).
- **Status:** Open, NON-BLOCKING (user deprioritized 2026-05-28). Not a leak; does not affect Phase 3 gating. Logged so it is not lost.
- **Action:** Diagnose during Phase 7 lifecycle/transition testing or a dedicated follow-up. Likely fix: sequence the audio `play()` to fire after the video→audio teardown + engine-ready completes.
