# Unimplemented Features - Noted During Phase 2 Testing

**Date:** 2025-10-29
**Context:** AudioPlayer @Observable migration testing

---

## Features Not Yet Implemented

### 1. Oscilloscope/RMS Visualizer Mode Toggle
**Status:** Partially implemented (backend exists, UI hidden)

**What EXISTS in Code:**
- ✅ RMS calculation implemented (`AudioPlayer.swift:882-904`)
- ✅ Mode switching implemented (`useSpectrumVisualizer ? spectrum : rms`)
- ✅ VisualizerOptions component exists with toggle (`VisualizerOptions.swift`)
- ✅ Both spectrum AND RMS data computed every frame

**What's MISSING:**
- ❌ VisualizerOptions UI is NOT displayed anywhere in main window
- ❌ No way for users to access the toggle
- ❌ Mode switch works IF toggle were visible, but it's hidden

**Technical Detail:**
- Backend fully functional (both modes computed and work)
- UI component exists but not integrated into window layout
- Simple fix: Add `VisualizerOptions()` to WinampMainWindow or equalizer window

**Why "Not Implemented":**
From user perspective, if the UI isn't accessible, the feature doesn't exist.

### 2. Repeat Mode "One" and "All"
**Status:** Partially implemented
**Current State:** Only On/Off toggle works
**Missing:** Distinction between:
- Repeat Off
- Repeat One (repeat current track)
- Repeat All (repeat entire playlist)

### 3. M3U Playlist File Support
**Status:** Deferred to internet radio feature
**Context:** M3U files can be seen but loading deferred to P5
**Reference:** `tasks/internet-radio-file-types/`

### 4. Settings Persistence Across Restarts
**Status:** Bug - not persisting correctly
**Symptoms:**
- Repeat mode resets to Off on restart
- Volume resets to max on restart
**Expected:** Settings should persist in UserDefaults
**Impact:** User preferences lost between sessions

### 5. Playlist Scrolling
**Status:** Not yet implemented
**Current State:** Static playlist view
**Missing:** Scroll support for playlists longer than window height

---

## Testing Results (Phase 2 AudioPlayer Migration)

### ✅ Working Correctly:
- Audio playback (no crashes, no dropouts)
- EQ slider changes (no audio glitches)
- Volume/balance sliders (smooth, no glitches)
- All playlist operations (add, remove, navigation)
- Time display updates (current time, duration)
- Spectrum analyzer (responsive to music and EQ adjustments)
- Track navigation (next, previous, jump to track)
- Seeking (tested and working)
- Auto-progression (tracks advance automatically)

### ⚠️ Known Issues:
- Settings don't persist (volume, repeat mode)
- Liquid Glass shimmer doesn't stop (separate bug, documented)

---

## Impact on @Observable Migration

**None.** These are pre-existing missing features/bugs, not related to the @Observable migration. Core functionality verified working with @Observable pattern.

---

## Recommendations

### Short-term:
1. **Complete Phase 2** - Migration is successful
2. **File settings persistence bug** as separate issue
3. **Defer** unimplemented features to backlog

### Long-term:
1. Implement settings persistence (UserDefaults save/load)
2. Implement proper repeat mode (Off/One/All)
3. Add oscilloscope visualizer mode
4. Implement playlist scrolling
5. Complete M3U support (as part of internet radio feature)

---

**Status:** Phase 2 AudioPlayer migration successful despite unimplemented features
