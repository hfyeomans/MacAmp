# Placeholder Documentation - Code Optimization Task

**Task ID:** code-optimization
**Created:** 2026-01-10
**Status:** Active

---

## Purpose

This file documents intentional placeholder/scaffolding code in the MacAmp codebase that is part of planned features. Per project conventions, we use centralized `placeholder.md` files instead of in-code TODO comments.

---

## Active Placeholders

### 1. `fallbackSkinsDirectory` Function

**Location:** `MacAmpApp/Models/AppSettings.swift:167`

**Function:**
```swift
static func fallbackSkinsDirectory() -> URL {
    URL.cachesDirectory
        .appending(component: "MacAmp/FallbackSkins", directoryHint: .isDirectory)
}
```

**Purpose:** Scaffolding for the default skin fallback feature.

**Related Task:** `tasks/default-skin-fallback/`

**Status:** Function defined but not called. Intentionally retained as scaffolding for upcoming feature.

**Action Required:**
- Implement when `default-skin-fallback` task is activated
- Remove this entry when feature is complete
- If feature is abandoned, remove function and this entry

---

### 2. `generateAutoPreset` Function (Auto EQ Analysis)

**Location:** `MacAmpApp/Audio/AudioPlayer.swift:936`

**Function:**
```swift
private func generateAutoPreset(for track: Track) {
    autoEQTask?.cancel()
    autoEQTask = nil
    AppLog.debug(.audio, "AutoEQ: automatic analysis disabled, no preset generated for \(track.title)")
}
```

**Purpose:** Placeholder for automatic audio frequency analysis to generate optimal EQ curves per-track.

**Current Behavior:** Logs "automatic analysis disabled" and does nothing. Per-track preset recall (manual save) works correctly.

**Related Feature:** Auto EQ toggle in Equalizer window

**Status:** Stub - never implemented. Discovered during Phase 8.1 testing (2026-01-11).

**Action Required:**
- Implement FFT-based audio analysis when Auto EQ feature is prioritized
- Could leverage existing visualizer tap infrastructure
- Remove this entry when feature is complete
- If feature is abandoned, remove Auto toggle from UI and clean up dead code

---

### 3. Streaming Audio Volume Control

**Location:** `MacAmpApp/Audio/AudioPlayer.swift` (AVPlayer backend)

**Current Behavior:** Volume slider does not affect playback volume when streaming audio from internet radio stations via AVPlayer backend.

**Root Cause:** AVPlayer uses a separate audio pipeline from AVAudioEngine. The volume control is wired to the AVAudioEngine mixer node, which only affects local file playback.

**Status:** Pre-existing limitation, not caused by Phase 8 refactoring. Discovered during Phase 8.3 testing (2026-01-11).

**Action Required:**
- Implement `AVPlayer.volume` property synchronization with main volume control
- Alternatively, route AVPlayer through AVAudioEngine for unified volume control
- Remove this entry when feature is complete

---

## Placeholder Policy

Per Oracle review and project conventions:

1. **No in-code TODO/FIXME comments** for planned features
2. **All placeholders documented** in task-specific `placeholder.md`
3. **Regular review** of placeholders during task completion
4. **Remove entries** when features are implemented or abandoned

---

## Audit Log

| Date | Action | By |
|------|--------|-----|
| 2026-01-10 | Created placeholder.md, documented `fallbackSkinsDirectory` | Claude |
| 2026-01-11 | Added `generateAutoPreset` Auto EQ stub (discovered in Phase 8.1 testing) | Claude |
| 2026-01-11 | Added streaming volume control limitation (discovered in Phase 8.3 testing) | Claude |
