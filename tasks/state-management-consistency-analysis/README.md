# State Management Consistency Analysis - MacAmp

## Overview

Latest review confirms several state management risks that affect stability and UX, but the earlier write-up overstated concurrency hazards. The focus now is on clarifying core state flows, tightening validation, and ensuring feedback loops reset correctly. The most important targets are `AudioPlayer`, `SkinManager`, and `AppSettings`.

## 🚨 Critical Issues (Fix Immediately)

### 1. AudioPlayer State Clarity - **INCONSISTENT BEHAVIOR RISK**
**File:** `MacAmpApp/Audio/AudioPlayer.swift`  
**Problem:** Playback flow relies on multiple booleans (`isPlaying`, `isPaused`, `wasStopped`, `trackHasEnded`, etc.), making transitions difficult to audit.  
**Impact:** Conflicting flags create edge cases after seeks/ejects and make regressions likely during future changes.  
**Fix:** Replace the boolean matrix with a single enum-driven state machine and audit transitions (play, pause, stop, seek, completion).

### 2. SkinManager Loading Lifecycle - **STATE STALENESS RISK**
**File:** `MacAmpApp/ViewModels/SkinManager.swift`  
**Problem:** Errors remain in `loadingError` even after successful loads; heavy parsing still runs on the main actor.  
**Impact:** Users see stale error banners and the UI stalls for large imports.  
**Fix:** Clear `loadingError` on success and move heavyweight parsing to a background worker that safely hops back to the main actor.

### 3. AppSettings Persistence - **DATA LOSS RISK**
**File:** `MacAmpApp/Models/AppSettings.swift`  
**Problem:** `userSkinsDirectory` silently ignores directory-creation failures; no validation of UserDefaults payloads.  
**Impact:** Skins can fail to install without feedback and corrupt defaults remain undetected.  
**Fix:** Handle file-system errors explicitly and validate persisted values before publishing them.

## ⚠️ High Priority Issues

### 4. Skin Import Guardrails - **ROBUSTNESS RISK**
**File:** `MacAmpApp/ViewModels/SkinManager.swift`  
**Problem:** Import logic trusts incoming archive paths and size.  
**Impact:** Malformed or oversized skins can lock the UI or cause crashes.  
**Fix:** Add path validation, sane size limits, and targeted user feedback.

### 5. UserDefaults Write Throttling - **PERFORMANCE RISK**
**File:** `MacAmpApp/ViewModels/DockingController.swift`  
**Problem:** Layout writes occur on every `panes` mutation with no coalescing.  
**Impact:** Bursty changes can thrash UserDefaults and slow UI updates.  
**Fix:** Debounce or batch persistence updates and surface failure logging.

### 6. EQF Parsing Validation - **CORRUPTION RISK**
**File:** `MacAmpApp/Models/EQF.swift`  
**Problem:** Parser lacks strict bounds checks and value clamps.  
**Impact:** Malformed EQF files can produce undefined presets.  
**Fix:** Add length checks, guard clauses, and range clamping around parsed values.

## 📋 Complete Analysis Files

- **`analysis.md`** - Detailed technical analysis of all issues
- **`fixes.md`** - Implementation plan with code examples

## 🔧 Quick Fix Summary

### Immediate Actions (This Week)

1. **Refactor AudioPlayer State**
   ```swift
   enum PlaybackState {
       case stopped, playing, paused, seeking, ended
   }
   ```

2. **Reset SkinManager Errors**
   ```swift
   loadingError = nil
   ```

3. **Harden AppSettings Persistence**
   ```swift
   guard let directory = try? ensureSkinsDirectory() else { return nil }
   ```

> **Auto EQ Note:** Automatic per-track EQ generation via the EQ window's “Auto” button is temporarily disabled due to repeated crashes during background analysis. See `notes/auto-eq-issues.md` for the error log and follow-up plan.

## 🎯 Risk Assessment

| Component | Risk Level | Impact | Priority |
|-----------|------------|--------|----------|
| AudioPlayer | Critical | Playback regressions | P0 |
| SkinManager | Critical | Stale UI + blocking | P0 |
| AppSettings | High | Missing skins / bad defaults | P1 |
| DockingController | Medium | Perf + persistence stress | P1 |
| EQF Parser | Medium | Invalid presets | P2 |

## 📊 Issue Statistics

- **Total Issues Found:** 16
- **Critical Issues:** 2
- **High Priority:** 5
- **Medium Priority:** 6
- **Low Priority:** 3

## 🚀 Implementation Timeline

### Week 1: Critical Fixes
- [ ] AudioPlayer state machine refactor
- [ ] SkinManager error-reset and background parsing
- [ ] AppSettings persistence validation

### Week 2: High Priority
- [ ] Skin import guardrails
- [ ] UserDefaults debouncing and logging
- [ ] EQF parsing validation

### Week 3: Medium Priority
- [ ] Input validation
- [ ] Error handling improvements
- [ ] Memory leak fixes

### Week 4: Testing & Validation
- [ ] Unit tests
- [ ] Integration tests
- [ ] Stress testing

## 🧪 Testing Strategy

1. **Unit Tests** for all state management logic  
2. **Concurrency Tests** for async parsing hand-offs  
3. **Stress Tests** for heavy asset imports and playback loops  
4. **Integration Tests** for component interactions

## 📝 Next Steps

1. **Review** the detailed analysis in `analysis.md`  
2. **Prioritize** critical fixes for immediate implementation  
3. **Create** branches for each fix  
4. **Implement** fixes with proper testing  
5. **Monitor** for regressions after deployment
