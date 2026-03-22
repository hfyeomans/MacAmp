# AppLog Migration Task List

**Branch:** codex-review
**Started:** 2024-12-14
**Objective:** Migrate from print()/NSLog() to unified AppLog abstraction

---

## Phase 1: Quick Win - Remove Unguarded DEBUG Statements
**Status:** Pending
**Estimated Time:** 30 minutes

- [ ] Add AppLogger.swift to project (currently untracked)
- [ ] Remove/migrate 6 `DEBUG AudioPlayer:` print statements in AudioPlayer.swift
- [ ] Verify build succeeds with Thread Sanitizer
- [ ] Commit Phase 1 changes

---

## Phase 2: Full Migration - Replace All 175 Call Sites
**Status:** Pending
**Estimated Time:** 2-3 hours

### High-Volume Files (Priority Order)

- [ ] **AudioPlayer.swift** (61 calls: 48 print + 13 NSLog)
  - [ ] Migrate print("AudioPlayer: ...") → AppLog.info(.audio, "...")
  - [ ] Migrate print("DEBUG AudioPlayer: ...") → AppLog.debug(.audio, "...")
  - [ ] Migrate print("ERROR: ...") → AppLog.error(.audio, "...")
  - [ ] Migrate NSLog("📺 Video...") → AppLog.debug(.audio, "...")
  - [ ] Remove emoji prefixes

- [ ] **SkinManager.swift** (50 calls: 3 print + 47 NSLog)
  - [ ] Migrate NSLog("🔍 ...") → AppLog.debug(.skin, "...")
  - [ ] Migrate NSLog("✅ ...") → AppLog.info(.skin, "...")
  - [ ] Migrate NSLog("❌ ...") → AppLog.error(.skin, "...")
  - [ ] Migrate NSLog("⚠️ ...") → AppLog.warn(.skin, "...")
  - [ ] Remove emoji prefixes

- [ ] **WindowCoordinator.swift** (40 calls: all print)
  - [ ] Migrate guarded prints → AppLog.debug(.window, "...")
  - [ ] Remove windowDebugLoggingEnabled checks (handled by #if DEBUG)

- [ ] **Skin.swift** (11 calls: all NSLog)
  - [ ] Migrate NSLog("🔍 ...") → AppLog.debug(.skin, "...")
  - [ ] Migrate NSLog("✅ ...") → AppLog.info(.skin, "...")
  - [ ] Migrate NSLog("❌ ...") → AppLog.error(.skin, "...")

### Lower-Volume Files

- [ ] **WinampMilkdropWindowController.swift** (4 print)
  - [ ] Migrate guarded prints → AppLog.debug(.window, "...")
  - [ ] Remove windowDebugLoggingEnabled checks

- [ ] **DockingController.swift** (1 NSLog)
  - [ ] Migrate error logging → AppLog.error(.window, "...")

- [ ] **SpriteResolver.swift** (1 NSLog)
  - [ ] Migrate warning → AppLog.warn(.ui, "...")

- [ ] **ImageSlicing.swift** (3 print)
  - [ ] Migrate → AppLog.debug(.ui, "...")

- [ ] **RadioStationLibrary.swift** (2 print)
  - [ ] Migrate → AppLog.info(.audio, "...")

- [ ] **WindowResizePreviewOverlay.swift** (2 print)
  - [ ] Migrate → AppLog.debug(.window, "...")

### Verification
- [ ] Build succeeds with Thread Sanitizer
- [ ] No print() or NSLog() remaining in MacAmpApp/ (except legitimate cases)
- [ ] Commit Phase 2 changes

---

## Phase 3: Cleanup
**Status:** Pending
**Estimated Time:** 30 minutes

- [ ] Remove `windowDebugLoggingEnabled` from AppSettings.swift
- [ ] Remove all `if settings.windowDebugLoggingEnabled` guards
- [ ] Remove related UserDefaults persistence code
- [ ] Verify no orphaned references to windowDebugLoggingEnabled
- [ ] Final build verification with Thread Sanitizer
- [ ] Commit Phase 3 changes

---

## Final Steps

- [ ] Squash commits or create summary commit
- [ ] Update code_review.md to reflect migration completion
- [ ] Push changes and update PR

---

## Migration Patterns Reference

```swift
// Old → New patterns

// Info-level (normal operation)
print("AudioPlayer: Playing track")     → AppLog.info(.audio, "Playing track")

// Debug-level (development only)
print("DEBUG AudioPlayer: ...")         → AppLog.debug(.audio, "...")
NSLog("🔍 Looking for skin...")         → AppLog.debug(.skin, "Looking for skin...")

// Warnings
NSLog("⚠️ Something unexpected")        → AppLog.warn(.category, "Something unexpected")

// Errors
print("ERROR: Failed to load")          → AppLog.error(.category, "Failed to load")
NSLog("❌ Skin not found")              → AppLog.error(.skin, "Skin not found")

// Guarded prints (guards become unnecessary)
if settings.windowDebugLoggingEnabled {
    print("Window moved")
}
→ AppLog.debug(.window, "Window moved")  // #if DEBUG built-in
```

## Category Mapping

| Current Prefix/Context | AppLog Category |
|------------------------|-----------------|
| AudioPlayer:, audio, EQ | .audio |
| 📺 Video, video | .audio |
| Window, dock, snap | .window |
| 🔍 Skin, 📦, skin loading | .skin |
| Playlist, track, playback | .playback |
| UI, sprite, image | .ui |
| General/uncategorized | .general |
