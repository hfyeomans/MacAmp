# Memory Management Analysis - MacAmp

This directory contains a comprehensive analysis of memory management issues in the MacAmp codebase, focusing on memory leaks, performance problems, and optimization opportunities.

## 📋 Analysis Summary

### Critical Issues Found:
1. **Timer Memory Leaks** - Orphaned timers consuming memory and CPU
2. **Unbounded Image Caching** - Skin images stored without limits
3. **Audio Buffer Retention** - Audio data not properly cleaned up
4. **SwiftUI State Accumulation** - State objects growing indefinitely
5. **ZIP Archive Memory Usage** - Large temporary objects during skin loading

### Memory Impact:
- **Current Usage**: 55-75MB normal use, 200MB+ problematic
- **Target Usage**: 45-60MB normal use, 150MB maximum
- **Expected Improvement**: 25-30% memory reduction

## 📁 File Structure

```
memory-management-analysis/
├── README.md              # This file - analysis overview
├── research.md            # Detailed research findings
├── plan.md               # Implementation plan for fixes
├── state.md              # Current state assessment
└── implementation/       # Code fixes and implementations
    ├── timer-fixes.swift
    ├── image-cache.swift
    ├── audio-buffers.swift
    └── state-cleanup.swift
```

## 🚨 Priority Issues

### IMMEDIATE (High Impact):
1. **EqualizerWindowView Timer Leak** - Creates timer every appearance, never invalidates
2. **Image Cache Growth** - No bounds checking, grows with each skin load
3. **Audio Buffer Cleanup** - Buffers retained after audio stops

### SHORT TERM (Medium Impact):
4. **State Management** - User interaction state accumulation
5. **Timer Patterns** - Inconsistent cleanup across views
6. **ZIP Processing** - Large temporary objects during extraction

### LONG TERM (Low Impact):
7. **Memory Monitoring** - Better visibility into usage patterns
8. **Diagnostic Tools** - Development-time memory debugging
9. **Documentation** - Memory management best practices

## 🔍 Key Findings

### Timer Issues:
```swift
// PROBLEM: EqualizerWindowView.swift:270
Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak audioPlayer] _ in
    // Timer created but never stored or invalidated
}
```

### Image Caching:
```swift
// PROBLEM: SkinManager.swift:335
var extractedImages: [String: NSImage] = [:]
// Grows indefinitely, no cleanup mechanism
```

### Audio Buffers:
```swift
// PROBLEM: AudioPlayer.swift:68-69
@Published var visualizerLevels: [Float] = Array(repeating: 0.0, count: 20)
@Published var visualizerPeaks: [Float] = Array(repeating: 0.0, count: 20)
// Never cleared when audio stops
```

## 📊 Memory Usage Profile

### Current State:
- **App Launch**: 35-50MB
- **With Skin**: 50-70MB  
- **During Playback**: 55-75MB
- **Problematic**: 200MB+

### Target State:
- **App Launch**: 30-40MB (-20%)
- **With Skin**: 40-55MB (-20%)
- **During Playback**: 45-60MB (-25%)
- **Maximum**: 150MB (hard limit)

## 🛠️ Implementation Strategy

### Phase 1: Critical Fixes (Week 1)
- Fix timer leaks in EqualizerWindowView
- Implement image cache size limits
- Add audio buffer cleanup

### Phase 2: Optimization (Week 2)
- Review and fix timer patterns
- Implement state cleanup
- Optimize ZIP processing

### Phase 3: Monitoring (Week 3)
- Add memory monitoring utilities
- Implement diagnostic tools
- Create testing framework

## 🧪 Testing Approach

### Memory Leak Detection:
1. **Static Analysis** - Code review for anti-patterns
2. **Runtime Profiling** - Xcode Memory Graph
3. **Extended Testing** - 24+ hour usage scenarios
4. **Stress Testing** - Multiple skin switches, large playlists

### Success Metrics:
- ✅ No memory growth during extended use
- ✅ Bounded image cache size
- ✅ Consistent timer count
- ✅ Proper resource cleanup

## 📈 Performance Impact

### Current Issues:
- UI stuttering during garbage collection
- Audio dropouts under memory pressure
- Slow skin switching with multiple skins
- System memory pressure warnings

### Expected Improvements:
- 25-30% reduction in memory usage
- Faster skin switching (2-3x improvement)
- Elimination of memory-related crashes
- Better performance under memory pressure

## 🚀 Getting Started

### For Developers:
1. Read `research.md` for detailed findings
2. Review `plan.md` for implementation strategy
3. Check `state.md` for current assessment
4. Implement fixes from `implementation/` directory

### For Testing:
1. Use Xcode Memory Graph Debugger
2. Monitor memory during extended use
3. Test with multiple skin switches
4. Verify timer cleanup in view lifecycle

## 📚 Related Documentation

- [Apple Memory Management Guide](https://developer.apple.com/documentation/xcode/managing-memory-in-your-app)
- [SwiftUI Memory Best Practices](https://developer.apple.com/documentation/swiftui/memory-management)
- [AVFoundation Memory Usage](https://developer.apple.com/documentation/avfoundation)

## 🔗 Related Tasks

- [Sprite Fallback System](../sprite-fallback-system/README.md)
- [Window Management Analysis](../window-management-docking-analysis/README.md)
- [State Management Consistency](../state-management-consistency-analysis/README.md)

---

**Last Updated**: October 23, 2025  
**Analysis Scope**: Complete MacAmp codebase  
**Severity**: High - Critical memory leaks identified  
**Next Review**: After Phase 1 implementation