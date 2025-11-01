# State Management Consistency Analysis - MacAmp Codebase

## Executive Summary

The audit focused on state-heavy components (`AudioPlayer`, `SkinManager`, `AppSettings`, `DockingController`, and supporting models). Earlier documentation framed several problems as concurrency hazards; closer review shows these types are isolated on the main actor, so the primary risks stem from state clarity, validation gaps, and missing feedback loops. This document catalogs the verified issues and recommended fixes.

---

## 1. Models

### 1.1 AppSettings.swift – **High**
**File:** `MacAmpApp/Models/AppSettings.swift`

- **Singleton isolation**  
  - *Current state:* The class is annotated with `@MainActor`, so access is serialized (`MacAmpApp/Models/AppSettings.swift:28`). No additional locking is required.  
  - *Action:* Retain the main-actor isolation; update documentation to avoid implying thread-unsafe behavior.

- **Persistence validation**  
  - *Issue:* Properties write straight to `UserDefaults` without validating payloads.  
  - *Impact:* Corrupted or unexpected values can persist across launches.  
  - *Recommendation:* Introduce explicit loaders with validation/clamping before updating `@Published` properties.

- **Skin directory handling**  
  - *Issue:* `userSkinsDirectory` uses `try?` and silently ignores failures (`MacAmpApp/Models/AppSettings.swift:94`).  
  - *Impact:* When directory creation fails, skins cannot be imported and the user receives no signal.  
  - *Recommendation:* Throw or surface an error, and return `nil` when the directory cannot be created.

### 1.2 EQF.swift – **Medium**
**File:** `MacAmpApp/Models/EQF.swift`

- *Issue:* `parse(data:)` assumes well-formed payloads, lacks bounds checks on header, values, and trailing fields.  
- *Impact:* Malformed files can trigger index errors or produce invalid gain values.  
- *Recommendation:* Guard on minimum byte count, verify value count before indexing, clamp results to the expected -12…+12 dB range.

### 1.3 EQPreset.swift – **Low**
**File:** `MacAmpApp/Models/EQPreset.swift`

- *Issue:* Conversion helpers do not clamp to the valid dB window.  
- *Impact:* Out-of-range inputs propagate to the UI and presets.  
- *Recommendation:* Clamp in `winampToDb`/`dbToWinamp` to guarantee consistent output.

### 1.4 Skin.swift / SpriteResolver.swift – **Low**

- *Skin.swift:* Force-unwrapped bundle lookups still risk crashes if assets are missing. Add `guard` + diagnostics (pending assets audit).  
- *SpriteResolver.swift:* Input validation for digit lookups should reject values outside 0–9 to avoid returning empty arrays.

---

## 2. ViewModels

### 2.1 DockingController.swift – **Medium**
**File:** `MacAmpApp/ViewModels/DockingController.swift`

- *Issue:* Persistence writes trigger on every change without debouncing (`MacAmpApp/ViewModels/DockingController.swift:53`).  
- *Impact:* Rapid toggles spam `UserDefaults`, causing unnecessary I/O and potential stutter.  
- *Recommendation:* Apply debounce/buffer before encoding, and log save failures. Bounds safety is already enforced (`toggleVisibility`, `toggleShade` guard indices).

### 2.2 SkinManager.swift – **Critical**
**File:** `MacAmpApp/ViewModels/SkinManager.swift`

- *Issue:* `loadingError` remains populated after successful loads, so stale error banners persist.  
- *Impact:* Users believe the skin failed even when it applied correctly.  
- *Recommendation:* Clear `loadingError` at the start of a load and after success.

- *Issue:* Heavy archive parsing and bitmap slicing run synchronously on the main actor (`MacAmpApp/ViewModels/SkinManager.swift:327`).  
- *Impact:* Large skins freeze the UI, and any failure mid-way leaves the manager in a partially-updated state.  
- *Recommendation:* Move extraction to a background executor (actor, task, or queue) that publishes results back on the main actor.

- *Issue:* Import flow trusts incoming URLs and file sizes.  
- *Impact:* Malicious or oversized archives can exhaust memory or overwrite unexpected paths.  
- *Recommendation:* Validate file extensions, enforce size limits, and normalise destination URLs before copying.

---

## 3. AudioPlayer.swift – **Critical**
**File:** `MacAmpApp/Audio/AudioPlayer.swift`

- *Issue:* Playback logic is spread across multiple boolean flags (`isPlaying`, `isPaused`, `isSeeking`, `wasStopped`, `trackHasEnded`).  
- *Impact:* It is difficult to prove the invariants hold after seek, stop, and completion callbacks, increasing regression risk.  
- *Recommendation:* Introduce a single `PlaybackState` enum with exhaustively handled transitions; derive legacy booleans from the enum until UI bindings are updated.

- *Issue:* Completion handlers rely on UUID comparison (`currentSeekID`), but nested operations can still re-enter `onPlaybackEnded`.  
- *Impact:* Transition confusion when seeks overlap with natural track ending.  
- *Recommendation:* Consolidate completion handling through the new state machine and ensure callbacks respect the active state.

- *Positive finding:* `startProgressTimer()` already invalidates the existing timer before scheduling a new one (`MacAmpApp/Audio/AudioPlayer.swift:655`), so there is no multi-timer leak. Retain this behavior.

---

## 4. Cross-Cutting Concerns

- **Error propagation:** Replace `try?` usage that hides failures across the app (notably filesystem work and archive extraction).  
- **User feedback:** Ensure UI-facing state (e.g., `loadingError`, progress indicators) reflects real success/failure transitions.  
- **Testing:** Add targeted unit tests for new validation layers (EQF parsing, AppSettings loaders, SkinManager import guardrails) and integration tests for the AudioPlayer state machine.

---

## 5. Items No Longer Considered Issues

- **Concurrency races in `AppSettings`, `SkinManager`, and `AudioPlayer`:** All three are `@MainActor`, so the earlier race-condition language was inaccurate.  
- **Progress timer leak:** Already mitigated by timer invalidation.  
- **`DockingController` array bounds:** Methods guard indices before mutation; no crash risk identified.  
- **`BalanceSliderView.swift` references:** Component has been replaced by `WinampBalanceSlider` in `MacAmpApp/Views/Components/WinampVolumeSlider.swift`.

---

## 6. Recommendations Overview

1. Refactor AudioPlayer state to an enum-driven machine (critical).  
2. Offload SkinManager parsing, reset `loadingError`, and harden import validation (critical/high).  
3. Validate all AppSettings persistence paths and surface filesystem errors (high).  
4. Debounce DockingController persistence and log anomalies (medium).  
5. Add strict bounds checking and clamping to EQF/EQPreset utilities (medium).
