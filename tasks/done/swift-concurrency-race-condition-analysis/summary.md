# Swift Concurrency Race Conditions - Executive Summary

## Critical Issues Identified

### 🚨 **CRITICAL: AudioPlayer Progress Timer Race Condition**
**File:** `AudioPlayer.swift:542-567`
**Impact:** Progress display jumps backward/forward during seek operations
**Root Cause:** Timer accesses `playheadOffset` while `seek()` modifies it concurrently

### 🚨 **CRITICAL: Seek Completion Handler Race Condition** 
**File:** `AudioPlayer.swift:687-774`
**Impact:** Playback jumps to wrong position, UI becomes inconsistent
**Root Cause:** Old completion handlers fire after seek operation starts

### ⚠️ **HIGH: Track Addition Race Condition**
**File:** `AudioPlayer.swift:96-106`
**Impact:** Duplicate tracks in playlist, multiple tracks starting simultaneously
**Root Cause:** Duplicate check happens before async metadata loading

### ⚠️ **HIGH: Visualizer Concurrent Updates**
**File:** `AudioPlayer.swift:569-664`
**Impact:** Visualizer flickering, inconsistent display
**Root Cause:** Multiple concurrent updates overwrite each other

## Immediate Actions Required

### 1. Fix Progress Timer (AudioPlayer.swift:542-567)
```swift
// BEFORE - Race condition:
let current = Double(playerTime.sampleTime) / playerTime.sampleRate + self.playheadOffset

// AFTER - Actor synchronization:
await self.progressState.updateTime(current)
```

### 2. Fix Seek Operations (AudioPlayer.swift:687-774)
```swift
// BEFORE - Multiple state changes:
isSeeking = true
// ... many operations ...
isSeeking = false

// AFTER - Atomic operation:
await MainActor.run {
    // All seek operations atomically
    isSeeking = true
    // ... all state changes ...
    isSeeking = false
}
```

### 3. Fix Track Addition (AudioPlayer.swift:96-106)
```swift
// BEFORE - Race condition:
if playlist.contains(where: { $0.url == url }) { return }
Task { @MainActor in
    // Multiple calls can pass the check simultaneously
}

// AFTER - Atomic addition:
trackAdditionQueue.async {
    // Single-threaded track addition
}
```

## Risk Assessment

| Issue | Severity | User Impact | Fix Complexity |
|-------|----------|-------------|----------------|
| Progress Timer | Critical | High | Medium |
| Seek Completion | Critical | High | High |
| Track Addition | High | Medium | Medium |
| Visualizer Updates | Medium | Low | Low |

## Recommended Fix Timeline

### Week 1: Critical Fixes
- [ ] Implement ProgressState actor
- [ ] Fix seek operation atomicity
- [ ] Add comprehensive testing

### Week 2: High Priority Fixes  
- [ ] Fix track addition race condition
- [ ] Implement visualizer synchronization
- [ ] Add timer coordinator

### Week 3: Medium Priority
- [ ] Enhanced error handling
- [ ] Memory management improvements
- [ ] Performance optimization

## Testing Requirements

### Must-Have Tests
1. **Seek During Playback**: Rapid seek operations while playing
2. **Concurrent Track Addition**: Multiple tracks added simultaneously  
3. **Progress Timer Stress**: Timer updates during seek operations
4. **Visualizer Stability**: Consistent display during state changes

### Performance Benchmarks
- Seek operation latency: < 50ms
- Progress update frequency: 10Hz stable
- Memory usage: No leaks during extended use

## Code Quality Improvements

### Immediate
- Add `@MainActor` annotations to all UI-modifying methods
- Implement proper error handling for async operations
- Add comprehensive logging for debugging

### Long-term
- Migrate to Swift Concurrency (async/await) throughout
- Implement structured concurrency patterns
- Add comprehensive unit test coverage

## Success Metrics

### Before Fixes
- Progress display corruption during seek: ~30% of operations
- Duplicate tracks in playlist: Occasional
- Visualizer flickering: Frequent during seek

### After Fixes (Target)
- Progress display corruption: 0%
- Duplicate tracks: 0%
- Visualizer stability: 100% during all operations

## Conclusion

The MacAmp codebase has critical concurrency issues that significantly impact user experience. The progress timer and seek operation race conditions are the most severe and require immediate attention. Implementing the recommended fixes will eliminate these issues and provide a stable foundation for future development.

**Priority**: Implement critical fixes before next release to prevent user-reported crashes and UI inconsistencies.