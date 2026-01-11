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
