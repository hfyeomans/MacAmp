# Window Management and Docking Logic Analysis

## Overview

This analysis identified **12 critical race conditions and logic problems** in MacAmp's window management and docking systems that could cause crashes, visual glitches, and inconsistent user experience.

## Key Findings Summary

### 🚨 Critical Issues (App Stability)

1. **Coordinate System Race Condition** - `WindowSnapManager.swift:41-48`
   - Non-atomic virtual screen calculations during multi-monitor changes
   - **Impact:** Windows can disappear or jump to invalid positions

2. **Window Reference Lifecycle Issue** - `WindowSnapManager.swift:82-88`
   - Unsafe iteration over weak window references
   - **Impact:** App crashes during window operations

3. **Feedback Loop Race Condition** - `WindowSnapManager.swift:64-68`
   - Multiple `isAdjusting` flags create infinite loops
   - **Impact:** Windows oscillate between positions

4. **NSWindow Delegate Memory Leak** - `WindowSnapManager.swift:28-29`
   - Strong reference cycle between manager and windows
   - **Impact:** Memory leaks, degraded performance

5. **Missing Screen Configuration Handling** - `WindowSnapManager.swift`
   - No handling for display parameter changes
   - **Impact:** Windows become inaccessible after screen changes

### ⚠️ High Priority Issues (User Experience)

6. **Dock State Persistence Race Condition** - `DockingController.swift:53-61`
   - Concurrent UserDefaults writes can corrupt data
   - **Impact:** Lost dock configurations

7. **Window Ordering Logic Problem** - `DockingController.swift:20-26`
   - Fixed position calculation ignores dynamic visibility
   - **Impact:** Incorrect dock layout and gaps

8. **Slider Input Validation Race Condition** - `BalanceSliderView.swift:44-51`
   - Rapid drag updates exceed bounds before clamping
   - **Impact:** Audio control issues, visual desync

9. **Animation State Corruption** - `UnifiedDockView.swift:108-126`
   - Non-atomic animation state during rapid mode changes
   - **Impact:** Visual glitches, stuck animations

## Files Affected

| File | Issues | Severity |
|------|--------|----------|
| `WindowSnapManager.swift` | 5 | 🚨 Critical |
| `DockingController.swift` | 2 | ⚠️ High |
| `BalanceSliderView.swift` | 1 | ⚠️ High |
| `UnifiedDockView.swift` | 1 | ⚠️ High |
| `WinampVolumeSlider.swift` | 1 | ⚠️ High |
| `DockingContainerView.swift` | 1 | ⚠️ High |

## Trigger Scenarios

### Most Likely to Cause Crashes:
- Connecting/disconnecting external monitors
- Rapid window open/close operations
- System memory pressure
- Multiple simultaneous window movements

### Most Likely to Cause User Issues:
- Rapid toggling of dock panes
- Quick slider movements during audio playback
- Changing appearance modes rapidly
- App termination during state changes

## Recommended Fix Priority

### Immediate (Critical Stability)
1. Fix coordinate system atomicity
2. Implement proper window lifecycle management  
3. Add screen configuration change handling
4. Fix NSWindow delegate memory leaks

### Short-term (User Experience)
5. Fix dock state persistence
6. Improve slider input validation
7. Fix animation state management
8. Correct window ordering logic

## Testing Recommendations

### Stress Tests:
- **Multi-monitor test:** Connect/disconnect monitors while dragging windows
- **Rapid operations test:** Quick succession of window operations
- **Memory test:** Extended runtime with frequent window changes
- **Slider test:** Rapid control movements during system load

### Regression Tests:
- **Configuration test:** Display setting changes while app running
- **Persistence test:** Dock state changes with app restart
- **Animation test:** Rapid appearance mode switching

## Implementation Notes

- Most fixes require atomic operations or proper synchronization
- Memory management issues need weak reference patterns
- State persistence needs debouncing or atomic writes
- Animation systems need proper state cleanup

## Impact Assessment

Without fixes:
- **High risk** of app crashes during normal use
- **Medium risk** of data loss (dock configurations)
- **High risk** of poor user experience (visual glitches)

With fixes:
- **Significantly improved** app stability
- **Consistent** window behavior across all scenarios
- **Better** memory management and performance
- **Reliable** state persistence and restoration

---

**Next Steps:** Review the detailed analysis in `analysis.md` for specific code fixes and implementation examples.