# Swift Modernization Recommendations - TODO

**Branch:** `swift-modernization-recommendations` (current) → new Phase 2 branch
**Status:** Phase 1 Complete ✅ | Phase 2 Ready to Start ⏳
**Last Updated:** 2025-10-29 (Post-Q&A session)

---

## 🔄 UPDATES (2025-10-29)

### Critical Corrections
- ⚠️ **@Bindable pattern CORRECTED** - Must be body-scoped (see Step 1 below)
- ✅ **AppSettings confirmed** - `MacAmpApp/Models/AppSettings.swift` (2 properties)
- ✅ **Test coverage known** - SkinManager good, AudioPlayer LIMITED
- ✅ **Commit strategy defined** - Atomic commits per class

### Pre-Phase 2 Requirements (DO FIRST)
- [ ] **Finalize audio tap crash fix**: land `AudioPlayer` tap helper changes & docs
- [ ] **Enable strict concurrency checking** in Xcode Build Settings → "Complete"
- [ ] **Run Thread Sanitizer baseline**: `xcodebuild test -scheme MacAmp -enableThreadSanitizer YES`
- [ ] **Document baseline results** (pass/fail, any warnings)
- [ ] **Commit research docs** (`tasks/swift-modernization-analysis/`) to docs branch
- [ ] **Create Phase 2 branch** from `swift-modernization-recommendations`

---

## ✅ PHASE 1 COMPLETE - Pixel-Perfect Sprite Rendering

### Implementation Checklist - ALL DONE ✅

- [x] Research pixel-perfect rendering requirements
- [x] Find all Image(nsImage:) locations (agent analysis)
- [x] Fix SpriteMenuItem.swift (menu sprites)
- [x] Fix SkinnedText.swift (text rendering)
- [x] Fix EqGraphView.swift (EQ graph, 2 locations)
- [x] Fix PresetsButton.swift (preset button)
- [x] Fix SkinnedBanner.swift (tiled banners)
- [x] Fix double-click gesture order in WinampPlaylistWindow.swift
- [x] Build and test all features
- [x] Commit Phase 1
- [x] Create PR #23
- [x] **PR #23 MERGED** ✅

**Result:** All sprites render pixel-perfect with sharp edges

---

## ⏳ PHASE 2 PENDING - @Observable Migration

### Research Complete ✅

- [x] Gemini research on @Observable stability (STABLE on macOS 15+/26+)
- [x] Agent mapped all @EnvironmentObject usage (28 occurrences, 13 files)
- [x] Identified classes to migrate (4 classes total)
- [x] Discovered @Bindable requirement for two-way bindings

### Implementation Checklist - TO DO

**Step 1: AppSettings Migration (2 hours) - SMALLEST, START HERE**

**File:** `MacAmpApp/Models/AppSettings.swift`

*Class Migration:*
- [ ] Add `import Observation` at top
- [ ] Change `@MainActor class AppSettings: ObservableObject` → `@Observable @MainActor final class AppSettings`
- [ ] Remove `@Published` from `materialIntegration` property
- [ ] Remove `@Published` from `enableLiquidGlass` property
- [ ] Keep `private init()` and singleton pattern unchanged

*App Root Update (MacAmpApp.swift):*
- [ ] Change `@StateObject private var appSettings` → `@State private var appSettings`
- [ ] Change `.environmentObject(appSettings)` → `.environment(appSettings)`

*View Updates - Pattern:*
```swift
// Before
@EnvironmentObject var appSettings: AppSettings

// After (read-only)
@Environment(AppSettings.self) var appSettings

// After (with bindings) - ✅ CORRECTED PATTERN
@Environment(AppSettings.self) private var appSettings
var body: some View {
    @Bindable var settings = appSettings  // Body-scoped!
    Toggle("Enable", isOn: $settings.enableLiquidGlass)
}
```

*Files to Update:*
- [ ] Find all `@EnvironmentObject var appSettings` with: `rg "@EnvironmentObject var appSettings"`
- [ ] Update each file to `@Environment(AppSettings.self)`
- [ ] Add body-scoped `@Bindable` ONLY where Toggle/Picker bindings exist

*Testing:*
- [ ] Build succeeds
- [ ] Preferences window opens
- [ ] Material integration picker works
- [ ] Liquid Glass toggle works
- [ ] Settings persist across app restarts
- [ ] **Commit:** "refactor: Migrate AppSettings to @Observable"

**Step 2: DockingController Migration (20 min)**
- [ ] Add `import Observation` to DockingController.swift
- [ ] Change to `@Observable class DockingController`
- [ ] Remove `@Published` from 1 property
- [ ] Update WinampMainWindow.swift (1 occurrence)
- [ ] Update UnifiedDockView.swift (1 occurrence)
- [ ] Build and test docking features
- [ ] Commit DockingController migration

**Step 3: SkinManager Migration (45 min)**
- [ ] Add `import Observation` to SkinManager.swift
- [ ] Change to `@Observable class SkinManager`
- [ ] Remove `@Published` from 4 properties
- [ ] Update 13 view files with @Environment(SkinManager.self)
- [ ] Check for @Bindable needs (if any skin selection UI)
- [ ] Build and test skin loading/switching
- [ ] Verify all sprites render correctly
- [ ] Commit SkinManager migration

**Step 4: AudioPlayer Migration (4-5 hours) - HIGHEST RISK ⚠️**

**⚠️ WARNING:** AudioPlayer has LIMITED test coverage (only stop/eject state transitions).
**Strategy:** EXHAUSTIVE manual testing required.

**File:** `MacAmpApp/Audio/AudioPlayer.swift`

*Class Migration:*
- [ ] Add `import Observation` at top
- [ ] Change `@MainActor class AudioPlayer: ObservableObject` → `@Observable @MainActor final class AudioPlayer`
- [ ] Remove `@Published` from ~28 properties (playlist, state, volume, eqBands, etc.)
- [ ] Add `@ObservationIgnored` to private engine properties:
  - [ ] `@ObservationIgnored private let audioEngine`
  - [ ] `@ObservationIgnored private let playerNode`
  - [ ] `@ObservationIgnored private let eqNode`
  - [ ] `@ObservationIgnored private var audioFile`
  - [ ] `@ObservationIgnored private var progressTimer`

*View Updates:*
- [ ] Find all `@EnvironmentObject var audioPlayer` with: `rg "@EnvironmentObject var audioPlayer"`
- [ ] Update to `@Environment(AudioPlayer.self)`
- [ ] Check for @Bindable needs (volume sliders, EQ bands)

*EXHAUSTIVE Testing (NO TEST COVERAGE):*
- [ ] **Playback:** Play, Pause, Stop, Resume
- [ ] **Track Navigation:** Next, Previous, Jump to track
- [ ] **Playlist:** Add files, Remove selected, Clear, Shuffle
- [ ] **Volume:** Volume slider, Balance slider
- [ ] **Equalizer:** Enable/disable, Band adjustments, Presets
- [ ] **Visualizer:** Spectrum/Oscilloscope switching
- [ ] **Time Display:** Current time updates, Duration correct
- [ ] **Repeat Modes:** Off, One, All
- [ ] **Shuffle:** Enable/disable, random track order
- [ ] **Multi-select:** Playlist selection state preserved
- [ ] **M3U Import:** Playlist file loading works

*Performance Check:*
- [ ] Large playlist (1000+ tracks) scrolling smooth
- [ ] No audio dropouts during playback
- [ ] EQ changes don't cause glitches

- [ ] **Commit:** "refactor: Migrate AudioPlayer to @Observable"

**Step 5: Final Verification (30 min)**
- [ ] Full app testing (all windows, all features)
- [ ] Performance comparison (before/after)
- [ ] Memory usage check
- [ ] Thread Sanitizer build
- [ ] Create PR #24
- [ ] Merge to main

---

## ⏳ PHASE 3 PENDING - NSMenuDelegate Pattern

### Implementation Checklist - TO DO

**Step 1: Create SpriteMenuDelegate (30 min)**
- [ ] Create new file: `MacAmpApp/Views/Components/SpriteMenuDelegate.swift`
- [ ] Implement `NSMenuDelegate` protocol
- [ ] Implement `menu(_:willHighlight:)` callback
- [ ] Handle sprite state updates

**Step 2: Integrate with Menus (30 min)**
- [ ] Update SpriteMenuItem to work with delegate
- [ ] Remove HoverTrackingView manual hover logic
- [ ] Set delegate on all NSMenu instances
- [ ] Test hover states still work

**Step 3: Add Keyboard Navigation (30 min)**
- [ ] Test Up/Down arrow keys in menus
- [ ] Test Enter key to select
- [ ] Test Escape to dismiss
- [ ] Verify VoiceOver reads menu items

**Step 4: Final Testing (30 min)**
- [ ] All menus navigable with keyboard
- [ ] Mouse hover still works
- [ ] Click actions still work
- [ ] VoiceOver announces items
- [ ] Create PR #25
- [ ] Merge to main

---

## 📋 Documentation Tasks - TO DO

### **For Next Session:**
- [ ] Create `ARCHITECTURE.md` - Modern Swift patterns document
- [ ] Update `BUILDING_RETRO_MACOS_APPS_SKILL.md` with:
  - [ ] Sprite coordinate extraction lesson
  - [ ] NSMenu vs NSHostingMenu comparison
  - [ ] @Observable migration pattern with @Bindable
  - [ ] Gesture order requirement
  - [ ] Keyboard monitor lifecycle
  - [ ] Multi-select Set<Int> pattern
  - [ ] Pixel-perfect rendering requirement
- [ ] Update `plan.md` with Phase 2/3 details
- [ ] Update `state.md` with Phase 1 completion

---

## 🎯 Success Criteria

### Phase 1 (Complete ✅)
- [x] All sprites pixel-perfect
- [x] No blurry rendering
- [x] Crisp, sharp retro aesthetic
- [x] Double-click works

### Phase 2 (Complete ✅)
- [x] All 4 classes migrated to @Observable
- [x] All @EnvironmentObject updated to @Environment
- [x] @Bindable correctly applied
- [x] All features still work
- [x] Performance verified (no regressions)
- [x] Swift 6 strict concurrency enabled
- [x] Zero concurrency warnings/errors

### Phase 3 (Complete ✅)
- [x] Keyboard navigation in menus (arrow keys)
- [x] VoiceOver support ready (delegate pattern)
- [x] Cleaner code (HoverTrackingView → ClickForwardingView)
- [x] Zero Swift 6 warnings (Timer.publish pattern)
- ⚠️ Enter key doesn't work (AppKit limitation, acceptable)

---

## ⏱️ Time Estimates (UPDATED 2025-10-29)

### Pre-Phase 2 Setup
- **30-60 minutes:** Strict concurrency, Thread Sanitizer, docs commit, branch creation

### Phase 2 Implementation
- **AppSettings:** 2 hours (smallest, simple)
- **DockingController:** 2-3 hours (medium)
- **SkinManager:** 3-4 hours (13 files, good tests)
- **AudioPlayer:** 4-5 hours (28 properties, LIMITED tests, exhaustive QA)
- **Final Verification:** 30 minutes
- **Phase 2 Total:** 12-14 hours

### Phase 3 Implementation
- **NSMenuDelegate:** 2-3 hours (delegate creation, integration, testing)

**Total Actual Time:** ~7 hours (Phase 2: 4h + Phase 3: 2h)
**Current Status:** ✅✅✅ ALL 3 PHASES COMPLETE!
**PRs:** #23 (merged), #24 (merged), #25 (open)
**Next:** Merge PR #25 → All planned work complete! 🎉
