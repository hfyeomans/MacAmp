# SwiftLint Pre-Existing Violations

**Discovered:** 2026-01-10
**Source:** Pre-commit hook on initial commit
**Total Violations:** 40 (in 4 staged files)
**Status:** Documented for future cleanup

---

## Summary by File

| File | Violations | Categories |
|------|------------|------------|
| `AudioPlayer.swift` | 21 | Length, whitespace, operators |
| `AppSettings.swift` | 10 | Redundant enum values, whitespace |
| `SnapUtils.swift` | 8 | Statement position |
| `EqGraphView.swift` | 1 | Closure body length |

---

## AudioPlayer.swift (21 violations)

### Critical / High Priority

| Line | Rule | Description | Effort |
|------|------|-------------|--------|
| 1:1 | `leading_whitespace` | File contains leading whitespace | Quick fix |
| 223:7 | `type_body_length` | Class spans 1178 lines (limit: 600) | Major refactor |
| 1:1 | `file_length` | File contains 1801 lines (limit: 1000) | Major refactor |
| 1219:32 | `function_body_length` | Function spans 107 lines (limit: 100) | Medium refactor |
| 1405:5 | `function_body_length` | Function spans 61 lines (limit: 60) | Minor refactor |

### Closure Body Length (3)

| Line | Description |
|------|-------------|
| 1223:9 | Closure spans 105 lines (limit: 50) |
| 1243:38 | Closure spans 62 lines (limit: 50) |
| 1268:38 | Closure spans 37 lines (limit: 30) |

### Code Style (10)

| Line | Rule | Description |
|------|------|-------------|
| 143:13 | `shorthand_operator` | Use `+=` instead of `x = x + y` |
| 319:9 | `implicit_optional_initialization` | Optional should be initialized without `= nil` |
| 647:13 | `redundant_discardable_let` | Use `_ = foo()` not `let _ = foo()` |
| 797:9 | `redundant_discardable_let` | Use `_ = foo()` not `let _ = foo()` |
| 1073:19 | `unused_optional_binding` | Use `!= nil` over `let _ =` |
| 716:1 | `vertical_whitespace` | Extra blank line (2 lines, limit 1) |
| 819:5 | `vertical_whitespace` | Extra blank lines (3 lines, limit 1) |
| 1182:1 | `vertical_whitespace` | Extra blank line (2 lines, limit 1) |

---

## AppSettings.swift (10 violations)

### Redundant String Enum Values (9)

All enums have explicit string values matching case names (unnecessary):

| Line | Enum |
|------|------|
| 7:20 | `MaterialIntegrationLevel.classic = "classic"` |
| 8:19 | `MaterialIntegrationLevel.hybrid = "hybrid"` |
| 9:19 | `MaterialIntegrationLevel.modern = "modern"` |
| 211:24 | `TimeDisplayMode.elapsed = "elapsed"` |
| 212:26 | `TimeDisplayMode.remaining = "remaining"` |
| 311:20 | `RepeatMode.off = "off"` |
| 312:20 | `RepeatMode.all = "all"` |
| 313:20 | `RepeatMode.one = "one"` |

### Whitespace (1)

| Line | Rule | Description |
|------|------|-------------|
| 345:1 | `vertical_whitespace_closing_braces` | Empty line before closing `}` |

---

## SnapUtils.swift (8 violations)

### Statement Position (8)

All violations: `else` should be on same line as closing `}`:

```swift
// Current (violations)
}
else { ... }

// Should be
} else { ... }
```

| Lines |
|-------|
| 53:64, 54:81, 55:67 |
| 60:65, 61:81, 62:64 |
| 104:44, 106:44 |

---

## EqGraphView.swift (1 violation)

| Line | Rule | Description |
|------|------|-------------|
| 46:40 | `closure_body_length` | Canvas closure spans 43 lines (limit: 30) |

---

## Cleanup Priority

### Phase A: Quick Fixes (< 30 min total)

1. **Leading whitespace** - AudioPlayer.swift:1 (1 line delete)
2. **Vertical whitespace** - Remove extra blank lines (5 edits)
3. **Shorthand operator** - `x = x + y` → `x += y` (1 edit)
4. **Redundant discardable let** - `let _ = ` → `_ = ` (2 edits)
5. **Unused optional binding** - `let _ = ` → `!= nil` (1 edit)
6. **Statement position** - Move `else` to same line (8 edits)
7. **Closing brace whitespace** - Remove blank line (1 edit)

**Estimated: 19 edits, ~20 minutes**

### Phase B: Enum Cleanup (15 min)

Remove redundant string values from enums (Swift infers them):

```swift
// Before
enum RepeatMode: String {
    case off = "off"
    case all = "all"
}

// After
enum RepeatMode: String {
    case off
    case all
}
```

**Estimated: 9 edits across 3 enums, ~15 minutes**

### Phase C: Refactoring (Multi-hour)

These require architectural changes:

1. **AudioPlayer.swift size** (1801 lines, class 1178 lines)
   - Extract audio engine setup to separate class
   - Extract visualization logic to separate class
   - Extract playlist management to separate class

2. **Large functions** (107 and 61 lines)
   - Break into smaller helper functions

3. **Large closures** (105, 62, 43, 37 lines)
   - Extract into private methods
   - Use computed properties where appropriate

---

## Recommendations

### Short-term (This Sprint)
- [ ] Fix Phase A violations (quick wins)
- [ ] Fix Phase B violations (enum cleanup)
- [ ] Re-run SwiftLint to verify 0 violations in modified files

### Medium-term (Next Sprint)
- [ ] Plan AudioPlayer.swift refactoring
- [ ] Create subtasks for function extraction
- [ ] Consider splitting into AudioEngineManager + PlaybackController

### Long-term (Technical Debt)
- [ ] Establish max file length policy (500-800 lines)
- [ ] Establish max class length policy (400 lines)
- [ ] Consider code-simplifier agent for broader cleanup

---

## Commands

```bash
# Run SwiftLint on specific file
swiftlint lint MacAmpApp/Audio/AudioPlayer.swift

# Auto-fix some violations
swiftlint lint --fix MacAmpApp/

# Check specific rule
swiftlint rules | grep vertical_whitespace
```
