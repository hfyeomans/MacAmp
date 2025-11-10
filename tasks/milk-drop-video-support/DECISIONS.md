# TASK 2 Final Decisions (2025-11-09)

## User Decisions

**1. V Button**: Option A - Opens Video window ✅
**2. Milkdrop Trigger**: Option A - Options menu checkbox (on/off) + Ctrl+Shift+K ✅
**3. Window Resize**: Option B - Defer to TASK 3 (focus, no scope creep) ✅

## Principle

**"Make it exist, then make it better"**

## Keyboard Shortcuts Available

- Ctrl+K: ✅ AVAILABLE
- Ctrl+M: ✅ AVAILABLE
- **Using**: Ctrl+Shift+K (Winamp historical standard for visualizations)

## Architecture

**Video Window**:
- NSWindowController pattern (like TASK 1)
- VIDEO.BMP sprites (new parser needed)
- V clutter button opens window
- 275×116 minimum size (fixed for TASK 2)

**Milkdrop Window**:
- NSWindowController pattern (like TASK 1)
- GEN.BMP sprites (reuse existing)
- Options menu checkbox
- Ctrl+Shift+K keyboard shortcut
- Resizable UI deferred

**Audio Tap**:
- Extend EXISTING AudioPlayer tap (not new)
- Single tap shared by spectrum + Milkdrop
- Add 512-bin FFT for Milkdrop
- Add 576-sample waveform

**Presets**:
- butterchurn-presets@3.0.0-beta.4 (NPM)
- 200+ .milk presets available
- Ship 5-8 curated presets
- No separate files needed (bundled in JS)

## Scope (TASK 2)

**In Scope**:
- Video window with VIDEO.BMP skinning
- Milkdrop window with GEN.BMP skinning
- Video playback (AVPlayer)
- Butterchurn visualization
- Magnetic snapping (both windows)
- Persistence (positions/state)
- Options menu integration
- V button integration

**Out of Scope** (TASK 3):
- Window resize (WIDTH+HEIGHT)
- 3-section layout
- Advanced Milkdrop features
- Advanced video features

**Timeline**: 8-10 days
