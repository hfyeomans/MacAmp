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
xcodebuild -scheme MacAmp -configuration Debug -enableThreadSanitizer YES build
```

**Expected:** Build succeeds with 0 warnings

### 5.2 Test Suite

```bash
xcodebuild test -scheme MacAmp -enableThreadSanitizer YES
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

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Behavior regression | Low | Medium | Tests + manual verification |
| Build failure | Very Low | High | Compile-time errors caught immediately |
| Performance impact | Very Low | Low | Optional.map is zero-cost abstraction |
| SwiftLint too strict | Medium | Low | Can adjust config |

---

## Time Estimate

| Phase | Estimated Time |
|-------|----------------|
| Phase 1: Force Unwrap Fixes | 30 minutes |
| Phase 2: Dead Code Docs | 5 minutes |
| Phase 3: SwiftLint Setup | 15 minutes |
| Phase 4: Pre-commit Hook | 10 minutes |
| Phase 5: Verification | 20 minutes |
| Phase 6: Commit & Docs | 10 minutes |
| **Total** | **~90 minutes** |

---

## Success Criteria

- [ ] All 5 force unwraps fixed
- [ ] Build succeeds with 0 warnings
- [ ] All tests pass
- [ ] SwiftLint reports 0 violations
- [ ] Oracle review passes
- [ ] Manual smoke test passes
- [ ] Changes committed to `code-simplification` branch
