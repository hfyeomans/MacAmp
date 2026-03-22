# Swift Modernization Recommendations - Implementation Plan

**Objective:** Modernize MacAmp codebase with Swift 6 and macOS 15+/26+ best practices
**Scope:** 3 phases based on 6 recommendations from AMP_FINDINGS.md
**Strategy:** Sequential PRs (Phase 1 → Phase 2 → Phase 3)
**Last Updated:** 2025-10-29 (Post-Q&A session)

---

## 🔄 Updates (2025-10-29)

### Q&A Findings Integrated
- ✅ **@Bindable pattern corrected** - Must use body-scoped @Bindable (see Phase 2)
- ✅ **AppSettings location confirmed** - `MacAmpApp/Models/AppSettings.swift`
- ✅ **Test coverage documented** - SkinManager good, AudioPlayer limited
- ✅ **Commit strategy defined** - Atomic commits per class migration
- ✅ **Strict concurrency** - Enable BEFORE Phase 2 starts

### Commit Strategy (Phase 2)
1. Commit research docs on docs-only branch (separate paper trail)
2. Create fresh Phase 2 branch from `swift-modernization-recommendations`
3. Atomic commits:
   - "refactor: Migrate AppSettings to @Observable"
   - "refactor: Migrate DockingController to @Observable"
   - "refactor: Migrate SkinManager to @Observable"
   - "refactor: Migrate AudioPlayer to @Observable"
4. Single PR with all 4 commits for review

### Pre-Phase 2 Checklist
- [ ] Enable strict concurrency checking (Build Settings → Complete)
- [ ] Run Thread Sanitizer baseline: `xcodebuild test -scheme MacAmp -enableThreadSanitizer YES`
- [ ] Commit research docs to docs branch
- [ ] Create Phase 2 branch

---

## Implementation Strategy

### **Phase 1: Pixel-Perfect Sprite Rendering** ✅ COMPLETE

**Status:** Implemented and merged (PR #23)
**Time:** 1 hour
**Priority:** CRITICAL

**What Was Done:**
- Applied `.interpolation(.none) + .antialiased(false)` to 5 components
- Fixed double-click gesture order
- All sprites now render pixel-perfect

**Files Modified:** 6 files
**Testing:** All features verified working
**Merged:** October 28, 2025

---

### **Phase 2: @Observable Migration** ⏳ NEXT

**Objective:** Migrate from ObservableObject to @Observable framework
**Time:** 2-3 hours
**Priority:** HIGH (performance + modern Swift)
**Complexity:** Medium-High

#### Classes to Migrate (4 total):

**1. AppSettings** (30 min)
- 2 properties: materialIntegration, enableLiquidGlass
- 3 view files affected
- **Special handling:** PreferencesView has Toggle bindings → needs @Bindable

**2. DockingController** (20 min)
- 1 property: panes
- 2 view files affected
- No bindings required

**3. SkinManager** (45 min)
- 4 properties: currentSkin, isLoading, availableSkins, loadingError
- 13 view files affected (most complex)
- Check for any skin selection UI with bindings

**4. AudioPlayer** (1 hour)
- 28 properties (extensive audio state)
- 10 view files affected
- Check for audio control bindings (volume, balance sliders)
- Most critical - test thoroughly

#### Migration Pattern

**For Classes:**
```swift
// 1. Add import
import Observation

// 2. Change class declaration
@Observable class ClassName {  // Remove: ObservableObject
    var property: Type      // Remove: @Published
}
```

**For Views (No Bindings):**
```swift
// Before
@EnvironmentObject var skinManager: SkinManager

// After
@Environment(SkinManager.self) private var skinManager
```

**For Views (With Bindings):**
```swift
// Before
@EnvironmentObject var settings: AppSettings
Toggle("Enable", isOn: $settings.property)

// After - ✅ CORRECTED PATTERN
@Environment(AppSettings.self) private var appSettings

var body: some View {
    @Bindable var settings = appSettings  // ✅ Body-scoped, environment is ready

    Toggle("Enable Liquid Glass", isOn: $settings.enableLiquidGlass)
    Picker("Material", selection: $settings.materialIntegration) { /*...*/ }
}
```

**⚠️ Important:** @Bindable MUST be created inside the body. @Environment values aren't populated at init time.

**For App Entry Point:**
```swift
// Before
@StateObject private var settings = AppSettings.instance()
.environmentObject(settings)

// After
@State private var settings = AppSettings.instance()
.environment(settings)
```

#### Testing After Each Migration:
1. Build with Thread Sanitizer
2. Test affected features
3. Verify state updates still work
4. Check for performance improvements
5. Commit if successful

---

### **Phase 3: NSMenuDelegate for Accessibility** ⏳ PENDING

**Objective:** Add keyboard navigation and VoiceOver support to menus
**Time:** 1-2 hours
**Priority:** MEDIUM (accessibility)
**Complexity:** Medium

#### Implementation Steps:

**Step 1: Create SpriteMenuDelegate** (30 min)
```swift
@MainActor
final class SpriteMenuDelegate: NSObject, NSMenuDelegate {
    func menu(_ menu: NSMenu, willHighlight item: NSMenuItem?) {
        // Update sprite states based on highlight
        for case let sprite as SpriteMenuItem in menu.items {
            sprite.setHighlighted(sprite === item)
        }
    }
}
```

**Step 2: Update SpriteMenuItem** (30 min)
- Add `setHighlighted(_:)` method
- Remove manual HoverTrackingView logic
- Simplify to use delegate-driven state

**Step 3: Integrate with Menus** (30 min)
- Create delegate instance for each menu
- Set `menu.delegate = spriteMenuDelegate`
- Update all 5 menu functions (ADD, REM, MISC, LIST)

**Step 4: Test** (30 min)
- Keyboard navigation (Up/Down arrows)
- Enter key to select
- Escape to dismiss
- VoiceOver announces items
- Mouse hover still works

#### Benefits:
- ✅ Keyboard navigation (accessibility)
- ✅ VoiceOver support (accessibility)
- ✅ Cleaner code (removes HoverTrackingView)
- ✅ More robust menu interaction

---

## Deferred Recommendations

### **Recommendation #2: Async File Panel Pattern**
**Status:** Optional (current pattern works fine)
**Decision:** Skip for now

**Rationale:**
- Current NSOpenPanel callback pattern is idiomatic and working
- SwiftUI `.fileImporter` not suitable for AppKit integration
- Async wrapper adds complexity without clear benefit
- Can revisit if adding complex file selection logic

### **Recommendation #1: @MainActor on AppKit Subclasses**
**Status:** Not needed
**Decision:** Skip

**Rationale:**
- NSView and NSMenuItem already implicitly @MainActor (inherit from NSResponder)
- Adding explicit @MainActor is redundant
- No action needed per Gemini research

### **Recommendation #5: Keyboard Monitor Cleanup**
**Status:** Already implemented in PR #21
**Decision:** Complete ✅

---

## Timeline

**Phase 1:** 1 hour ✅ Complete (October 28)
**Phase 2:** 2-3 hours ⏳ Next session
**Phase 3:** 1-2 hours ⏳ After Phase 2

**Total:** 4-6 hours across 2-3 sessions

---

## Success Metrics

### Phase 1 ✅
- All sprites pixel-perfect
- No blurry rendering
- Authentic retro aesthetic

### Phase 2 (Target)
- 10-20% performance improvement in state updates
- Cleaner, more modern code
- All features still working

### Phase 3 (Target)
- Full keyboard accessibility
- VoiceOver support
- Code simplification

---

**Status:** Phase 1 complete, research done for Phases 2-3
**Next:** Implement @Observable migration with @Bindable
**Branch:** `swift-modernization-recommendations`
