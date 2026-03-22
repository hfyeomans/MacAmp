# AppLog Migration State

**Date:** 2025-12-14
**Status:** Phases 1-3 Complete
**Branch:** codex-review

---

## Summary

Successfully migrated all `print()` and `NSLog()` statements to the unified `AppLog` abstraction across the MacAmp codebase. This migration provides:
- Consistent logging through Apple's OSLog framework
- Automatic `#if DEBUG` guards for debug/info logs
- Error/warning logs that persist in production
- Category-based filtering in Console.app

---

## Files Modified

### Phase 1: AppLogger Infrastructure

| File | Changes |
|------|---------|
| `MacAmpApp/Utilities/AppLogger.swift` | Fixed Swift 6 @autoclosure compatibility issue. Message now evaluated before passing to OSLog to avoid escaping closure error. |

### Phase 2: Full Migration (175 call sites)

| File | Before | After | Notes |
|------|--------|-------|-------|
| `MacAmpApp/Audio/AudioPlayer.swift` | 61 (48 print + 13 NSLog) | 0 | All migrated to `.audio` category |
| `MacAmpApp/ViewModels/SkinManager.swift` | 50 (3 print + 47 NSLog) | 0 | All migrated to `.skin` category |
| `MacAmpApp/ViewModels/WindowCoordinator.swift` | 40 print | 0 | All migrated to `.window` category. Guards removed. |
| `MacAmpApp/Models/Skin.swift` | 11 NSLog | 0 | All migrated to `.skin` category |
| `MacAmpApp/Windows/WinampMilkdropWindowController.swift` | 4 print | 0 | Migrated to `.window` category. Guards removed. |
| `MacAmpApp/Utilities/WindowResizePreviewOverlay.swift` | 2 print | 0 | Migrated to `.window` category |
| `MacAmpApp/Models/ImageSlicing.swift` | 3 print | 0 | Migrated to `.ui` category (error logs) |
| `MacAmpApp/ViewModels/DockingController.swift` | 1 NSLog | 0 | Migrated to `.window` category (error log) |
| `MacAmpApp/Models/SpriteResolver.swift` | 1 NSLog | 0 | Migrated to `.ui` category (warning log) |
| `MacAmpApp/Models/RadioStationLibrary.swift` | 2 print | 0 | Migrated to `.audio` category (error logs) |

### Phase 3: Cleanup

| File | Changes |
|------|---------|
| `MacAmpApp/Models/AppSettings.swift` | Removed `windowDebugLoggingEnabled` property and all related UserDefaults persistence code |

---

## Migration Patterns Applied

### Log Level Mapping

| Original Pattern | AppLog Call |
|------------------|-------------|
| `print("AudioPlayer: ...")` | `AppLog.info(.audio, "...")` |
| `print("DEBUG AudioPlayer: ...")` | `AppLog.debug(.audio, "...")` |
| `print("ERROR: ...")` | `AppLog.error(.category, "...")` |
| `NSLog("...")` (search) | `AppLog.debug(.category, "...")` |
| `NSLog("...")` (success) | `AppLog.info(.category, "...")` |
| `NSLog("...")` (error) | `AppLog.error(.category, "...")` |
| `NSLog("...")` (warning) | `AppLog.warn(.category, "...")` |

### Guard Removal

All `if settings.windowDebugLoggingEnabled { print(...) }` guards were removed. The `#if DEBUG` directive in AppLog handles debug-only logging automatically.

### Emoji Removal

All emoji prefixes were removed from log messages for cleaner output.

---

## Category Usage

| Category | Usage |
|----------|-------|
| `.audio` | AudioPlayer, RadioStationLibrary, video playback |
| `.window` | WindowCoordinator, DockingController, WinampMilkdropWindowController, WindowResizePreviewOverlay |
| `.skin` | SkinManager, Skin |
| `.ui` | ImageSlicing, SpriteResolver |
| `.playback` | (Available for future use) |
| `.general` | (Available for future use) |

---

## Technical Notes

### Swift 6 Compatibility Fix

Original AppLogger had an escaping autoclosure issue:
```swift
// Broken in Swift 6
logger(for: category).debug("\(message(), privacy: .public)")
```

Fixed by evaluating message first:
```swift
// Fixed
let msg = message()
logger(for: category).debug("\(msg, privacy: .public)")
```

### Debug vs Production Behavior

| Level | Debug Build | Production Build |
|-------|-------------|------------------|
| `debug()` | Logs to Console | No-op (compiled out) |
| `info()` | Logs to Console | No-op (compiled out) |
| `warn()` | Logs to Console | Logs to Console |
| `error()` | Logs to Console | Logs to Console |

---

## Verification Checklist

- [x] No `print(` statements remain in MacAmpApp/
- [x] No `NSLog(` statements remain in MacAmpApp/
- [x] No references to `windowDebugLoggingEnabled`
- [x] All `AppLog.` calls use valid categories (161 calls verified via ast-grep)
- [x] Build succeeds with Thread Sanitizer enabled
- [ ] No runtime errors in Console.app

---

## Oracle (Codex) Review Findings

**Issues Found and Fixed:**

1. **`AppLog.warn` used `Logger.notice` instead of `Logger.warning`**
   - Fixed: Now correctly forwards to `logger.warning()` for proper severity in Console.app

2. **3 warn-level messages in AudioPlayer.swift were wrapped in `#if DEBUG`**
   - Fixed: Removed guards so warnings fire in production builds
   - Affected: `scheduleFrom`, `seekToPercent`, `seek` methods

**Oracle Rating:** All files clean after fixes

---

## Files for Review

The following files contain `AppLog` calls and should be verified:

1. `MacAmpApp/Utilities/AppLogger.swift` - The logging abstraction
2. `MacAmpApp/Audio/AudioPlayer.swift` - Audio playback logging
3. `MacAmpApp/ViewModels/SkinManager.swift` - Skin loading logging
4. `MacAmpApp/ViewModels/WindowCoordinator.swift` - Window management logging
5. `MacAmpApp/Models/Skin.swift` - Bundle skin discovery logging
6. `MacAmpApp/Windows/WinampMilkdropWindowController.swift` - Milkdrop window logging
7. `MacAmpApp/Utilities/WindowResizePreviewOverlay.swift` - Resize preview logging
8. `MacAmpApp/Models/ImageSlicing.swift` - Image cropping error logging
9. `MacAmpApp/ViewModels/DockingController.swift` - Docking persistence error logging
10. `MacAmpApp/Models/SpriteResolver.swift` - Sprite resolution warning logging
11. `MacAmpApp/Models/RadioStationLibrary.swift` - Radio station persistence error logging
12. `MacAmpApp/Models/AppSettings.swift` - Removed windowDebugLoggingEnabled
