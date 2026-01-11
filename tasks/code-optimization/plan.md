# Code Optimization Plan

**Task ID:** code-optimization
**Branch:** code-simplification
**Created:** 2026-01-10
**Status:** Ready for Implementation

---

## Objective

Improve MacAmp code quality by:
1. Eliminating unsafe force unwrap patterns
2. Installing and configuring SwiftLint for automated linting
3. Documenting intentional dead code
4. Establishing code quality gates for future development

---

## Phase 1: Force Unwrap Elimination

### 1.1 SnapUtils.swift Refactoring

**Files:** `MacAmpApp/Models/SnapUtils.swift`
**Lines:** 71-72, 153-154

**Change:**
Replace ternary-with-force-unwrap pattern with `Optional.map`:

```swift
// BEFORE (lines 71-72)
return Point(
    x: (newPos.x == nil ? 0 : newPos.x! - a.x),
    y: (newPos.y == nil ? 0 : newPos.y! - a.y)
)

// AFTER
return Point(
    x: newPos.x.map { $0 - a.x } ?? 0,
    y: newPos.y.map { $0 - a.y } ?? 0
)
```

Apply same pattern to lines 153-154 in `snapWithinDiff`.

**Verification:**
- Build succeeds
- Window snapping still works correctly
- No behavior change

---

### 1.2 AudioPlayer.swift Line 907 Refactoring

**File:** `MacAmpApp/Audio/AudioPlayer.swift`
**Line:** 907

**Change:**
Replace awkward `?.isEmpty == false` with `flatMap`:

```swift
// BEFORE
let finalName = (suggestedName?.isEmpty == false ? suggestedName! : fallbackName)

// AFTER
let finalName = suggestedName.flatMap { $0.isEmpty ? nil : $0 } ?? fallbackName
```

**Verification:**
- EQ preset import still extracts correct names
- Empty names fall back correctly

---

### 1.3 AudioPlayer.swift Line 1178 Analysis

**File:** `MacAmpApp/Audio/AudioPlayer.swift`
**Line:** 1178

**Current:**
```swift
RunLoop.main.add(progressTimer!, forMode: .common)
```

**Required Analysis:**
1. Read surrounding context to understand timer lifecycle
2. Determine if force unwrap is safe (timer guaranteed non-nil)
3. If not safe, wrap in `if let`

**Potential Fix:**
```swift
if let timer = progressTimer {
    RunLoop.main.add(timer, forMode: .common)
}
```

---

### 1.4 AppSettings.swift Line 167-168 Refactoring (Swift 6 Pattern)

**File:** `MacAmpApp/Models/AppSettings.swift`
**Lines:** 167-168

**Change:**
Replace entire function with modern Swift 6 pattern using non-optional `URL.cachesDirectory`:

```swift
// BEFORE
static func fallbackSkinsDirectory(fileManager: FileManager = .default) -> URL {
    let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
    return caches.appendingPathComponent("MacAmp/FallbackSkins", isDirectory: true)
}

// AFTER (Swift 6 Pattern)
static func fallbackSkinsDirectory() -> URL {
    // URL.cachesDirectory is available in macOS 13+ and is non-optional.
    // .appending(component:directoryHint:) is the modern path API.
    URL.cachesDirectory
        .appending(component: "MacAmp/FallbackSkins", directoryHint: .isDirectory)
}
```

**Rationale:**
- `URL.cachesDirectory` is non-optional in macOS 13+ (project targets macOS 15+)
- No force unwrap, no guard, no fatalError needed
- Uses modern `.appending(component:directoryHint:)` API
- Removes unnecessary `fileManager` parameter
- Cleaner, more idiomatic Swift 6 code

---

### 1.5 EqGraphView.swift Line 21 Refactoring

**File:** `MacAmpApp/Views/EqGraphView.swift`
**Line:** 21

**Change:**
Chain optional in existing guard:

```swift
// BEFORE
guard let rep = NSBitmapImageRep(data: image.tiffRepresentation!) else { return [] }

// AFTER
guard let tiffData = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiffData) else {
    return []
}
```

**Verification:**
- EQ graph still renders correctly
- Graceful handling if image format is unsupported

---

## Phase 2: Dead Code Documentation (placeholder.md Approach)

### 2.1 Document fallbackSkinsDirectory

**Decision:** Use centralized `placeholder.md` instead of in-code TODO comments.

**File Created:** `tasks/code-optimization/placeholder.md` ✅

**NO in-code changes** - The function remains as-is without TODO comments.
Documentation is centralized in `placeholder.md` per project conventions.

**Content documented:**
- Function location: `MacAmpApp/Models/AppSettings.swift:167`
- Purpose: Scaffolding for `tasks/default-skin-fallback/` feature
- Status: Intentionally retained, function defined but not called
- Action: Implement when feature activated, or remove if abandoned

---

## Phase 3: SwiftLint Setup

### 3.1 Install SwiftLint

**Command:**
```bash
brew install swiftlint
```

### 3.2 Create Configuration

**File:** `.swiftlint.yml` (project root)

```yaml
# MacAmp SwiftLint Configuration
# See: tasks/code-optimization/research.md for rationale

opt_in_rules:
  - force_unwrapping
  - implicitly_unwrapped_optional
  - legacy_random
  - redundant_nil_coalescing
  - unused_import
  - vertical_whitespace_closing_braces
  - yoda_condition
  - closure_body_length
  - cyclomatic_complexity
  - function_body_length
  - type_body_length
  - weak_delegate
  - unused_closure_parameter
  - redundant_optional_initialization
  - empty_count
  - first_where
  - last_where
  - sorted_first_last
  - contains_over_filter_count
  - contains_over_filter_is_empty
  - flatmap_over_map_reduce

disabled_rules:
  - line_length
  - identifier_name
  - trailing_whitespace

excluded:
  - tmp/
  - .build/
  - tasks/
  - Package.swift

force_unwrapping:
  severity: warning

cyclomatic_complexity:
  warning: 15
  error: 25

function_body_length:
  warning: 60
  error: 100

type_body_length:
  warning: 400
  error: 600

reporter: xcode
```

### 3.3 Run Initial Lint

**Command:**
```bash
swiftlint lint --path MacAmpApp/
```

**Expected:** May find additional issues beyond our manual scan

### 3.4 Fix Any New Violations

Address any additional violations found by SwiftLint.

---

## Phase 4: Pre-commit Hook (.githooks/ - Tracked Directory)

### 4.1 Create Tracked Hooks Directory

**Directory:** `.githooks/`
**File:** `.githooks/pre-commit`

```bash
#!/bin/bash

# SwiftLint pre-commit hook for MacAmp
# Run: git config core.hooksPath .githooks

STAGED_SWIFT_FILES=$(git diff --cached --name-only --diff-filter=ACM | grep '\.swift$')

if [ -n "$STAGED_SWIFT_FILES" ]; then
    echo "🔍 Running SwiftLint on staged files..."

    if ! command -v swiftlint &> /dev/null; then
        echo "⚠️  SwiftLint not installed. Run: brew install swiftlint"
        exit 0  # Don't block commit if SwiftLint not installed
    fi

    swiftlint lint --strict --quiet $STAGED_SWIFT_FILES
    RESULT=$?

    if [ $RESULT -ne 0 ]; then
        echo "❌ SwiftLint found violations. Please fix before committing."
        exit 1
    fi

    echo "✅ SwiftLint passed"
fi

exit 0
```

### 4.2 Setup Commands

```bash
# Create directory and hook
mkdir -p .githooks
# (write pre-commit script)
chmod +x .githooks/pre-commit

# Configure git to use tracked hooks
git config core.hooksPath .githooks
```

### 4.3 README Documentation

Add to project README:
```markdown
## Developer Setup

### Git Hooks
This project uses tracked git hooks in `.githooks/`. After cloning:

\`\`\`bash
git config core.hooksPath .githooks
\`\`\`
```

---

## Phase 5: Verification

### 5.1 Build Verification

```bash
xcodebuild -scheme MacAmpApp -configuration Debug -enableThreadSanitizer YES build
```

**Expected:** Build succeeds with 0 warnings

### 5.2 Test Suite

```bash
xcodebuild test -scheme MacAmpApp -enableThreadSanitizer YES
```

**Expected:** All tests pass

### 5.3 SwiftLint Verification

```bash
swiftlint lint --path MacAmpApp/ --strict
```

**Expected:** 0 violations

### 5.4 Manual Smoke Test

Test affected features:
1. **EQ Graph:** Open equalizer, verify graph renders
2. **Window Snapping:** Drag windows, verify magnetic snapping
3. **EQ Presets:** Import an EQF file, verify name extraction
4. **Audio Playback:** Play a track, verify progress updates

### 5.5 Oracle Review

Have Codex validate the implementation:
```bash
codex "@MacAmpApp/Models/SnapUtils.swift @MacAmpApp/Audio/AudioPlayer.swift @MacAmpApp/Models/AppSettings.swift @MacAmpApp/Views/EqGraphView.swift
Review these changes for:
- Correct Swift optional handling patterns
- No regression in functionality
- Thread safety maintained
- Memory management correct"
```

---

## Phase 6: Commit & Documentation

### 6.1 Commit Changes

```bash
git add -A
git commit -m "refactor: eliminate force unwraps and add SwiftLint

- Replace force unwrap patterns with Optional.map and guard let
- Add SwiftLint configuration for automated code quality
- Document planned fallbackSkinsDirectory function
- Add pre-commit hook for lint enforcement

Files changed:
- MacAmpApp/Models/SnapUtils.swift (2 functions)
- MacAmpApp/Audio/AudioPlayer.swift (2 locations)
- MacAmpApp/Models/AppSettings.swift (1 function + docs)
- MacAmpApp/Views/EqGraphView.swift (1 function)
- .swiftlint.yml (new)
- .git/hooks/pre-commit (new)

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"
```

### 6.2 Update State

Update `state.md` with final metrics.

### 6.3 Mark Task Complete

Move task to `tasks/done/` when verified.

---

## Phase 7: Swift 6 Modernization & Quick Fixes ✅ COMPLETE

### 7.1 Pre-existing Bug Fix
- [x] Fix `EqGraphView.swift:25` - `min(0, width-1)` → `0` (leftmost column intent)

### 7.2 Background File I/O
- [x] Refactor `importEqfPreset` to use `Task.detached` for file I/O
- [x] Add `applyImportedPreset` helper for MainActor state updates

### 7.3 UserDefaults Keys Consolidation
- [x] Add `Keys` enum to `AppSettings` with all UserDefaults keys
- [x] Replace all string literals with `Keys.*` references
- [x] Prevents typos, enables refactoring

### 7.4 Redundant Enum Values
- [x] Remove redundant `= "value"` from `MaterialIntegrationLevel` (3 cases)
- [x] Remove redundant `= "value"` from `TimeDisplayMode` (2 cases)
- [x] Remove redundant `= "value"` from `RepeatMode` (3 cases)

### 7.5 Timer Modernization - EVALUATED
- [x] Analyzed `ContinuousClock` replacement for progress timer
- [x] Decision: Keep `Timer` with `.common` RunLoop mode
- [x] Rationale: Timer ensures updates during scroll/drag, proper tool for job

---

## Phase 8: AudioPlayer Refactoring (REVISED per Oracle Review 2026-01-11)

### Overview

**Status:** Planning Complete - Ready for Implementation
**Oracle Review:** Complete (see research.md §13)
**Recommended Approach:** Option B (EQPresetStore extraction) with incremental follow-up

The Oracle review identified that the original Phase 8 plan was incomplete and underestimated coupling (25+ files depend on AudioPlayer). The revised plan prioritizes low-risk extractions with verification between each step.

### 8.0 Pre-requisites (Quick Fixes - Separate Commits)

**Rationale:** Oracle recommends doing mechanical SwiftLint fixes BEFORE refactoring to reduce diff noise.

#### 8.0.1 AudioPlayer.swift Quick Fixes (Commit 1)
- [ ] Remove leading whitespace (line 1)
- [ ] Use shorthand operator `+=` (line 143)
- [ ] Remove implicit `= nil` initialization (line 319)
- [ ] Replace `let _ =` with `_ =` (lines 647, 797)
- [ ] Replace unused optional binding with `!= nil` (line 1073)
- [ ] Remove extra blank lines (lines 716, 819, 1182)
- [ ] Build verification
- [ ] Commit: "style: Fix SwiftLint violations in AudioPlayer"

#### 8.0.2 SnapUtils.swift Quick Fixes (Commit 2 - if not already done)
- [ ] Verify else-on-same-line fixes from Phase 7
- [ ] Run `swiftlint lint MacAmpApp/Models/SnapUtils.swift`
- [ ] Fix any remaining violations
- [ ] Commit: "style: Fix remaining SwiftLint violations in SnapUtils"

### 8.1 Phase 8a: Extract EQPresetStore (Low Risk)

**Responsibility:** EQ preset persistence and management
**Lines moved:** ~150
**Risk:** Low - isolated functionality, minimal coupling
**Layer:** Mechanism (like AppSettings) - NOT directly accessible by views

#### Architecture Constraints (Oracle Review)
1. **Layer Boundary:** No direct view access to EQPresetStore. Route via AudioPlayer/PlaybackCoordinator only.
2. **Background I/O:** Preserve `Task.detached` for file I/O. Only state updates on @MainActor.
3. **Computed Forwarding:** AudioPlayer exposes computed properties forwarding to EQPresetStore. Existing bindings remain stable.

#### Implementation
- [ ] Create `MacAmpApp/Audio/EQPresetStore.swift`
- [ ] Add `@MainActor @Observable final class EQPresetStore`
- [ ] Move properties:
  - `userPresets: [EQPreset]`
  - `perTrackPresets: [String: EqfPreset]`
  - `presetsFileName`
  - `userPresetDefaultsKey`
- [ ] Move methods:
  - `loadUserPresets()`
  - `persistUserPresets()`
  - `loadPerTrackPresets()`
  - `savePerTrackPresets()`
  - `storeUserPreset(_:)`
  - `importEqfPreset(from:)`
  - `appSupportDirectory()`
  - `presetsFileURL()`
- [ ] Add `eqPresetStore` property to AudioPlayer
- [ ] Update AudioPlayer methods to delegate to store
- [ ] Build verification
- [ ] Test: Save/load presets, import EQF, per-track presets
- [ ] Commit: "refactor: Extract EQPresetStore from AudioPlayer"

### 8.2 Phase 8b: Extract VisualizerPipeline (Medium Risk) - OPTIONAL

**Responsibility:** Audio tap and visualization data
**Lines moved:** ~200-250
**Risk:** Medium - `Unmanaged` pointer lifetime is fragile

#### Prerequisites
- [ ] Complete 8.1 (EQPresetStore)
- [ ] Verify all tests pass
- [ ] Document current tap lifecycle

#### Implementation
- [ ] Create `MacAmpApp/Audio/VisualizerPipeline.swift`
- [ ] Move `VisualizerScratchBuffers` class
- [ ] Move `VisualizerTapContext` struct
- [ ] Move `ButterchurnFrame` struct
- [ ] Move tap installation/removal logic
- [ ] Move visualizer data properties
- [ ] Move `makeVisualizerTapHandler` static method
- [ ] Update AudioPlayer to hold `visualizerPipeline` reference
- [ ] **CRITICAL:** Ensure `Unmanaged` pointer lifetime is preserved
- [ ] Build verification
- [ ] Test: Spectrum analyzer, oscilloscope, Butterchurn
- [ ] Commit: "refactor: Extract VisualizerPipeline from AudioPlayer"

### 8.3 Phase 8c: Extract MetadataLoader (Low Risk)

**Responsibility:** Async track and video metadata loading
**Lines moved:** ~100-150
**Risk:** Low - async-only, no shared mutable state
**Swift 6.2:** Perfect for `@concurrent` attribute

#### Implementation
- [ ] Create `MacAmpApp/Audio/MetadataLoader.swift`
- [ ] Add `nonisolated struct MetadataLoader`
- [ ] Move metadata loading logic from AudioPlayer
- [ ] Mark loading methods as `@concurrent` (Swift 6.2 ready)
- [ ] Build verification
- [ ] Test: Track info display, bitrate/sample rate
- [ ] Commit: "refactor: Extract MetadataLoader from AudioPlayer"

### 8.4 Phase 8d: Extract PlaylistController (Low Risk)

**Responsibility:** Playlist data management, navigation, shuffle
**Lines moved:** ~150-200
**Risk:** Low - pure data manipulation
**Swift 6.2:** Shuffle can use `@concurrent` for large playlists

#### Implementation
- [ ] Create `MacAmpApp/Audio/PlaylistController.swift`
- [ ] Add `@MainActor @Observable final class PlaylistController`
- [ ] Move: playlist array, currentIndex, shuffle/repeat state
- [ ] Move: add/remove/reorder logic, navigation methods
- [ ] Build verification
- [ ] Test: Add tracks, navigate, shuffle, repeat modes
- [ ] Commit: "refactor: Extract PlaylistController from AudioPlayer"

### 8.5 Phase 8e: Extract VideoPlaybackController (Medium Risk)

**Responsibility:** AVPlayer for video playback
**Lines moved:** ~150-200
**Risk:** Medium - AVPlayer observer lifecycle needs care

#### Implementation
- [ ] Create `MacAmpApp/Audio/VideoPlaybackController.swift`
- [ ] Move: videoPlayer, videoEndObserver, videoTimeObserver
- [ ] Move: video-specific playback logic
- [ ] Ensure observer cleanup is correct
- [ ] Build verification
- [ ] Test: Video playback, seek, metadata
- [ ] Commit: "refactor: Extract VideoPlaybackController from AudioPlayer"

### 8.6 Phase 8f: Extract VisualizerPipeline (HIGH Risk) - LAST

**Responsibility:** Audio tap and visualization data
**Lines moved:** ~200-250
**Risk:** HIGH - `Unmanaged` pointer lifetime is critical
**Swift 6.2:** FFT processing can use `@concurrent`

#### Prerequisites
- [ ] Complete 8.1-8.5 (all lower-risk extractions)
- [ ] Verify all tests pass
- [ ] Document current tap lifecycle thoroughly

#### Implementation
- [ ] Create `MacAmpApp/Audio/VisualizerPipeline.swift`
- [ ] Move `VisualizerScratchBuffers` class
- [ ] Move `VisualizerTapContext` struct
- [ ] Move `ButterchurnFrame` struct
- [ ] Move tap installation/removal logic
- [ ] Move visualizer data properties
- [ ] Move `makeVisualizerTapHandler` static method
- [ ] **CRITICAL:** Ensure `Unmanaged` pointer lifetime is preserved
- [ ] Build verification
- [ ] Test: Spectrum analyzer, oscilloscope, Butterchurn
- [ ] Commit: "refactor: Extract VisualizerPipeline from AudioPlayer"

### 8.7 Phase 8g: AudioEngineController - DEFER DECISION

**Status:** Evaluate after 8.6 completion
**Risk:** HIGHEST - core playback, seek guards, engine state

**Key Insight:** AudioEngineController extraction may not be worth the risk. After extracting all other components, AudioPlayer will be ~400-500 lines focused on engine lifecycle. This may be an acceptable "core" size.

**Decision Point:** After Phase 8.6, if AudioPlayer is still >500 lines with complex interdependencies, consider extraction. Otherwise, leave as-is.

### 8.8 Alternative: Extension-Based Organization (Option A)

**Use if:** Full extraction proves too risky

Split AudioPlayer into extensions without behavior change:
```
MacAmpApp/Audio/
├── AudioPlayer.swift              (~200 lines - core)
├── AudioPlayer+Playback.swift     (~400 lines)
├── AudioPlayer+EQ.swift           (~200 lines)
├── AudioPlayer+Visualizer.swift   (~250 lines)
├── AudioPlayer+Playlist.swift     (~200 lines)
├── AudioPlayer+Video.swift        (~200 lines)
└── AudioPlayer+Presets.swift      (~150 lines)
```

**Note:** Option A provides near-zero Swift 6.2 benefit - only use as fallback.

### 8.9 Verification Checklist

After each extraction phase:
- [ ] `xcodebuild -scheme MacAmpApp -configuration Debug build` succeeds
- [ ] `swiftlint lint MacAmpApp/Audio/` shows reduced violations
- [ ] Manual smoke test:
  - [ ] Play/pause/stop local files
  - [ ] EQ on/off, band adjustment
  - [ ] Presets save/load/import
  - [ ] Visualizer updates when playing
  - [ ] Video playback works
  - [ ] Seek/scrub during playback

### 8.10 Decision Log

| Decision | Options | Chosen | Rationale |
|----------|---------|--------|-----------|
| Approach | A (Extensions) / B (EQPresetStore) / C (Full) | **C (Incremental)** | Highest Swift 6.2 reward, managed risk via sequencing |
| Quick fixes | Bundle / Separate | **Separate** | Oracle: reduces diff noise |
| SnapUtils fixes | With Phase 8 / Separate | **Separate** | Unrelated to AudioPlayer |
| Sequencing | Big bang / Incremental | **Incremental** | Risk-ordered: low → medium → high |
| VisualizerPipeline | Early / Late | **Last** | `Unmanaged` pointers are highest risk |
| AudioEngineController | Extract / Keep | **Defer decision** | Evaluate after 8.6; may not be worth risk |
| Swift 6.2 readiness | Now / Later | **Design for it** | Use `@concurrent`-ready patterns |

---

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Behavior regression | Low | Medium | Tests + manual verification |
| Build failure | Very Low | High | Compile-time errors caught immediately |
| Performance impact | Very Low | Low | Optional.map is zero-cost abstraction |
| SwiftLint too strict | Medium | Low | Can adjust config |

---

## Time Estimate

| Phase | Estimated Time | Status |
|-------|----------------|--------|
| Phase 1: Force Unwrap Fixes | 30 minutes | ✅ Complete |
| Phase 2: Dead Code Docs | 5 minutes | ✅ Complete |
| Phase 3: SwiftLint Setup | 15 minutes | ✅ Complete |
| Phase 4: Pre-commit Hook | 10 minutes | ✅ Complete |
| Phase 5: Verification | 20 minutes | ✅ Complete |
| Phase 6: Commit & Docs | 10 minutes | ✅ Complete |
| Phase 7: Swift 6 Modernization | 45 minutes | ✅ Complete |
| Phase 8: AudioPlayer Refactor | 4-6 hours | ⏳ Deferred |
| **Total (Phases 1-7)** | **~135 minutes** | ✅ |

---

## Success Criteria

### Phases 1-7 (Current)
- [x] All 8 force unwraps fixed
- [x] Build succeeds with 0 warnings
- [x] SwiftLint force_unwrapping: 0 violations
- [x] Oracle review passes (9/10)
- [x] Manual smoke test passes
- [x] Pre-existing bug fixed (EqGraphView)
- [x] Swift 6 modernizations applied
- [x] UserDefaults keys consolidated
- [x] Changes committed to `code-simplification` branch

### Phase 8 (Deferred)
- [ ] AudioPlayer.swift < 600 lines
- [ ] All extracted classes have single responsibility
- [ ] SwiftLint violations reduced to < 10
- [ ] All tests pass after refactor
- [ ] API surface maintained for existing callers
