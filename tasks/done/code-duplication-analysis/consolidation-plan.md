# Consolidation Implementation Plan

## Phase 1: Critical Duplicate Removal (Week 1)

### 1.1 Remove Modern Window Variants
**Target Files to Remove:**
- `MacAmpApp/Views/PlaylistWindowView.swift`
- `MacAmpApp/Views/MainWindowView.swift` 
- `MacAmpApp/Views/EqualizerWindowView.swift`

**Steps:**
1. Verify no external references to these files
2. Check `MacAmpApp.swift` for window declarations
3. Update any import statements
4. Remove files from Xcode project
5. Clean build directory

**Verification:**
- Build succeeds without errors
- All window functionality still works
- No missing symbol errors

### 1.2 Clean Temporary Resources
**Target Directories:**
- `tmp/` (entire directory)
- Build cache directories

**Steps:**
1. Remove all files in `tmp/`
2. Clean Xcode build folder (`Cmd+Shift+K`)
3. Remove `.build/` directory if present
4. Verify skins still accessible from `MacAmpApp/Skins/`

**Expected Space Savings:**
- ~50MB from duplicate skin files
- ~200MB from temporary analysis files

### 1.3 Remove Test Window
**Target File:**
- `MacAmpApp/Views/SimpleTestMainWindow.swift`

**Steps:**
1. Verify no references in production code
2. Move to test directory or delete entirely
3. Update any project references

## Phase 2: Component Consolidation (Week 2)

### 2.1 Slider Consolidation
**Target Files to Remove:**
- `MacAmpApp/Views/VolumeSliderView.swift`
- `MacAmpApp/Views/BalanceSliderView.swift`
- `MacAmpApp/Views/EQSliderView.swift`

**Target Files to Keep:**
- `MacAmpApp/Views/Components/WinampVolumeSlider.swift`
- `MacAmpApp/Views/Components/WinampBalanceSlider.swift`
- `WinampVerticalSlider` (in WinampEqualizerWindow.swift)

**Migration Steps:**
1. Update imports in window files
2. Replace VolumeSliderView with WinampVolumeSlider
3. Replace BalanceSliderView with WinampBalanceSlider
4. Update EQ slider usage to use WinampVerticalSlider
5. Test all slider functionality

**Code Changes Required:**
```swift
// Before
VolumeSliderView(background: volumeBg, thumb: volumeThumb, value: $audioPlayer.volume)

// After  
WinampVolumeSlider(volume: $audioPlayer.volume)
```

### 2.2 Extract Common Window Behaviors
**Create New File:** `MacAmpApp/Views/Components/WindowBehaviors.swift`

**Extract Common Patterns:**
1. Titlebar button component
2. Window dragging gesture
3. Window snap registration
4. Shade mode toggle logic

**Implementation:**
```swift
struct WinampTitlebarButtons: View {
    let onMinimize: () -> Void
    let onShade: () -> Void  
    let onClose: () -> Void
    let isShadeMode: Bool
    // ... implementation
}

struct WindowDragArea: View {
    // ... implementation for WindowDragGesture
}
```

### 2.3 Extract Common Button Patterns
**Create New File:** `MacAmpApp/Views/Components/WinampButton.swift`

**Common Button Features:**
1. Hover effects with scale and shadow
2. Plain button styling
3. Sprite image handling
4. Haptic feedback integration

**Implementation:**
```swift
struct WinampButton: View {
    let spriteName: String
    let size: CGSize
    let action: () -> Void
    let shadowColor: Color?
    let enableHaptics: Bool
    // ... implementation
}
```

## Phase 3: Code Quality Improvements (Week 3)

### 3.1 Remove TODO Comments
**Files with TODOs:**
- `SkinManager.swift`: "TODO: Parse cursors"
- `Skin.swift`: "TODO: Add properties for other skin elements"
- `AudioPlayer.swift`: "TODO: Implement eject logic"
- `WinampEqualizerWindow.swift`: "TODO: Save to user presets", "TODO: Implement .eqf file picker"

**Actions:**
1. Implement cursor parsing in SkinManager or remove TODO
2. Add missing skin properties or remove TODO
3. Implement eject functionality or remove TODO
4. Implement preset saving and .eqf loading or remove TODOs

### 3.2 Remove Deprecated Methods
**Target:** `AudioPlayer.swift`
- Remove `loadTrack(url:)` method
- Update any remaining references
- Add migration guide comment if needed

### 3.3 Clean Legacy Comments
**Target:** `SimpleSpriteImage.swift`
- Remove or update legacy compatibility comment
- Document current behavior clearly

## Phase 4: Testing and Validation (Week 4)

### 4.1 Functionality Testing
**Test Areas:**
1. All window open/close operations
2. Slider interactions (volume, balance, EQ)
3. Window snapping and docking
4. Skin loading and switching
5. Audio playback controls

### 4.2 Performance Testing
**Metrics to Verify:**
1. Build time improvement
2. Binary size reduction
3. Memory usage during runtime
4. Launch time impact

### 4.3 Regression Testing
**Areas to Check:**
1. No broken references after file removal
2. All UI elements still accessible
3. Skin rendering still works correctly
4. Window management still functional

## Implementation Order

### Day 1-2: Critical Removals
1. Backup current state
2. Remove duplicate window files
3. Clean temporary directories
4. Test basic build

### Day 3-4: Slider Migration  
1. Update slider imports
2. Replace slider components
3. Test slider functionality
4. Verify visual appearance

### Day 5-7: Component Extraction
1. Create WindowBehaviors.swift
2. Create WinampButton.swift
3. Update window implementations
4. Test extracted components

### Day 8-10: Code Quality
1. Resolve TODO comments
2. Remove deprecated methods
3. Clean up comments
4. Update documentation

### Day 11-14: Final Testing
1. Comprehensive functionality testing
2. Performance measurement
3. Regression testing
4. Documentation updates

## Risk Mitigation

### High Risk Areas
1. **Window Removal**: May break window declarations
2. **Slider Migration**: May break UI layout
3. **Component Extraction**: May introduce new bugs

### Mitigation Strategies
1. **Incremental Changes**: Make one change at a time
2. **Frequent Testing**: Test after each change
3. **Backup Strategy**: Git commits after each phase
4. **Rollback Plan**: Document how to revert changes

### Success Criteria
1. **Build Success**: Project builds without errors
2. **Functionality**: All features work as before
3. **Performance**: Measurable improvements in build time/size
4. **Maintainability**: Clearer, more maintainable codebase

## Expected Outcomes

### Quantitative Improvements
- **Lines of Code**: -2,000 lines (~10% reduction)
- **Files**: -6 to -8 files
- **Disk Space**: -50MB from duplicate resources
- **Build Time**: 5-10% improvement expected

### Qualitative Improvements
- **Single Source of Truth**: One implementation per major component
- **Consistent Patterns**: Unified approach to similar functionality
- **Easier Maintenance**: Less code to maintain and update
- **Better Onboarding**: Clearer structure for new developers

### Long-term Benefits
- **Reduced Bug Surface**: Fewer duplicate implementations to maintain
- **Faster Development**: Clear patterns to follow for new features
- **Better Testing**: Focused testing on single implementations
- **Cleaner Architecture**: More logical component organization