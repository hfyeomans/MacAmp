# Butterchurn Integration - State

**Task ID:** butterchurn-integration
**Created:** 2026-01-05
**Revised:** 2026-01-05 (Oracle Review)
**Last Updated:** 2026-01-05

---

## Current State

**Phase:** PLAN REVISED - Ready for Phase 1 Implementation

**Oracle Review:** ✅ Complete (2026-01-05)

---

## Key Decisions (Oracle Review)

| Decision | Choice | Impact |
|----------|--------|--------|
| Stream scope | Local playback only | No Butterchurn for streams until SystemAudioCapture |
| Update rate | 30 FPS Swift→JS | Better stability; JS render loop at 60 FPS |
| Preset manager layer | Bridge (ViewModels) | UI-coupled state, timer ownership |
| Audio tap strategy | Merge into existing | AVAudioEngine allows only one tap per bus |
| @Observable pattern | Plain `var`, `@ObservationIgnored` timers | Correct Swift 6 pattern |
| NSViewRepresentable | `struct` not `class` | SwiftUI best practice |

---

## Component Status

| Component | Status | Notes |
|-----------|--------|-------|
| Research | ✅ Complete | Oracle findings added |
| Plan | ✅ Revised | 6-phase plan with code examples |
| Todo | ✅ Revised | 85 checkboxes, phase-aligned |
| Milkdrop window chrome | ✅ Complete | GEN.bmp sprites, focus states |
| Butterchurn assets | ✅ Bundled | .js files in Butterchurn/ folder |
| WKWebView integration | ⏳ Phase 1 | WKUserScript injection approach |
| Audio data bridge | ⏳ Phase 2-3 | Merge into existing tap, 30 FPS |
| Preset management | ⏳ Phase 4 | Cycling, randomize, history |
| UI integration | ⏳ Phase 5 | Shortcuts, track titles |
| Verification | ⏳ Phase 6 | Local-only validation |

---

## Layer Placement (Three-Layer Pattern)

```
┌─────────────────────────────────────────────────────────────┐
│  PRESENTATION (Views)                                        │
│  ├── ButterchurnWebView.swift (struct NSViewRepresentable)  │
│  └── WinampMilkdropWindow.swift (embeds ButterchurnWebView) │
├─────────────────────────────────────────────────────────────┤
│  BRIDGE (ViewModels)                                         │
│  ├── ButterchurnBridge.swift (WKScriptMessageHandler)       │
│  └── ButterchurnPresetManager.swift (cycling, transitions)  │
├─────────────────────────────────────────────────────────────┤
│  MECHANISM (Models/Audio)                                    │
│  ├── AudioPlayer.swift (extended tap, Butterchurn FFT)      │
│  └── AppSettings.swift (Butterchurn preferences)            │
└─────────────────────────────────────────────────────────────┘
```

---

## Critical Constraints (Oracle Identified)

### Audio Tap Limitation
- AVAudioEngine allows only **one tap per bus**
- Must merge Butterchurn FFT into existing 19-bar tap
- Do NOT add a second tap

### Stream Playback
- `StreamPlayer` (AVPlayer) provides **no PCM data**
- Butterchurn is local playback only for now
- Future: `ButterchurnAudioSource` protocol for SystemAudioCapture

### Script Injection Order
1. `butterchurn.min.js` at `.atDocumentStart`
2. `butterchurnPresets.min.js` at `.atDocumentStart`
3. `bridge.js` at `.atDocumentEnd` (after DOM ready)

### Memory Management
- Must call `removeScriptMessageHandler` in `dismantleNSView`
- Timers must be stopped on cleanup
- Use `@ObservationIgnored` for non-observable state

---

## Files Inventory

### Existing (Ready to Use)

| File | Location | Size |
|------|----------|------|
| butterchurn.min.js | Butterchurn/ | 238 KB |
| butterchurnPresets.min.js | Butterchurn/ | 230 KB |
| bridge.js | Butterchurn/ | 4 KB (to be rewritten) |
| index.html | Butterchurn/ | 3 KB (to be simplified) |

### Window Infrastructure (Complete)

| File | Lines | Status |
|------|-------|--------|
| WinampMilkdropWindow.swift | 31 | ✅ Placeholder view |
| WinampMilkdropWindowController.swift | 52 | ✅ NSWindowController |
| MilkdropWindowChromeView.swift | 162 | ✅ GEN.bmp chrome |

### To Be Created

| File | Layer | Est. Lines |
|------|-------|------------|
| ButterchurnWebView.swift | Presentation | ~80 |
| ButterchurnBridge.swift | Bridge | ~100 |
| ButterchurnPresetManager.swift | Bridge | ~120 |

### To Be Modified

| File | Layer | Changes |
|------|-------|---------|
| AudioPlayer.swift | Mechanism | Add Butterchurn FFT in tap |
| AppSettings.swift | Mechanism | Add Butterchurn settings |
| WinampMilkdropWindow.swift | Presentation | Embed ButterchurnWebView |
| bridge.js | N/A | Rewrite for new architecture |
| index.html | N/A | Simplify for injection |

---

## Technical Specifications

| Spec | Value |
|------|-------|
| FFT Size | 2048 (1024 bins for Butterchurn) |
| Swift→JS Rate | 30 FPS |
| JS Render Rate | 60 FPS (requestAnimationFrame) |
| Window Size | 256×198px content area |
| Preset Transition | 2.7 seconds default |
| Auto-cycle Interval | 15 seconds |
| Total JS Injection | ~472 KB as strings |

---

## Branch Status

- **Current branch:** `feature/butterchurn-integration`
- **Base commit:** `0ff0089` (main)
- **Target:** main (after all 6 phases complete)

---

## Dependencies

| Dependency | Status | Notes |
|------------|--------|-------|
| Milkdrop window chrome | ✅ Available | PR #36 merged |
| AudioPlayer visualizer tap | ✅ Available | Needs FFT merge |
| WKWebView | ✅ Available | macOS 15+ standard |
| WebKit framework | ✅ Available | Already linked |

---

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Injection timing race | Medium | High | bridge.js at documentEnd |
| 30 FPS too slow | Low | Medium | Test and tune |
| Memory leaks | Medium | Medium | Cleanup in dismantleNSView |
| Tap merge breaks 19-bar | Low | High | Test existing analyzer |

---

## Session Log

| Date | Action | Result |
|------|--------|--------|
| 2026-01-05 | Research completed | 4 agents analyzed all sources |
| 2026-01-05 | Task files created | research.md, state.md, plan.md, todo.md |
| 2026-01-05 | Oracle review | 12 findings, all addressed in revised plan |
| 2026-01-05 | Plan revised | 6-phase architecture with Oracle corrections |

---

## Next Action

Begin **Phase 1: WebView + JS Injection**
- Create ButterchurnWebView.swift
- Configure script injection
- Rewrite bridge.js
- Verify static frame renders
