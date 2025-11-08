# Oscilloscope/RMS Mode Toggle - Current State

**Date:** 2025-10-30
**Status:** ✅ COMPLETE - Merged to Main (PR #27)

---

## Task Status

### Research Phase
- ✅ Gemini research complete (webamp analysis)
- ✅ Backend discovery complete
- ✅ Existing components identified
- ✅ Oracle review complete (2 rounds, all issues fixed)

### Implementation Phase
- ✅ **COMPLETE** - All phases done and Oracle-approved
  - Commit 2b529d6: Initial RMS/spectrum exposure
  - Commit 5651a2d: Click-to-cycle implementation
  - Commit 5ea58bd: Fix oscilloscope data source (waveform not RMS)
  - Commit 24a3793: Oracle cleanup (enum, comments)
  - Commit 0bbdc7a: Fix state divergence + centralize constants
  - Commit f9d0a3d: Final constant cleanup

### Oracle Code Review
- ✅ Round 1: 5 issues found (planning stage)
- ✅ Round 2: 2 issues found (implementation review)
- ✅ All issues fixed
- ✅ Final approval received
- ✅ Production ready ✅

---

## Critical Discovery: Backend Already Exists! ✅

### Found Components

**1. AudioPlayer - Mode Toggle Property**
- **File:** `MacAmpApp/Audio/AudioPlayer.swift`
- **Line:** 107
- **Property:** `var useSpectrumVisualizer: Bool = true`
- **Status:** ✅ Fully functional, just needs UI

**2. Audio Tap - Dual Calculation**
- **File:** `MacAmpApp/Audio/AudioPlayer.swift`
- **Lines:** 838-958
- **Calculates BOTH:**
  - RMS (Root Mean Square) - Lines 882-903
  - Spectrum (FFT) - Lines 904-948
- **Selector:** Line 840 chooses based on `useSpectrumVisualizer`
- **Status:** ✅ Working, tested

**3. VisualizerOptions UI Component**
- **File:** `MacAmpApp/Views/VisualizerOptions.swift`
- **Lines:** 1-40
- **Has:** Toggle("Spec", isOn: $player.useSpectrumVisualizer)
- **Status:** ✅ Exists but NOT surfaced in main window
- **Action:** Just add to WinampMainWindow!

**4. VISCOLOR Colors**
- **Parser:** `VisColorParser.swift` ✅
- **Storage:** `Skin.visualizerColors` ✅
- **Colors 2-17:** Spectrum (loaded but not applied yet)
- **Colors 18-22:** Oscilloscope/RMS (loaded, not used)
- **Status:** ⚠️ Loaded but hardcoded colors still in use

**5. AppSettings.visualizerMode**
- **File:** `MacAmpApp/Models/AppSettings.swift`
- **Line:** ~167
- **Property:** `var visualizerMode: Int = 0`
- **Status:** ✅ Scaffolded, ready to use

---

## What's Missing

### UI Integration
- [ ] VisualizerOptions not in main window
- [ ] Visualizer not clickable (webamp has this)
- [ ] V button not wired
- [ ] No keyboard shortcut

### Additional Modes
- [ ] Oscilloscope waveform rendering
- [ ] Mode cycling (3+ modes)
- [ ] None/Off mode

### Visual Polish
- [ ] VISCOLOR colors not applied
- [ ] Colors 18-22 not used for RMS/oscilloscope

---

## Prerequisites Checklist

### ✅ Verified

#### Existing Backend
- [x] ✅ useSpectrumVisualizer toggle exists
- [x] ✅ RMS calculation implemented
- [x] ✅ Spectrum calculation implemented
- [x] ✅ VisualizerOptions component exists
- [x] ✅ visualizerMode scaffolded in AppSettings

#### Framework Support
- [x] ✅ SwiftUI Canvas API (for oscilloscope)
- [x] ✅ Accelerate framework (for FFT)
- [x] ✅ @Observable architecture
- [x] ✅ Body-scoped @Bindable pattern

### Required Additions

#### Phase 1 (MVP)
- [ ] Add VisualizerOptions to WinampMainWindow (+1 line)

#### Phase 2 (Enhanced)
- [ ] Add .onTapGesture to VisualizerView
- [ ] Migrate to visualizerMode enum
- [ ] Wire V button
- [ ] Add Ctrl+V shortcut
- [ ] Expose getRMSData() from AudioPlayer

#### Phase 3 (Full Feature)
- [ ] Implement oscilloscope waveform rendering
- [ ] Expose getWaveformSamples() from AudioPlayer
- [ ] Apply VISCOLOR colors 18-22
- [ ] Add oscilloscope to mode cycle

---

## Implementation Paths

### Path A: MVP (30 minutes) - Expose Existing

**What:**
- Add VisualizerOptions to main window
- Spectrum/RMS toggle works immediately
- Uses existing backend

**Effort:** 30 min
**Risk:** 🟢 Very Low
**Value:** ✅ HIGH (instant feature)

### Path B: Click-to-Cycle (2 hours) - Webamp Pattern

**What:**
- Clickable visualizer area
- V button functional
- Keyboard shortcut Ctrl+V
- Mode cycling: Spectrum → RMS → None

**Effort:** 2 hours
**Risk:** 🟢 Low
**Value:** ✅ HIGH (matches webamp UX)

### Path C: Full Oscilloscope (6 hours) - Complete Feature

**What:**
- Add waveform rendering
- VISCOLOR colors 18-22 applied
- 3 modes: Spectrum, RMS, Oscilloscope
- Full webamp parity

**Effort:** 6 hours
**Risk:** 🟡 Medium
**Value:** ⚠️ MEDIUM (nice-to-have)

---

## Discovered File Locations

### Files That Exist
- ✅ `MacAmpApp/Audio/AudioPlayer.swift` - Backend logic
- ✅ `MacAmpApp/Views/VisualizerOptions.swift` - UI toggle (hidden)
- ✅ `MacAmpApp/Views/VisualizerView.swift` - Rendering
- ✅ `MacAmpApp/Models/AppSettings.swift` - visualizerMode scaffolded
- ✅ `MacAmpApp/Models/VisColorParser.swift` - VISCOLOR parser
- ✅ `MacAmpApp/Models/Skin.swift` - visualizerColors storage

### Files to Modify
1. `WinampMainWindow.swift` - Expose VisualizerOptions, wire V button
2. `VisualizerView.swift` - Add click handler, mode switching
3. `AppSettings.swift` - Add VisualizerMode enum, persistence
4. `AppCommands.swift` - Add Ctrl+V shortcut
5. `AudioPlayer.swift` - Expose getRMSData(), getWaveformSamples()

### Files to Create (Optional)
- `OscilloscopeView.swift` - Waveform rendering (Phase 3)

---

## Current vs Webamp Comparison

### Webamp
- ✅ 3 modes: Spectrum, Oscilloscope, None
- ✅ Click visualizer to cycle
- ✅ VISCOLOR colors applied
- ✅ All modes rendered correctly

### MacAmp (Current)
- ✅ Backend: Spectrum + RMS ✅
- ❌ UI: Toggle hidden
- ❌ Modes: Only 2 (no oscilloscope)
- ❌ Click: Not implemented
- ❌ VISCOLOR: Loaded but not applied

### MacAmp (After Implementation)
- ✅ 3 modes: Spectrum, RMS, None (+ Oscilloscope optional)
- ✅ Click visualizer to cycle
- ✅ V button + Ctrl+V
- ✅ VISCOLOR colors can be applied

---

## Integration Points

### V Button (Clutter Bar)
- Currently scaffolded (disabled)
- Perfect for visualizer mode toggle
- Sprite shows selected when visualizer active
- Pattern: Copy from D/A buttons

### VisualizerOptions Component
- Exists at: `MacAmpApp/Views/VisualizerOptions.swift`
- Has: Toggle, smoothing slider, peak falloff slider
- Just needs to be added to main window
- Position: Above or next to visualizer area

### VisualizerView (Clickable Area)
- Current: Renders bars, not clickable
- Add: .onTapGesture to cycle modes
- Pattern: Like webamp canvas onClick

---

## Confidence Assessment

### High Confidence ✅
- Backend already exists and works
- VisualizerOptions component ready
- Simple integration (1 line to expose)
- V button scaffolding complete
- AppSettings.visualizerMode ready

### Medium Confidence ⚠️
- Oscilloscope rendering (new code)
- VISCOLOR color application (needs testing)
- Mode cycling logic (straightforward but untested)

### Low Risk ⚠️
- No architecture changes needed
- No breaking changes
- Backend is isolated and tested
- UI additions are non-invasive

---

## Next Steps

1. ⏸️ Oracle review of research and plan
2. ⏸️ User approval to proceed
3. ⏸️ Implement Phase 1 (30 min)
4. ⏸️ Test Spectrum vs RMS
5. ⏸️ Optional: Implement Phase 2
6. ⏸️ Optional: Implement Phase 3

---

**Status:** ✅ Research complete, backend discovered, ready for Oracle review
**Confidence:** HIGH (backend exists, simple UI exposure)
**Effort:** 30 min (MVP) to 6 hours (full feature)

---

## 🎉 Final Summary

**Status:** ✅ COMPLETE - Oracle-Approved - Production Ready

**Delivered Features:**
1. ✅ Click spectrum analyzer to cycle modes
2. ✅ Spectrum mode (FFT frequency bars)
3. ✅ Oscilloscope mode (time-domain waveform)
4. ✅ None mode (off)
5. ✅ State persistence
6. ✅ Type-safe enum
7. ✅ Centralized constants

**Commits:** 7 total
**Files Modified:** 4
**Oracle Reviews:** 2 (all issues fixed)
**User Testing:** ✅ "Amazing! It works!"

**Production Ready:** ✅ YES

---

*Task completed: 2025-10-30*
*Ready for PR merge: YES*
