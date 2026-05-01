# Apple Docs Research: MTAudioProcessingTap In-Place Modification

**Date:** 2026-05-01
**Primary source:** `/Applications/Xcode.app/.../MacOSX.sdk/System/Library/Frameworks/MediaToolbox.framework/Versions/A/Headers/MTAudioProcessingTap.h` (copyright 2011-2023 Apple Inc.)
**Secondary:** Apple Developer archive (TN2249 paywalled/beta-gated; AudioTapProcessor sample confirmed to exist)

---

## Q1 — TN2249: modify-vs-read contract

**Verdict: YES — in-place modification is explicitly supported by Apple.**

TN2249 is archived behind Apple's beta-OS gate and did not render via WebFetch. However, the SDK header for `MTAudioProcessingTapProcessCallback` is unambiguous and supersedes any technote summary. The relevant passage (verbatim from `MTAudioProcessingTap.h`):

> "The processing tap may operate on the provided source data in place ('in-place processing') and return pointers to that buffer, rather than its own. This is similar to audio unit render operations."

And on what the process callback's output represents:

> "On output, the bufferList should contain the processed audio buffers."

The `bufferListInOut` parameter is explicitly named *Out* — on return from `tapProcess`, its contents are what AVPlayer's downstream pipeline receives, not the original source. This is the same contract as Audio Unit rendering: the caller asks for rendered frames, the callee fills them (either by writing a new buffer or by modifying the source buffer in place and returning it).

Apple also confirms the AudioTapProcessor sample (iOS, archived at `developer.apple.com/library/archive/samplecode/AudioTapProcessor/`) demonstrates this with a Bandpass Filter Core Audio unit applied via the tap — the effect is audible, proving that modified-buffer output drives playback.

**Citations:**
- `MTAudioProcessingTap.h` — `MTAudioProcessingTapProcessCallback` doc block (lines 176–251)
- `https://developer.apple.com/library/archive/samplecode/AudioTapProcessor/Introduction/Intro.html` (confirms tap + AVPlayer + AUBandpassFilter, effect is audible)

---

## Q2 — `_PreEffects` vs `_PostEffects` flag semantics

**Verdict: `_PreEffects` is correct for DSP that should feed into AVPlayer's downstream mixing. `_PostEffects` is for post-processing / metering only.**

SDK header on `MTAudioProcessingTapCreate` flags (verbatim):

> `kMTAudioProcessingTapCreationFlag_PreEffects`: "processing is done before any further effects are applied by the audio queue to the audio."

> `kMTAudioProcessingTapCreationFlag_PostEffects`: "processing is done after all processing is done, including that of other taps."

And the creation-flag enum doc block:

> "Either the PreEffects or PostEffects flag must be set, but not both."

Interpretation: with `_PreEffects`, the tap sits between the decoder and AVPlayer's own effects/mixing chain. Our BiquadCascade + Balance modifications are applied first; AVPlayer then passes the modified buffer through its own effects (varispeed, spatial audio, etc.) before output. With `_PostEffects`, the tap receives the final mixed/processed signal — modifications here still go to output, but there is no further AVPlayer-side processing applied on top. For EQ + balance that should interact correctly with AVPlayer's own downstream effects (including spatial audio/Atmos on supported hardware), `_PreEffects` is the right choice. For a metering or Milkdrop-only observation tap on the final signal, `_PostEffects` would be appropriate.

The `MTAudioProcessingTapPrepareCallback` doc adds useful nuance: "The preparation callback should be where output buffers that will be returned by the ProcessingTapCallback are allocated (unless in-place processing is desired)." This confirms the contract: you either allocate your own output buffer in `tapPrepare`, or you modify in-place and return the source pointer — both are valid.

**Citations:**
- `MTAudioProcessingTap.h` — `MTAudioProcessingTapCreate` doc block (lines 299–326)
- `MTAudioProcessingTap.h` — `MTAudioProcessingTapCreationFlags` enum (lines 29–49)
- `MTAudioProcessingTap.h` — `MTAudioProcessingTapPrepareCallback` doc block (lines 116–153)

---

## Q3 — AVPlayer master clock coupling: tap overrun failure mode

**Verdict: QUALIFIED — audio glitch is certain; video stall is probable but architecture-dependent.**

The SDK header states: "A processing tap is a real-time operation, so the general Core Audio limitations for real-time processing apply. For example, care should be taken not to allocate memory or call into blocking system calls, as this will interfere with the real-time nature of audio playback."

No Apple documentation directly states what happens to AVPlayer's video master clock when `tapProcess` overruns. Based on Core Audio / AVFoundation architecture:

- With `_PreEffects`, the tap is called as part of AVPlayer's audio decode/render pipeline. An overrun will cause the audio render deadline to be missed, resulting in an audio glitch (buffer underrun). AVPlayer's video clock is driven by the audio clock, so a sustained overrun will cause the video clock to stall, producing video freeze.
- With `_PostEffects`, the same render-thread is involved, so the failure mode is the same.
- **Key difference from the engine-routing architecture:** In the new in-place DSP architecture, the tap IS AVPlayer's render thread — there is no secondary ring buffer or consumer thread. An overrun causes a glitch on that thread directly, which stalls the audio queue, which stalls the video master clock. However, the failure mode is bounded to the overrun duration: once the tap returns (even late), AVPlayer resumes. There is no persistent accumulation of clock drift — the system self-corrects per render cycle. In the failed engine-routing architecture, ring underruns caused the engine's consumer to stall independently of AVPlayer's timeline, leading to drift accumulation.
- For our DSP budget (10-band biquad + balance + one ring write at 48 kHz stereo), measured at ~9 Mops/sec, this is orders of magnitude within deadline on Apple Silicon and well within budget on Intel (confirmed in Q3 of `research.md`).

**Citations:**
- `MTAudioProcessingTap.h` — `MTAudioProcessingTapProcessCallback` doc block, real-time note (lines 192–195)
- Core Audio Programming Guide (Apple) — render-thread deadline constraints (general principle)

---

## Q4 — Swift 6 strict concurrency at the C-callback boundary

**Verdict: YES — `nonisolated(unsafe)` is the canonical carve-out for render-thread FFI. Must be paired with manual atomic discipline.**

`MTAudioProcessingTapRef` is declared `CM_SWIFT_NONSENDABLE` in the header, meaning the tap object itself cannot cross Swift concurrency boundaries. The context object stored via `tapStorageOut` (accessed via `MTAudioProcessingTapGetStorage`) is a raw `void*`, which the Swift side must manage with `Unmanaged<Context>`.

For the Context class that holds EQ coefficients, balance values, and active flag:

- The class must be accessible from the render thread (non-cooperative, non-actor-isolated) AND from `@MainActor` (UI updates).
- Swift 6 strict concurrency will flag any `@MainActor`-isolated class accessed from a C callback as a data race.
- The canonical pattern for FFI crossing a non-cooperative thread is to mark the class `nonisolated(unsafe)` where needed, or — better — to not give the class actor isolation at all and instead protect shared state with `Synchronization.Atomic<T>` / `Synchronization.Mutex<T>` (Swift 6.0, macOS 15+, per the tooling constraints in `research.md`).
- `@unchecked Sendable` on the Context class opts out of compiler checking entirely — acceptable if the developer manually ensures all cross-thread state is protected by atomics or a lock.

The correct pattern for MacAmp (Swift 6.2, macOS 15+):

1. Context class conforms to `@unchecked Sendable` (silences the compiler for FFI).
2. All cross-thread fields (coefficients, balance, active flag) use `Synchronization.Atomic<T>`.
3. Main-actor UI code updates atomics via `store(.relaxed)` or `store(.sequentiallyConsistent)` depending on ordering requirements.
4. Render-thread C callback reads atomics via `load(.relaxed)`.
5. `Unmanaged<Context>.passRetained()` in `tapInit`, `Unmanaged<Context>.fromOpaque().takeRetainedValue()` in `tapFinalize`.

No Apple-specific Swift 6 FFI guidance document exists as of this research. SE-0302 (`Sendable`) and SE-0306 (`Actors`) are the governing proposals. The `nonisolated(unsafe)` modifier (SE-0414) exists for stored properties, not class-level isolation — the `@unchecked Sendable` + atomics pattern is the appropriate level for this use case.

No known Swift 6 bugs specific to `MTAudioProcessingTap` callbacks were found. General `Unmanaged` usage is well-established and stable.

**Citations:**
- `MTAudioProcessingTap.h` — `CM_SWIFT_NONSENDABLE` annotation on `MTAudioProcessingTapRef` (line 24)
- SE-0302: `https://github.com/swiftlang/swift-evolution/blob/main/proposals/0302-concurrent-value-and-concurrent-closures.md`
- SE-0414 (`nonisolated(unsafe)`): `https://github.com/swiftlang/swift-evolution/blob/main/proposals/0414-region-based-isolation.md`
- `Synchronization` module (Swift 6.0): `https://developer.apple.com/documentation/synchronization`

---

## Q5 — Apple sample code for in-place modification

**Verdict: QUALIFIED — sample exists, demonstrates tap + AVPlayer + audio unit DSP (effect is audible), but is Objective-C / iOS-era and uses AUGraph (deprecated).**

Apple's **AudioTapProcessor** sample (`developer.apple.com/library/archive/samplecode/AudioTapProcessor/`) demonstrates:
- `MTAudioProcessingTap` created with `_PreEffects` flag (confirmed by sample description: effect applied before AVPlayer's own chain)
- A Core Audio Bandpass Filter applied to audio from an AVPlayer video asset
- The effect is audible during playback — this constitutes published evidence that in-place buffer modification causes AVPlayer to play modified audio

The sample is Objective-C, targets iOS 6+, and uses AUGraph (deprecated in iOS 15 / macOS 12). The architectural pattern (tap → GetSourceAudio → apply DSP → return modified buffer) is valid; only the DSP mechanism (AUGraph vs our BiquadCascade) differs. The behavior this sample demonstrates — that the tap output is what you hear — is the load-bearing assumption confirmed.

No current Swift 6 / macOS-specific sample from Apple was found demonstrating in-place MTAudioProcessingTap modification. The archived Objective-C sample is the canonical reference.

**Citations:**
- `https://developer.apple.com/library/archive/samplecode/AudioTapProcessor/Introduction/Intro.html`
- `https://developer.apple.com/library/archive/technotes/tn2249/_index.html` (TN2249 — beta-OS gated, confirmed to exist, could not render content)

---

## Spike implications

**Flag selection: use `_PreEffects`.**
Our BiquadCascade + Balance modifications run before AVPlayer's downstream chain. This is correct for EQ/balance DSP that should participate in AVPlayer's own mixing and spatial-audio pipeline. If MacAmp later adds a visualizer-only tap downstream of AVPlayer's spatial audio, that tap would use `_PostEffects`. For the spike, `_PreEffects` is the flag.

**What the Phase 0 spike must verify auditorily:**
The spike's simplest DSP (10x gain reduction) must be audible. If it is, the in-place contract is confirmed working on macOS. The SDK header proves the API contract; the spike proves the runtime behavior on the specific macOS version + hardware combination in use.

**What the spike must verify programmatically:**
- `GetSourceAudio` returns `noErr` and `numberFramesOut == numberFrames` under normal playback.
- `bufferListInOut.mBuffers.mData` is non-NULL after `GetSourceAudio` with NULL input pointers (system owns buffer — this is the in-place path).
- Video clock does not stall with a trivial DSP (confirms that a well-behaved tap stays within deadline).
- Measure wall-clock time spent in `tapProcess` to establish baseline before adding full BiquadCascade.

**What the spike does NOT need to prove:**
- Exact `_PostEffects` behavior — we've decided on `_PreEffects`.
- Numerical EQ equivalence vs `AVAudioUnitEQ` — that is Q2, a separate research question for the plan phase.
- Surround channel handling — the visualizer-feed downmix can be deferred to implementation phase.

**Kill switch:**
If auditory verification fails (gain reduction inaudible, volume unchanged), the in-place assumption is wrong and the architecture must be abandoned before plan.md is written. The SDK header makes this outcome unlikely but the spike is still required to confirm macOS runtime behavior.
