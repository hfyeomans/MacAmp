# MacAmp Skin Switching - Prioritized Implementation Roadmap

**Created:** 2025-10-11
**Analyzed by:** Gemini AI
**Methodology:** Software Engineering Principles (Risk-First, Incremental Delivery, Fast Feedback)

---

## Executive Summary

Gemini analyzed the implementation plan and recommends a **4-phase approach** that prioritizes risk mitigation and incremental value delivery. The key insight: **prove hot-reloading works first** before investing in UI, as this is the highest-risk unknown.

**Total Estimated Time:** 4.5 hours
**Critical Success Factor:** Phase 1 validates the entire architecture

---

## Part 1: Critical Path Analysis

### Dependency Chain

The implementation has a clear sequential dependency structure:

```
1. Data Structures (Foundation)
   ↓
2. Core Logic (SkinManager)
   ↓
3. UI Components (Menu + Preferences)
   ↓
4. User Interaction (File Import)
```

**Key Dependencies:**
- `SkinMetadata` and `AppSettings` must exist before `SkinManager` can be enhanced
- `SkinManager.availableSkins` must be published before UI can consume it
- `SkinManager.switchToSkin()` must work before any UI can trigger switches
- All core logic must be stable before building the preferences panel

---

## Part 2: Risk Assessment

### Risk Levels by Component

**🔴 HIGHEST RISK: Skin Hot-Reloading**
- **What:** Changing `currentSkin` at runtime and having all views update correctly
- **Why Risky:** Deep SwiftUI integration, potential for memory leaks, visual glitches, crashes
- **Impact:** If this doesn't work, the entire feature fails
- **Mitigation:** Build and test this FIRST in Phase 1

**🟡 MEDIUM RISK: File I/O & Parsing**
- **What:** Scanning directories, copying files, parsing arbitrary .wsz files
- **Why Risky:** File permissions, corrupted archives, unexpected content
- **Impact:** Poor error handling leads to crashes and bad UX
- **Mitigation:** Robust error handling, graceful fallbacks

**🟢 LOW RISK: UI Implementation**
- **What:** Building menu items and preferences panel
- **Why Low Risk:** Standard SwiftUI, straightforward logic
- **Impact:** Minimal - worst case is UI bugs, not data corruption
- **Mitigation:** Standard testing

---

## Part 3: Value-Ordered Prioritization

### Must-Have (Core Value)
1. ✅ Switch between two bundled skins (Winamp.wsz ↔ Internet-Archive.wsz)
2. ✅ Simple UI to trigger the switch (Menu Bar)
3. ✅ Persist user's selection between launches

### High-Value (Polish)
4. ⭐ Remember last skin choice across restarts

### Nice-to-Have (Power User)
5. 🎁 Import custom skins from local files
6. 🎁 Detailed Preferences panel

---

## Part 4: Recommended Implementation Order

## 🔷 Phase 1: The Foundational Slice (Prove the Switch)

**Goal:** Attack highest risk first - prove hot-reloading works

### What to Build

1. **Data Structures** (`Skin.swift`):
   - `SkinMetadata` struct
   - `SkinSource` enum

2. **AppSettings Extensions**:
   - `selectedSkinIdentifier` property
   - `userSkinsDirectory` static property

3. **SkinManager Core**:
   - Add `@Published var availableSkins: [SkinMetadata]`
   - Add `@Published var loadingError: String?`
   - Implement `scanAvailableSkins()` for bundled skins only
   - Implement `switchToSkin(identifier:)`

4. **Debug Hook**:
   - Add temporary button/method to force switch between skins
   - This proves the concept without building full UI

### Rationale

- **Risk Mitigation:** Tackles the highest-risk item (hot-reloading) immediately
- **Fail Fast:** If hot-reload doesn't work, we know before investing in UI
- **Thin Vertical Slice:** Technically complete end-to-end, just without pretty UI
- **Early Validation:** Proves the entire architecture is viable

### Expected Duration
⏱️ **1.5 hours**

### Success Criteria
✅ Trigger skin switch programmatically (debug button)
✅ Entire app UI updates to "Internet Archive" skin
✅ Switch back to "Winamp" skin works
✅ No visual glitches, memory leaks, or crashes
✅ All windows update correctly (Main, EQ, Playlist)

### Testing Strategy
- **Unit Tests:** Validate `SkinMetadata` initialization, path generation
- **Integration Test:** Visual inspection of hot-reload
- **Memory Test:** Profile for leaks during switching

### Risk Mitigation
⚠️ If hot-reload fails, STOP and re-evaluate architecture before proceeding

---

## 🔷 Phase 2: Interactive Menu & Persistence

**Goal:** Deliver first user-facing value with persistence

### What to Build

1. **Menu Commands** (`SkinsCommands.swift`):
   - Create command group for skins
   - Add menu items for each bundled skin
   - Keyboard shortcuts (Cmd+1, Cmd+2)

2. **Integration** (`MacAmpApp.swift`):
   - Add SkinsCommands to CommandGroup

3. **Persistence**:
   - Enhance `SkinManager.init()` to load saved choice
   - Update `switchToSkin()` to save to UserDefaults
   - Implement `loadInitialSkin()` method

### Rationale

- **User Value:** First tangible user-facing feature
- **Builds on Proven Foundation:** Phase 1 validated the mechanism
- **High-Value Addition:** Persistence makes it feel complete
- **Low Risk:** Straightforward SwiftUI + UserDefaults

### Expected Duration
⏱️ **1 hour**

### Success Criteria
✅ "Skins" menu appears in menu bar
✅ Lists both bundled skins correctly
✅ Selecting a skin changes app appearance
✅ Quit and relaunch restores last selected skin
✅ Keyboard shortcuts work

### Testing Strategy
- **UI Tests:** Click every menu item, test keyboard shortcuts
- **Persistence Test:** Set skin A → quit → relaunch → verify A loaded
- **Persistence Test:** Set skin B → quit → relaunch → verify B loaded

---

## 🔷 Phase 3: Custom Skin Import

**Goal:** Enable power users to load their own skins

### What to Build

1. **File Picker** (`SkinManager`):
   - Implement `loadUserSkinFile()` with NSOpenPanel
   - Filter for .wsz files only

2. **Import Logic**:
   - Implement `importAndLoadSkin(from:)` to copy file
   - Add to `availableSkins` array
   - Trigger `switchToSkin()`

3. **Directory Scanning**:
   - Enhance `scanAvailableSkins()` to scan user directory
   - Merge bundled + user skins

4. **Menu Updates** (`SkinsCommands.swift`):
   - Add "Load Custom Skin..." menu item
   - Add "Show Skins Folder" menu item

### Rationale

- **Progressive Enhancement:** Core is stable, now extend it
- **Power User Feature:** Not required for MVP but high value
- **Standalone:** Doesn't alter existing stable functionality
- **Medium Risk:** File I/O, but contained and testable

### Expected Duration
⏱️ **1 hour**

### Success Criteria
✅ "Load Custom Skin..." opens file picker
✅ .wsz filter works correctly
✅ Selected file copied to Application Support
✅ New skin appears in menu
✅ Can activate imported skin
✅ "Show Skins Folder" opens Finder to correct location

### Testing Strategy
- **Happy Path:** Import valid .wsz, verify it works
- **Error Handling:** Try invalid file, corrupted zip
- **Permissions:** Test with file on network drive
- **Directory Creation:** Test when Skins folder doesn't exist

---

## 🔷 Phase 4: The Preferences Panel

**Goal:** Provide rich, discoverable UI for skin management

### What to Build

1. **Preferences View** (`SkinsPreferencesView.swift`):
   - List view showing all available skins
   - Current skin indicator
   - "Import Custom Skin" button
   - "Open Skins Folder" button
   - Error display area

2. **Helper Views**:
   - `SkinRowView` for each skin item
   - Selection indicator
   - Delete button for user skins (optional)

3. **Integration** (`PreferencesView.swift`):
   - Add "Skins" tab to TabView
   - Include SF Symbol icon

### Rationale

- **Polish Layer:** Underlying logic is 100% complete and tested
- **Low Risk:** Pure UI work, no business logic
- **Discoverability:** More intuitive than hunting for menu items
- **Optional:** Could ship without this if time constrained

### Expected Duration
⏱️ **1 hour**

### Success Criteria
✅ "Skins" tab appears in Preferences
✅ Lists all bundled and user skins
✅ Shows current selection clearly
✅ Can switch skins from preferences
✅ Can import custom skins from preferences
✅ State syncs with menu bar (switch in one reflects in other)
✅ Error messages display correctly

### Testing Strategy
- **UI Tests:** Click every button, test every interaction
- **State Sync:** Switch in menu → verify preferences updates
- **State Sync:** Switch in preferences → verify menu updates
- **Visual Regression:** Compare to design mockups

---

## Part 5: Testing Strategy Summary

### Phase-by-Phase Validation

**Phase 1: Foundational**
- Primary: Visual inspection of hot-reload
- Secondary: Memory profiling
- Gate: Must pass before Phase 2

**Phase 2: Interactive**
- Primary: Manual UI testing of menu
- Secondary: Persistence testing (quit/relaunch)
- Gate: Must persist correctly before Phase 3

**Phase 3: Import**
- Primary: Import valid skin successfully
- Secondary: Error handling for invalid files
- Gate: Must handle errors gracefully before Phase 4

**Phase 4: Polish**
- Primary: Full UI/UX testing
- Secondary: State synchronization validation
- Final: Visual regression testing

### Critical Test Cases (All Phases)

1. ✅ Switch between bundled skins
2. ✅ Persistence across restarts
3. ✅ Import custom .wsz file
4. ✅ Handle corrupted .wsz gracefully
5. ✅ Handle missing skin files
6. ✅ Switch time < 500ms (performance)
7. ✅ Memory leak check during multiple switches
8. ✅ All windows update (Main, EQ, Playlist)

---

## Implementation Checklist

### Phase 1: Foundation
- [ ] Create `SkinMetadata` struct in Skin.swift
- [ ] Create `SkinSource` enum in Skin.swift
- [ ] Add `selectedSkinIdentifier` to AppSettings
- [ ] Add `userSkinsDirectory` to AppSettings
- [ ] Add `availableSkins` property to SkinManager
- [ ] Add `loadingError` property to SkinManager
- [ ] Implement `scanAvailableSkins()` (bundled only)
- [ ] Implement `switchToSkin(identifier:)`
- [ ] Add debug button to test switching
- [ ] **GATE: Validate hot-reload works**

### Phase 2: Menu & Persistence
- [ ] Create SkinsCommands.swift file
- [ ] Add menu items for bundled skins
- [ ] Add keyboard shortcuts (Cmd+1, Cmd+2)
- [ ] Integrate into MacAmpApp.swift
- [ ] Implement `loadInitialSkin()` in SkinManager
- [ ] Update `switchToSkin()` to save to UserDefaults
- [ ] Test menu functionality
- [ ] **GATE: Validate persistence works**

### Phase 3: Custom Import
- [ ] Implement `loadUserSkinFile()` with NSOpenPanel
- [ ] Implement `importAndLoadSkin(from:)`
- [ ] Enhance `scanAvailableSkins()` for user directory
- [ ] Add "Load Custom Skin..." menu item
- [ ] Add "Show Skins Folder" menu item
- [ ] Test with valid .wsz file
- [ ] **GATE: Validate import works**

### Phase 4: Preferences
- [ ] Create SkinsPreferencesView.swift
- [ ] Create SkinRowView helper
- [ ] Add to PreferencesView.swift
- [ ] Test all interactions
- [ ] **GATE: Validate UI completeness**

---

## Risk Register

### Phase 1 Risks
| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Hot-reload doesn't work | Medium | Critical | Validate early, have fallback plan |
| Memory leaks during switch | Low | High | Profile with Instruments |
| Views don't update | Low | Critical | Test all window types |

### Phase 2 Risks
| Risk | Likelihood | Impact | Mitigation |
| UserDefaults corruption | Very Low | Medium | Use standard APIs |
| Menu doesn't appear | Very Low | Low | Follow SwiftUI patterns |

### Phase 3 Risks
| Risk | Likelihood | Impact | Mitigation |
| File picker fails | Very Low | Medium | Test permissions |
| Copy operation fails | Low | Medium | Robust error handling |
| Corrupted .wsz crashes app | Medium | High | Try-catch, validation |

### Phase 4 Risks
| Risk | Likelihood | Impact | Mitigation |
| State desync | Low | Medium | Use single source of truth |
| UI layout issues | Medium | Low | Test on different window sizes |

---

## Success Metrics

### Phase 1 Complete When:
- ✅ Can switch skins programmatically
- ✅ All UI updates without glitches
- ✅ No memory leaks detected
- ✅ Switch time < 500ms

### Phase 2 Complete When:
- ✅ Menu appears and works
- ✅ Keyboard shortcuts functional
- ✅ Persistence works across restarts

### Phase 3 Complete When:
- ✅ Can import custom .wsz
- ✅ File copied to correct location
- ✅ Errors handled gracefully

### Phase 4 Complete When:
- ✅ Preferences tab complete
- ✅ All interactions functional
- ✅ State synchronized everywhere

### Feature Complete When:
- ✅ All 4 phases complete
- ✅ All test cases pass
- ✅ Documentation updated
- ✅ No known bugs

---

## Timeline Estimate

| Phase | Duration | Cumulative |
|-------|----------|------------|
| Phase 1: Foundation | 1.5 hours | 1.5 hours |
| Phase 2: Menu & Persistence | 1 hour | 2.5 hours |
| Phase 3: Custom Import | 1 hour | 3.5 hours |
| Phase 4: Preferences | 1 hour | 4.5 hours |
| **Total** | **4.5 hours** | |

**Note:** Times assume no major blockers. Add 20% buffer for unexpected issues.

---

## Rollback Plan

### If Phase 1 Fails (Hot-Reload Doesn't Work)
1. **Option A:** Investigate SwiftUI state propagation issues
2. **Option B:** Implement app restart requirement (less ideal)
3. **Option C:** Use different architecture (e.g., notification-based)

### If Phase 3 Fails (File Import Issues)
1. Fall back to bundled skins only
2. Ship without custom import feature
3. Add in future update when resolved

---

## Conclusion

This phased approach:
- ✅ **Mitigates risk** by validating hot-reload first
- ✅ **Delivers value incrementally** at each phase
- ✅ **Enables fast feedback** with testable slices
- ✅ **Follows dependencies** naturally
- ✅ **Allows early termination** if Phase 1 fails

**Recommendation:** Start with Phase 1 immediately. If hot-reload works, the rest is straightforward SwiftUI development.
