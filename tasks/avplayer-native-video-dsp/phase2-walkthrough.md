# Phase 2 Walkthrough — `avplayer-native-video-dsp` (S3-2)

> **Status:** Phase 2 ✅ closed 2026-05-02. Codex Oracle 9.0/10 APPROVED after 7 review rounds.
> **Commits:** Initial scaffold `ac7e0d5`; revision `7d3367c`. 34 commits ahead of main.
> **Tests:** 85/85 with TSan ON (72 baseline + 2 contract + 6 lifecycle + 5 seek-state-matrix).
> **Audience:** Hank, reviewing what Phase 2 shipped before moving to Phase 3.

---

## TL;DR

Phase 2 is the **production scaffold** for the in-place `MTAudioProcessingTap` that will eventually apply EQ + balance + visualizer DSP to AVPlayer's audio buffer. **No actual DSP runs yet** — the tap is observably pass-through; AVPlayer plays the buffer unchanged. Phase 3 fills in the biquad math.

What Phase 2 does ship:
- The full C-callback machinery + Unmanaged lifetime + ASBD format gate + ADR-10 release-on-failure.
- An ADR-3a-compliant `@unchecked Sendable` containment via marker protocol (`RenderThreadSafe`) + header contract block + DEBUG Mirror + source-level regex tests.
- Option C structural fix for ADR-7: `audioMix` is configured during `AVPlayerItem` construction, BEFORE the `AVPlayer` adopts the item — eliminates the mid-playback mutation race the original plan had.
- Generation-counter orchestration in AudioPlayer that short-circuits superseded video loads BEFORE any AVPlayer/observer mutation, plus identity guards on observers + seek so stale callbacks can't mutate transport state.

---

## Code paths overview

### Engine path (audio files + streams) — UNCHANGED in Phase 2

```
AVAudioPlayerNode  ──┐
(local files)        │
                     ├──► AVAudioUnitEQ ──► balance ──► main mixer ──► output
AVAudioSourceNode  ──┘                                        │
(streams: custom decode →                              installTap (bus 0)
 ring → source node)                                          │
                                                              ▼
                                                    VisualizerFeed.write()
                                                    (engine-side tap publishes
                                                     RMS×20 + Goertzel×20 +
                                                     2048-pt FFT scope+spectrum)
                                                              │
                                                              ▼
                                                    VisualizerPipeline (30 Hz Timer)
                                                    → spectrum bars / Butterchurn
```

Phase 1 already extracted `VisualizerFeed` + `VisualizerScratchBuffers` out of `VisualizerPipeline.swift` into module-internal files so the new video tap can publish to the same single-slot SPSC structure.

### Video path — NEW in Phase 2 (pass-through scaffold)

```
playTrack(video)
   │ AudioPlayer.startVideoLoad(track:)        ← bumps videoLoadGeneration
   ▼                                              cancels prior in-flight Task
Task { @MainActor [weak self] in ... }          ← captures `gen` by value
   │
   ▼
[stale-check: gen == self.videoLoadGeneration?] ─ no ─► return
   │ yes
   ▼
await videoPlaybackController.loadVideo(
    url:, autoPlay: false,
    audioMixBuilder: { asset in
        [stale-check #2 inside builder]
        let tracks = await asset.loadTracks(.audio)   ← async; can suspend
        [stale-check #3 after await]
        let context = VideoTapContext()
        let mix = try VideoTap.buildAudioMix(audioTrack:, context:)
            ↳ MTAudioProcessingTapCreate (Unmanaged.passRetained context)
            ↳ ADR-10: release retained on Create failure, throw createFailed
            ↳ wrap in AVMutableAudioMixInputParameters + AVMutableAudioMix
        self.videoTapContext = context  ← AFTER buildAudioMix succeeds (no phantom on throw)
        return mix
    },
    isStillRelevant: { gen == self.videoLoadGeneration }
)
   │
   ▼
loadVideo internal:
   cleanup()                                       ← pauses + nils prior player
   AVURLAsset(url:)                                ← sync
   let mix = await audioMixBuilder(asset)          ← may return nil (no track / stale)
   guard isStillRelevant?() else { return }        ← short-circuits BEFORE any
                                                     AVPlayerItem/AVPlayer/observer
                                                     mutation
   AVPlayerItem(asset:)                            ← sync
   playerItem.audioMix = mix                       ← ADR-7: set ONCE, BEFORE
                                                     AVPlayer adopts the item
   AVPlayer(playerItem:)                           ← sync
   self.player = newPlayer                         ← sync
   install observers (with player-identity guards)
   if autoPlay { player.play() }                   ← false here; play() fires from
                                                     the outer Task after gen check
   │
   ▼
[stale-check #4 post-load]
[gate: playbackState == .playing]                  ← user pause-during-load honoured
   │
   ▼
videoPlaybackController.play()
   │
   ▼
🔊 (Phase 2: pass-through. tapProcess: GetSourceAudio + format gate + return.
    Phase 3+: biquad → balance → visualizer DSP, all in place.)
```

### Tap callback flow (render thread, MTAudioProcessingTap-owned)

```
[tapInit fires once at MTAudioProcessingTapCreate]
    tapStorageOut.pointee = clientInfo (the +1-retained Unmanaged context)

[tapPrepare fires when format is known / re-known]
    Read AudioStreamBasicDescription
    Set processingFormatTag (.releasing): supported (Float32 LPCM) or unsupported
    Set pendingSampleRate (Double bit-pattern)
    Set isActive = true

[tapProcess fires per render quantum]
    GetSourceAudio (writes flagsOut + framesOut + bufferList in place)
    Increment processCallCount + frameCount
    if formatTag != supported { return }                 ← pass-through (ADR-11)
    -- Phase 3 will add steps 2-6 here from ADR-5 --
        2. Filter reset on flagsOut.startOfStream (ADR-9)
        3. Preamp multiply (gated on != 1.0)
        4. EQ on/off gate
        5. BiquadCascade.process via P-4 hand-off scheme
        6. Balance L/R multiplies (gated on != 0.5)
    return

[tapUnprepare fires when format will change / tap ends]
    Set isActive = false

[tapFinalize fires once when tap is released]
    Unmanaged<VideoTapContext>.fromOpaque(storage).release()  ← exactly once
```

### Detach paths (all converge on pause-before-detach + audioMix=nil)

```
playTrack(audio)  while currentMediaType == .video
    AudioPlayer.invalidateInFlightVideoLoad()
    AudioPlayer.pauseAndDetachVideoTapIfNeeded()       ← pauses if playing,
        videoPlaybackController.pause()                  then VideoTap.detach
        VideoTap.detach(from: playerItem)
        videoTapContext = nil
    videoPlaybackController.cleanup()

playTrack(video)  (already video → swap items)
    AudioPlayer.pauseAndDetachVideoTapIfNeeded()
    startVideoLoad(track:)  ← cleanup runs inside loadVideo

stop()
    AudioPlayer.invalidateInFlightVideoLoad()
    AudioPlayer.pauseAndDetachVideoTapIfNeeded()
    videoPlaybackController.stop()  → cleanup()
```

---

## New files (Phase 2 source surface)

| File | Purpose |
|---|---|
| `MacAmpApp/Audio/RenderThreadSafe.swift` | ADR-3a Gate 2 marker protocol (`internal protocol RenderThreadSafe: ~Copyable {}`) + conformance extensions for `Atomic`, `Mutex`, `Optional<Wrapped: RenderThreadSafe>`, unsafe pointer types, `AudioStreamBasicDescription`, `VisualizerFeed`, `VisualizerScratchBuffers`. Centralization rule: all conformances live in this file (single audit surface). |
| `MacAmpApp/Audio/VideoDSP/VideoTapContext.swift` | `final class VideoTapContext: @unchecked Sendable`. ADR-3a Gate 1 header contract block at top (allowed shapes: Atomic / Mutex / immutable primitive `let` / Unsafe[Mutable]Pointer with documented lifetime / RenderThreadSafe-conforming; forbidden: `@MainActor`-isolated, actor-isolated, non-Sendable refs, capturing closures, `var` of primitive). 9 atomic fields (`coefficientSetPointer`, `balance`, `isEqOn`, `preampLinearGainBits`, `processingFormatTag`, `pendingSampleRate`, `processCallCount`, `frameCount`, `isActive`). Two pre-allocated `BiquadCoefficientSet` blocks for alloc/dealloc lifecycle. **No install API in Phase 2** (per P-4). DEBUG `_makeForContractTest` factory. |
| `MacAmpApp/Audio/VideoDSP/VideoTap.swift` | 5 file-scope `private let` C-callback closures (`tapInit`/`tapFinalize`/`tapPrepare`/`tapUnprepare`/`tapProcess`). `@MainActor static func buildAudioMix(audioTrack:context:) throws -> AVMutableAudioMix` returns a configured mix for caller assignment during AVPlayerItem construction. ADR-10 release-on-failure. ADR-11 ASBD format gate. `@MainActor static func detach(from playerItem:)` for explicit teardown paths. |
| `MacAmpApp/Audio/VideoDSP/BiquadCoefficientSet.swift` | Empty struct stub (P-1). Phase 3 fills with `let bands: (BiquadCoefs ×10)` + `compute(for:sampleRate:)` factory. |
| `Tests/MacAmpTests/VideoTapSendableContractTests.swift` | 2 contract tests under `#if DEBUG`: Test 3a (Mirror reflection over `_makeForContractTest()`); Test 3b (source-level regex on stored `var` declarations). |
| `Tests/MacAmpTests/VideoTapLifecycleTests.swift` | 6 lifecycle/race tests using real clapperboard fixtures: singleAttachLifecycle, rapidDoubleBuildLifecycle, detachDuringPlayerLifetime, loadVideoBailsWhenStaleAfterAudioMixBuilder, loadVideoConstructsPlayerWhenRelevant, staleLoadVideoDropsBuiltMixWithoutLeak. |
| `Tests/MacAmpTests/VideoSeekStateMatrixTests.swift` | 5 tests pinning the seek-completion state contract: nil+playing → still playing; nil+paused → still paused; nil+loaded-idle → stays loaded-idle (regression-protects the Round-5 ACTIONABLE fix); explicit true → playing; explicit false → paused. |

### Modified files

- **`MacAmpApp/Audio/AudioPlayer.swift`** — added `videoTapContext`, `videoLoadGeneration`, `inFlightVideoLoadTask`, private `startVideoLoad(track:)`, `pauseAndDetachVideoTapIfNeeded()`, `invalidateInFlightVideoLoad()`. Wired into `playTrack` (video case + media-switch from video) and `stop()`. The `attachVideoTap`/`detachVideoTap` public facades from the original Phase 2 plan were removed — orchestration is internal.
- **`MacAmpApp/Audio/VideoPlaybackController.swift`** — `loadVideo` became `async` with optional `audioMixBuilder` + `isStillRelevant` parameters. AVPlayerItem is constructed AFTER the audioMix is built (so audioMix is set BEFORE AVPlayer adopts the item — ADR-7 by construction). Identity guards added to `seek` completion, `endObserver`, and the periodic time observer. Seek completion's `resume: nil` path now preserves loaded-but-idle state instead of converting it to "paused"; pause issued during seek is honoured.
- **`.gitignore`** — added allow-rules for `clapperboard-videos/*.mov`/`*.mp4`/`*.m4v` so the lifecycle + seek tests resolve their fixtures on a clean checkout / CI; ad-hoc `*.csv` measurement output stays ignored.

---

## EQ — was it broken out into a shared module?

**No, not in Phase 2 — and that's deliberate per the plan.**

EQ refactoring belongs to **Phase 5** (`EQ + balance state fanout`). Phase 2's charter is the new tap module + ADR-3a containment + the wiring needed for ADR-7 to hold; touching `EqualizerController` is out of scope for this phase.

The plan's **ADR-5** decision is explicit: **parallel-fanout pattern, NOT extraction.**

| Concern | Phase 5 Owner | Engine consumer | Tap consumer |
|---|---|---|---|
| `isEqOn`, `preampLinearGain`, 10 `bandGainsDB` | `EqualizerController` (existing) | `AVAudioUnitEQ` parameter writes (existing) | New: recompute `BiquadCoefficientSet`, push into `VideoTapContext` |
| `balance: Float` | `AudioPlayer` (existing) | balance node parameter writes (existing) | New: write Float bit-pattern into `VideoTapContext.balance: Atomic<UInt32>` |

**EQ math lives twice — engine path uses `AVAudioUnitEQ` (Apple's AU); tap path will use a fresh `BiquadCascade` (RBJ cookbook formulas) added in Phase 3.** Per **Principle 4 (AHA Rule of Three)**, that's the right kind of WET duplication:
- **Different threading domains.** Engine render thread (AVAudioEngine-managed) vs. MTAudioProcessingTap render thread (MediaToolbox-managed). Both non-cooperative; separately owned.
- **Different parameter-update paths.** AU parameter writes (`AVAudioUnitEQ.bands[i].gain = ...`) vs. atomic-pointer coefficient swap (the Phase 3 P-4 design picks the exact scheme).
- **Different lifetimes.** Engine AU is long-lived per session; tap-side cascade exists per AVPlayerItem.

Sharing the math between these two contexts would require flag-driven divergence inside the implementation — the **wrong abstraction** per AHA.

EQ **values** live ONCE (in `EqualizerController`); they're pushed to the two consumers via the Phase 5 fanout. That's where modularity lives — at the canonical owner, not at the math.

---

## Test count: 85 today vs. 110 you remembered

The 110 you're remembering was on the **paused-as-reference saved branch** (`feat/video-audio-engine-routing` at commit `5af91eb`), which had Phase 1+2+3+5+6+7-partial of the engine-routing approach all built. That branch is preserved but not being merged.

This branch (`feat/avplayer-native-video-dsp`) started from scratch architecturally:
- **72 baseline:** what cherry-picked from main (Phase 1 engine config observer + everything pre-existing).
- **+13 Phase 2 tests:** 2 contract + 6 lifecycle + 5 seek-state-matrix.
- **= 85 today.**
- **Target by S3-2 close: 110+/110+.** Phase 3 adds ~4 BiquadNumericalMatchTests; Phase 7 adds ~6 additional lifecycle tests (rapid track skip, tap-create injected failure, pause/resume preserved state, seek-state-flush, signed-bundle smoke); Phase 8 verification matrix is documentation-only (no new tests).

We're not behind the saved branch — we're rebuilding under a different (smaller, safer) topology and the test count grows phase by phase per `plan.md` §10.

---

## Architecture extraction status (research.md → docs/)

**All architecture changes are captured in task-level docs and explicitly slated for Phase 9 extraction to `docs/`.**

| What | Where it lives now | Where it goes |
|---|---|---|
| Architecture diagram (engine + video paths, data flow, topology deltas vs saved branch) | `tasks/avplayer-native-video-dsp/research.md` §"Architecture (proposed end-state)" lines 19-93 | Phase 9 → `docs/MACAMP_ARCHITECTURE_GUIDE.md` + `docs/VIDEO_WINDOW.md` |
| ADRs 1-11 + 3a + amendments (concurrency contract, coefficient hand-off, EQ/balance fanout, dual-producer visualizer, tap lifecycle, biquad implementation, filter reset, release-on-fail, ASBD gate, plus the ADR-4/ADR-7 amendments from Phase 2 implementation reality) | `tasks/avplayer-native-video-dsp/plan.md` §4 | Phase 9 → cited from the architecture guide |
| `RenderThreadSafe` pattern (`@unchecked Sendable` + `Synchronization.Atomic` + marker protocol + DEBUG contract tests) | `MacAmpApp/Audio/RenderThreadSafe.swift` + `VideoTapContext.swift` header contract block + `VideoTapSendableContractTests.swift` | Phase 9 → new "Audio Mechanism Concurrency Contract" subsection of `docs/MACAMP_ARCHITECTURE_GUIDE.md` codifying it as a project-wide convention |
| In-place tap DSP topology (replaces engine-routing) | `tasks/avplayer-native-video-dsp/research.md` + `plan.md` ADR-1, ADR-2, ADR-7 | Phase 9 → new "Audio DSP Architecture" section of `docs/VIDEO_WINDOW.md` |
| Phase 2 implementation findings (4 deviations forced by Swift 6 / Oracle review) | `placeholder.md` P-1/P-2/P-3/P-4 + `state.md` "Phase 2 implementation findings" | Phase 3 closes P-1 + P-4; Phase 9 docs reference P-2 + P-3 as standing items if not resolved by then |

**`plan.md` §6 Phase 9 §9.4-9.6 is the explicit extraction mandate** as a hard PR requirement (mandatory documentation updates land in the same PR as the implementation per project convention — docs/code drift is unacceptable).

---

## Why Oracle scored 9.0 not 10.0

The 1.0 gap is structural, not residual code defects. Oracle won't give 10/10 to a phase that ships with documented deferrals — and these deferrals are **by design** for Phase 2's scope:

1. **No actual DSP yet.** Phase 2 is intentionally pass-through; `tapProcess` calls `GetSourceAudio` and returns. EQ/balance/visualizer math doesn't run until Phase 3+. A "DSP correctness" gate (Phase 8 verification matrix: ≤0.5 dB numerical match, route-change matrix, long-playback drift, surround handling, signed-bundle smoke) hasn't been exercised because there's nothing yet to verify against.
2. **Four open `placeholder.md` items (P-1/P-2/P-3/P-4).** P-1 (BiquadCoefficientSet stub) + P-4 (race-safe coefficient hand-off design) are Phase 3 gates. P-2 (Mirror reflection coverage gap on `~Copyable` types) is a documented Swift language limitation. P-3 (`@preconcurrency import AVFoundation`) resolves only when Apple ships proper `Sendable` annotations for `AVAsset`.
3. **Two manual verification items deferred** (todo 2.39 clapperboard smoke, todo 2.40 Allocations Instruments leak). Automated lifecycle tests (6 in `VideoTapLifecycleTests`) cover the bulk of what Allocations would manually verify, but human eyes/ears on the actual 5 video clips + Instruments-attached leak inspection still needs to happen (see "Manual testing — when?" below).

If you want a 10/10 someday, it requires Phase 3 P-4 redesign + Phase 8 verification matrix execution + manual smoke. That's the natural arc, not Phase 2's scope.

---

## Manual testing — when?

The two deferred items are:

- **todo 2.39 — manual smoke on 5 clapperboard clips.** Each clip should play normally with the tap installed but no DSP applied (audio plays through clean, no audible glitches, video plays without stutter). Tests that the pass-through tap doesn't break video playback.
- **todo 2.40 — Allocations Instruments leak check.** Launch the app, attach Instruments → Allocations template, play N video tracks (e.g. queue 5-10 clips and let them auto-advance), stop, observe whether `VideoTapContext` allocation count == deallocation count. Tests that the +1 retain from `Unmanaged.passRetained` is always balanced by `tapFinalize`.

**Where they're deferred TO:** I haven't formally moved them to a future phase — they're still open as `[ ]` items in `tasks/avplayer-native-video-dsp/todo.md` §2.39 + §2.40. Practically, two timing options:

1. **Do them NOW**, before starting Phase 3. Catches any pass-through regression Phase 3 might trip over. ~10 minutes of clapperboard playback + ~5 minutes of Allocations attach/run. **Recommended** because it confirms Phase 2's ground truth before Phase 3 layers DSP on top.
2. **Defer to Phase 8 (verification matrix execution).** Phase 8 already has slots for "Manual end-to-end" + "Allocations Instruments" gates as part of the 15-gate matrix. Combining keeps Phase 2 closure unblocked but means a Phase 3 regression caught at Phase 8 has more to bisect.

**My recommendation: do them now.** When you're ready, I'll walk through:
- A. Open the project in Xcode, build the macOS scheme (`MacAmpApp`), Run (⌘R).
- B. Drag clapperboard fixture clips one at a time into the playlist (or use Open URL); play each. Listen for audio and watch the video for the full ~3 seconds. Repeat for all 5. None should glitch, drop frames, or fail.
- C. Open Instruments (⌥⌘I or `Product > Profile`); choose Allocations template. With the app running and a clip queued, hit Record. Play the queued clip + 4 more (auto-advance via playlist or manual). Stop after ~30s. In the Allocations track, search for "VideoTapContext" — the count should drop to 0 (or match the number of currently-playing items, which should be 1 or 0 after stop).

Tell me when you're ready and I'll babysit through the steps.

---

## What's in the active commit (7d3367c)

- All Round 1-7 Oracle revisions (7 fix rounds, 18 commits worth of work consolidated).
- 5 source files in `MacAmpApp/Audio/VideoDSP/` (Context + Tap + BiquadCoefficientSet stub + AudioPlayer/VideoPlaybackController modifications).
- `MacAmpApp/Audio/RenderThreadSafe.swift`.
- 3 test files in `Tests/MacAmpTests/` (contract + lifecycle + seek-state-matrix).
- 5 clapperboard fixtures in `clapperboard-videos/` (~12 KB each, now tracked).
- `.gitignore` allow-rules for the fixtures.
- Task-level doc updates: `plan.md` (ADR-4/ADR-7 amendments + §5.2/§5.4/§6 narrative refreshes), `state.md` (Round 1-7 summary + 85/85 count), `placeholder.md` (P-4 added, P-1/P-3 sharpened), `todo.md` (Phase 2 cross-outs + Phase 4/5 reference refreshes), `resume-prompt.md` (Phase 3 instructions + P-4 GATING flag).

---

## Phase 3 starting line

When you're ready to start Phase 3, the resume-prompt's First Action section is the canonical instruction. The single-most-important thing to understand: **Phase 3 is GATED on resolving placeholder.md P-4 first** (race-safe coefficient hand-off redesign + plan.md ADR-4 amendment + Oracle re-review on the redesign). Don't try to write `BiquadCascade.swift` until P-4 is settled — the install path is what `BiquadCascade.process` reads from on the render thread.
