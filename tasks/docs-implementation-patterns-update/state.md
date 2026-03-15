# State: Docs Implementation Patterns Update

> **Purpose:** Document cross-file SwiftUI extension anti-pattern and correct child-view pattern in IMPLEMENTATION_PATTERNS.md
> **Created:** 2026-03-14
> **Sprint:** S2 (MEDIUM) — executing first for docs hygiene
> **Status:** IN PROGRESS

---

## Current Status

**Phase:** Implementation
**Status:** IN PROGRESS
**Last Updated:** 2026-03-14

---

## Context

During T3 (mainwindow-layer-decomposition), a cross-file SwiftUI extension anti-pattern was discovered and corrected. The anti-pattern (extending a View from another file to add body content) and the correct pattern (child view structs with dependency injection) need to be documented in IMPLEMENTATION_PATTERNS.md. Additionally, all docs/ files should be audited for staleness after Wave 3 changes.
