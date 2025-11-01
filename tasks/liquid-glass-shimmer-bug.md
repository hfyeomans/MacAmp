# Liquid Glass Shimmer Bug

**Status:** Deferred (not blocking Phase 2)
**Severity:** Minor (cosmetic)
**Discovered:** 2025-10-29 during AppSettings migration testing

## Symptom

When changing Material Integration setting (Classic/Hybrid/Modern) in Preferences, a wavy shimmer effect starts and **never stops** until app restart.

## Root Cause

**File:** `MacAmpApp/Views/UnifiedDockView.swift`
**Lines:** 118-125, 157-161, 188-192

```swift
// Line 118-124: Shimmer toggle
if settings.enableLiquidGlass && (...) {
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
        materialShimmer = true  // Starts .repeatForever() animation
    }
} else {
    materialShimmer = false  // Does NOT stop .repeatForever()!
}

// Line 159-161: The forever animation
.animation(
    .easeInOut(duration: 6.0).repeatForever(autoreverses: true),
    value: materialShimmer
)
```

**SwiftUI Bug:** `.repeatForever()` animations cannot be stopped by changing the state value. Once started, they continue until view destruction.

## Fix Options

### Option 1: Use Transaction-Based Animation
```swift
withAnimation(.easeInOut(duration: 6.0)) {
    materialShimmer.toggle()
}
// Schedule next toggle with Timer
```

### Option 2: Force View Recreation
```swift
.id("material-\(settings.materialIntegration)-\(settings.enableLiquidGlass)")
// New ID forces SwiftUI to destroy and recreate view
```

### Option 3: Use TimelineView (macOS 26+)
```swift
TimelineView(.animation(minimumInterval: 3.0)) { context in
    let shimmerPhase = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 6.0) / 6.0
    // Use shimmerPhase for opacity (0.0-1.0)
}
```

### Option 4: Use Real Liquid Glass (macOS 26+ only)
```swift
#if available(macOS 26.0, *) {
    content.glassEffect(.regular.interactive())
} else {
    content  // No shimmer on macOS 15
}
```

## Impact

**User Experience:**
- Shimmer starts when changing modes
- Continues indefinitely (cosmetic distraction)
- Requires app restart to stop

**Functionality:**
- ✅ App works normally
- ✅ Settings save/persist correctly
- ✅ No crashes or performance issues

## Recommendation

**Fix in separate commit** after Phase 2 completes. Use Option 2 (view ID) or Option 4 (real Liquid Glass for macOS 26+).

## Related

- Xcode 26 Documentation: `SwiftUI-Implementing-Liquid-Glass-Design.md`
- True Liquid Glass uses `.glassEffect()` modifier (macOS 26+ only)
- Current implementation is custom shimmer workaround for macOS 15
