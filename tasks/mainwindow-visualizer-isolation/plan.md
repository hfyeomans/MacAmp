# Plan: MainWindow Visualizer Isolation

> **Purpose:** Add a SwiftUI recomposition boundary so the spectrum analyzer does not pause during volume / balance slider drag in the main window. Implementation is gated by a Phase 0 Instruments spike that disambiguates three candidate root causes.
> **Source of truth:** `tasks/mainwindow-visualizer-isolation/research.md` (Oracle-validated 2026-04-27, 9/9 actionable items applied). This plan does not restate research findings — it links to them.

---

## Status Header

| Field | Value |
|------|------|
| Date | 2026-04-27 |
| Sprint | S3 (Wave S3-1, Worktree A) |
| Branch | `feat/mainwindow-visualizer-isolation` |
| Spike branch | `spike/mwvi-volume-drag-profile` (throwaway, deleted after Phase 0) |
| PR target | PR #A (S3-1 first to merge; B (`stream-pause-tail`) merges after) |
| Predecessors | None |
| Parallel worktree | B = `stream-pause-tail` (zero file overlap per `tasks/_context/state.md` conflict map) |
| Successors | `video-audio-engine-routing` (S3-2) waits for both A and B to merge |

---

## 1. Problem Statement

Concrete failure mode (manual repro on `main` HEAD):

1. Launch MacAmp, load a local audio file, hit Play, confirm spectrum analyzer is animating at ~30 fps.
2. Drag the volume slider continuously for 3-5 seconds.
3. **Observed:** spectrum bars freeze for the duration of the drag and resume on release. The same symptom occurs for the balance slider.
4. The visualizer animation is timer-driven at 30 Hz (`VisualizerView.updateTimer`, `MacAmpApp/Views/VisualizerView.swift:38`); the freeze is therefore a stall in either:
   - SwiftUI body re-evaluation churn that resets `VisualizerView`'s state, or
   - main-thread starvation that delays the timer's tick delivery.

Cost: degraded perceived audio responsiveness and breaks 1:1 Winamp visualizer continuity.

This is **Principle 1 (Problem-First)** evidence — concrete failure mode, manual repro, not "file is too long".

## 2. Non-Goals

This task **does NOT**:

- Touch the playlist window's `VisualizerView()` site (`MacAmpApp/Views/WinampPlaylistWindow.swift:196`). That site is shade-mode-only and has no sibling slider drag pattern. Out of scope unless Phase 0 produces evidence to the contrary.
- Modify the visualizer timer's identity or storage strategy (Mechanism C work) unless Phase 0 explicitly indicates timer churn dominates after the extraction.
- Change `VisualizerView` itself (no edits to bar count, decay rate, VISCOLOR resolution, oscilloscope, mode cycling, or `@State` shape).
- Restructure `MainWindowFullLayer` beyond the single visualizer extraction (other inline `@ViewBuilder` helpers stay).
- Move existing files to new directories (Structure Sprint policy: D-STRUCTURE, post-S3 only).
- Modify `WinampVolumeSlider` / `WinampBalanceSlider` / `PlaybackCoordinator.setVolume` / `AudioPlayer.volume` setter chain. Mechanism B fix, if needed, is documented as a fallback (Phase 1B) — gated on Phase 0 measurements.
- Promote the `T3 Instruments body evaluation profiling` deferred item to a permanent fixture; the Phase 0 spike satisfies it for the volume-drag case only.

## 3. Pre-Decomposition Gate Checklist

Per `tasks/_context/principles.md`. All 8 items must be complete before structural edits proceed.

| # | Item | Status |
|---|------|--------|
| 1 | Problem statement written | DONE — see §1. Manual repro is binary (bars freeze yes/no). |
| 2 | Non-goals listed | DONE — see §2. |
| 3 | Principles contract approved | DONE — Principles 1, 3, 5, 6, 7 apply. See `research.md` "Principles compliance" table; this plan adds enforcement gates per phase. |
| 4 | Responsibility map | DONE — `MainWindowVisualizerLayer` owns *layout policy for the visualizer slot* (frame/background/position). `VisualizerView` owns *animation state + frequency resolution*. `MainWindowFullLayer` retains composition + non-visualizer @ViewBuilder helpers. No state crosses the boundary. |
| 5 | Complexity assessed | DONE — `MainWindowFullLayer.swift` is 258 lines (verbose, low cognitive complexity per `principles.md` cognitive vs. physical table). The extraction is **not** about size; it is about isolating a 30 Hz animated subtree from sibling drag invalidation. |
| 6 | Candidate split scored | DONE — see §10 Risk Assessment. Cohesion gain: small but positive (visualizer slot becomes a single named layer). State risk: zero (no shared mutable state). Visibility impact: zero (new struct is `internal` like siblings). Pass-through risk: avoided by retaining layout policy in the new struct (Principle 6 guardrail). |
| 7 | Public/internal API delta listed | DONE — adds one new internal `View` struct `MainWindowVisualizerLayer`. Deletes one private helper `MainWindowFullLayer.buildSpectrumAnalyzer()`. No file outside `MacAmpApp/Views/MainWindow/` changes. No symbol becomes more visible. |
| 8 | Stop criteria defined | DONE — see §11 Stop Criteria / Kill Switch. |

**Hard gate cleared.** Items 1-5 are complete; structural edits in Phase 1 may proceed *after* Phase 0 returns Mechanism A confirmation.

---

## 4. Phase 0 — Instruments Spike (REQUIRED, gates Phases 1+)

**Branch:** `spike/mwvi-volume-drag-profile` (throwaway).
**Outcome:** writes findings into `research.md` under a new section "Phase 0 — Spike Results" and is deleted before Phase 1 starts.
**Why required:** `research.md` §"Root Cause Analysis" demonstrates the original "parent body re-eval at gesture rate" theory is **not** supported by static analysis (volume is not read by `MainWindowFullLayer.body`). The extraction in Phase 1 is justified only if Mechanism A is confirmed; Mechanism B (synchronous `UserDefaults` persistence + multi-backend volume routing per drag tick — `AudioPlayer.swift:65-70`, `PlaybackCoordinator.swift:193-197`) is a real candidate that the extraction does not fix.

### 4.1 Measurement Protocol

1. Branch from `main`: `git checkout main && git pull && git checkout -b spike/mwvi-volume-drag-profile`.
2. Build for profiling with TSan **disabled** (TSan distorts timer / signpost timings):
   ```bash
   xcodebuildmcp macos build --json '{"extraArgs":["-enableThreadSanitizer","NO","-configuration","Debug"]}'
   ```
3. Add temporary Swift signposts (do not commit) at three sites:
   - `MainWindowFullLayer.body` — `os_signpost(.event, ...)` at the top of `body`.
   - `MainWindowSlidersLayer.body` — same pattern.
   - `VisualizerView.body` — same pattern.
   These signposts are scaffolding for the spike only; they are reverted before deleting the branch. Use `OSLog(subsystem: "com.macamp.spike", category: "swiftui-body")`.
4. Launch MacAmp from Instruments using the **SwiftUI** template (or Time Profiler + os_signpost track). Macros `xcodebuildmcp macos run` may also be used to launch the built artifact.
5. Load `~/Music/<known-good-local-track>.mp3`, hit Play, wait 5 seconds for the analyzer to settle to its idle baseline rate.
6. Capture **T1 (volume control):** 30 seconds of playback with no slider interaction. Records baseline body evaluation frequency for all three signposts.
7. Capture **T2 (volume drag):** start a fresh recording, then drag the volume slider continuously for 30 seconds (release-grab cycles every ~5 seconds are fine). Stop recording.
8. Capture **T3 (balance control):** repeat step 6, fresh recording, no slider interaction. Required separately because Instruments overhead and host load can drift between trace runs; the balance comparison must use a control captured in the same session.
9. Capture **T4 (balance drag):** repeat step 7 with the balance slider.

The four-trace set (T1, T2, T3, T4) is mandatory; do not collapse T1 and T3 into a single shared control. Naming `T1`/`T2`/`T3`/`T4` is used verbatim in todo.md and in the §4.2 decision rule below.

### 4.2 Decision Rule

Aggregate the four traces (T1-T4 from §4.1). The decision rule compares **drag traces (T2, T4) against same-session control traces (T1, T3 respectively)**. The rule maps directly to research.md "Root Cause Analysis" mechanism table:

| Observation: drag trace (T2 or T4) vs. its control (T1 or T3) | Dominant mechanism | Phase 1 scope |
|---|---|---|
| `MainWindowFullLayer.body` evaluation rate in T2/T4 ≥ 3× control AND `VisualizerView.body` rate in T2/T4 ≥ 1.5× control | A (parent body invalidation) | **Phase 1A only** (extraction). Expected fix. |
| `MainWindowFullLayer.body` rate is within ±20% of control AND `VisualizerView.body` rate is within ±20% of control AND visualizer still freezes visually during T2/T4 | B (main-thread starvation from synchronous setter chain) | **Phase 1B only** (commit `UserDefaults` persistence on `onEnded`). Skip extraction. |
| Both `MainWindowFullLayer.body` and `VisualizerView.body` spike during drag, AND `UserDefaults` writes are observed at gesture rate (verify via temporary `os_log` in `volume.didSet` or via Instruments File Activity) | A + B compound | **Phase 1A + Phase 1B.** |
| `MainWindowFullLayer.body` rate is within ±20% of control AND `VisualizerView.body` rate ≥ 1.5× control | C alone (timer publisher churn without parent invalidation — extremely unlikely per research.md §C) | **Phase 1C** (timer promotion). Document as anomalous; consult Oracle before proceeding. |
| All three signpost rates within ±20% of control AND no visual freeze under Instruments overhead | Heisenbug — Instruments masks the issue | **HALT.** Do not proceed. Re-spike with sampling at lower overhead, or escalate. |

Apply the rule once for the volume axis (T2 vs T1) and once for the balance axis (T4 vs T3). If volume and balance disagree on dominant mechanism, take the union (apply Phase 1 scopes for both) and document the asymmetry in the Phase 0 spike results section.

### 4.3 Spike Deliverables

- A new section **"Phase 0 — Spike Results"** appended to `research.md`, including: trace tool versions, raw evaluation counts per body per trace, the dominant mechanism per the table above, and the resulting Phase 1 scope decision.
- The `spike/mwvi-volume-drag-profile` branch is deleted (`git branch -D spike/mwvi-volume-drag-profile`) after the results are committed to `research.md` on the `feat/mainwindow-visualizer-isolation` branch.
- Signpost scaffolding is removed; only the prose findings persist.

### 4.4 Spike Hygiene

- The spike branch is **never** merged.
- No production code changes are committed on the spike branch.
- If TSan is needed mid-spike for a subsidiary investigation (e.g. suspected race in `barHeights` mutation), explicitly note that the timer-rate measurements taken under TSan are unreliable.

---

## 5. Phase 1A — Extraction (executes only if Phase 0 returns Mechanism A or A+B)

### 5.1 New file: `MacAmpApp/Views/MainWindow/MainWindowVisualizerLayer.swift`

**Why this file exists (Principle 1):** Phase 0 has confirmed `MainWindowFullLayer.body` re-evaluates at drag tick rate, which transitively reconstructs the inline `VisualizerView()` and disrupts its 30 Hz animation. A dedicated `View` struct creates a SwiftUI identity boundary so the visualizer subtree is unaffected by parent re-evaluation.

**Public surface:** one type, `internal struct MainWindowVisualizerLayer: View`. No init args. No properties beyond `body` and the `Layout` typealias.

**State ownership (Principle 3):** zero. The struct holds no `@State`, no `@Environment`, no observed objects. `VisualizerView` continues to own its animation `@State` and its three `@Environment` reads.

**Visibility (Principle 5):** `internal` (Swift default), matching `MainWindowSlidersLayer`, `MainWindowTransportLayer`, etc. No widening.

**Pass-through guardrail (Principle 6):** the struct retains layout policy (`.frame(width:height:)` + `.background(...)` + `.at(Layout.spectrumAnalyzer)`). Do **not** let it degenerate into a one-line `VisualizerView()` shim — that would make it a pass-through middleman and the boundary intent would not be self-documenting.

```swift
import SwiftUI

/// Spectrum analyzer / oscilloscope host. Owns the visualizer slot's layout
/// policy (frame, background, absolute position) and creates a SwiftUI
/// recomposition boundary so volume / balance slider drags in the sibling
/// MainWindowSlidersLayer do not invalidate VisualizerView.
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

**Anticipated diff:** new file, ~16 lines including doc comment and import.

### 5.2 Modified file: `MacAmpApp/Views/MainWindow/MainWindowFullLayer.swift`

Two edits, both verified against HEAD:

1. **Line 33** (`buildSpectrumAnalyzer()` call inside `body`): replace with `MainWindowVisualizerLayer()`.
2. **Lines 132-140** (the `// MARK: - Spectrum Analyzer` divider plus the `@ViewBuilder private func buildSpectrumAnalyzer() -> some View { ... }` helper): delete entirely.

**Anticipated diff:** -8 lines, +1 line. Net file size 258 → 251 lines.

**Symbols changed:**
- Removed: `MainWindowFullLayer.buildSpectrumAnalyzer()` (private @ViewBuilder method).
- Added (callsite): `MainWindowVisualizerLayer()` initializer call.

### 5.3 XcodeGen regeneration

Run `xcodegen generate` after the new file is created. `project.yml:20-24` uses `path: MacAmpApp` directory globbing — no edit to `project.yml` required. Verified against HEAD.

---

## 6. Phase 1B — UserDefaults persistence debounce (executes only if Phase 0 returns Mechanism B or A+B)

**Why separate from 1A:** Mechanism B is real, Mechanism A is hypothetical until Phase 0 measurement. Combining the two changes muddies attribution. A separate phase keeps the diff revertable.

**Hypothesis:** the `volume` setter chain runs synchronously on the main actor per drag tick:
- `WinampVolumeSlider.updateVolume(...)` → binding `set` (`MainWindowSlidersLayer.swift:50`)
- → `PlaybackCoordinator.setVolume(_:)` (`PlaybackCoordinator.swift:193-197`) — three property writes
- → `AudioPlayer.volume.didSet` (`AudioPlayer.swift:65-70`) — `engine?.setVolume`, `videoPlaybackController.volume`, **`UserDefaults.standard.set(volume, forKey: Keys.volume)`**

The `UserDefaults` write per drag frame is the suspect main-thread starvation source.

### 6.1 Design: explicit "persist?" contract, not a global drag flag

**State ownership constraint (Principle 3):** transient gesture state belongs to the UI layer (slider + interaction state). It must **not** leak into `AudioPlayer`. An earlier draft proposed an `isVolumeDragActive` flag inside `AudioPlayer`; that was rejected because (a) it cross-couples UI to model state, (b) it creates a second control path for persistence (the global flag and the explicit commit) that can desync, and (c) it makes the persistence policy non-local — a future caller writing `audioPlayer.volume = x` cannot tell from the call site whether persistence will happen.

The chosen design makes persistence policy **call-site-driven** instead.

**Option B-i (chosen, single contract):**

1. **Split the `volume` setter behavior into two named operations on `AudioPlayer`:**
   - Replace the public stored property `var volume: Float` with a backing private field plus an explicit `applyVolume(_:persistDefaults: Bool)` method, **or** keep the stored property and add a sibling `commitVolumeToDefaults()` method while removing the `UserDefaults.standard.set(...)` line from `volume.didSet` entirely.
   - The chosen sub-variant is the second one (lower blast radius): keep `var volume: Float` observable, drop the `UserDefaults` write from `didSet`, and add a single new method `func commitVolumeToDefaults()` that performs the write. `didSet` continues to do the audio-graph propagation only (`engine?.setVolume(volume)`, `videoPlaybackController.volume = volume`).
2. **Surface the commit through `PlaybackCoordinator`:** add `func commitVolume()` near `setVolume(_:)` (around `PlaybackCoordinator.swift:193`) that calls `audioPlayer.commitVolumeToDefaults()`. Coordinator does no other work.
3. **Caller list (Principle 5 ownership contract):** `commitVolumeToDefaults()` is `internal` on `AudioPlayer`. The **only** approved callers are: `PlaybackCoordinator.commitVolume()` and (for symmetry / startup load) the existing `AudioPlayer` init persistence path if any. Document this caller list in the doc comment on `commitVolumeToDefaults()`. No widening beyond `internal`; no new public API. Any future caller that wants to expand the list must update this section of the plan / a follow-up ADR.
4. **Plumb drag-end signal from the UI without leaking gesture state into the model:** add an `onDragEnded: (() -> Void)?` closure parameter to `WinampVolumeSlider`. `WinampVolumeSlider.volumeInteractionArea`'s `.onEnded { _ in isDragging = false; onDragEnded?() }` (`WinampVolumeSlider.swift:64-66`) calls it. `MainWindowSlidersLayer.buildVolumeSlider()` injects `{ playbackCoordinator.commitVolume() }`. The slider's transient `isDragging` `@State` remains local to the slider; nothing about the gesture lifecycle is observable to `AudioPlayer`.
5. **No global drag flag.** No new `@ObservationIgnored` state on `AudioPlayer`. No new "is currently dragging" semantics anywhere. Persistence is performed if and only if a caller invokes `commitVolume()`.

**Option B-ii (fallback, only if B-i blocked):** in `AudioPlayer.volume.didSet`, coalesce `UserDefaults` writes via a debounced timer (e.g. 250 ms after the last write). More invasive (timer + `@ObservationIgnored` state). Prefer B-i. This is documented for completeness only; if the team chooses B-ii, re-validate against Principle 3 (timer state ownership) before proceeding.

**Why this satisfies Principle 3 (single source of truth):** `AudioPlayer.volume` remains the single source of truth for the *value*. Persistence is now an explicit *action* (`commitVolumeToDefaults`) rather than an implicit *side effect* of a write, which removes the second control path entirely.

**Why this satisfies Principle 5 (API surface minimization):** the entire new `internal` API surface is three additions: (a) one new `internal` method on `AudioPlayer` (`commitVolumeToDefaults`), (b) one new `internal` method on `PlaybackCoordinator` (`commitVolume`), and (c) one new optional stored property `WinampVolumeSlider.onDragEnded: (() -> Void)? = nil`, which expands the synthesized memberwise initializer of `WinampVolumeSlider` by exactly one labeled parameter (with a default value, so all existing call sites remain source-compatible). No previously-`private` symbol gains broader visibility. Approved caller list is documented inline on `commitVolumeToDefaults`.

### 6.2 Out of scope (leave for follow-up)

- Coalescing `engine?.setVolume(volume)` and `videoPlaybackController.volume = volume` into a debounced apply. These are sub-millisecond and necessary at drag rate for audible smoothness.
- Changing `balance` setter chain. Apply the same fix to balance only if Phase 0 shows the balance drag has the same starvation symptom; otherwise defer to a future task to keep diff scope tight.
- Restoring `UserDefaults` persistence at app-quit time as a safety net (existing behavior already persists on every drag end + every other write, so quit-time persistence is implicit; no new code required).

### 6.3 Decision gate

If Phase 0 shows Mechanism A alone, **skip Phase 1B entirely.** Document the deferral in the PR description and leave the debounce as a future task in `tasks/_context/state.md` deferred items inventory.

---

## 7. Phase 1C — Timer promotion fallback (executes only if Phase 0 returns Mechanism C alone — extremely unlikely)

If `MainWindowFullLayer.body` rate is at baseline but `VisualizerView.body` rate spikes during drag, `VisualizerView`'s stored-property timer publisher (`updateTimer`, `VisualizerView.swift:38`) may be reconstructing on each invalidation. Promote it into a `@State`-stored publisher so its identity is stable across rebuilds.

**Anticipated work:** modify `VisualizerView` only. Convert `let updateTimer = ...` to `@State private var updateTimer = ...`, ensure `.onReceive(updateTimer)` still subscribes correctly. ~5-line diff in `MacAmpApp/Views/VisualizerView.swift`.

This phase is documented for completeness; per `research.md` §C it is unlikely to be the dominant mechanism.

---

## 8. Files Inventory

Anticipated changes per phase. Read-against-HEAD line numbers.

| File | Phase | Change Type | Notes |
|------|-------|-------------|-------|
| `MacAmpApp/Views/MainWindow/MainWindowVisualizerLayer.swift` | 1A | **New** (~16 lines) | Wraps `VisualizerView()` in a recomposition-boundary `View` struct. |
| `MacAmpApp/Views/MainWindow/MainWindowFullLayer.swift` | 1A | Modified | Replace line 33 callsite, delete lines 132-140. Net -7. Verified against HEAD. |
| `MacAmpApp/Audio/AudioPlayer.swift` | 1B (conditional) | Modified | Refactor `volume.didSet` persistence path. Lines 65-70. |
| `MacAmpApp/Audio/PlaybackCoordinator.swift` | 1B (conditional) | Modified | Add `commitVolume()` if Option B-i. Around line 193. |
| `MacAmpApp/Views/MainWindow/MainWindowSlidersLayer.swift` | 1B (conditional) | Modified | Wire `onEnded` to call `commitVolume()`. Around line 47-54. |
| `MacAmpApp/Views/Components/WinampVolumeSlider.swift` | 1B (conditional) | Possibly modified | Only if `onEnded` plumbing requires a closure parameter. |
| `MacAmpApp/Views/VisualizerView.swift` | 1C (very conditional) | Modified | Promote `updateTimer` to `@State`. Line 38. |
| `project.yml` | none | No change | Directory globbing covers new file. |
| `tasks/mainwindow-visualizer-isolation/research.md` | 0 | Modified (append) | Phase 0 spike results section. |
| `tasks/_context/state.md` | post-merge | Modified | Mark task complete; close deferred-items entry at lines 142-165. |

**File overlap with parallel S3-1 worktree B (`stream-pause-tail`):** none. Confirmed via `tasks/_context/state.md` cross-task file conflict map (mwvi column vs. spt column at lines 304-316). If Phase 1B fires, `AudioPlayer.swift` becomes a shared file with `stream-pause-tail`; in that case, the merge order (A first, B second) means `stream-pause-tail` rebases on top of mwvi's changes.

---

## 9. Verification Approach

### 9.1 Required: post-fix Instruments measurement

After Phase 1A (and 1B if applicable) lands locally, repeat the Phase 0 measurement protocol and append a "Phase 1 — Verification Trace" section to `research.md`.

Quantitative success criteria (reproduces `research.md` §"Verification Approach" table):

| Body | Pre-fix (Phase 0) | Post-fix expectation | Pass condition |
|------|-------------------|----------------------|----------------|
| `MainWindowFullLayer.body` | High during drag (if Mechanism A confirmed) | At control baseline | Drag-trace count is within ±20% of control-trace count for the same duration. |
| `MainWindowSlidersLayer.body` | High during drag (correct — owns slider) | High during drag (still correct) | No regression: drag-trace count remains within ±20% of pre-fix value. |
| `VisualizerView.body` | High during drag if Mechanism A or C | At control baseline | Drag-trace count is within ±20% of control-trace count. |
| Visual continuity | Bars freeze during drag | Bars continue animating | Manual binary check (see 9.2). |

If `VisualizerView.body` count remains elevated post-fix, escalate to Phase 1B (Mechanism B) or Phase 1C (Mechanism C), per the §4.2 decision rule.

### 9.2 Manual repro checklist (primary symptom verification)

Run on `feat/mainwindow-visualizer-isolation` after Phase 1A lands:

- [ ] `xcodegen generate` and a TSan build complete without warnings.
- [ ] Launch MacAmp; load a known-good local audio file; hit Play.
- [ ] Confirm spectrum analyzer is animating at ~30 fps.
- [ ] Drag the volume slider continuously for 5 seconds. **Expected:** bars continue animating.
- [ ] Drag the balance slider continuously for 5 seconds. **Expected:** bars continue animating.
- [ ] Toggle double-size mode (Ctrl+D); repeat both drag tests. **Expected:** still animating.
- [ ] Load skin set #2 (e.g., `Bento_v2.wsz`); repeat the volume drag. **Expected:** still animating, VISCOLOR palette correct.
- [ ] Load skin set #3 (e.g., a custom WSZ with non-default VISCOLOR); repeat the volume drag.
- [ ] Click the visualizer area to cycle modes (spectrum → oscilloscope → none → spectrum). **Expected:** mode cycling unaffected.
- [ ] Toggle shade mode; confirm main window shrinks and visualizer is no longer visible there. Toggle back; confirm visualizer reappears and animates.
- [ ] When shade is on AND playlist visualizer is enabled in `WinampPlaylistWindow.swift:194`, confirm playlist-window visualizer still animates (untouched site).

### 9.3 Regression sweep (automated + manual)

- [ ] `xcodebuildmcp macos test --json '{"extraArgs":["-enableThreadSanitizer","YES"]}'` — full 57-test suite passes, zero TSan warnings.
- [ ] No new Xcode warnings in build log (`mcp__xcode__GetBuildLog` if Xcode IDE is open).
- [ ] Skin reload (`SkinManager.currentSkin` change) still updates VISCOLOR in spectrum bars.
- [ ] Manual: confirm shade mode still works (no visualizer in main window in shade mode; visualizer rendered in playlist window when `isMainWindowShaded` is true and `showVisualizer` is true).

### 9.4 Automated tests

No new unit tests. The fix is a SwiftUI structural change; SwiftUI body invalidation behavior is not unit-testable without view-host harnesses that the repo does not have. The Instruments traces in 9.1 are the verification artifact.

---

## 10. Risk Assessment

Builds on `research.md` "Risk Assessment" table; this section adds plan-level execution risks.

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|-----------|
| Phase 0 returns "Heisenbug — Instruments overhead masks issue" | Low | High (blocks task) | Stop criteria (§11). Halt and consult Oracle before any implementation. |
| `VisualizerView` Environment injection breaks because new layer is a new struct | Very low | High (blank visualizer) | `@Environment` is read by leaves; SwiftUI walks the chain regardless of intermediate structs. Manual test in 9.2 catches this immediately. |
| `.at(Layout.spectrumAnalyzer)` positioning regression | Very low | Medium | Modifier chain is preserved verbatim (`.frame().background().at()`). |
| Phase 1B introduces two new `internal` methods (`AudioPlayer.commitVolumeToDefaults`, `PlaybackCoordinator.commitVolume`) | Medium (only if 1B fires) | Low | Principle 5 enforcement: §6.1 design names exact caller list inline; todo 1B.8 grep audit catches scope creep; both symbols are net-new (no `private` → `internal` widening). |
| Phase 1B accidentally introduces a gesture-state flag inside `AudioPlayer` (Principle 3 violation) | Low (explicit non-goal) | High (cross-layer coupling) | Plan §6.1 point 5 + todo 1B.7 grep gate forbid `isVolumeDragActive` and equivalents. PR review must reject any such symbol. |
| Spike branch accidentally merged or pushed | Low | Medium | Branch policy: `spike/*` branches are deleted with `git branch -D` post-spike; never `git push`. Document in PR description. |
| Diff scope creep into other inline `@ViewBuilder` helpers | Low | Low | Non-goals (§2) explicitly forbid this. |
| Concurrency regression (data race in `barHeights` mutation) introduced by extraction | Very low | Medium | TSan-on test run in 9.3 must be clean. Extraction does not move any actor boundary; `VisualizerView` remains main-actor. |
| Conflict with parallel `stream-pause-tail` worktree | Very low | Low | Zero file overlap if only Phase 1A fires. If Phase 1B fires, `AudioPlayer.swift` overlaps; merge order (A then B) handles it via standard rebase. |

### 10.1 Principles compliance (link to research.md, this plan defends the gates)

| Principle | Plan verdict | Where defended |
|-----------|--------------|----------------|
| 1. Problem-First | PASS | §1 manual repro; Phase 0 gate prevents speculative cleanup. |
| 2. Cohesion Over Line Count | PASS | §3 item 5 — extraction is justified by isolation, not LOC. |
| 3. State Ownership | PASS | §5.1 — new struct holds zero state; original ownership preserved. |
| 4. Rule of Three (AHA) | N/A | §3 item 6 — no abstraction. Single named layer for a single problem. |
| 5. API Surface | PASS for 1A | §5.1 — `internal` only. PR-time gate for 1B if it fires. |
| 6. No Pass-Through Middlemen | PASS | §5.1 guardrail — the new layer owns layout policy, not just a `VisualizerView()` shim. |
| 7. ADR + Kill Switch | PASS | §11 — explicit halt conditions. |

---

## 11. Stop Criteria / Kill Switch

Cancel or roll back the task if any of these conditions hold. Pre-merge and post-merge halts have different procedures.

### 11.1 Pre-merge halt triggers (before PR is merged)

1. **Phase 0 returns "all signposts within ±20% of control AND no visual freeze under Instruments overhead"** (Heisenbug). Do not proceed; reconvene with Oracle on alternative measurement strategies.
2. **Phase 0 returns Mechanism C alone** (highly unlikely per research.md §C). Pause; consult Oracle. Do not proceed without explicit Oracle sign-off because that result contradicts the static analysis and may indicate a measurement artifact.
3. **Post-Phase 1A measurement (§9.1) fails its pass condition** (`VisualizerView.body` rate still ≥120% of control during drag) AND Phase 1B has already been applied without effect. Halt; revert local commits; investigate alternate timer ownership models with Oracle.
4. **TSan warnings appear in §9.3 regression sweep that did not exist on `main`.** Halt; revert local commits.
5. **Manual repro in §9.2 still shows freezing after both 1A and 1B.** Halt; document findings; defer to a follow-up task.
6. **Diff for Phase 1A exceeds 30 net lines** (excluding doc comments). Likely scope creep; review before continuing.

**Pre-merge halt procedure:**

1. Stash or commit any in-progress work on `feat/mainwindow-visualizer-isolation` to a `wip/<context-tag>` branch first so context is not lost.
2. **Decide which path to take BEFORE any reset:**
   - **Path A (default — preserve implementation history):** append halt findings to `research.md` and commit them on top of the existing implementation commits. No reset performed. Use this whenever possible — it is strictly safer than Path B because nothing is destroyed.
   - **Path B (discard implementation, keep only findings):** only when the implementation diff is positively unwanted (wrong direction confirmed) AND a maintainer has signed off on the discard. Use **Path B-cherry-pick** below — the only safe sequence, because `git reset --hard` discards both committed and uncommitted working-tree state.
     - **Path B-cherry-pick (the only Path B variant):**
       1. First commit halt findings on `feat/mainwindow-visualizer-isolation` (same as Path A's commit step). Capture the SHA: `FINDINGS_SHA=$(git rev-parse HEAD)`.
       2. `git reset --hard <pre-impl-sha>` to discard implementation commits AND the findings commit (the findings SHA still exists in the reflog).
       3. `git cherry-pick "$FINDINGS_SHA"` to reapply only the findings commit on top of the reset branch.
       4. Result: feature branch has `<pre-impl-sha>` plus a single findings commit; implementation commits are unreachable from the branch tip but recoverable from the reflog for ~30 days.
   - **Forbidden sequence:** writing findings to the working tree but **not committing**, then `git reset --hard`. This destroys uncommitted findings. Do not do this.
3. Do NOT delete the feature branch; future iterations may resume on it.
4. Report back to the user before any further code changes.

### 11.2 Post-merge halt / revert (after PR is merged)

If a regression is discovered after the PR has merged into `main`, follow the §13 Rollback Plan procedure. Do not perform Step 11.1's local-reset workflow; that path destroys merged history.

---

## 12. Branch + PR Plan

### 12.1 Branches

| Branch | Origin | Purpose | Lifetime |
|--------|--------|---------|----------|
| `spike/mwvi-volume-drag-profile` | `main` | Phase 0 only. Holds temporary signposts. | Created at Phase 0 start; **deleted** before Phase 1 starts. Never pushed. |
| `feat/mainwindow-visualizer-isolation` | `main` | Phase 1A (and 1B/1C if needed). The PR branch. | Created after Phase 0 results are written. Pushed to remote when ready for PR. |

The two branches are independent. Phase 0 findings are committed to `feat/mainwindow-visualizer-isolation` (in `research.md`), not to the spike branch.

### 12.2 Predecessor merge dependencies

- None. mwvi has zero predecessors per `tasks/_context/state.md` Sprint S3 ordering table.
- Parallel sibling: `fix/stream-pause-tail` (worktree B) runs concurrently. Merge order: A first (this PR), B second.
- Successor: `feat/video-audio-engine-routing` (S3-2) waits for both A and B.

### 12.3 PR title + body skeleton

```
PR title:
fix(main-window): isolate visualizer recomposition during slider drag

PR body:
## Summary

- Adds `MainWindowVisualizerLayer` to create a SwiftUI recomposition boundary so the spectrum analyzer continues animating during volume / balance slider drags.
- [Conditional, gated on Phase 0:] Defers `AudioPlayer.volume` UserDefaults persistence to drag-end to eliminate main-thread starvation per drag tick.

## Root cause

See `tasks/mainwindow-visualizer-isolation/research.md`. Phase 0 Instruments spike confirmed Mechanism <A | A+B | …>.

## Verification

- Phase 0 spike traces (`research.md` §"Phase 0 — Spike Results") and post-fix traces (§"Phase 1 — Verification Trace").
- Manual repro across full mode, shade mode, double-size mode, and 3 skins.
- Full TSan test suite (57 tests) passes.

## Files

- New: `MacAmpApp/Views/MainWindow/MainWindowVisualizerLayer.swift`
- Modified: `MacAmpApp/Views/MainWindow/MainWindowFullLayer.swift`
- [If Phase 1B fired:] Modified: `MacAmpApp/Audio/AudioPlayer.swift`, `MacAmpApp/Audio/PlaybackCoordinator.swift`, `MacAmpApp/Views/MainWindow/MainWindowSlidersLayer.swift`.

## Sprint context

Sprint S3, Wave S3-1 Worktree A. Predecessors: none. Parallel: `fix/stream-pause-tail`. Successor: `feat/video-audio-engine-routing`.
```

### 12.4 PR review gate

After PR is opened, run `pr-review-toolkit:review-pr` plus Codex Oracle on the diff before requesting human review. Address all ACTIONABLE comments via `scripts/resolve-pr-comments.sh`.

---

## 13. Rollback Plan

If a regression is discovered post-merge:

1. **Phase 1A only revert:** `git revert <commit-sha>` on `main`. The change is two-file and self-contained; revert is clean.
2. **Phase 1A + 1B revert:** revert in reverse order (1B first, then 1A). Each was committed as a separate commit on `feat/mainwindow-visualizer-isolation`. If the PR was squashed, revert the squash commit, then split into a hotfix that restores 1A only if 1B was the sole regression source.
3. **Spike-state restoration:** the `spike/mwvi-volume-drag-profile` branch was deleted; no rollback required there. Phase 0 findings remain in `research.md` for future reference.
4. **Communicate:** update `tasks/_context/state.md` to mark the task as `REVERTED` and add a deferred-items entry capturing what was learned.

Commit hygiene: keep Phase 1A and Phase 1B as separate commits on the PR branch (do not squash locally) so a partial revert is possible at PR-review time. The maintainer's merge strategy can squash on merge.

---

## 14. Oracle Validation Summary

Iterated against `mcp__codex-cli__codex` (model `gpt-5.3-codex`, reasoningEffort `xhigh`).

| Iteration | Score | Actionable Issues | Resolution Summary |
|-----------|-------|-------------------|--------------------|
| 1 | 8.4/10 | 5 (1 HIGH, 3 MEDIUM, 1 LOW) | See iteration 1 detail below. All 5 applied. |
| 2 | 9.0/10 | 2 (1 MEDIUM, 1 LOW) + 1 nitpick | See iteration 2 detail below. All 3 applied. |
| 3 | 8.8/10 | 1 (MEDIUM — Path B-1 safety bug introduced in iter 2 fix) | See iteration 3 detail below. Applied. |
| 4 | **9.4/10** | **0** | **Final approval granted.** No actionable, no false positives, no nitpicks. |

### Iteration 1 detail (2026-04-27)

| # | Severity | Issue | Resolution |
|---|----------|-------|------------|
| 1 | HIGH | `isVolumeDragActive` flag in `AudioPlayer` violates Principle 3 (cross-layer state coupling) | Removed flag from design entirely. §6.1 rewritten to make persistence call-site-driven via explicit `commitVolumeToDefaults()` + UI-injected closure. todo 1B.7 adds grep gate to prevent regression. |
| 2 | MEDIUM | Option B-i visibility contract was internally inconsistent (`private` then required coordinator call → forced widening) | §6.1 now specifies one explicit contract: two new `internal` methods (`AudioPlayer.commitVolumeToDefaults`, `PlaybackCoordinator.commitVolume`); approved-caller list documented inline; no `private` → `internal` widening. |
| 3 | MEDIUM | Plan and todo disagreed on trace count (4 vs 3) | §4.1 expanded to 4 explicit traces (T1-T4) with same-session control requirement. §4.2 decision rule updated to compare T2/T1 and T4/T3 separately, with explicit ratios (≥3× for `MainWindowFullLayer.body`, ≥1.5× for `VisualizerView.body`). todo §0.5-0.10 mirrors. |
| 4 | MEDIUM | Spike hygiene: temporary signposts had no explicit cleanup checkbox before commit | Added todo 0.12 (mandatory: revert signpost edits, `git status` clean) before the results-write step. |
| 5 | LOW | Stop-criteria rollback procedure conflated pre-merge and post-merge cases | §11 split into §11.1 (pre-merge halt procedure: `wip/` branch preserve, append findings, then reset) and §11.2 (defer to §13 Rollback Plan for post-merge). todo Stop Criteria Reminder mirrors. |

### False positives recorded (not applied)

| # | Severity | Issue | Why not applied |
|---|----------|-------|-----------------|
| FP1 | — | "`internal` visibility note in §5.1 is inaccurate" | Verified at HEAD: sibling layers (`MainWindowSlidersLayer`, `MainWindowTransportLayer`, etc.) declare `struct Foo: View` without explicit modifiers, so default-`internal` is correct. |
| FP2 | — | "Plan line references are stale" | All re-verified at HEAD before plan was written: `MainWindowFullLayer.swift:33`, `:132-140`, file is 258 lines, `VisualizerView.swift:38`. |
| FP3 | — | "Extraction violates Principle 6 as pass-through" | Layout policy retained in new layer per §5.1 guardrail; not a pure forwarder. |

### Nitpicks recorded

| # | Issue | Status |
|---|-------|--------|
| N1 | Diff notation `~+16 / -8 / +1` was hard to parse | Applied — todo 1A.6 now lists per-file additions/removals explicitly. |
| N2 | Trace naming should be `T1-T4` | Applied — plan §4.1, §4.2 and todo §0.5-0.10 use `T1`/`T2`/`T3`/`T4`. |

### Iteration 2 detail (2026-04-27)

| # | Severity | Issue | Resolution |
|---|----------|-------|------------|
| 6 | MEDIUM | Pre-merge halt procedure could drop the halt-findings commit if Path B is taken (commit findings then hard-reset = findings lost) | §11.1 split into Path A (preserve impl + findings, no reset, default) and Path B (B-1: edit findings but don't commit until after reset; B-2: cherry-pick findings SHA after reset). todo Stop Criteria Reminder mirrors. |
| 7 | LOW | Spike-branch "never pushed" verification used `git remote -v` (lists remotes, not refs) | todo 0.14 now uses `git ls-remote --heads origin 'spike/*'` plus `git branch -r \| rg 'spike/'` — both should return zero rows. |
| N3 | NITPICK | API-surface audit wording missed the `WinampVolumeSlider.onDragEnded` synthesized-init expansion | Applied — plan §6.1 and todo 1B.8 now name all three additions explicitly: two `internal` methods + one optional stored property with default value (source-compatible synthesized memberwise init expansion). |

### Iteration 2 false positive recorded

| # | Issue | Why not applied |
|---|-------|-----------------|
| FP4 | "Research file lists `WinampMainWindow.swift` as 111 lines; current is 110" (nitpick #2 from iteration 2) | research.md is Oracle-validated and frozen as the source of truth; per task brief, plan must NOT contradict research. The 1-line drift is cosmetic and does not affect plan correctness. The Oracle validation summary in research.md §"Oracle Validation Summary" item #5 already corrected this from 111 to 110 in the prose body. The "Files Analyzed" footer line is the only stale reference; not worth touching the frozen research artifact. |

### Iteration 3 detail (2026-04-27)

| # | Severity | Issue | Resolution |
|---|----------|-------|------------|
| 8 | MEDIUM | Iteration-2 fix introduced a Path B-1 safety bug: "edit findings, do not commit, then `git reset --hard`" loses uncommitted findings (reset --hard discards working-tree state) | Removed Path B-1 entirely. Plan §11.1 and todo Stop Criteria now have only Path A (default, no reset) and Path B-cherry-pick (commit findings first to capture SHA, reset, then cherry-pick the findings SHA back from reflog). Added explicit "Forbidden sequence" warning. |

**Final score:** **9.4/10** (iteration 4 — final approval, zero remaining issues)
**Iterations:** 4 of max 4. Score progression: 8.4 → 9.0 → 8.8 → 9.4. Target ≥ 9/10 met.
