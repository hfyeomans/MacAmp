```markdown
# Implementation Plan – Memory & Performance Hardening

## 0. Goals
- Keep long-term memory footprint <150 MB during heavy use.
- Remove obsolete remediation steps that target deleted views.
- Focus engineering time on the issues validated in the 2025-10-24 research sweep.

## 1. Scope Check
| Area | Included | Notes |
| ---- | -------- | ----- |
| Audio pipeline (timers, taps, buffers) | ✅ | `MacAmpApp/Audio/AudioPlayer.swift` |
| Winamp window timers | ✅ | `WinampMainWindow.swift`, `VisualizerView.swift` |
| Skin loading, ZIP extraction | ✅ | `SkinManager.swift`, `Skin.swift` |
| Legacy window stack (`EqualizerWindowView`, etc.) | ❌ | Removed from project – nothing to touch. |
| Instrumentation & docs | ✅ | Update README + add follow-up tasks post-fix. |

## 2. Work Breakdown

### 2.1 Audio Tap Lifecycle
1. Add `removeVisualizerTapIfNeeded()` that tears down the tap, resets `visualizerTapInstalled`, and optionally clears scratch buffers.
2. Call removal from `stop()`, `eject()`, and when playback errors occur (`onPlaybackEnded` guard paths).
3. Ensure `installVisualizerTapIfNeeded()` toggles the flag only after successful install; add safety check to reinstall after engine resets.
4. Cover with unit/integration test (or targeted swift test) that plays, stops, and plays again while checking the tap count (via debug hooks).

### 2.2 Visualizer Scratch Buffer Reuse
1. Introduce lightweight `AudioScratchBuffers` (owned by `AudioPlayer`) with pre-sized `mono`, `rms`, and `spectrum` arrays.
2. Update tap closure to reuse buffers instead of allocating per-call; profile for thread-safety (closure runs on engine render thread).
3. Provide `resetVisualizerBuffers()` invoked when playback stops to release large arrays if memory pressure requires.

### 2.3 Timer Ergonomics & Safety
1. Wrap timer creation (`progressTimer`, `scrollTimer`, `updateTimer`) with helper that automatically registers in `.common` run loop mode.
2. Audit `DispatchQueue.main.asyncAfter` in `WinampMainWindow.resetScrolling()` – add guard to skip restart if the view has disappeared (use `isViewVisible` state flag).
3. Document timer expectations in code comments and add debug-only leak detector (e.g., count timers via `TimerManager` diagnostics).

### 2.4 Skin Extraction Peak Memory
1. Pre-size `Data` buffers using `entry.uncompressedSize` and reuse temporary `NSBitmapImageRep` where possible.
2. Gate the verbose sprite logging behind `#if DEBUG`.
3. Consider streaming extraction for very large BMPs (>2 MB) via `CGImageSourceCreateWithDataProvider` to avoid duplicating buffers.
4. Add lightweight benchmark (unit test or dev command) to measure peak allocation while loading a representative skin.

### 2.5 Verification & Tooling
1. Draft a manual QA checklist that exercises: launch, play track, pause/stop, rapid skin switching.
2. Prepare Instruments session templates (Leaks + Allocations) for regression tracking.
3. Update `tasks/memory-management-analysis/state.md` after implementation with before/after metrics.

## 3. Sequencing
1. **Audio tap lifecycle** – highest risk for both memory and CPU.
2. **Scratch buffer reuse** – depends on tap hooks; implement immediately after.
3. **Timer ergonomics** – touches UI only; can be parallel but simpler once tap work stabilizes.
4. **Skin extraction** – medium risk, isolate in later PR to avoid destabilising playback.
5. **Verification** – run after each major phase; update documentation/state.

## 4. Risks & Mitigations
- **Audio engine regressions**: guard changes with feature flag (e.g., `enableVisualizerTapRefactor`) until validated.
- **Thread-safety of shared buffers**: use `AudioBuffer`’s render queue; wrap mutations in `withUnsafeMutablePointer` to avoid data races.
- **Skin loading edge cases**: test with corrupted archives; maintain fallback path by keeping legacy extraction for now with a flag.

## 5. Out of Scope / Follow-up Ideas
- Full memory monitoring HUD (`MemoryMonitor` from legacy implementation) – postpone until core fixes complete.
- Rewriting sprite resolver/caching – keep as-is unless profiling shows hot spot.
- Automated leak tests in CI – to be explored once instrumentation pipeline exists.
```
