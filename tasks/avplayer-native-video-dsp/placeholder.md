# Placeholders: AVPlayer-Native Video DSP

> **Task:** `tasks/avplayer-native-video-dsp/`
> **Status:** ACTIVE — 3 of 6 items still open (P-2, P-3, P-6); P-1/P-4/P-5 closed.
> **Last revised:** 2026-09-05 — P-2/P-3/P-6 open; P-1/P-4/P-5 resolved.

Per project convention (`/Users/hank/.claude/CLAUDE.md` — "Placeholders" section), no `// TODO` comments are allowed in production code. Anything that's stubbed/deferred during implementation must be documented here with: file:line, purpose, status, and action.

---

## P-1 — `BiquadCoefficientSet` empty struct stub (resolved)

- **File:** `MacAmpApp/Audio/VideoDSP/BiquadCoefficientSet.swift`
- **Phase:** 2
- **Purpose:** Forced by Swift's access-control rules — `VideoTapContext.coefficientSetPointer: Atomic<UnsafePointer<BiquadCoefficientSet>?>` (a module-internal field) needs a non-fileprivate type. Empty internal stub created in Phase 2 so the field is `internal`. The two coefficient blocks (`coefficientBlockA/B`) are allocated against this stub's stride (1 byte for an empty struct). Phase 2 has NO writer or reader for the pointer (the install method was withdrawn pre-merge per P-4); the pointer stays nil throughout Phase 2 and `tapProcess` never reads it.
- **Status:** RESOLVED (Phase 3, commit `24f8a12` — real `BiquadCoefficientSet` landed)
- **Action (Phase 3 — DONE):** Replaced the empty struct with the real `struct BiquadCoefficientSet { let bands: (BiquadCoefs ×10) }` per plan §6 Phase 3 §3.1. The field declaration on `VideoTapContext` and the `init`/`deinit` allocation pattern stay unchanged because the type name is preserved. Phase 3 ALSO designed and added the install method per P-4 (the prior naive A/B-swap design was withdrawn).

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
- **Status:** RESOLVED (commit `c040e76`, 2026-05-02). Field doc on `player` now explicitly notes it is observed.
- **Test gap:** the existing `VideoTapLifecycleTests` exercise `VideoPlaybackController.loadVideo` directly and verify `controller.player` is/isn't assigned, but they cannot test "the SwiftUI view re-renders." That coverage stays in the manual smoke test (todo 2.39). If we ever automate it, the surface to assert against is `Mirror(reflecting: VideoPlaybackController()).children` — verify `player` shows up as a non-Void reflected child (`@ObservationIgnored` would hide it from observation tracking).

---

## P-4 — ADR-4 double-buffer coefficient hand-off needed redesign before Phase 3 read coefficients (closed)

- **Files:** `MacAmpApp/Audio/VideoDSP/VideoTapContext.swift` (at the time of the finding: alloc/dealloc still in place, install method withdrawn for Phase 2); `tasks/avplayer-native-video-dsp/plan.md` ADR-4 — amended in Phase 3 (amendment #2).
- **Phase:** Phase 2 finding; resolution required by Phase 3.
- **Purpose:** Oracle review of Phase 2 (gpt-5.5, 2026-05-02, score 8/10 REVISE) flagged that the naive A/B swap from ADR-4 is not race-safe in practice. Sequence: render thread loads pointer → P=A → starts processing using A. Main thread installs new coefficients into B and swaps pointer → P=B. Main thread installs again — picks A as the "inactive" block (since current is B) and writes to A while render thread is STILL reading A (its initial load happened before any of this). Result: render reads partially-overwritten A. Acquire/release ordering does not fix the pointee-lifetime race. Latent in Phase 2 because `tapProcess` does not yet read coefficients, but the scaffold encoded the unsafe invariant — `installCoefficientSet` was withdrawn before Phase 2 close to avoid making the racy contract reusable.
- **Status:** ✅ **CLOSED (Phase 3 — `Mutex<BiquadCoefficientSet?>` + `installCoefficients` + `BiquadCascade` landed; todo 3.8 / 5.6).**
- **Decision history (2026-05-28 — scheme chosen, Oracle-approved before implementation):** Candidate 3 selected: `let coefficients: Mutex<BiquadCoefficientSet?>` with main `withLock` / render `withLockIfAvailable` (copy-out into a render-owned `BiquadCascade` cache, process lock-free, skip-on-contention reuses cache). Rationale + design rules + code delta recorded in `plan.md` **ADR-4 amendment #2**. Codex Oracle (gpt-5.5, xhigh) returned **9.0/10 APPROVED**, no blockers; 4 actionable items (double-optional `BiquadCoefficientSet??` handling, `BiquadCascade` ownership/lifetime + retain re-verify trigger, softened starvation wording, stale downstream §6 text) all folded into the amendment + §6 Phase 3 Files block.
- **Action (Phase 3 — DONE):** implemented per ADR-4 amendment #2 — removed `coefficientSetPointer` + `coefficientBlockA/B` + manual alloc/dealloc from `VideoTapContext`; add `let coefficients: Mutex<BiquadCoefficientSet?>`; build `BiquadCascade` as the render-owned state holder (z1/z2 + coefficient cache) with explicit per-tap ownership; wire `tapProcess` step 5 to refresh the cache via `withLockIfAvailable` with three-case handling. Re-verify `passRetained`↔`tapFinalize` balance if a render-state wrapper is introduced. P-4 closed when the install path landed (todo 3.8; leak balance unchanged — no re-verify trigger hit).

---

## P-6 — Video→audio transition does not auto-play (requires manual Next/forward)

- **File:** `MacAmpApp/Audio/AudioPlayer.swift` — `playTrack` media-switch path (`.video → .audio`): cleanup at lines 544-547, then `loadAudioFile` (line 559) + `play()` (line ~572). *(Line numbers re-verified at HEAD `056c69a`, 2026-09-05; the original 2026-05-28 record cited 490-494 / 505 / ~516.)*
- **Phase:** Phase 2 finding, discovered during the todo 2.40 leak check (2026-05-28).
- **Symptom:** After playing a video, loading an audio track does NOT auto-play — the user must hit Next/forward to start audio. Audio-only → audio-only transitions auto-play normally.
- **Suspected cause (unconfirmed):** the `.video → .audio` cleanup (`invalidateInFlightVideoLoad` + `pauseAndDetachVideoTapIfNeeded` + `videoPlaybackController.cleanup()`) likely leaves transport state such that the trailing `play()` no-ops; or `loadAudioFile` is async and the immediate `play()` races ahead of the engine being ready. Needs end-to-end diagnosis (instrument both the media-switch decision and the engine-ready state, per the pipeline-diagnosis discipline).
- **Status:** Open, NON-BLOCKING (user deprioritized 2026-05-28). Not a leak; does not affect Phase 3 gating. Logged so it is not lost.
- **Action:** Phase 7 closed 2026-06-26 without diagnosing it. Now: expected known-issue caveat in Phase 8 manual gate 8.14; document in Phase 9 (`docs/VIDEO_WINDOW.md` "Known Issue" section); fix in a dedicated follow-up or the S4-2 GitHub-issues sprint. Likely fix: sequence the audio `play()` to fire after the video→audio teardown + engine-ready completes.
