# Swift Modernization Quick Reference
## TL;DR for Busy Developers

**5-minute read** | **3 pages** | **Just the essentials**

---

## THE VERDICT

### ✅ DO THESE (High Priority)

1. **Fix Image Interpolation** (2-3 hours)
   - Add `.pixelPerfect()` to all sprites
   - **CRITICAL BUG:** Fix WinampVolumeSlider.swift line 28

2. **Add @MainActor** (1 hour)
   - Add to `SpriteMenuItem` class
   - Future-proof for Swift 6

3. **Use NSMenuDelegate** (3 hours)
   - Replace HoverTrackingView with PlaylistMenuDelegate
   - Enables keyboard navigation + VoiceOver

4. **Migrate to @Observable** (10-14 hours)
   - SkinManager first, then AudioPlayer
   - Better performance, modern SwiftUI

### ⚠️ OPTIONAL

5. **Async File Panels** (2 hours)
   - Current callback pattern is fine
   - Only if adding complex file selection

---

## CRITICAL BUG FIX

**Do this RIGHT NOW:**

```swift
// File: WinampVolumeSlider.swift (Line 28)
// WRONG:
Image(nsImage: volumeBg)
    .interpolation(.high)  // ❌ BLURRY!

// RIGHT:
Image(nsImage: volumeBg)
    .interpolation(.none)
    .antialiased(false)    // ✅ SHARP!
```

**Also fix line 151** (same issue)

---

## PHASE 1: QUICK WINS (Day 1-2)

### Step 1: Add Extension (5 min)
File: `SimpleSpriteImage.swift` (after line 106)

```swift
extension Image {
    func pixelPerfect() -> some View {
        self.interpolation(.none).antialiased(false)
    }
}
```

### Step 2: Apply Everywhere (1 hour)
Add `.pixelPerfect()` to these files:
- ✅ SimpleSpriteImage.swift (already has it)
- ❌ SpriteMenuItem.swift line 125
- ❌ PresetsButton.swift line 64
- ❌ SkinnedText.swift line 24
- ❌ PlaylistBitmapText.swift line 39
- ❌ EqGraphView.swift lines 46, 89
- ❌ WinampVolumeSlider.swift lines 28, 151 **CRITICAL**

### Step 3: Add @MainActor (30 min)
File: `SpriteMenuItem.swift` (line 48)

```swift
// BEFORE:
final class SpriteMenuItem: NSMenuItem {

// AFTER:
@MainActor
final class SpriteMenuItem: NSMenuItem {
```

### Step 4: NSMenuDelegate (3 hours)
1. Create `PlaylistMenuDelegate.swift` (copy from code-examples.md)
2. Replace `SpriteMenuItem.swift` (copy from code-examples.md)
3. Update menu creation: `menu.delegate = menuDelegate`

**Test:** Arrow keys highlight menu items ✅

---

## PHASE 2: @OBSERVABLE (Day 3-5)

### Step 1: SkinManager (4 hours)

```swift
// ADD import:
import Observation

// CHANGE:
@MainActor
class SkinManager: ObservableObject {
    @Published var currentSkin: Skin?

// TO:
@Observable
@MainActor
final class SkinManager {
    var currentSkin: Skin?
```

### Step 2: Update Views (2 hours)

```swift
// BEFORE:
@EnvironmentObject var skinManager: SkinManager

// AFTER:
@Environment(SkinManager.self) var skinManager
```

### Step 3: Update App Root (30 min)

```swift
// BEFORE:
@StateObject private var skinManager = SkinManager()
.environmentObject(skinManager)

// AFTER:
@State private var skinManager = SkinManager()
.environment(skinManager)
```

### Step 4: AudioPlayer (6 hours)
Same pattern as SkinManager

### Step 5: Test Everything (2 hours)
```bash
xcodebuild -scheme MacAmp -enableThreadSanitizer YES test
```

---

## BUILD SETTINGS

**Enable Strict Concurrency:**
1. Xcode → Build Settings
2. Search: "concurrency"
3. Set: "Complete"

**Enable Thread Sanitizer:**
1. Edit Scheme → Test → Diagnostics
2. Check: "Thread Sanitizer"

---

## GIT WORKFLOW

```bash
# Create branch
git checkout -b feature/swift-modernization

# Phase 1 commits (4 commits)
git commit -m "feat: Add pixelPerfect extension"
git commit -m "feat: Apply pixel-perfect to all sprites"
git commit -m "feat: Add @MainActor to SpriteMenuItem"
git commit -m "feat: Use NSMenuDelegate for keyboard nav"

# Phase 2 commits (4 commits)
git commit -m "refactor: Migrate SkinManager to @Observable"
git commit -m "refactor: Update views for @Observable SkinManager"
git commit -m "refactor: Migrate AudioPlayer to @Observable"
git commit -m "refactor: Update views for @Observable AudioPlayer"

# Push
git push origin feature/swift-modernization
```

---

## VALIDATION CHECKLIST

### After Phase 1:
- [ ] All sprites sharp (not blurry)
- [ ] Arrow keys navigate menus
- [ ] Enter activates menu items
- [ ] VoiceOver reads menus
- [ ] No Thread Sanitizer errors

### After Phase 2:
- [ ] All windows open correctly
- [ ] Skin switching works
- [ ] Playlist works
- [ ] Equalizer works
- [ ] All tests pass
- [ ] Performance OK (no regressions)

---

## ROLLBACK

If anything breaks:

```bash
# Revert last commit
git revert HEAD

# OR reset entire branch
git reset --hard origin/main
```

---

## FILES TO CHANGE

### Phase 1 (7 files)
1. `SimpleSpriteImage.swift` - Add extension
2. `SpriteMenuItem.swift` - Add @MainActor, apply .pixelPerfect()
3. `PresetsButton.swift` - Apply .pixelPerfect()
4. `SkinnedText.swift` - Apply .pixelPerfect()
5. `PlaylistBitmapText.swift` - Apply .pixelPerfect()
6. `EqGraphView.swift` - Apply .pixelPerfect()
7. `WinampVolumeSlider.swift` - Fix CRITICAL BUG

**NEW FILE:**
8. `PlaylistMenuDelegate.swift` - Create new file

### Phase 2 (20+ files)
1. `SkinManager.swift` - Migrate to @Observable
2. `AudioPlayer.swift` - Migrate to @Observable
3. All views using `@EnvironmentObject` (15+ files)
4. App root (MacAmpApp.swift)
5. Tests (5+ files)

---

## PERFORMANCE TARGETS

| Metric | Before | After | Change |
|--------|--------|-------|--------|
| View Updates | 100% | 80-90% | ✅ 10-20% fewer |
| GPU Load | 100% | 95% | ✅ 5% reduction |
| Keyboard Nav | ❌ None | ✅ Full | ✅ NEW |
| VoiceOver | ❌ Partial | ✅ Full | ✅ NEW |

---

## RISK ASSESSMENT

| Phase | Risk | Mitigation |
|-------|------|------------|
| Phase 1 | Very Low | Easy rollback, visual testing |
| Phase 2 | Medium | Test coverage, atomic commits |

---

## TIME ESTIMATES

**Conservative (testing-heavy):**
- Phase 1: 2 days
- Phase 2: 5 days
- **Total: 7 days**

**Aggressive (minimal testing):**
- Phase 1: 1 day
- Phase 2: 3 days
- **Total: 4 days**

**Recommended:** Conservative approach

---

## GOTCHAS

1. **Don't add @MainActor to NSView subclasses**
   - They're already implicitly @MainActor
   - Only NSMenuItem needs it

2. **Don't use .interpolation(.high) for sprites**
   - Makes pixel art blurry
   - Always use .interpolation(.none)

3. **Test keyboard navigation after NSMenuDelegate**
   - Arrow keys should work
   - Enter should activate

4. **@Observable requires thorough testing**
   - Touches ALL views
   - Test every window/feature

---

## DEPENDENCIES

**Required:**
- macOS 15+ (Sequoia) or macOS 26+ (Tahoe)
- Xcode with Swift 6 support
- Observation framework (built-in)

**Optional:**
- Instruments (for performance testing)
- Thread Sanitizer (for concurrency testing)

---

## SUCCESS DEFINITION

### Phase 1:
✅ All sprites sharp
✅ Keyboard navigation works
✅ No visual regressions

### Phase 2:
✅ @Observable everywhere
✅ All tests pass
✅ Performance same or better

---

## HELP

**Stuck?** Check these docs:

1. **Detailed analysis:** [research.md](./research.md)
2. **Step-by-step plan:** [plan.md](./plan.md)
3. **Copy-paste code:** [code-examples.md](./code-examples.md)
4. **Overview:** [README.md](./README.md)

---

## ONE-LINER SUMMARY

**"Fix blurry sprites, add keyboard navigation, migrate to @Observable - 4-7 days, low risk, high reward."**

---

**Ready?** Start with Phase 1 → Fix the critical interpolation bug NOW!
