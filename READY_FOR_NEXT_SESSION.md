# Ready for Next Session - MacAmp Development

**Last Updated:** 2025-10-28
**Current Branch:** `swift-modernization-recommendations`
**Build Status:** ✅ Successful - Phase 1 Complete, Phases 2-3 Pending

---

## 🎯 Current Task: Swift Modernization (3 Phases)

### **Phase 1: Pixel-Perfect Sprite Rendering** ✅ COMPLETE

**Branch:** `swift-modernization-recommendations`
**PR:** #23 (Merged to main)
**Task Folder:** `tasks/swift-modernization-recommendations/`
**Status:** ✅ All sprite rendering now pixel-perfect

**What Was Implemented:**
- Applied `.interpolation(.none) + .antialiased(false)` to 5 components
- Fixed double-click gesture order (must come before single-click)
- All sprites render crisp and sharp (authentic retro aesthetic)

**Files Modified:**
- SpriteMenuItem.swift (menu sprites)
- SkinnedText.swift (text rendering)
- EqGraphView.swift (EQ graph, 2 locations)
- PresetsButton.swift (preset button)
- SkinnedBanner.swift (tiled banners)
- WinampPlaylistWindow.swift (gesture order)

---

### **Phase 2: @Observable Migration** ⏳ NEXT SESSION

**Status:** Research complete, implementation paused
**Complexity:** Medium-High (requires careful @Bindable handling)

**What Needs to Be Done:**
- Migrate 4 classes from ObservableObject to @Observable:
  1. AppSettings (2 properties, 3 files) - Has bindings
  2. DockingController (1 property, 2 files)
  3. SkinManager (4 properties, 13 files)
  4. AudioPlayer (28 properties, 10 files)
- Update 28 @EnvironmentObject → @Environment declarations across 13 files
- Handle @Bindable for views with two-way bindings (Toggle, Picker, etc.)

**Critical Discovery:**
- Views with bindings (e.g., `Toggle(isOn: $settings.property)`) need **@Bindable**
- Pattern: `@Environment(AppSettings.self) + @Bindable var settings`
- This is more complex than just replacing @EnvironmentObject

**Estimated Time:** 2-3 hours for careful implementation + testing

---

### **Phase 3: NSMenuDelegate for Accessibility** ⏳ PENDING

**Status:** Researched, ready after Phase 2
**Benefit:** Keyboard navigation + VoiceOver support
**Complexity:** Medium
**Estimated Time:** 1-2 hours

---

## ✅ This Session's Accomplishments (2025-10-28)

### **PR #20: Playlist Menu System + Multi-Select** ✅ MERGED
- All 5 menu buttons (ADD, REM, SEL, MISC, LIST OPTS)
- Multi-select with Shift+Click, Command+A, Escape/Cmd+D
- REM SEL removes multiple tracks
- CROP keeps only selected tracks
- 17 commits, ~8 hours work

### **PR #21: Playlist Text Rendering Fix** ✅ MERGED
- Replaced bitmap fonts with native SwiftUI Text
- Fixed duplicate highlight bug (current track background)
- Fixed keyboard monitor lifecycle (Cmd+A persists)
- Unicode support enabled
- 1 commit, 45 minutes

### **PR #22: Playlist Sprite Position Fix** ✅ MERGED
- Fixed blue edge on right side of playlist window
- Shifted bottom HStack 2px right
- Perfect sprite alignment
- 1 commit, 20 minutes

### **PR #23: Pixel-Perfect Sprite Rendering** ✅ MERGED
- Applied .interpolation(.none) to all sprite rendering
- Fixed double-click gesture order
- All sprites now crisp and sharp
- 1 commit, Phase 1 of modernization

**Total PRs Merged:** 4 PRs in one session!
**Lines Changed:** ~3,000+ additions/deletions
**Build Output:** Signed app in /Applications/MacAmp.app

---

## 📚 Architecture Patterns Learned This Session

### **1. Sprite Coordinate Extraction** (CRITICAL)
**Issue:** AI hallucinated sprite coordinates causing visual mismatches
**Solution:** Manual verification using Preview Inspector (⌘I)
**Documented:** BUILDING_RETRO_MACOS_APPS_SKILL.md Section 6

**Process:**
1. Open PLEDIT.BMP in Preview
2. Tools → Show Inspector (⌘I)
3. Hover over sprite top-left corner
4. Read (x, y) coordinates
5. Never trust AI - always verify from source

### **2. NSMenu Width Consistency**
**Issue:** SEL menu showed width inconsistency
**Investigation:** Attempted NSHostingMenu migration (macOS 15+)
**Result:** NSHostingMenu has unavoidable AppKit padding (8-12px)
**Decision:** Kept NSMenu pattern (tight width, proven)
**Research:** Fully documented in tasks/playlist-menu-system/

### **3. SwiftUI Gesture Order**
**Issue:** Double-click not firing after single-click gesture added
**Root Cause:** SwiftUI consumes first click of double-click as single-click
**Solution:** Double-click MUST be declared BEFORE single-click
```swift
.onTapGesture(count: 2) { }  // First
.onTapGesture { }            // Second
```

### **4. Pixel-Perfect Rendering**
**Pattern:** All retro sprites need:
```swift
Image(nsImage: sprite)
    .interpolation(.none)    // No GPU blending
    .antialiased(false)      // Sharp edges
    .resizable()
```
**Why:** GPU interpolation blurs pixels (ruins retro aesthetic)

### **5. Keyboard Event Monitor Lifecycle**
**Issue:** NSEvent monitor stopped working after view interactions
**Solution:** Store monitor reference, cleanup in .onDisappear
```swift
@State private var keyboardMonitor: Any?

.onAppear {
    keyboardMonitor = NSEvent.addLocalMonitorForEvents(...)
}
.onDisappear {
    if let m = keyboardMonitor {
        NSEvent.removeMonitor(m)
    }
}
```

### **6. Multi-Select State Management**
**Pattern:** Use Set<Int> for multi-selection
```swift
@State private var selectedIndices: Set<Int> = []

// Normal click: Clear and select
selectedIndices = [index]

// Shift+Click: Toggle
if selectedIndices.contains(index) {
    selectedIndices.remove(index)
} else {
    selectedIndices.insert(index)
}

// Command+A: Select all
selectedIndices = Set(0..<playlist.count)
```

**Removal:** Always iterate in reverse order to maintain indices
```swift
for index in indices.sorted().reversed() {
    playlist.remove(at: index)
}
```

---

## 🏗️ Current Architecture (After Session)

### **State Management:**
- **SkinManager:** ObservableObject with @Published (4 properties)
- **AudioPlayer:** ObservableObject with @Published (28 properties)
- **AppSettings:** ObservableObject with @Published (2 properties)
- **DockingController:** ObservableObject with @Published (1 property)
- **Injection:** @EnvironmentObject throughout all views

**Next:** Migrate to @Observable for better performance

### **Sprite Rendering:**
- **SimpleSpriteImage:** Core component with proper interpolation ✅
- **All Image(nsImage:) calls:** Now have .interpolation(.none) ✅
- **Pixel-perfect:** Sharp, blocky retro aesthetic maintained ✅

### **Menu System:**
- **Pattern:** NSMenu with SpriteMenuItem custom component
- **Hover:** HoverTrackingView with NSTrackingArea
- **Click:** mouseDown() override forwards to NSMenuItem action
- **Width:** Tight, consistent across all menus (no padding issues)

### **Selection:**
- **State:** Set<Int> for multi-track selection
- **Interactions:** Single-click selects, double-click plays, Shift+Click toggles
- **Keyboard:** Command+A (select all), Escape/Cmd+D (deselect all)
- **Actions:** REM SEL, CROP work with multi-selection

---

## 🔄 Next Session: Phase 2 & 3 Implementation

### **Phase 2: @Observable Migration**

**Objective:** Migrate from ObservableObject to @Observable framework

**Classes to Migrate (Priority Order):**
1. AppSettings (2 properties, 3 files) - **Needs @Bindable** for Toggle bindings
2. DockingController (1 property, 2 files)
3. SkinManager (4 properties, 13 files)
4. AudioPlayer (28 properties, 10 files)

**Pattern for Views with Bindings:**
```swift
// Old
@EnvironmentObject var settings: AppSettings
Toggle("Enable", isOn: $settings.property)

// New
@Environment(AppSettings.self) private var appSettings
@Bindable private var settings = appSettings

Toggle("Enable", isOn: $settings.property)
```

**Pattern for Views without Bindings:**
```swift
// Old
@EnvironmentObject var skinManager: SkinManager

// New
@Environment(SkinManager.self) private var skinManager
```

**Files to Update:** 13 view files, 4 class files, 1 app entry point

**Verification Needed:**
- All features still work
- Performance improvement measurable
- No regressions in state updates

**Estimated Time:** 2-3 hours

---

### **Phase 3: NSMenuDelegate for Accessibility**

**Objective:** Add keyboard navigation and VoiceOver support to menus

**Implementation:**
- Create SpriteMenuDelegate conforming to NSMenuDelegate
- Implement `menu(_:willHighlight:)` callback
- Replace HoverTrackingView hover logic with delegate
- Test keyboard navigation (arrow keys in menus)

**Benefits:**
- Keyboard menu navigation (Up/Down arrows)
- VoiceOver compatibility
- Cleaner code (removes manual hover tracking)

**Estimated Time:** 1-2 hours

---

## 📋 Task Documentation Structure

### **tasks/swift-modernization-recommendations/**

**Created This Session:**
- `research.md` - 6 recommendations extracted from AMP_FINDINGS.md
- `plan.md` - [TO UPDATE: Add Phase 2/3 implementation details]
- `state.md` - [TO UPDATE: Phase 1 complete status]
- `todo.md` - [TO UPDATE: Phase 2/3 checklists]

**TODO for Next Session:**
- [ ] Create architecture document (modern Swift patterns from Phase 1)
- [ ] Update BUILDING_RETRO_MACOS_APPS_SKILL.md with session learnings
- [ ] Document @Bindable requirement for @Observable migration
- [ ] Document gesture order requirement
- [ ] Document keyboard monitor lifecycle pattern

---

## 🧪 Testing Checklist (Current Build)

### **All Features Working:** ✅

**Playlist Menus:**
- ADD menu (file pickers work)
- REM menu (remove actions work)
- SEL button (alert)
- MISC menu (alerts)
- LIST OPTS menu (alerts)

**Multi-Select:**
- Single-click: Select only
- Double-click: Play track ✅
- Shift+Click: Toggle selection ✅
- Command+A: Select all ✅
- Escape/Cmd+D: Deselect all ✅
- REM SEL: Remove multiple ✅
- CROP: Keep selected ✅

**Text Rendering:**
- Native text (not bitmap fonts) ✅
- Unicode support ✅
- PLEDIT.txt colors applied ✅
- Current track: White text, no background ✅
- Selected tracks: Colored text, blue background ✅

**Sprite Rendering:**
- All sprites pixel-perfect ✅
- Menu sprites crisp ✅
- EQ graph sharp ✅
- No blurring or anti-aliasing ✅

**Navigation:**
- Next/Previous track buttons ✅
- Auto-advance after track ends ✅
- Double-click any track plays it ✅

---

## 📊 Session Statistics

**Duration:** Extended session (10+ hours cumulative)
**PRs Merged:** 4 (playlist menus, text rendering, sprite fix, interpolation)
**Commits:** 20+ commits across all PRs
**Files Modified:** 20+ files
**Lines Changed:** ~3,200 additions, ~970 deletions
**Features Added:**
- 5 playlist menu buttons
- Multi-select functionality
- Native text rendering
- Pixel-perfect sprite rendering

**Code Quality Improvements:**
- Fixed sprite coordinate issues
- Fixed gesture ordering
- Fixed keyboard monitor lifecycle
- Applied pixel-perfect rendering
- Removed 144 temporary files from repo

---

## 🚀 Build & Distribution

**Current Signed Build:** /Applications/MacAmp.app
- Developer ID signed ✅
- Code signature verified ✅
- Thread Sanitizer enabled builds ✅
- All features tested and working ✅

**Build Process:**
```bash
# Build Release in tmp/
xcodebuild -project MacAmpApp.xcodeproj \
  -scheme MacAmpApp \
  -configuration Release \
  -derivedDataPath tmp/release \
  build

# Output: dist/MacAmp.app (auto-copied and signed)
# Install: cp -R dist/MacAmp.app /Applications/
```

---

## 📝 Quick Start for Next Session

### **Immediate Next Steps:**

**1. Continue Phase 2 - @Observable Migration**
```bash
# Already on swift-modernization-recommendations branch
# Start with AppSettings (smallest class)
```

**2. Follow This Order:**
- AppSettings (implement @Bindable pattern for PreferencesView)
- DockingController
- SkinManager
- AudioPlayer (largest, most complex)

**3. Test Thoroughly After Each Class:**
- Build and run after each migration
- Verify all features still work
- Check performance improvements

**4. Create PR #24 When Phase 2 Complete**

**5. Then Implement Phase 3 (NSMenuDelegate)**

### **Documentation Tasks:**
- [ ] Create `tasks/swift-modernization-recommendations/ARCHITECTURE.md`
- [ ] Update `BUILDING_RETRO_MACOS_APPS_SKILL.md` with all session learnings
- [ ] Document @Bindable pattern for @Observable migration
- [ ] Document all architecture changes

---

## 🎓 Key Learnings This Session

### **Sprite Coordinate Extraction**
**Never trust AI coordinates** - Always verify with Preview Inspector (⌘I)

### **NSMenu vs NSHostingMenu**
**NSHostingMenu** has unavoidable AppKit padding - stick with **NSMenu** for tight layouts

### **@Observable Migration Complexity**
**Not a simple find-replace** - Views with bindings need @Bindable wrapper

### **SwiftUI Gesture Priority**
**Declare gestures in reverse order** - Double-click before single-click

### **Pixel-Perfect Rendering**
**GPU interpolation ruins pixel art** - Always use `.interpolation(.none)`

### **Keyboard Monitor Lifecycle**
**Store reference in @State** - Clean up in .onDisappear or it stops working

### **Multi-Select State**
**Use Set<Int>** - Remove in reverse order to maintain indices

---

## 📖 Complete Task History

### **Completed Tasks:**
1. ✅ Playlist Menu System (tasks/playlist-menu-system/)
2. ✅ Playlist Text Rendering (tasks/playlist-text-rendering-fix/)
3. ✅ Playlist Sprite Position (tasks/playlist-sprite-adjustments/)
4. ⏳ Swift Modernization Phase 1 (tasks/swift-modernization-recommendations/)

### **In Progress:**
- Swift Modernization Phases 2-3

### **Deferred Tasks:**
- M3U export/import (SAVE LIST, LOAD LIST)
- Sort operations (SORT LIST)
- File info dialog (FILE INFO)
- Internet radio streaming (P5)

---

## 🔀 Git Workflow - Sequential PR Strategy

**Branch:** `swift-modernization-recommendations`

**PR Strategy** (Option A - Sequential):
1. PR #23 (Phase 1) ✅ Merged
2. PR #24 (Phase 2) ⏳ Next - After @Observable migration
3. PR #25 (Phase 3) ⏳ Final - After NSMenuDelegate implementation

**After Each Merge:**
```bash
git checkout main
git pull origin main
git checkout swift-modernization-recommendations
git rebase main
# Continue with next phase
```

---

## 📂 Important Files & Folders

**Task Folders:**
- `tasks/playlist-menu-system/` - Menu system documentation
- `tasks/playlist-text-rendering-fix/` - Text rendering docs
- `tasks/playlist-sprite-adjustments/` - Sprite position fix
- `tasks/swift-modernization-recommendations/` - Modernization docs

**Key Files:**
- `BUILDING_RETRO_MACOS_APPS_SKILL.md` - Comprehensive skill guide
- `AMP_FINDINGS.md` - Code review findings (source of modernization tasks)
- `README.md` - Project overview with all features

**Signed Build:**
- `/Applications/MacAmp.app` - Latest signed release

---

## 🎯 Recommended Next Actions

**Option A: Complete Swift Modernization** (3-5 hours)
- Finish Phase 2 (@Observable migration)
- Implement Phase 3 (NSMenuDelegate)
- Create PRs #24 and #25
- Update BUILDING_RETRO_MACOS_APPS_SKILL.md

**Option B: Ship Current Build**
- Phase 1 is valuable on its own
- Build signed release with pixel-perfect sprites
- Defer Phases 2-3 to future session

**Option C: Different Priority**
- Work on other P1/P2 tasks
- Internet radio streaming
- Async audio loading

---

## ⚠️ Known Issues / Notes

**@Observable Migration:**
- Requires @Bindable for views with two-way bindings
- More complex than simple find-replace
- Need to test each class migration carefully

**Performance:**
- Phase 1 (interpolation) improves rendering
- Phase 2 (@Observable) will improve state updates (10-20%)
- All features currently working well

**Repository Cleanup:**
- Added tmp/ and Screenshot* to .gitignore
- Removed 144 temporary files from repo
- Clean professional repository state

---

**Status:** ✅ Phase 1 shipped, Phases 2-3 ready for next session
**Branch:** `swift-modernization-recommendations`
**Next:** Implement @Observable migration with @Bindable pattern
**Context:** All research complete, clear implementation path
