# Implementation Plan - Memory & CPU Optimization

> **Purpose:** Comprehensive plan for fixing memory leaks, reducing peak memory, eliminating audio skips, and optimizing CPU usage in MacAmp.
> **Branch:** `perf/memory-cpu-optimization`
> **Date:** 2026-02-14
> **Prerequisites:** Read `research.md` for full profiling data and root cause analysis.
> **Oracle Review:** Evaluated by gpt-5.3-codex (reasoningEffort: xhigh) on 2026-02-14. Corrections integrated below.

## 0. Executive Summary

MacAmp has three categories of issues identified via LLDB profiling:
1. **Audio skips** caused by heap allocations on the real-time audio thread (~150-170 allocs/sec)
2. **Peak memory spike** (594 MB) caused by loading two full skins simultaneously at startup
3. **Memory leaks** (47 leaks / 496 KB) from CGImage intermediate buffers during sprite cropping

Current actual footprint (~48 MB) is reasonable for a macOS audio player. The focus is on fixing the audio thread violations, reducing peak memory, and eliminating leaks.

## Oracle Review Summary

Key corrections from Codex gpt-5.3-codex evaluation:
1. **Phase 3.3 already implemented** - `removeVisualizerTapIfNeeded()` already called in `stop()` (line 490) and `eject()` calls `stop()`. Removed from scope.
2. **Lock-free SPSC preferred** over `OSAllocatedUnfairLock` - blocking unfair lock on audio thread risks underruns. Use lock-free single-producer single-consumer pattern with atomic generation/index.
3. **Two cropping loops need fixes** - `parseDefaultSkin()` at SkinManager.swift:161 also has sprite cropping without autorelease pools. Both loops need the fix.
4. **`prepare()` reallocation is minor** - Buffer size is fixed at 2048 (VisualizerPipeline.swift:274), so frame-count churn is unlikely the main allocation source. Deprioritized.
5. **Tap active during pause** - `pause()` doesn't remove tap, so audio thread processing continues during pause. Add pause tap policy.
6. **Quick-win: reuse default skin** - If selected skin IS the default Winamp skin, skip re-parsing.
7. **Canonicalize CGContext to RGBA8** - Don't silently fall back to shared cropped CGImage on context failure; use canonical DeviceRGB + premultiplied alpha.
8. **Sequential sheet processing deferred** - Low ROI vs complexity per Oracle assessment.

---

## 1. Phase 1: Audio Thread Safety (CRITICAL - Fixes Audio Skips)

### 1.1 Pre-allocate Snapshot Buffers

**Problem:** `VisualizerPipeline.makeTapHandler()` creates 5-6 new arrays per callback at 21.5 Hz. This is the primary source of ~150-170 heap allocations/sec on the audio thread.

**Solution:** Add pre-allocated snapshot arrays to `VisualizerScratchBuffers`. All snapshot methods must copy data into pre-existing storage instead of creating new Array instances:

```swift
// In VisualizerScratchBuffers
// Pre-allocated at max expected sizes in init()
private var snapshotRmsBuffer: [Float]      // 20 bars
private var snapshotSpectrumBuffer: [Float]  // 20 bars
private var snapshotWaveformBuffer: [Float]  // 75 oscilloscope samples
private var snapshotButterchurnSpectrum: [Float]  // 1024
private var snapshotButterchurnWaveform: [Float]  // 576

// Fill methods copy data without allocation
func fillSnapshotRms() -> UnsafeBufferPointer<Float> { ... }
func fillSnapshotSpectrum() -> UnsafeBufferPointer<Float> { ... }
```

**Critical:** The `VisualizerData` struct must also avoid carrying fresh Array storage. Use pre-allocated fixed-capacity float buffers that are published to the main thread, not constructed per-callback.

**Files:** `VisualizerPipeline.swift:31-176`, `VisualizerPipeline.swift:488-515`

### 1.2 Replace Task Dispatch with Lock-Free SPSC Pattern

**Problem:** `Task { @MainActor [context, data] in }` allocates a Task object on every audio callback (line 518).

**Solution (Oracle-corrected):** Use a lock-free single-producer single-consumer (SPSC) publish pattern instead of `OSAllocatedUnfairLock` (which can block the real-time thread on contention):

```swift
// Pre-allocated shared storage
final class VisualizerSharedBuffer: @unchecked Sendable {
    // Double-buffer with atomic index swap
    private var buffers: (VisualizerData, VisualizerData)
    private let activeIndex = ManagedAtomic<Int>(0)  // swift-atomics or os_atomic
    private let generation = ManagedAtomic<UInt64>(0)

    // Audio thread: write to inactive buffer, then swap index
    func publish(rms: UnsafeBufferPointer<Float>, spectrum: ...) {
        let writeIdx = 1 - activeIndex.load(ordering: .relaxed)
        // memcpy into buffers[writeIdx] fields
        generation.wrappingIncrement(ordering: .releasing)
        activeIndex.store(writeIdx, ordering: .releasing)
    }

    // Main thread: read from active buffer (no lock)
    func consume() -> VisualizerData? {
        let readIdx = activeIndex.load(ordering: .acquiring)
        // Copy from buffers[readIdx]
    }
}
```

**Alternative (simpler, acceptable for macOS 15+):** Use `os_unfair_lock` with non-blocking `os_unfair_lock_trylock()` semantics - drop the frame on contention rather than blocking the audio thread.

**Main thread polling:** Use a DisplayLink or Timer at ~30 Hz to poll the shared buffer instead of being pushed via Task.

**Files:** `VisualizerPipeline.swift:518`, `VisualizerPipeline.swift:256-289`

### 1.3 Add Pause Tap Policy (Oracle addition)

**Problem:** `pause()` (AudioPlayer.swift:449) does not remove the visualizer tap. The audio engine's mixer continues invoking the tap callback during pause, causing unnecessary processing and allocations.

**Solution:** Remove tap on pause, re-install lazily on resume:

```swift
func pause() {
    // ... existing pause code
    removeVisualizerTapIfNeeded()  // Stop audio thread processing
}

func resumeFromPause() {
    // ... existing resume code
    installVisualizerTapIfNeeded()  // Re-install when playing resumes
}
```

**Files:** `AudioPlayer.swift:449-459`

### 1.4 Estimated Impact
- Audio thread allocations: ~150-170/sec -> ~0/sec (all pre-allocated, lock-free publish)
- Audio skip probability: Eliminated (no heap allocation, no lock contention on audio thread)
- CPU during pause: Reduced (tap removed, no callback processing)

---

## 2. Phase 2: Peak Memory Reduction (HIGH)

### 2.1 Quick-Win: Skip Re-parse for Default Skin (Oracle addition)

**Problem:** If the user's selected skin IS the default Winamp skin, it gets loaded twice: once as default fallback, once as selected skin.

**Solution:** Check if selected skin ID matches default before loading:

```swift
func loadInitialSkin() {
    // ... load default skin for fallback
    if selectedSkinId == "bundled:Winamp" {
        // Reuse already-loaded default skin
        currentSkin = defaultSkin
        return
    }
    // ... load selected skin
}
```

**Files:** `SkinManager.swift:284-330`

### 2.2 Lazy Default Skin Fallback

**Problem:** `SkinManager.init()` loads the entire default Winamp.wsz skin (all sprites) just for fallback.

**Solution:** Two-stage approach:
1. Keep the default skin ZIP data in memory (small, ~200 KB compressed)
2. Only extract + crop specific fallback sprites that are actually missing from the selected skin
3. Cache extracted fallback sprites so they're only created once

```swift
private var defaultSkinArchiveData: Data?  // ~200 KB compressed
private var fallbackSpriteCache: [String: NSImage] = [:]

func fallbackSprite(named: String) -> NSImage? {
    if let cached = fallbackSpriteCache[named] { return cached }
    guard let archiveData = defaultSkinArchiveData else { return nil }
    // Determine which sheet contains this sprite
    // Extract just that sheet from ZIP
    // Crop just this sprite
    // Cache and return
}
```

**Files:** `SkinManager.swift:120-153` (init), `SkinManager.swift:609-751` (applySkinPayload)

**Expected saving:** ~200-400 MB reduction in peak memory at startup

### 2.3 Autorelease Pool in BOTH Sprite Cropping Loops (Oracle-corrected)

**Problem:** CGImage intermediate buffers accumulate during sprite extraction loops. Oracle identified that BOTH `parseDefaultSkin()` (line 161) AND `applySkinPayload()` (line 635) have this issue.

**Solution:** Wrap each sprite crop in an autorelease pool in both locations:

```swift
// In parseDefaultSkin() - SkinManager.swift:169
for sprite in sprites {
    autoreleasepool {
        if let croppedImage = sheetImage.cropped(to: sprite.rect) {
            extractedImages[sprite.name] = croppedImage
        }
    }
}

// In applySkinPayload() - SkinManager.swift:634-700
for sprite in sprites {
    autoreleasepool {
        if let croppedImage = sheetImage.cropped(to: CGRect(...)) {
            extractedImages[sprite.name] = croppedImage
        }
    }
}
```

**Files:** `SkinManager.swift:161-173`, `SkinManager.swift:634-700`

---

## 3. Phase 3: Memory Leak Fixes (MEDIUM)

### 3.1 Protect lockFocus with defer

Defensive hygiene fix (Oracle notes this is not a major leak source in Swift, but good practice):

```swift
let image = NSImage(size: size)
image.lockFocus()
defer { image.unlockFocus() }
// ... drawing code
```

**Files:** `SkinManager.swift:478` (preprocessMainBackground), `SkinManager.swift:547` (createFallbackSprite)

### 3.2 Break CGImage Parent-Child Reference Chain (Oracle-enhanced)

**Problem:** `CGImage.cropping(to:)` returns a CGImage that shares the parent's pixel buffer.

**Solution (Oracle-corrected):** Create an independent copy using a canonical RGBA8 context. Do NOT silently fall back to the shared cropped CGImage on context creation failure:

```swift
func cropped(to rect: CGRect) -> NSImage? {
    guard let cgImage = self.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        AppLog.error(.ui, "ImageSlicing: Failed to get CGImage from NSImage")
        return nil
    }

    let imageBounds = CGRect(x: 0, y: 0, width: CGFloat(cgImage.width), height: CGFloat(cgImage.height))
    if !imageBounds.contains(rect) && !imageBounds.intersects(rect) {
        AppLog.error(.ui, "ImageSlicing: Rect \(rect) is outside image bounds \(imageBounds)")
        return nil
    }

    guard let croppedCGImage = cgImage.cropping(to: rect) else {
        AppLog.error(.ui, "ImageSlicing: CGImage.cropping failed for rect \(rect)")
        return nil
    }

    // Create independent copy to break parent buffer reference
    // Canonicalize to DeviceRGB + premultiplied alpha (RGBA8) per Oracle recommendation
    let width = Int(rect.width)
    let height = Int(rect.height)
    guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
          let context = CGContext(
              data: nil,
              width: width,
              height: height,
              bitsPerComponent: 8,
              bytesPerRow: width * 4,
              space: colorSpace,
              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
          ) else {
        AppLog.error(.ui, "ImageSlicing: Failed to create independent CGContext for \(rect)")
        // Do NOT fall back to shared cropped image - this would retain parent buffer
        return nil
    }
    context.draw(croppedCGImage, in: CGRect(origin: .zero, size: rect.size))
    guard let independentCGImage = context.makeImage() else {
        AppLog.error(.ui, "ImageSlicing: Failed to create independent CGImage for \(rect)")
        return nil
    }
    return NSImage(cgImage: independentCGImage, size: rect.size)
}
```

**Files:** `ImageSlicing.swift:7-27`

**Expected saving:** Releases the parent BMP's full float pixel buffer after cropping. Fixes the 3x 136 KB leaks identified by `leaks` tool.

~~### 3.3 Explicit Visualizer Tap Removal~~ **ALREADY IMPLEMENTED** (Oracle finding)

`removeVisualizerTapIfNeeded()` is already called in `stop()` at AudioPlayer.swift:490, and `eject()` calls `stop()`. No changes needed.

---

## 4. Phase 4: Polish (LOW)

### 4.1 Gate Verbose Logging
Wrap `AppLog.debug(.skin, ...)` calls that dump sprite lists behind appropriate log levels.

### 4.2 Precompute Spectrum Band Coefficients (Oracle addition)
Precompute the Goertzel/spectrum band frequency coefficients used in the tap callback (`VisualizerPipeline.swift:450`) to avoid per-callback computation.

---

## 5. Phase 5: Verification

### 5.1 Before/After Metrics
Re-run profiling tools after each phase:
```bash
ps -o pid,rss,vsz,%mem,%cpu -p <PID>
vmmap --summary <PID>
footprint <PID>
leaks --noContent <PID>
heap <PID>
```

### 5.2 Audio Skip Test
- Play audio continuously for 10+ minutes
- Switch skins during playback
- Monitor for any audio glitches or skips
- Verify visualizer still updates smoothly

### 5.3 Skin Visual Regression Test
- Load all 7 bundled skins + verify visual correctness
- Compare screenshots before/after changes
- Check for alpha/color artifacts from RGBA8 canonicalization

### 5.4 Skin Switching Stress Test
- Switch between 5+ skins rapidly
- Verify memory returns to baseline after each switch
- Check for visual artifacts or missing sprites

---

## 6. Sequencing & Dependencies (Oracle-corrected)

```
Phase 1.1-1.2 (Audio SPSC)  ──>  Phase 1.3 (Pause Tap Policy)
       |                                    |
       v                                    v
Phase 2.1 (Default Skin Quick-Win)    Phase 5.2 (Audio Test)
       |
       v
Phase 2.2-2.3 (Lazy Fallback + Autorelease in BOTH loops)
       |
       v
Phase 3.1-3.2 (lockFocus + CGImage Copy)
       |
       v
Phase 4 (Polish)
       |
       v
Phase 5 (Full Verification)
```

Oracle recommended order:
1. Audio transport fix first (critical, fixes user-facing audio skips)
2. CGImage/cropping fixes in both loops (fixes leaks)
3. Startup dedupe quick-win (easy, safe)
4. Lazy fallback refactor (optional, higher complexity)
5. Sequential sheet processing deferred (low ROI vs complexity)

---

## 7. Risks & Mitigations (Oracle-enhanced)

| Risk | Likelihood | Mitigation |
|------|-----------|------------|
| Lock-free SPSC introduces visual lag | Medium | Poll at 30 Hz via DisplayLink; acceptable for visualizer |
| RGBA8 canonicalization changes color/alpha | Low | Visual snapshot comparison across all bundled skins |
| Lazy fallback extraction misses edge cases | Medium | Keep full fallback as debug-only comparison; test all skins |
| Audio tap reinstall on resume has artifact | Medium | Install tap before playerNode.play() |
| Contended lock stalls audio thread | **Eliminated** | Using lock-free SPSC instead of blocking lock |
| CGContext creation silently fails | Low | **Eliminated** - return nil instead of falling back to shared buffer |

---

## 8. Success Criteria

- [ ] Zero memory leaks reported by `leaks` tool
- [ ] Peak memory < 200 MB during startup
- [ ] Actual footprint < 45 MB at idle
- [ ] Zero audio skips during 10-minute playback test
- [ ] Audio thread allocations: 0/sec (from current ~150-170/sec)
- [ ] All 7 bundled skins render correctly after changes
- [ ] CPU at idle remains 0.0%
- [ ] No audio thread lock contention (lock-free SPSC verified)
