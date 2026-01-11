# Placeholder Documentation - Code Optimization Task

**Task ID:** code-optimization
**Created:** 2026-01-10
**Status:** Active

---

## Purpose

This file documents intentional placeholder/scaffolding code in the MacAmp codebase that is part of planned features. Per project conventions, we use centralized `placeholder.md` files instead of in-code TODO comments.

---

## Active Placeholders

### 1. `fallbackSkinsDirectory` Function

**Location:** `MacAmpApp/Models/AppSettings.swift:167`

**Function:**
```swift
static func fallbackSkinsDirectory() -> URL {
    URL.cachesDirectory
        .appending(component: "MacAmp/FallbackSkins", directoryHint: .isDirectory)
}
```

**Purpose:** Scaffolding for the default skin fallback feature.

**Related Task:** `tasks/default-skin-fallback/`

**Status:** Function defined but not called. Intentionally retained as scaffolding for upcoming feature.

**Action Required:**
- Implement when `default-skin-fallback` task is activated
- Remove this entry when feature is complete
- If feature is abandoned, remove function and this entry

---

## Placeholder Policy

Per Oracle review and project conventions:

1. **No in-code TODO/FIXME comments** for planned features
2. **All placeholders documented** in task-specific `placeholder.md`
3. **Regular review** of placeholders during task completion
4. **Remove entries** when features are implemented or abandoned

---

## Audit Log

| Date | Action | By |
|------|--------|-----|
| 2026-01-10 | Created placeholder.md, documented `fallbackSkinsDirectory` | Claude |
