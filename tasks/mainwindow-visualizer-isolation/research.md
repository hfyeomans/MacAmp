# Research: MainWindow Visualizer Isolation

> **Purpose:** Research the SwiftUI recomposition boundary fix that isolates `VisualizerView` from volume/balance slider drag re-evaluations in the main window.

**Status:** Research complete and Oracle-validated (2026-04-27). 9 actionable items applied; see Oracle Validation Summary section.

---

## Context

During T3 (`mainwindow-layer-decomposition`) manual testing, the spectrum analyzer **pauses while the user drags the volume or balance slider**. This was logged as pre-existing behavior in `tasks/done/mainwindow-layer-decomposition/todo.md:111` and deferred to S3 in `tasks/_context/state.md:142-165`.

The observed failure: visualizer bars freeze for the duration of a slider drag and resume on release. The deferred-item entry in shared state attributes this to `VisualizerView()` being rendered inline in `MainWindowFullLayer.body` and proposes extracting it into a dedicated `MainWindowVisualizerLayer` to create a SwiftUI recomposition boundary.

**This research treats that mechanism as an unproven hypothesis, not a fact.** Under `@Observable` per-property tracking, writing `audioPlayer.volume` should *not* invalidate `MainWindowFullLayer.body` if that body never reads `.volume` — and a code audit (below) confirms the parent body reads `shuffleEnabled` and `repeatMode` but not `volume`. The boundary extraction is still defensible as a precaution, but the actual root cause must be measured before we can claim the extraction is sufficient.

Source: `tasks/_context/state.md:142-165` (Wave 2b deferred items table).

---

## Current Architecture

### File inventory — `MacAmpApp/Views/MainWindow/`

| File | Lines | Role |
|------|-------|------|
| `WinampMainWindow.swift` | 110 | Root composition; switches Full vs Shade child |
| `WinampMainWindowLayout.swift` | 53 | `WinampMainWindowLayout` enum of CGPoints |
| `WinampMainWindowInteractionState.swift` | 132 | `@Observable @MainActor` shared interaction state (scrub, scroll, pause blink) |
| `MainWindowOptionsMenuPresenter.swift` | 109 | NSMenu bridge for the Options (O) button |
| `MainWindowFullLayer.swift` | 258 | Full-mode composition + 7 inline `@ViewBuilder` helpers |
| `MainWindowShadeLayer.swift` | 136 | Shade-mode composition (no visualizer) |
| `MainWindowTransportLayer.swift` | 57 | Transport buttons child view |
| `MainWindowTrackInfoLayer.swift` | 48 | Scrolling text child view |
| `MainWindowIndicatorsLayer.swift` | 82 | Play/pause/mono/stereo/bitrate/sample-rate child view |
| `MainWindowSlidersLayer.swift` | 68 | Position/volume/balance sliders child view |

### `MainWindowFullLayer.body` — the problem site

`MacAmpApp/Views/MainWindow/MainWindowFullLayer.swift:18-51`

```swift
var body: some View {
    Group {
        buildTitlebarButtons()                 // inline @ViewBuilder
        MainWindowIndicatorsLayer(...)         // child View struct
        buildTimeDisplay()                     // inline @ViewBuilder
        MainWindowTrackInfoLayer(...)          // child View struct
        buildSpectrumAnalyzer()                // inline @ViewBuilder ← HOT PATH
        MainWindowTransportLayer(...)          // child View struct
        buildShuffleRepeatButtons()            // inline @ViewBuilder
        MainWindowSlidersLayer(...)            // child View struct
        buildWindowToggleButtons()             // inline @ViewBuilder
        buildClutterBarOAI()                   // inline @ViewBuilder
        buildClutterBarDV()                    // inline @ViewBuilder
    }
}

@ViewBuilder
private func buildSpectrumAnalyzer() -> some View {
    VisualizerView()                            // file:line 134-140
        .frame(width: VisualizerLayout.width, height: VisualizerLayout.height)
        .background(Color.black.opacity(0.5))
        .at(Layout.spectrumAnalyzer)
}
```

`buildSpectrumAnalyzer()` is a `@ViewBuilder` method on `MainWindowFullLayer` — it does **not** create a SwiftUI view-identity boundary. Its output is composed directly into `body`, so `VisualizerView()` is rebuilt every time `MainWindowFullLayer.body` is re-evaluated.

### `MainWindowFullLayer` `@Environment` reads

`MacAmpApp/Views/MainWindow/MainWindowFullLayer.swift:6-10`

```swift
@Environment(SkinManager.self) private var skinManager
@Environment(AudioPlayer.self) private var audioPlayer        // ← reads .shuffleEnabled, .repeatMode
@Environment(AppSettings.self) private var settings
@Environment(PlaybackCoordinator.self) private var playbackCoordinator
@Environment(WindowFocusState.self) private var windowFocusState
```

Reads of `audioPlayer.shuffleEnabled` (`buildShuffleRepeatButtons`, line 147) and `audioPlayer.repeatMode` (line 155) put `audioPlayer` in the parent body's dependency set. Settings reads (`isAlwaysOnTop`, `showTrackInfoDialog`, `isDoubleSizeMode`, `showVideoWindow`, `timeDisplayMode`) bring `settings` in too. `playbackCoordinator.displayDuration` / `displayTime` / `isPaused` bring the coordinator in.

### `AudioPlayer.volume` is observable

`MacAmpApp/Audio/AudioPlayer.swift:7,65`

```swift
@Observable
@MainActor
final class AudioPlayer {
    ...
    var volume: Float = 0.75 { didSet { ... } }
    var isEngineRendering: Bool { engine.isEngineRunning && (isPlaying || isBridgeActive) }
    ...
}
```

`@Observable` macro makes every stored property change emit a notification. With `@Observable`, SwiftUI tracks reads at *property* granularity inside a body — but every `@ViewBuilder` helper of the same parent struct shares that one body's tracking scope. `buildVolumeSlider()` reads `audioPlayer.volume` for the slider thumb position calculation only inside `MainWindowSlidersLayer.body`, but `MainWindowFullLayer.body` reads `shuffleEnabled` and `repeatMode` from the same instance and so registers as a dependent of those properties. (Volume itself does not invalidate `MainWindowFullLayer.body` per `@Observable`'s per-property tracking; this is one of the open questions below.)

### `VisualizerView` — what it reads

`MacAmpApp/Views/VisualizerView.swift:11-86`

```swift
struct VisualizerView: View {
    @Environment(AudioPlayer.self) var audioPlayer
    @Environment(SkinManager.self) var skinManager
    @Environment(AppSettings.self) var settings

    @State private var barHeights: [CGFloat] = ...
    @State private var peakPositions: [CGFloat] = ...
    @State private var peakTimers: [Date] = ...

    let updateTimer = Timer.publish(every: 1.0/30.0, ...).autoconnect()

    var body: some View {
        let mode = settings.visualizerMode
        Group { ... switch mode { ... } }
            .onReceive(updateTimer) { _ in
                if audioPlayer.isEngineRendering && mode == .spectrum {
                    updateBars()  // mutates @State barHeights/peakPositions
                }
            }
            .onChange(of: audioPlayer.isEngineRendering) { ... }
    }
}
```

`VisualizerView.body` reads `settings.visualizerMode` and `audioPlayer.isEngineRendering` (inside `.onReceive`). It does **not** read `audioPlayer.volume`. Its animation is driven by `@State barHeights` updated from the autoconnect `Timer.publish`.

Notable concern: `let updateTimer = Timer.publish(...).autoconnect()` is a stored property on the struct value. Each time `VisualizerView()` is reconstructed, a fresh `Publishers.Autoconnect` is created — but SwiftUI compares View values by identity (positional), not by stored-property equality. Whether SwiftUI reuses the existing `.onReceive` subscription across rebuilds depends on view identity stability.

---

## Root Cause Analysis

The originally-stated cause ("volume change → parent body re-eval → inline `VisualizerView` rebuilt at gesture rate") is **not supported by static analysis** of the current code:

- `MainWindowFullLayer.body` reads `audioPlayer.shuffleEnabled` (line 147) and `audioPlayer.repeatMode` (line 155) but never `audioPlayer.volume`.
- `audioPlayer.volume` is read in `MainWindowSlidersLayer.buildVolumeSlider()` (line 49), inside a `Binding.get` closure scoped to that child layer.
- Under `@Observable` per-property tracking, a write to `audioPlayer.volume` should invalidate only the bodies that read `volume` — i.e., `MainWindowSlidersLayer.body`, not `MainWindowFullLayer.body`.

Therefore the visualizer pause must originate from one of the following candidate mechanisms. Each is listed with its plausibility based on the code as it stands today.

### Candidate mechanisms

**A. Parent body invalidation despite per-property tracking (PRIMARY HYPOTHESIS, requires measurement).**

`@Observable` tracking is body-scoped: the dependency set is computed when the body executes, not per-helper. If SwiftUI's tracking under `@ViewBuilder` helpers, `Group { ... }` content, or `@Environment` access sometimes registers the *type* (`AudioPlayer`) rather than only the read properties, then any `volume` write would still invalidate `MainWindowFullLayer.body`. This is the mechanism the original deferred-item write-up assumed. It is consistent with the symptom but unconfirmed against this codebase.

**B. Synchronous main-actor work per drag tick (SECONDARY, contributing factor).**

Each volume slider drag tick calls `playbackCoordinator.setVolume($0)`, which writes `audioPlayer.volume`. The `volume` setter has a `didSet` observer that propagates to backends and persists to `UserDefaults`. The 30 Hz visualizer animation runs on `Timer.publish(every: 1.0/30.0, on: .main, in: .common)`, so it competes with drag-handling work for the main run loop. If the synchronous setter chain stalls the main thread, the visualizer's RunLoop ticks may be delayed independent of any recomposition. This applies even if Mechanism A is null.

**C. Timer subscription churn (TERTIARY, fallback only).**

`VisualizerView` stores `let updateTimer = Timer.publish(every: 1.0/30.0, ...).autoconnect()` as a stored property. If parent body invalidation does happen (Mechanism A), each rebuild produces a new publisher value; SwiftUI's `.onReceive` would re-subscribe. This *could* present as missed ticks. However, this requires Mechanism A to fire — without parent body re-eval, the timer publisher is not reconstructed. So this is a downstream effect of A, not a co-equal explanation. (Pre-fix, the visualizer animates fine when no slider is being dragged, which weighs against churn being the dominant cause.)

### Why the proposed extraction still helps

- **If Mechanism A is real**, extracting `MainWindowVisualizerLayer` as a sibling `View` struct moves the visualizer subtree out of `MainWindowFullLayer.body`'s tracking scope. The new struct's body has zero `@Environment` reads, so it cannot be invalidated by any `AudioPlayer` change. Mechanism A and (its downstream) Mechanism C are both mitigated.
- **If Mechanism A is null**, extraction is essentially a no-op for performance — but it is still a sound architectural change (per Oracle's earlier finding that no-arg sibling structs improve recomposition isolation), and it does not regress anything.
- **Mechanism B is unaffected** by extraction; if it dominates, a separate fix is needed (e.g., debounce `UserDefaults` persistence to drag-end).

### Confirmation plan

Before merging, perform an Instruments SwiftUI trace (deferred item `tasks/_context/state.md:177`) capturing `MainWindowFullLayer.body` and `VisualizerView.body` evaluation counts during a 5-second slider drag. This decisively rules Mechanism A in or out and tells us whether the fix is sufficient or whether Mechanism B also requires action.

---

## Target Architecture

Extract `buildSpectrumAnalyzer()` into a dedicated `MainWindowVisualizerLayer` `View` struct.

### New file: `MacAmpApp/Views/MainWindow/MainWindowVisualizerLayer.swift`

```swift
import SwiftUI

/// Spectrum analyzer / oscilloscope host. Separate View struct creates a
/// SwiftUI recomposition boundary so volume/balance slider drags in the
/// sibling MainWindowSlidersLayer do not cause VisualizerView to be
/// reconstructed at gesture rate.
struct MainWindowVisualizerLayer: View {
    private typealias Layout = WinampMainWindowLayout

    var body: some View {
        VisualizerView()
            .frame(width: VisualizerLayout.width, height: VisualizerLayout.height)
            .background(Color.black.opacity(0.5))
            .at(Layout.spectrumAnalyzer)
    }
}
```

No `@Environment` declarations. `VisualizerView` declares its own (`AudioPlayer`, `SkinManager`, `AppSettings`) and SwiftUI injects them automatically through the hierarchy. The new struct's body has zero dependency reads, so it re-evaluates only when its own identity changes — effectively never for the lifetime of the parent.

### Modified file: `MacAmpApp/Views/MainWindow/MainWindowFullLayer.swift`

In `body` (line 33), replace:

```swift
buildSpectrumAnalyzer()
```

with:

```swift
MainWindowVisualizerLayer()
```

Delete the `buildSpectrumAnalyzer()` helper (lines 134-140) and the `// MARK: - Spectrum Analyzer` divider.

---

## Files Changed

| File | Change | Notes |
|------|--------|-------|
| `MacAmpApp/Views/MainWindow/MainWindowVisualizerLayer.swift` | **NEW** (~15 lines) | Wraps `VisualizerView()` in a dedicated `View` struct |
| `MacAmpApp/Views/MainWindow/MainWindowFullLayer.swift` | Modified | Replace inline `buildSpectrumAnalyzer()` call with `MainWindowVisualizerLayer()`; delete helper |

**No-change note:** `project.yml` does not need an edit. The `MacAmp` target's `sources:` uses `path: MacAmpApp` with directory globbing (lines 20-24), so new `.swift` files in `MainWindow/` are auto-picked up. Run `xcodegen generate` after adding the file.

### Production runtime call sites for `VisualizerView()`

1. `MacAmpApp/Views/MainWindow/MainWindowFullLayer.swift:136` (this task — main window full mode)
2. `MacAmpApp/Views/WinampPlaylistWindow.swift:196` (out of scope — different parent body, gated on `settings.isMainWindowShaded`, no slider sibling causing the same re-eval pattern)

A third reference exists in `MacAmpApp/Views/VisualizerView.swift:223` inside the `#Preview` block — non-runtime, no action needed.

`MainWindowShadeLayer.swift` does **not** render the visualizer (verified: lines 1-136 contain no `VisualizerView` reference). Shade mode delegates the shaded visualizer to the playlist window (`WinampPlaylistWindow.swift:194-201` gates on `settings.isMainWindowShaded`).

---

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|-----------|
| `VisualizerView` Environment injection breaks because new layer drops it | Low | High (blank visualizer) | `@Environment` is read by the leaf, not the new wrapper. SwiftUI walks the environment chain regardless of intermediate struct types. Manual visual test confirms post-extraction. |
| Pixel positioning regression (`.at()` modifier) | Very low | Medium | The `.frame().background().at()` chain is preserved verbatim, only relocated. |
| Identity churn from `MainWindowVisualizerLayer()` being a no-arg struct | None | None | SwiftUI uses positional identity in `Group { }`; no init args means stable identity. |
| Behavior change in shade mode | None | None | Shade layer has no visualizer reference; not touched. |
| Visualizer pause not actually fixed (theory wrong) | Low-Medium | Low | Manual repro is binary (bars freeze yes/no). If unfixed, escalate to Instruments profiling and timer-promotion fallback. |
| Other inline `@ViewBuilder` helpers in `MainWindowFullLayer` have the same pause issue | Low | Low | Only the visualizer is timer-driven at 30 Hz; other helpers (titlebar, time, shuffle/repeat, window toggles, clutter bar) have cheap re-evaluations and no animation continuity to break. |
| Synchronous main-actor work per drag tick (Mechanism B above) — `volume` setter writes `UserDefaults` and propagates to multiple backends every drag frame, starving the 30 Hz visualizer timer regardless of recomposition | Medium | Medium | Out of scope for this task's extraction, but call out as the secondary fallback fix. If post-extraction the bars still pause: coalesce `audioPlayer.volume` `UserDefaults` persistence to drag-end (`onChanged` updates engine only; `onEnded` persists). Refs: `WinampVolumeSlider.swift:60`, `PlaybackCoordinator.swift:193`, `AudioPlayer.swift:65`. |

### Principles compliance

| Principle | Verdict |
|-----------|---------|
| 1. Problem-First | PASS — concrete failure mode (visualizer pauses on drag) with manual repro |
| 2. Cohesion Over Line Count | PASS — extracting one cohesive concern; doesn't fragment state |
| 3. State Ownership | PASS — no shared state involved; `VisualizerView` owns its `@State` |
| 4. Rule of Three (AHA) | N/A — no abstraction being introduced beyond a single-purpose struct |
| 5. API Surface | PASS — no visibility widening; new struct is `internal` (default) like its siblings |
| 6. No Pass-Through Middlemen | PASS — the new struct owns layout policy (`.frame().background().at(Layout.spectrumAnalyzer)`) and the recomposition boundary intent. Guardrail: keep layout policy in this layer; do not let it degenerate into a one-line `VisualizerView()` shim. |
| 7. ADR + Kill Switch | PASS — kill switch: if manual repro still shows pause, revert and pursue (a) Instruments profiling, (b) timer promotion to `@State`/`@Observable` driver |

---

## Verification Approach

### Required: mechanism measurement (decisive validation)

Before claiming the fix is sufficient, capture an Instruments SwiftUI trace measuring body invalidation sources during a 5-second volume slider drag, **both pre-fix and post-fix**. This is a required step — promote the deferred "T3 Instruments body evaluation profiling" item (`tasks/_context/state.md:177`) into this task's verification.

Specifically measure:

| Body | Pre-fix expectation | Post-fix expectation | Decision |
|------|---------------------|----------------------|----------|
| `MainWindowFullLayer.body` | If high during drag → Mechanism A is real | Should drop to baseline (only changes from buttons reading `shuffleEnabled`/`repeatMode`/etc.) | If still high post-fix → investigate `@Observable` tracking edges |
| `MainWindowSlidersLayer.body` | High during drag (correct — owns slider) | High during drag (still correct) | No regression expected |
| `VisualizerView.body` | If high during drag → confirms downstream effect of A or C | Should drop to baseline (only `isEngineRendering` / `visualizerMode` changes) | If still high → mechanism is something other than parent-body churn; investigate Mechanism B |

Decision rule: if post-fix `VisualizerView.body` evaluation count during drag is at its baseline (no different from non-drag rate), the fix is sufficient. If it still spikes during drag, pivot to the Mechanism B fallback (debounce `UserDefaults` persistence on `volume`).

### Manual repro (primary symptom verification)

1. `xcodegen generate` and build with Thread Sanitizer enabled (per project standard).
2. Launch MacAmp, load a known-good local audio file, hit Play.
3. Confirm spectrum analyzer is animating at ~30 fps.
4. Drag the volume slider continuously for 3-5 seconds.
5. **Expected:** Bars continue animating uninterrupted during drag.
6. Repeat for the balance slider.
7. Repeat in double-size mode.
8. Repeat with at least one custom skin loaded (VISCOLOR palette) to ensure the skin lookup path inside `SpectrumBar` still resolves.

### Regression sweep

- Run `xcodebuildmcp macos test --json '{"extraArgs":["-enableThreadSanitizer","YES"]}'`. Existing 57-test suite must pass.
- Manual: confirm shade mode still works (no visualizer in main window in shade mode; visualizer rendered in playlist window when `isMainWindowShaded` is true and `showVisualizer` is true).
- Manual: visualizer mode cycling via `.onTapGesture` in `VisualizerView.body:64-71` still works (spectrum → oscilloscope → none).
- Manual: skin reload (`SkinManager.currentSkin` change) still updates VISCOLOR palette in spectrum bars.

---

## Open Questions

1. **Mechanism A vs B — which dominates?** Static analysis says `MainWindowFullLayer.body` should not invalidate on `volume` writes under per-property tracking. The Instruments trace step is required precisely to settle this. If A dominates, the extraction fixes it. If B dominates, post-extraction bars will still pause and the follow-on is to debounce `UserDefaults` persistence in the `volume` setter chain (`AudioPlayer.swift:65`).
2. **Should the `VisualizerView()` consumer in `WinampPlaylistWindow.swift:196` get the same treatment?** That site only renders when shade mode is active. The playlist window does not have a volume slider sibling driving the pattern. Out of scope unless a manual repro shows similar pause behavior there in shade mode.
3. **Does the new struct need `@MainActor`?** `View` conformance is implicitly main-actor for SwiftUI on Swift 6.2+; sibling layers (`MainWindowSlidersLayer`, etc.) do not annotate. Match existing convention — no annotation.
4. **Timer publisher fallback (Mechanism C downstream of A):** if Instruments shows `MainWindowFullLayer.body` stable during drag but `VisualizerView.body` still spikes, promote `updateTimer` into a `@State` wrapper or move tick generation into an `@Observable` driver so it survives any future view-value reconstruction.

---

## Oracle Validation Summary

Reviewed by `mcp__codex-cli__codex` (gpt-5.3-codex, reasoningEffort xhigh) on 2026-04-27.

Actionable feedback applied:

1. **CRITICAL — Reframed root cause as unproven hypothesis.** Original draft asserted `MainWindowFullLayer.body` re-evaluates at gesture-tick frequency; static analysis does not support that under `@Observable` per-property tracking. Root Cause Analysis section now lists three candidate mechanisms (A: parent body invalidation, B: synchronous main-actor work per drag tick, C: timer subscription churn — downstream of A) and requires Instruments measurement to disambiguate.
2. **HIGH — Reworded extraction's expected impact** as conditional on Mechanism A being confirmed. Section "Why the proposed extraction still helps" added.
3. **MEDIUM — Downgraded Hypothesis C** (timer publisher churn) from co-equal to fallback-after-A. Argument: pre-fix the visualizer animates fine when no slider is being dragged, so churn is not dominant.
4. **MEDIUM — Added Mechanism B as a documented risk** (`UserDefaults` write per drag tick from the `volume` setter chain), with a concrete mitigation (debounce persistence to `onEnded`).
5. **LOW — Corrected `WinampMainWindow.swift` line count** (110, not 111).
6. **LOW — Clarified `VisualizerView()` call sites:** two production runtime sites, plus one preview reference. Made the preview reference explicit.
7. **LOW — Cleaned Files Changed table** to list only edited files; moved `project.yml` no-change note out of the table.
8. **LOW — Updated Principle 6 verdict** from WATCH to PASS with a guardrail note (keep layout policy in the new layer).
9. **MEDIUM — Promoted Instruments measurement to a required step** in Verification Approach with a measurement table and explicit decision rule.

No rejected feedback — all 8 actionable items were applied.

---

## Files Analyzed

- `MacAmpApp/Views/MainWindow/MainWindowFullLayer.swift` (258 lines, full read)
- `MacAmpApp/Views/MainWindow/MainWindowSlidersLayer.swift` (68 lines, full read)
- `MacAmpApp/Views/MainWindow/MainWindowShadeLayer.swift` (136 lines, full read)
- `MacAmpApp/Views/MainWindow/MainWindowIndicatorsLayer.swift` (82 lines, full read)
- `MacAmpApp/Views/MainWindow/MainWindowTrackInfoLayer.swift` (48 lines, full read)
- `MacAmpApp/Views/MainWindow/MainWindowTransportLayer.swift` (57 lines, full read)
- `MacAmpApp/Views/MainWindow/MainWindowOptionsMenuPresenter.swift` (109 lines, full read)
- `MacAmpApp/Views/MainWindow/WinampMainWindow.swift` (111 lines, full read)
- `MacAmpApp/Views/MainWindow/WinampMainWindowInteractionState.swift` (132 lines, full read)
- `MacAmpApp/Views/MainWindow/WinampMainWindowLayout.swift` (53 lines, full read)
- `MacAmpApp/Views/VisualizerView.swift` (277 lines, full read)
- `MacAmpApp/Views/WinampPlaylistWindow.swift:185-206` (sibling consumer)
- `MacAmpApp/Audio/AudioPlayer.swift:1-65,624-630` (Observable surface, frequency data API)
- `tasks/_context/state.md:142-165,177` (Wave 2b deferred items + Instruments profiling)
- `tasks/_context/principles.md` (full)
- `tasks/done/mainwindow-layer-decomposition/{research,plan,state,todo}.md` (parent task context)
- `project.yml:1-80` (XcodeGen target sources strategy)
