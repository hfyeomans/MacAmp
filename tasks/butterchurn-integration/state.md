# Butterchurn Integration - State

**Task ID:** butterchurn-integration
**Created:** 2026-01-05
**Last Updated:** 2026-01-05

---

## Current State

**Phase:** RESEARCH COMPLETE - Ready for Implementation

---

## Component Status

| Component | Status | Notes |
|-----------|--------|-------|
| Research | ✅ Complete | webamp, docs, existing code analyzed |
| Milkdrop window chrome | ✅ Complete | GEN.bmp sprites, focus states |
| Butterchurn assets | ✅ Bundled | .js files in Butterchurn/ folder |
| WKWebView integration | ❌ Blocked | file:// URL restriction |
| Bundle injection approach | 🔄 Planned | WKUserScript solution |
| Audio data bridge | ❌ Not started | Needs higher-res FFT tap |
| Preset management | ❌ Not started | Cycling, randomize, history |

---

## Blocker Summary

**PRIMARY BLOCKER:** WKWebView cannot load external JavaScript files from bundle

**Root Cause:** macOS security restriction on `file://` URLs with `<script src>`

**Solution:** WKUserScript injection - load .js files as strings, inject at document start

---

## Files Inventory

### Existing (Ready to Use)

| File | Location | Size |
|------|----------|------|
| butterchurn.min.js | Butterchurn/ | 238 KB |
| butterchurnPresets.min.js | Butterchurn/ | 230 KB |
| bridge.js | Butterchurn/ | 4 KB |
| index.html | Butterchurn/ | 3 KB |
| test.html | Butterchurn/ | 440 B |

### Window Infrastructure (Complete)

| File | Lines | Status |
|------|-------|--------|
| WinampMilkdropWindow.swift | 31 | ✅ Placeholder view |
| WinampMilkdropWindowController.swift | 52 | ✅ NSWindowController |
| MilkdropWindowChromeView.swift | 162 | ✅ GEN.bmp chrome |

### To Be Created

| File | Purpose |
|------|---------|
| ButterchurnWebView.swift | WKWebView with script injection |
| ButterchurnBridge.swift | Swift ↔ JS communication |
| ButterchurnPresetManager.swift | Preset state management |

---

## Technical Decisions

1. **Approach:** WKUserScript injection (Option B from research)
2. **FFT Size:** 2048 (1024 frequency bins for Butterchurn)
3. **Update Rate:** 60 FPS animation loop
4. **Window Size:** 256×198px content area (fixed initially)
5. **Preset Cycling:** 15 seconds (match Webamp)

---

## Branch Status

- **Current branch:** main
- **Target branch:** feature/butterchurn-integration
- **Base commit:** TBD (after task files committed)

---

## Dependencies

| Dependency | Status | Notes |
|------------|--------|-------|
| Milkdrop window chrome | ✅ Available | PR #36 merged |
| AudioPlayer FFT tap | ⚠️ Needs upgrade | Currently 19-bar, need 1024-bin |
| WKWebView | ✅ Available | macOS 15+ standard |
| WebKit framework | ✅ Available | Already linked |

---

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Injection fails | Low | High | Test minimal case first |
| Performance issues | Medium | Medium | Profile WebGL rendering |
| Audio sync lag | Medium | Low | Reduce buffer sizes |
| Memory leaks | Low | Medium | Proper WKWebView cleanup |

---

## Next Action

Begin Phase 1: Create ButterchurnWebView.swift with WKUserScript injection and verify Butterchurn loads successfully.

---

## Session Log

| Date | Action | Result |
|------|--------|--------|
| 2026-01-05 | Research completed | 4 agents analyzed all sources |
| 2026-01-05 | Task files created | research.md, state.md, plan.md, todo.md |
