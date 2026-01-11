# Code Optimization Research

**Task ID:** code-optimization
**Branch:** code-simplification
**Date:** 2026-01-10
**Status:** Research Complete

---

## 1. Swift LSP Capabilities Assessment

### Available LSP Operations

| Operation | Use Case for Code Review | Tested |
|-----------|-------------------------|--------|
| `findReferences` | Find dead code (symbols with 0 references) | ✅ |
| `incomingCalls` | Identify over-coupled functions (too many callers) | ✅ |
| `outgoingCalls` | Find functions with too many dependencies | ✅ |
| `hover` | Check type complexity, missing docs | ✅ |
| `documentSymbol` | Audit file structure, find bloated files | ✅ |
| `workspaceSymbol` | Find duplicate/similar symbol names | ✅ |
| `goToDefinition` | Navigate to symbol definitions | ✅ |
| `goToImplementation` | Find protocol implementations | ✅ |
| `prepareCallHierarchy` | Get call hierarchy for functions | ✅ |

### LSP Limitations

LSP is primarily for **navigation**, not analysis. It does NOT provide:
- ❌ Linting / style violations
- ❌ Automatic refactoring actions
- ❌ Code smell detection
- ❌ Complexity metrics
- ❌ "Slop" pattern detection

### LSP Dead Code Detection Example

Using `findReferences` on `AppSettings.swift`:
- `fallbackSkinsDirectory` (line 167) - **0 references found** (potential dead code)
- Verified via ripgrep: Only defined, never called in production code
- However: Referenced in `tasks/default-skin-fallback/` planning docs - intentional scaffolding

---

## 2. Available Code Quality Tools

### Installed & Working

| Tool | Purpose | Status |
|------|---------|--------|
| **Swift LSP** (sourcekit-lsp) | Navigation, dead code detection | ✅ Working |
| **ast-grep (sg)** | Syntax-aware pattern matching | ✅ Working |
| **ripgrep (rg)** | Fast text/regex search | ✅ Working |
| **jq** | JSON processing | ✅ Installed |
| **yq** | YAML/XML processing | ✅ Installed |
| **fd** | Fast file discovery | ✅ Installed |
| **Xcode compiler** | Warnings/errors | ✅ Working |

### Not Installed (Recommended)

| Tool | Purpose | Installation |
|------|---------|--------------|
| **SwiftLint** | Swift linting & style | `brew install swiftlint` |
| **swift-format** | Code formatting | `brew install swift-format` |

### Agent-Based Tools

| Agent | Purpose | Invocation |
|-------|---------|------------|
| `code-simplifier:code-simplifier` | Automated refactoring suggestions | Task tool |
| `swift-macos-ios-engineer` | Expert Swift guidance | Task tool |
| `pr-review-toolkit:code-reviewer` | Code review | Task tool |
| Codex Oracle | Implementation validation | `mcp__codex-cli__codex` |

---

## 3. Current Codebase Quality Metrics

### Compiler Status
```
Compiler Warnings: 0
Compiler Errors: 0
Build Status: ✅ Clean
```

### Anti-Pattern Scan Results

| Pattern | Count | Severity | Notes |
|---------|-------|----------|-------|
| Force unwraps (`!`) | 11 | ⚠️ Medium | 5 fixable, 6 from Apple APIs |
| Force casts (`as!`) | 0 | ✅ None | - |
| Force try (`try!`) | 0 | ✅ None | - |
| Dead code detected | 1 | ⚠️ Low | Planned feature scaffolding |
| Print statements | 0 | ✅ None | Uses AppLog |
| TODOs/FIXMEs | 0 | ✅ None | Clean |

---

## 4. Force Unwrap Analysis

### All Force Unwraps Found (11 total)

#### API-Required (Not Fixable - 6)
These are from Apple's delegate signatures:
```swift
// WKNavigationDelegate methods - Apple's API signature
func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error)
func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error)
```

#### Fixable (5 locations)

| File | Line | Current Pattern | Issue |
|------|------|-----------------|-------|
| `SnapUtils.swift` | 71-72 | `newPos.x == nil ? 0 : newPos.x!` | Ternary with force unwrap |
| `SnapUtils.swift` | 153-154 | `newPos.x == nil ? 0 : newPos.x!` | Ternary with force unwrap |
| `AudioPlayer.swift` | 907 | `suggestedName?.isEmpty == false ? suggestedName!` | Awkward optional check |
| `AudioPlayer.swift` | 1178 | `progressTimer!` | Timer force unwrap |
| `AppSettings.swift` | 168 | `.first!` on directory URLs | Implicit crash |
| `EqGraphView.swift` | 21 | `tiffRepresentation!` | Implicit crash |

---

## 5. Code Simplifier Agent Analysis

### SnapUtils.swift (lines 71-72, 153-154)

**Current:**
```swift
return Point(
    x: (newPos.x == nil ? 0 : newPos.x! - a.x),
    y: (newPos.y == nil ? 0 : newPos.y! - a.y)
)
```

**Simplified:**
```swift
return Point(
    x: newPos.x.map { $0 - a.x } ?? 0,
    y: newPos.y.map { $0 - a.y } ?? 0
)
```

**Rationale:**
- Uses `Optional.map` - idiomatic Swift pattern
- Eliminates force unwrapping
- More concise and expressive
- Pattern `optional.map { transform } ?? default` is standard Swift idiom

---

### AudioPlayer.swift (line 907)

**Current:**
```swift
let finalName = (suggestedName?.isEmpty == false ? suggestedName! : fallbackName)
```

**Simplified:**
```swift
let finalName = suggestedName.flatMap { $0.isEmpty ? nil : $0 } ?? fallbackName
```

**Alternative (more explicit):**
```swift
let finalName: String
if let name = suggestedName, !name.isEmpty {
    finalName = name
} else {
    finalName = fallbackName
}
```

**Rationale:**
- Eliminates force unwrapping
- `flatMap` converts empty strings to `nil` for clean nil-coalescing
- Avoids awkward `?.isEmpty == false` pattern

---

### AppSettings.swift (line 168)

**Current:**
```swift
let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
```

**Simplified:**
```swift
guard let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first else {
    fatalError("Unable to locate caches directory")
}
```

**Rationale:**
- Replaces implicit force unwrap with explicit guard
- Provides meaningful error message
- Makes assumption explicit in code

---

### EqGraphView.swift (line 21)

**Current:**
```swift
guard let rep = NSBitmapImageRep(data: image.tiffRepresentation!) else { return [] }
```

**Simplified:**
```swift
guard let tiffData = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiffData) else {
    return []
}
```

**Rationale:**
- Chains optional handling in single guard
- Eliminates force unwrap
- Graceful degradation if `tiffRepresentation` returns nil

---

### AudioPlayer.swift (line 1178)

**Current:**
```swift
RunLoop.main.add(progressTimer!, forMode: .common)
```

**Analysis Needed:**
- Need to check context - is timer guaranteed non-nil at this point?
- May need guard let or if let wrapping

---

## 6. Dead Code Analysis

### Confirmed Unused: `fallbackSkinsDirectory`

**Location:** `MacAmpApp/Models/AppSettings.swift:167`

**Evidence:**
- LSP `findReferences`: 0 references
- ripgrep: Only definition found, no calls
- Referenced in task planning docs: `tasks/default-skin-fallback/`

**Recommendation:**
- **Keep for now** - Part of planned feature
- Add `// MARK: - Planned Feature: Default Skin Fallback` comment
- Re-evaluate if `default-skin-fallback` task is abandoned

---

## 7. Recommended SwiftLint Configuration

```yaml
# .swiftlint.yml - Recommended for MacAmp

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
  - line_length  # Often too strict for SwiftUI
  - identifier_name  # Winamp conventions differ

excluded:
  - tmp/
  - .build/
  - tasks/

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
```

---

## 8. Pattern Detection Commands

### Force Unwrap Detection
```bash
rg --type swift '\w+!' MacAmpApp/ -n | grep -v '//' | grep -v 'import' | grep -v '@objc'
```

### Unused Symbol Detection (LSP)
```bash
# Via Claude Code LSP tool
LSP findReferences on each documentSymbol
# If 0 references -> potential dead code
```

### Complex Function Detection (ast-grep)
```bash
# Functions with many parameters
sg --lang swift -p 'func $NAME($A, $B, $C, $D, $E, $$$) { $$$ }'

# Nested closures (complexity smell)
sg --lang swift -p '{ $$$ { $$$ { $$$ } $$$ } $$$ }'
```

### Retain Cycle Risk Detection
```bash
# Closures capturing self without weak
rg --type swift '\{ [^}]*\bself\.' MacAmpApp/ | grep -v '\[weak self\]'
```

---

## 9. Key Findings Summary

### Strengths
1. **Zero compiler warnings** - Clean build
2. **No force casts or force try** - Good optional handling culture
3. **No debug print statements** - Proper logging via AppLog
4. **Clean TODO/FIXME status** - No technical debt markers

### Areas for Improvement
1. **5 fixable force unwraps** - Should use safer patterns
2. **SwiftLint not installed** - Missing automated linting
3. **No formal code style enforcement** - Manual review only
4. **1 dead code function** - Needs documentation or removal

### Quick Wins
1. Apply 5 force unwrap fixes (30 min)
2. Install SwiftLint (5 min)
3. Create `.swiftlint.yml` config (10 min)
4. Add pre-commit hook for linting (15 min)

---

## 10. References

- [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)
- [SwiftLint Rules](https://realm.github.io/SwiftLint/rule-directory.html)
- [ast-grep Swift Patterns](https://ast-grep.github.io/catalog/swift/)
- Project docs: `docs/IMPLEMENTATION_PATTERNS.md`
- Project docs: `docs/MACAMP_ARCHITECTURE_GUIDE.md`

---

## 11. SwiftLint Pre-Existing Violations

**Discovered:** 2026-01-10
**Source:** Pre-commit hook on initial commit
**Original Total:** 40 violations (in 4 staged files)
**After Phase 7 Fixes:** ~22 remaining (deferred architectural)

### Summary by File

| File | Original | Fixed | Remaining |
|------|----------|-------|-----------|
| `AudioPlayer.swift` | 21 | 5 | 16 (architectural - Phase 8) |
| `AppSettings.swift` | 10 | 10 | **0** ✅ |
| `SnapUtils.swift` | 8 | 8 | **0** ✅ |
| `EqGraphView.swift` | 1 | 0 | 1 (closure length - acceptable) |

### AudioPlayer.swift (21 violations - Deferred)

#### Critical / High Priority (Deferred to Phase 8)

| Line | Rule | Description | Status |
|------|------|-------------|--------|
| 1:1 | `leading_whitespace` | File contains leading whitespace | Deferred |
| 223:7 | `type_body_length` | Class spans 1178 lines (limit: 600) | Deferred |
| 1:1 | `file_length` | File contains 1801 lines (limit: 1000) | Deferred |
| 1219:32 | `function_body_length` | Function spans 107 lines (limit: 100) | Deferred |
| 1405:5 | `function_body_length` | Function spans 61 lines (limit: 60) | Deferred |

#### Closure Body Length (3) - Deferred

| Line | Description |
|------|-------------|
| 1223:9 | Closure spans 105 lines (limit: 50) |
| 1243:38 | Closure spans 62 lines (limit: 50) |
| 1268:38 | Closure spans 37 lines (limit: 30) |

#### Code Style (10) - Deferred

| Line | Rule | Description |
|------|------|-------------|
| 143:13 | `shorthand_operator` | Use `+=` instead of `x = x + y` |
| 319:9 | `implicit_optional_initialization` | Optional initialized with `= nil` |
| 647:13 | `redundant_discardable_let` | Use `_ = foo()` not `let _ = foo()` |
| 797:9 | `redundant_discardable_let` | Use `_ = foo()` not `let _ = foo()` |
| 1073:19 | `unused_optional_binding` | Use `!= nil` over `let _ =` |
| 716:1 | `vertical_whitespace` | Extra blank line (2 lines, limit 1) |
| 819:5 | `vertical_whitespace` | Extra blank lines (3 lines, limit 1) |
| 1182:1 | `vertical_whitespace` | Extra blank line (2 lines, limit 1) |

### AppSettings.swift (10 violations) - ✅ ALL FIXED

#### Redundant String Enum Values (9) - ✅ FIXED

All enums had explicit string values matching case names. Fixed by removing redundant values.

#### Whitespace (1) - ✅ FIXED

| Line | Rule | Description | Status |
|------|------|-------------|--------|
| 345:1 | `vertical_whitespace_closing_braces` | Empty line before closing `}` | ✅ Fixed |

### SnapUtils.swift (8 violations) - ✅ ALL FIXED

#### Statement Position (8) - ✅ FIXED

All `else` statements moved to same line as closing `}`. Reformatted to multi-line style:

```swift
// Before
if condition { x = value }
else if condition { x = other }

// After
if condition {
    x = value
} else if condition {
    x = other
}
```

| Lines | Status |
|-------|--------|
| 53-56 (snap function, X axis) | ✅ Fixed |
| 60-63 (snap function, Y axis) | ✅ Fixed |
| 104-107 (snapWithin function) | ✅ Fixed |

### EqGraphView.swift (1 violation) - Acceptable

| Line | Rule | Description |
|------|------|-------------|
| 46:40 | `closure_body_length` | Canvas closure spans 43 lines (limit: 30) |

**Note:** This is a SwiftUI Canvas closure with drawing code. Extracting would reduce readability. Consider raising threshold or disabling for Canvas closures.

---

## 12. Swift 6 Modernization Opportunities

### Implemented ✅

1. **File I/O off main thread** - `importEqfPreset` now uses `Task.detached`
2. **UserDefaults keys consolidation** - Added `Keys` enum to prevent typos
3. **Redundant enum values** - Removed from 3 enums

### Evaluated and Deferred

1. **ContinuousClock for timer** - Evaluated, Timer with .common RunLoop mode is appropriate for progress updates during scroll/drag. Not a clear win.

### Future Opportunities (Phase 8)

1. **AudioPlayer.swift refactoring** - Split into:
   - `AudioEngineController` (AVAudioEngine + nodes)
   - `EQPresetStore` (persistence)
   - `VisualizerPipeline` (tap + smoothing)
   - `PlaybackState` (observable state)

---

## 13. Phase 8 Oracle Review (2026-01-11)

**Oracle Model:** gpt-5.2-codex
**Reasoning Effort:** xhigh (high)
**File Analyzed:** `MacAmpApp/Audio/AudioPlayer.swift` (1,810 lines)

### 13.1 Oracle Findings Summary

The Oracle review identifies **significant gaps** in the Phase 8 plan. While the proposed extraction strategy is directionally correct, it:

1. **Misses major responsibilities** (playlist management, video playback, metadata loading)
2. **Underestimates coupling** (25+ files depend on AudioPlayer)
3. **Has high-risk areas** (visualizer tap lifetime, seek re-entrancy guards)

### 13.2 Key Findings by Priority

#### HIGH Priority Issues

| Issue | Location | Risk |
|-------|----------|------|
| Incomplete decomposition - plan misses playlist/video/metadata | Lines 369, 587, 638, 1658 | Refactor leaves large coupled class |
| Visualizer tap uses `Unmanaged` pointers across actor boundaries | Lines 1342, 1362 | Crashes or UI stalls if lifetime broken |

#### MEDIUM Priority Issues

| Issue | Location | Risk |
|-------|----------|------|
| SwiftUI views bind directly to AudioPlayer properties | WinampMainWindow:360, VisualizerOptions:23 | UI breaks without forwarding |
| PlaybackCoordinator relies on API surface + PlaylistAdvanceAction | AudioPlayer:1659, PlaybackCoordinator:173 | Stream/local routing breaks |

#### LOW Priority Issues

| Issue | Location | Risk |
|-------|----------|------|
| SwiftLint fixes are mechanical, unrelated to behavior | Lines 1, 647, 1073 | Bundling increases diff noise |

### 13.3 Dependency Analysis

AudioPlayer is referenced by **25+ files** across the codebase:

**Core Infrastructure:**
- `MacAmpApp.swift:6,16` - App bootstrap
- `WindowCoordinator.swift:108` - Window coordination
- `PlaybackCoordinator.swift:37,75,173,228` - Playback routing

**Window Controllers:**
- `WinampMainWindowController.swift:6`
- `WinampEqualizerWindowController.swift:6`
- `WinampPlaylistWindowController.swift:6`
- `WinampVideoWindowController.swift:6`
- `WinampMilkdropWindowController.swift:12`

**Views (Direct Property Binding):**
- `WinampMainWindow.swift:360,870` - Playback state
- `WinampPlaylistWindow.swift:35` - Playlist
- `WinampEqualizerWindow.swift:55,195` - EQ controls
- `VisualizerView.swift:91` - Visualization data
- `VisualizerOptions.swift:23` - Visualizer settings
- `WinampVideoWindow.swift:19` - Video player
- `EqGraphView.swift:57` - EQ curve
- `PresetsButton.swift:79` - Preset management
- `TrackInfoView.swift:18` - Track metadata

**Butterchurn Integration:**
- `ButterchurnBridge.swift:41,139,165` - Audio data feed

### 13.4 Risk Analysis

**Highest Risk Areas:**

1. **Seek Re-entrancy Guards** (Lines 355, 1608, 1414)
   - Complex state machine: `currentSeekID`, `seekGuardActive`, `isHandlingCompletion`
   - Refactoring can easily reintroduce double-completions or stuck state

2. **Visualizer Tap Lifetime** (Lines 1342, 1375)
   - `Unmanaged.passUnretained(self)` creates raw pointer
   - Changing ownership risks use-after-free or tap not removed

3. **Video/Audio Switching** (Lines 505, 587)
   - Requires strict cleanup ordering
   - Moving pieces risks stale observers or incorrect `currentMediaType`

4. **UI Observation**
   - All views depend on `@Observable` property changes
   - Extracted types must preserve change notifications

### 13.5 Phase 8 Approach Options

#### Option A: Extension-Based Organization (Zero Risk)

Split AudioPlayer into logical extensions without moving code:

```
MacAmpApp/Audio/
├── AudioPlayer.swift              (~200 lines - core + init)
├── AudioPlayer+Playback.swift     (~400 lines - play/pause/stop/seek)
├── AudioPlayer+EQ.swift           (~200 lines - equalizer)
├── AudioPlayer+Visualizer.swift   (~250 lines - tap + data)
├── AudioPlayer+Playlist.swift     (~200 lines - navigation)
├── AudioPlayer+Video.swift        (~200 lines - AVPlayer)
└── AudioPlayer+Presets.swift      (~150 lines - persistence)
```

**Pros:** Zero behavior change, immediate readability improvement
**Cons:** No reduction in coupling, still one large type
**Effort:** ~1 hour

#### Option B: Extract EQPresetStore Only (Low Risk)

Extract the clearest single-responsibility violation:

```swift
// New file: MacAmpApp/Audio/EQPresetStore.swift
@MainActor
@Observable
final class EQPresetStore {
    var userPresets: [EQPreset] = []
    var perTrackPresets: [String: EqfPreset] = [:]

    func loadUserPresets() { ... }
    func persistUserPresets() { ... }
    func loadPerTrackPresets() { ... }
    func savePerTrackPresets() { ... }
    func storeUserPreset(_ preset: EQPreset) { ... }
    func importEqfPreset(from url: URL) { ... }
}
```

AudioPlayer keeps `eqPresetStore` reference and delegates.

**Pros:** Clear SRP win, low coupling, easy to test
**Cons:** Only ~150 lines extracted
**Effort:** ~2 hours

#### Option C: Full Extraction (High Risk, High Reward)

Expand Phase 8 to include all responsibilities:

1. `AudioEngineController` - AVAudioEngine, nodes, connections
2. `EQPresetStore` - Preset persistence
3. `VisualizerPipeline` - Tap, FFT, data delivery
4. `PlaylistController` - Track management, navigation
5. `VideoPlaybackController` - AVPlayer for video
6. `MetadataLoader` - Async track/video metadata

AudioPlayer becomes a thin facade coordinating these components.

**Pros:** Full decomposition, testable components
**Cons:** High risk, extensive testing required, ~6-8 hours
**Effort:** 6-8 hours

### 13.6 Swift 6.0/6.2 Considerations

**Extension Approach (Option A):**
- Compatible with Swift 6 but doesn't leverage new patterns
- No improvement in testability or actor isolation
- Good for immediate organization but technical debt remains

**EQPresetStore Extraction (Option B):**
- Aligns with Swift 6 `@Observable` pattern
- Can be made `Sendable` for background persistence
- Fits MacAmp's three-layer architecture (mechanism layer)
- Enables unit testing of preset logic

**Full Extraction (Option C):**
- Best long-term architecture for Swift 6 strict concurrency
- Each component can have appropriate actor isolation
- VisualizerPipeline could use `@preconcurrency` for tap callbacks
- Matches Apple's modern framework patterns (separation of concerns)

### 13.7 Quick Fixes (Separate Commit)

**SwiftLint violations in AudioPlayer.swift (do before refactor):**

| Line | Rule | Fix |
|------|------|-----|
| 1 | `leading_whitespace` | Remove leading blank line |
| 143 | `shorthand_operator` | Use `+=` |
| 319 | `implicit_optional_initialization` | Remove `= nil` |
| 647, 797 | `redundant_discardable_let` | Use `_ = foo()` |
| 1073 | `unused_optional_binding` | Use `!= nil` |
| 716, 819, 1182 | `vertical_whitespace` | Remove extra blank lines |

**SnapUtils.swift else-on-same-line fixes:** Also separate commit.

### 13.8 Recommended Sequencing

1. **Pre-refactor:** Quick fixes (separate commit)
2. **Pre-refactor:** SnapUtils fixes (separate commit)
3. **Phase 8a:** Extract EQPresetStore (low risk)
4. **Verify:** Build + manual smoke test
5. **Phase 8b:** Extract VisualizerPipeline (medium risk)
6. **Verify:** Build + visualizer test
7. **Phase 8c:** Extract AudioEngineController (high risk)
8. **Verify:** Full playback regression test
9. **Phase 8d (optional):** PlaylistController, VideoPlaybackController

### 13.9 Testing Strategy

**Core Playback:**
- Local file: play/pause/stop/seek
- End-of-track auto-advance
- Repeat modes: off/all/one
- Shuffle mode
- Scrub while playing

**Playlist:**
- Add/remove/reorder tracks
- Empty playlist behavior
- Stream handoff to PlaybackCoordinator

**EQ/Presets:**
- Toggle EQ on/off
- Adjust bands/preamp
- Save/load user presets
- Per-track auto presets
- Import EQF file

**Visualizer:**
- Spectrum updates when playing
- Oscilloscope updates when playing
- Freeze when stopped
- Butterchurn frame feed

**Video:**
- Play video file
- Switch audio <-> video
- Metadata string updates
- Cleanup on stop/eject

### 13.10 Architecture Review (Oracle, 2026-01-11)

Second Oracle review validating Phase 8 plan against `docs/MACAMP_ARCHITECTURE_GUIDE.md` and `docs/IMPLEMENTATION_PATTERNS.md`.

**Model:** gpt-5.2-codex (high reasoning)

**Validation Results:**

| Question | Answer |
|----------|--------|
| Does Phase 8 align with three-layer architecture? | ✅ Yes, if extracted classes remain Mechanism layer |
| Does EQPresetStore follow IMPLEMENTATION_PATTERNS? | ✅ Mostly - ensure computed forwarding |
| Any architecture concerns? | ⚠️ Layer-boundary leakage, main-thread I/O |
| Which layer for EQPresetStore? | **Mechanism layer** (like AppSettings) |

**Findings:**

1. **Layer Boundary Protection (Medium):** EQPresetStore must NOT be accessed directly by views. Access via AudioPlayer/PlaybackCoordinator only. This maintains the "No Skip" rule (Presentation → Bridge → Mechanism).

2. **Background I/O Preservation (Medium):** EQPresetStore methods that do file I/O must preserve background execution. Only state updates should be on @MainActor.

3. **Single Source of Truth (Low):** Use computed forwarding on AudioPlayer to avoid duplicate state. Existing bindings remain stable.

**Open Question:**
- Inject EQPresetStore via Environment or keep private behind AudioPlayer?
- **Decision:** Keep private behind AudioPlayer (maintains layer boundary)

**Final Recommendations:**
1. Add explicit note: "no direct view access to EQPresetStore; route via AudioPlayer/PlaybackCoordinator"
2. Preserve background I/O for preset load/import, with MainActor updates only
3. Add computed forwarding on AudioPlayer to keep existing bindings stable

### 13.11 Deep Evaluation: Swift 6.0/6.2 Trade-off Analysis

**Evaluation Date:** 2026-01-11
**Swift Version Context:** Swift 6.0 (current), Swift 6.2 (macOS 26 Tahoe)

---

#### Swift 6.2 Key Features for This Analysis

From Xcode 26 documentation (`Swift-Concurrency-Updates.md`):

| Feature | Description | Relevance |
|---------|-------------|-----------|
| `@concurrent` | Explicitly offload work to background thread pool | High - FFT, file I/O |
| Isolated conformances | `extension Type: @MainActor Protocol` | Medium - protocol conformances |
| Default MainActor inference | Opt-in mode for app targets | High - reduces annotations |
| Approachable concurrency | Async functions run on caller's actor by default | High - simplifies async code |

---

#### Option A: Extensions Only

**What it does:** Split AudioPlayer into 7 files using Swift extensions without creating new types.

**Swift 6.0 Impact:**
- ❌ No concurrency improvements - still one giant @MainActor type
- ❌ Cannot use `@concurrent` because all code is MainActor-isolated
- ❌ Cannot leverage isolated conformances (no new types to conform)
- ❌ No testability improvements - same tightly coupled type

**Swift 6.2 Impact:**
- ❌ Default MainActor inference provides no benefit (already @MainActor)
- ❌ `@concurrent` cannot be applied to methods needing instance state
- ❌ Approachable concurrency irrelevant - no new async boundaries

**Risk/Reward:**
```
Risk:   ★☆☆☆☆ (Very Low - zero behavior change)
Reward: ★☆☆☆☆ (Very Low - organizational only)
Effort: ★☆☆☆☆ (~1 hour)
```

**Long-term value:** Near zero. Technical debt remains. Future Swift versions provide no benefit.

---

#### Option B: EQPresetStore Extraction

**What it does:** Extract ~150 lines of preset persistence logic to a new @Observable @MainActor class.

**Swift 6.0 Impact:**
- ✅ Follows `@Observable` pattern correctly
- ✅ File I/O can use `Task.detached` for background execution (already done)
- ✅ Unit testable in isolation with mock file system
- ⚠️ Limited scope - main complexity remains in AudioPlayer

**Swift 6.2 Impact:**
- ✅ Can mark file I/O methods as `@concurrent`:
  ```swift
  nonisolated struct EQPresetPersistence {
      @concurrent
      func loadPresets() async -> [EQPreset] { ... }
  }
  ```
- ✅ Clean separation allows isolated conformances if needed
- ✅ Establishes pattern for future extractions

**Risk/Reward:**
```
Risk:   ★★☆☆☆ (Low - isolated functionality, minimal coupling)
Reward: ★★★☆☆ (Medium - proves pattern, enables testing, Swift 6.2 ready)
Effort: ★★☆☆☆ (~2-3 hours)
```

**Long-term value:** Good foundation. Establishes extraction pattern. Can iterate.

---

#### Option C: Full Extraction

**What it does:** Create 6 focused components:
1. `EQPresetStore` - Preset persistence
2. `VisualizerPipeline` - Audio tap, FFT, data delivery
3. `AudioEngineController` - AVAudioEngine, nodes, connections
4. `PlaylistController` - Track management, navigation
5. `VideoPlaybackController` - AVPlayer for video
6. `MetadataLoader` - Async track/video metadata

AudioPlayer becomes a thin facade coordinating these components.

**Swift 6.0 Impact:**
- ✅ Each component has appropriate actor isolation
- ✅ VisualizerPipeline can be `nonisolated` with explicit MainActor updates
- ✅ Full unit testability with dependency injection
- ✅ Matches Apple's modern framework separation of concerns

**Swift 6.2 Impact:**
- ✅ **`@concurrent` for CPU-intensive work:**
  ```swift
  nonisolated struct FFTProcessor {
      @concurrent
      func processSpectrum(samples: [Float]) async -> [Float] { ... }
  }
  ```
- ✅ **Isolated conformances for each component:**
  ```swift
  extension EQPresetStore: @MainActor PresetProvider { ... }
  extension PlaylistController: @MainActor PlaylistNavigable { ... }
  ```
- ✅ **MetadataLoader perfect for `@concurrent`:**
  ```swift
  nonisolated struct MetadataLoader {
      @concurrent
      func loadMetadata(for url: URL) async throws -> TrackMetadata { ... }
  }
  ```
- ✅ Components can opt into default MainActor inference individually

**Risk Assessment by Component:**

| Component | Risk | Reason |
|-----------|------|--------|
| EQPresetStore | ★★☆☆☆ Low | Isolated, no shared state |
| PlaylistController | ★★☆☆☆ Low | Pure data manipulation |
| MetadataLoader | ★★☆☆☆ Low | Async-only, no side effects |
| VideoPlaybackController | ★★★☆☆ Medium | AVPlayer observer lifecycle |
| VisualizerPipeline | ★★★★☆ HIGH | `Unmanaged` pointer lifetime critical |
| AudioEngineController | ★★★★★ HIGHEST | Core playback, seek guards, engine state |

**Risk/Reward:**
```
Risk:   ★★★★☆ (High - especially VisualizerPipeline and AudioEngineController)
Reward: ★★★★★ (Highest - full Swift 6.2 leverage, testable, maintainable)
Effort: ★★★★☆ (6-8 hours)
```

---

#### The `Unmanaged` Pointer Problem (VisualizerPipeline)

The visualizer tap uses `Unmanaged<AudioPlayer>` to cross the Core Audio callback boundary:

```swift
// Current code (AudioPlayer.swift:1362-1363)
let context = VisualizerTapContext(
    playerPointer: Unmanaged.passUnretained(self).toOpaque()
)
// ... later in callback (line 1343):
let player = Unmanaged<AudioPlayer>.fromOpaque(context.playerPointer).takeUnretainedValue()
```

**Why this is HIGH RISK:**
1. `passUnretained` means AudioPlayer could be deallocated while tap is running
2. Core Audio callbacks run on realtime audio thread (not main actor)
3. Incorrect lifetime management → crash or memory corruption
4. Swift 6 strict concurrency makes this even more fragile

**Swift 6.2 solution would require:**
- Careful `Sendable` conformance for data crossing actor boundary
- Explicit lifecycle management for pipeline vs AudioPlayer
- Possibly `@preconcurrency` annotation for Core Audio callback

---

#### Verdict: Is Full Refactor Highest Reward?

**YES** - but with critical caveats:

**Full extraction (Option C) provides highest long-term reward because:**

1. **Swift 6.2 `@concurrent`** - Only Option C can fully leverage this for:
   - FFT spectrum processing
   - Metadata loading
   - File I/O operations
   - Shuffle algorithm for large playlists

2. **Testability** - Only Option C provides true unit testing:
   - Mock `EQPresetStore` for UI tests
   - Test `PlaylistController` shuffle deterministically
   - Test `MetadataLoader` with fake network responses

3. **Maintainability** - With 25+ files depending on AudioPlayer:
   - Facade pattern localizes changes
   - Each component has single responsibility
   - Easier onboarding for new contributors

4. **Future-proofing** - Swift evolution favors:
   - Fine-grained actor isolation
   - Explicit concurrency boundaries
   - Protocol-based composition

**BUT - the reward/risk ratio is optimized by incremental extraction:**

```
Recommended Sequence (Risk-Ordered):

1. EQPresetStore      (★★☆☆☆) → Proves pattern, low risk
2. PlaylistController (★★☆☆☆) → Pure logic, easy to test
3. MetadataLoader     (★★☆☆☆) → Async-focused, Swift 6.2 @concurrent perfect
4. VideoPlaybackController (★★★☆☆) → Observer lifecycle needs care
5. VisualizerPipeline (★★★★☆) → Unmanaged pointers, do LAST
6. AudioEngineController (★★★★★) → OPTIONAL - may not be worth the risk
```

**Key Insight:** AudioEngineController extraction may not be worth the risk. The seek guards, engine lifecycle, and tap installation are deeply intertwined. Leaving this as the "core" of AudioPlayer while extracting peripheral concerns may be the optimal architecture.

---

#### Final Recommendation

**Pursue Option C incrementally, with Option B as the first milestone:**

| Phase | Component | Swift 6.2 Benefit | Risk |
|-------|-----------|-------------------|------|
| 8.0 | Quick Fixes | - | ★☆☆☆☆ |
| 8.1 | EQPresetStore | `@concurrent` file I/O | ★★☆☆☆ |
| 8.2 | MetadataLoader | `@concurrent` metadata | ★★☆☆☆ |
| 8.3 | PlaylistController | Testability | ★★☆☆☆ |
| 8.4 | VideoPlaybackController | Observer cleanup | ★★★☆☆ |
| 8.5 | VisualizerPipeline | `@concurrent` FFT | ★★★★☆ |
| 8.6 | AudioEngineController | DEFER | ★★★★★ |

**Stop Point:** After Phase 8.5, evaluate if AudioEngineController extraction provides sufficient value given the risk. The remaining AudioPlayer would be ~400-500 lines focused solely on engine lifecycle - a reasonable size for a single class.

**Swift 6.2 Readiness Score by Option:**
- Option A: 1/10 (no benefit)
- Option B: 5/10 (partial benefit, foundation for more)
- Option C (incremental): 9/10 (full benefit, managed risk)

---

## 14. Option C Architecture: Full Extraction Design

### 14.1 Current AudioPlayer Structure (Before)

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        AudioPlayer.swift (1,810 lines)                  │
│                     @Observable @MainActor final class                  │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌─────────────────────┐  ┌─────────────────────┐  ┌─────────────────┐  │
│  │   Engine Layer      │  │   State Layer       │  │   UI Data       │  │
│  │   ─────────────     │  │   ───────────       │  │   ───────       │  │
│  │   audioEngine       │  │   playbackState     │  │   currentTitle  │  │
│  │   playerNode        │  │   isPlaying         │  │   currentTime   │  │
│  │   eqNode            │  │   isPaused          │  │   currentDur... │  │
│  │   audioFile         │  │   currentSeekID     │  │   playbackProg..│  │
│  │   progressTimer     │  │   seekGuardActive   │  │   visualizer... │  │
│  └─────────────────────┘  └─────────────────────┘  └─────────────────┘  │
│                                                                         │
│  ┌─────────────────────┐  ┌─────────────────────┐  ┌─────────────────┐  │
│  │   EQ/Presets        │  │   Playlist          │  │   Video         │  │
│  │   ─────────────     │  │   ────────          │  │   ─────         │  │
│  │   preamp            │  │   playlist[]        │  │   videoPlayer   │  │
│  │   eqBands[]         │  │   currentTrack      │  │   videoEnd...   │  │
│  │   isEqOn            │  │   currentPlaylist...│  │   videoTime...  │  │
│  │   userPresets[]     │  │   shuffleEnabled    │  │   currentMedia..│  │
│  │   perTrackPresets{} │  │   repeatMode        │  │   videoMetadata │  │
│  └─────────────────────┘  └─────────────────────┘  └─────────────────┘  │
│                                                                         │
│  ┌─────────────────────┐  ┌─────────────────────┐                       │
│  │   Visualizer        │  │   Metadata          │                       │
│  │   ──────────        │  │   ────────          │                       │
│  │   visualizerTap...  │  │   channelCount      │                       │
│  │   visualizerPeaks[] │  │   bitrate           │                       │
│  │   latestRMS[]       │  │   sampleRate        │                       │
│  │   latestSpectrum[]  │  │                     │                       │
│  │   butterchurn...    │  │                     │                       │
│  └─────────────────────┘  └─────────────────────┘                       │
│                                                                         │
├─────────────────────────────────────────────────────────────────────────┤
│                         Supporting Types (Top of File)                  │
├─────────────────────────────────────────────────────────────────────────┤
│  • VisualizerScratchBuffers (class, @unchecked Sendable) - lines 22-165 │
│  • VisualizerTapContext (struct, @unchecked Sendable) - lines 167-169   │
│  • ButterchurnFrame (struct) - lines 176-182                            │
│  • Track (struct, Identifiable, Equatable) - lines 186-205              │
│  • PlaybackStopReason (enum) - lines 207-211                            │
│  • PlaybackState (enum) - lines 213-219                                 │
└─────────────────────────────────────────────────────────────────────────┘
```

### 14.2 MARK Sections and Line Counts

| MARK Section | Line | Functions | Responsibility |
|--------------|------|-----------|----------------|
| Butterchurn FFT Processing | 97 | 4 | FFT calculation for visualizer |
| Butterchurn Audio Frame | 176 | - | Data struct for visualizer |
| Track | 186 | - | Track data model |
| Track Management | 369 | 2 | addTrack, playTrack |
| Video Time Observer | 587 | 2 | Video progress tracking |
| Preset persistence | 970 | 8 | Load/save presets |
| Engine Wiring | 1042 | 5 | AVAudioEngine setup |
| Seeking / Scrubbing | 1381 | 2 | Seek operations |
| Visualizer Support | 1517 | 3 | Get visualizer data |
| Butterchurn Audio Data | 1600 | 1 | Snapshot for Butterchurn |
| Playlist navigation | 1658 | 3 | Next/prev track |

### 14.3 Target Architecture (After Option C)

```
┌─────────────────────────────────────────────────────────────────────────┐
│                              Mechanism Layer                             │
│                        (Business Logic & Persistence)                    │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌───────────────────────┐  ┌───────────────────────┐                   │
│  │    EQPresetStore      │  │    MetadataLoader     │                   │
│  │    ─────────────      │  │    ──────────────     │                   │
│  │    @MainActor         │  │    nonisolated        │                   │
│  │    @Observable        │  │    @concurrent ready  │                   │
│  ├───────────────────────┤  ├───────────────────────┤                   │
│  │  • userPresets[]      │  │  • loadMetadata()     │                   │
│  │  • perTrackPresets{}  │  │  • extractArtwork()   │                   │
│  │  • loadUserPresets()  │  │  • parseDuration()    │                   │
│  │  • persistPresets()   │  │                       │                   │
│  │  • importEqfPreset()  │  │  ~100-150 lines       │                   │
│  │  ~150 lines           │  └───────────────────────┘                   │
│  └───────────────────────┘                                              │
│                                                                         │
│  ┌───────────────────────┐  ┌───────────────────────┐                   │
│  │  PlaylistController   │  │ VideoPlaybackController│                   │
│  │  ──────────────────   │  │ ─────────────────────  │                   │
│  │  @MainActor           │  │  @MainActor           │                   │
│  │  @Observable          │  │  @Observable          │                   │
│  ├───────────────────────┤  ├───────────────────────┤                   │
│  │  • playlist[]         │  │  • videoPlayer        │                   │
│  │  • currentTrack       │  │  • endObserver        │                   │
│  │  • shuffleEnabled     │  │  • timeObserver       │                   │
│  │  • repeatMode         │  │  • loadVideo()        │                   │
│  │  • nextTrack()        │  │  • cleanupPlayer()    │                   │
│  │  • previousTrack()    │  │  ~150-200 lines       │                   │
│  │  ~150-200 lines       │  └───────────────────────┘                   │
│  └───────────────────────┘                                              │
│                                                                         │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │                      VisualizerPipeline                           │  │
│  │                      ──────────────────                           │  │
│  │                      nonisolated (with MainActor updates)         │  │
│  ├───────────────────────────────────────────────────────────────────┤  │
│  │  • VisualizerScratchBuffers (class, @unchecked Sendable)          │  │
│  │  • VisualizerTapContext (struct, @unchecked Sendable)             │  │
│  │  • ButterchurnFrame (struct)                                      │  │
│  │  • installTap() / removeTap()                                     │  │
│  │  • makeVisualizerTapHandler() - static                            │  │
│  │  • getFrequencyData() / getRMSData() / getWaveformSamples()       │  │
│  │  ~200-250 lines                                                   │  │
│  │  ⚠️ HIGH RISK: Unmanaged pointer lifecycle                        │  │
│  └───────────────────────────────────────────────────────────────────┘  │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────┐
│                              Bridge Layer                                │
│                          (Facade & Coordination)                         │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │                    AudioPlayer (Facade)                           │  │
│  │                    ────────────────────                           │  │
│  │                    @MainActor @Observable                         │  │
│  ├───────────────────────────────────────────────────────────────────┤  │
│  │                                                                   │  │
│  │  Engine Core (~400-500 lines after extraction):                   │  │
│  │  ─────────────────────────────────────────────                    │  │
│  │  • audioEngine, playerNode, eqNode                                │  │
│  │  • audioFile, progressTimer                                       │  │
│  │  • playbackState, isPlaying, isPaused                             │  │
│  │  • currentSeekID, seekGuardActive, isHandlingCompletion           │  │
│  │  • setupEngine(), configureEQ(), rewireForCurrentFile()           │  │
│  │  • scheduleFrom(), startEngineIfNeeded()                          │  │
│  │  • play(), pause(), stop(), eject()                               │  │
│  │  • seekToPercent(), seek()                                        │  │
│  │                                                                   │  │
│  │  Component References:                                            │  │
│  │  ─────────────────────                                            │  │
│  │  • eqPresetStore: EQPresetStore                                   │  │
│  │  • playlistController: PlaylistController                         │  │
│  │  • videoController: VideoPlaybackController                       │  │
│  │  • visualizerPipeline: VisualizerPipeline                         │  │
│  │  • metadataLoader: MetadataLoader                                 │  │
│  │                                                                   │  │
│  │  Computed Forwarding (maintains existing bindings):               │  │
│  │  ─────────────────────────────────────────────────                │  │
│  │  var userPresets: [EQPreset] { eqPresetStore.userPresets }        │  │
│  │  var playlist: [Track] { playlistController.playlist }            │  │
│  │  var currentTrack: Track? { playlistController.currentTrack }     │  │
│  │                                                                   │  │
│  └───────────────────────────────────────────────────────────────────┘  │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────┐
│                           Presentation Layer                             │
│                             (SwiftUI Views)                              │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  Views access AudioPlayer only (never extracted components directly):   │
│                                                                         │
│  • WinampMainWindow      → audioPlayer.play/pause/stop                  │
│  • EqualizerView         → audioPlayer.eqBands, audioPlayer.preamp      │
│  • PlaylistView          → audioPlayer.playlist, audioPlayer.nextTrack  │
│  • SpectrumAnalyzerView  → audioPlayer.getFrequencyData()               │
│  • VideoWindowView       → audioPlayer.videoMetadataString              │
│                                                                         │
│  ⚠️ LAYER BOUNDARY: Views never import or access:                       │
│     EQPresetStore, PlaylistController, VisualizerPipeline, etc.         │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### 14.4 Component Specifications

#### EQPresetStore

```swift
// MacAmpApp/Audio/EQPresetStore.swift
@MainActor
@Observable
final class EQPresetStore {
    // MARK: - State
    private(set) var userPresets: [EQPreset] = []
    var perTrackPresets: [String: EqfPreset] = [:]

    // MARK: - Private
    private let presetsFileName = "perTrackPresets.json"
    private let userPresetDefaultsKey = "MacAmp.UserEQPresets.v1"

    // MARK: - Lifecycle
    init() {
        loadUserPresets()
        loadPerTrackPresets()
    }

    // MARK: - Public API
    func storeUserPreset(_ preset: EQPreset) { ... }
    func deleteUserPreset(id: UUID) { ... }
    func importEqfPreset(from url: URL) { ... }  // Uses Task.detached
    func presetForTrack(_ trackPath: String) -> EqfPreset? { ... }
    func savePresetForTrack(_ trackPath: String, preset: EqfPreset) { ... }

    // MARK: - Private Persistence
    private func appSupportDirectory() -> URL? { ... }
    private func presetsFileURL() -> URL? { ... }
    private func loadPerTrackPresets() { ... }
    private func savePerTrackPresets() { ... }
    private func loadUserPresets() { ... }
    private func persistUserPresets() { ... }
}
```

**Swift 6.2 Enhancement:**
```swift
// File I/O can use @concurrent when Swift 6.2 is adopted
nonisolated struct EQPresetPersistence {
    @concurrent
    func loadPresets(from url: URL) async throws -> [EQPreset] { ... }

    @concurrent
    func savePresets(_ presets: [EQPreset], to url: URL) async throws { ... }
}
```

#### MetadataLoader

```swift
// MacAmpApp/Audio/MetadataLoader.swift
nonisolated struct MetadataLoader {
    // MARK: - Swift 6.2 Ready (@concurrent)
    func loadTrackMetadata(url: URL) async -> Track { ... }
    func loadVideoMetadata(url: URL) async -> VideoMetadata { ... }
    func extractAudioProperties(url: URL) -> AudioProperties { ... }
}

struct AudioProperties {
    let channelCount: Int
    let bitrate: Int
    let sampleRate: Int
}

struct VideoMetadata {
    let title: String
    let duration: Double
    let resolution: CGSize?
}
```

#### PlaylistController

```swift
// MacAmpApp/Audio/PlaylistController.swift
@MainActor
@Observable
final class PlaylistController {
    // MARK: - State
    private(set) var playlist: [Track] = []
    private(set) var currentTrack: Track?
    private var currentIndex: Int?
    var shuffleEnabled: Bool = false

    // MARK: - Repeat Mode (delegates to AppSettings)
    var repeatMode: AppSettings.RepeatMode {
        get { AppSettings.instance().repeatMode }
        set { AppSettings.instance().repeatMode = newValue }
    }

    // MARK: - Playlist Operations
    func addTrack(_ track: Track) { ... }
    func removeTrack(at index: Int) { ... }
    func moveTrack(from: Int, to: Int) { ... }
    func clear() { ... }

    // MARK: - Navigation
    func nextTrack(isManualSkip: Bool) -> PlaylistAdvanceAction { ... }
    func previousTrack() -> PlaylistAdvanceAction { ... }
    func selectTrack(at index: Int) -> Track? { ... }
    func updatePosition(with track: Track?) { ... }
}

enum PlaylistAdvanceAction {
    case playTrack(Track)
    case stopPlayback
    case noChange
}
```

#### VideoPlaybackController

```swift
// MacAmpApp/Audio/VideoPlaybackController.swift
@MainActor
@Observable
final class VideoPlaybackController {
    // MARK: - State
    private(set) var player: AVPlayer?
    private(set) var metadataString: String = ""
    private(set) var currentTime: Double = 0
    private(set) var duration: Double = 0

    // MARK: - Private
    private var endObserver: NSObjectProtocol?
    private var timeObserver: Any?

    // MARK: - Callbacks
    var onPlaybackEnded: (() -> Void)?
    var onTimeUpdate: ((Double) -> Void)?

    // MARK: - Lifecycle
    func loadVideo(url: URL) async { ... }
    func play() { ... }
    func pause() { ... }
    func seek(to time: Double) { ... }
    func cleanup() { ... }

    // MARK: - Private
    private func setupTimeObserver() { ... }
    private func tearDownObservers() { ... }
}
```

#### VisualizerPipeline

```swift
// MacAmpApp/Audio/VisualizerPipeline.swift

// MARK: - Supporting Types (moved from AudioPlayer.swift)
final class VisualizerScratchBuffers: @unchecked Sendable { ... }
private struct VisualizerTapContext: @unchecked Sendable { ... }
struct ButterchurnFrame { ... }

// MARK: - Pipeline
@MainActor
final class VisualizerPipeline {
    // MARK: - State
    private var tapInstalled = false
    private var scratch: VisualizerScratchBuffers?
    private var latestRMS: [Float] = []
    private var latestSpectrum: [Float] = []
    private var latestWaveform: [Float] = []
    private var butterchurnSpectrum: [Float] = Array(repeating: 0, count: 1024)
    private var butterchurnWaveform: [Float] = Array(repeating: 0, count: 1024)

    // MARK: - Configuration
    var smoothing: Float = 0.6
    var peakFalloff: Float = 1.2

    // MARK: - Tap Management
    /// ⚠️ CRITICAL: Must be called with valid mixer node
    /// The Unmanaged pointer must remain valid while tap is installed
    func installTap(on mixer: AVAudioMixerNode, playerPointer: UnsafeMutableRawPointer) { ... }
    func removeTap(from mixer: AVAudioMixerNode) { ... }

    // MARK: - Data Access
    func getFrequencyData(bands: Int) -> [Float] { ... }
    func getRMSData(bands: Int) -> [Float] { ... }
    func getWaveformSamples(count: Int) -> [Float] { ... }
    func snapshotButterchurnFrame() -> ButterchurnFrame? { ... }

    // MARK: - Internal Update (called from tap handler via Task)
    func updateLevels(rms: [Float], spectrum: [Float], waveform: [Float],
                      butterchurnSpectrum: [Float], butterchurnWaveform: [Float]) { ... }

    // MARK: - Static Tap Handler Factory
    static func makeVisualizerTapHandler(
        pipeline: VisualizerPipeline,
        context: VisualizerTapContext,
        scratch: VisualizerScratchBuffers
    ) -> AVAudioNodeTapBlock { ... }
}
```

### 14.5 Data Flow Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           User Interaction                               │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                         SwiftUI Views (Presentation)                     │
│                                                                         │
│   EqualizerView ──────┐     PlaylistView ──────┐     SpectrumView ────┐ │
│                       │                        │                      │ │
└───────────────────────┼────────────────────────┼──────────────────────┼─┘
                        │                        │                      │
                        ▼                        ▼                      ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                    AudioPlayer (Facade/Coordinator)                      │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │                        Public API                                │   │
│  │  • play() / pause() / stop()                                     │   │
│  │  • setEqBand(index:value:)          ──────▶ eqPresetStore        │   │
│  │  • nextTrack() / previousTrack()    ──────▶ playlistController   │   │
│  │  • getFrequencyData(bands:)         ──────▶ visualizerPipeline   │   │
│  │  • playVideoFile(url:)              ──────▶ videoController      │   │
│  └──────────────────────────────────────────────────────────────────┘   │
│                                                                         │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │                     Engine Core (retained)                       │   │
│  │  • AVAudioEngine lifecycle                                       │   │
│  │  • AVAudioPlayerNode scheduling                                  │   │
│  │  • Seek guards (currentSeekID, seekGuardActive)                  │   │
│  │  • Progress timer                                                │   │
│  └──────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────┘
          │              │              │              │
          ▼              ▼              ▼              ▼
┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐
│ EQPreset    │  │ Playlist    │  │ Visualizer  │  │ Video       │
│ Store       │  │ Controller  │  │ Pipeline    │  │ Controller  │
│             │  │             │  │             │  │             │
│ @Observable │  │ @Observable │  │ @MainActor  │  │ @Observable │
│ @MainActor  │  │ @MainActor  │  │ nonisolated │  │ @MainActor  │
│             │  │             │  │ tap handler │  │             │
├─────────────┤  ├─────────────┤  ├─────────────┤  ├─────────────┤
│ File I/O    │  │ Pure Logic  │  │ Core Audio  │  │ AVPlayer    │
│ UserDefaults│  │ Array Ops   │  │ Realtime    │  │ Observers   │
└─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘
          │                                               │
          ▼                                               ▼
┌─────────────────────────────┐             ┌─────────────────────────────┐
│       App Support Dir       │             │         AVPlayer            │
│   • perTrackPresets.json    │             │   (Video Playback)          │
│   • UserDefaults            │             │                             │
└─────────────────────────────┘             └─────────────────────────────┘
```

### 14.6 Dependency Graph

```
                        ┌─────────────────────┐
                        │    AudioPlayer      │
                        │      (Facade)       │
                        └─────────────────────┘
                                  │
              ┌───────────────────┼───────────────────┐
              │                   │                   │
              ▼                   ▼                   ▼
     ┌────────────────┐  ┌────────────────┐  ┌────────────────┐
     │ EQPresetStore  │  │PlaylistController│  │VisualizerPipeline│
     └────────────────┘  └────────────────┘  └────────────────┘
              │                   │                   │
              │                   │                   │
              ▼                   ▼                   ▼
     ┌────────────────┐  ┌────────────────┐  ┌────────────────┐
     │  AppSettings   │  │  AppSettings   │  │ AVAudioEngine  │
     │  (RepeatMode)  │  │  (RepeatMode)  │  │ (mixer node)   │
     └────────────────┘  └────────────────┘  └────────────────┘
              │
              ▼
     ┌────────────────┐
     │ MetadataLoader │ ◀─────── (no dependencies, pure functions)
     └────────────────┘

     ┌────────────────┐
     │VideoPlayback   │
     │   Controller   │ ◀─────── (AVPlayer, no AudioPlayer dep)
     └────────────────┘

Dependencies Legend:
─────────────────────
→  Direct dependency (holds reference)
◀  No external dependencies (standalone)
```

### 14.7 File Structure After Extraction

```
MacAmpApp/
├── Audio/
│   ├── AudioPlayer.swift              (~400-500 lines) - Facade + Engine Core
│   ├── EQPresetStore.swift            (~150 lines) - Preset persistence
│   ├── MetadataLoader.swift           (~100-150 lines) - Track metadata
│   ├── PlaylistController.swift       (~150-200 lines) - Playlist logic
│   ├── VideoPlaybackController.swift  (~150-200 lines) - AVPlayer wrapper
│   ├── VisualizerPipeline.swift       (~200-250 lines) - Audio tap + FFT
│   └── Models/
│       ├── Track.swift                (~50 lines) - Track data model
│       ├── EQPreset.swift             (existing)
│       ├── EqfPreset.swift            (existing)
│       ├── PlaybackState.swift        (~20 lines) - State enums
│       └── ButterchurnFrame.swift     (~20 lines) - Visualizer frame
```

### 14.8 Migration Checklist

| Step | Component | Existing Deps | New Location | Risk |
|------|-----------|---------------|--------------|------|
| 1 | EQPreset model | None | Models/EQPreset.swift | ★☆☆☆☆ |
| 2 | Track model | None | Models/Track.swift | ★☆☆☆☆ |
| 3 | PlaybackState enums | None | Models/PlaybackState.swift | ★☆☆☆☆ |
| 4 | EQPresetStore | AppSettings | EQPresetStore.swift | ★★☆☆☆ |
| 5 | MetadataLoader | AVFoundation | MetadataLoader.swift | ★★☆☆☆ |
| 6 | PlaylistController | AppSettings | PlaylistController.swift | ★★☆☆☆ |
| 7 | VideoPlaybackController | AVFoundation | VideoPlaybackController.swift | ★★★☆☆ |
| 8 | VisualizerPipeline | AVAudioEngine | VisualizerPipeline.swift | ★★★★☆ |
| 9 | AudioPlayer refactor | All above | AudioPlayer.swift | ★★★☆☆ |

### 14.9 Testing Strategy Per Component

| Component | Unit Tests | Integration Tests | Manual Tests |
|-----------|------------|-------------------|--------------|
| EQPresetStore | ✅ Mock file system | ✅ Real persistence | Load/save presets |
| MetadataLoader | ✅ Mock URLs | ✅ Real audio files | Track info display |
| PlaylistController | ✅ Pure logic | ✅ With AudioPlayer | Add/remove/navigate |
| VideoPlaybackController | ⚠️ Mock AVPlayer | ✅ Real video files | Play video |
| VisualizerPipeline | ⚠️ Synthetic data | ✅ With engine | Spectrum display |
| AudioPlayer (Facade) | ⚠️ Mock components | ✅ Full stack | Full playback |

### 14.10 Rollback Strategy

Each extraction is a separate commit with clear boundaries:

```
git log --oneline (after Phase 8 complete):
──────────────────────────────────────────
abc1234 refactor: Extract VisualizerPipeline from AudioPlayer
def5678 refactor: Extract VideoPlaybackController from AudioPlayer
ghi9012 refactor: Extract PlaylistController from AudioPlayer
jkl3456 refactor: Extract MetadataLoader from AudioPlayer
mno7890 refactor: Extract EQPresetStore from AudioPlayer
pqr1234 style: Fix SwiftLint violations in AudioPlayer
```

**To rollback any extraction:**
```bash
git revert <commit-hash>  # Reverts specific extraction
# OR
git reset --hard <previous-hash>  # Reverts to before extraction
```

Each extracted component is self-contained, so reverting one doesn't affect others.
