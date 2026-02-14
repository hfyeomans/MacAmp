# Task State - Memory & CPU Optimization

> **Purpose:** Track the current state of this optimization effort including progress, blockers, and metrics.
> **Last Updated:** 2026-02-14 (Verification complete)

## Current Phase: COMPLETE (All phases verified)

- [x] Branch created: `perf/memory-cpu-optimization`
- [x] LLDB profiling completed (PID 54652)
- [x] Code analysis completed (all key files reviewed)
- [x] Web research completed (macOS benchmarks, Core Graphics leaks, audio thread best practices)
- [x] Previous task research reviewed (`tasks/memory-management-analysis/`)
- [x] Research documented in `research.md`
- [x] Plan documented in `plan.md`
- [x] Plan evaluated by Oracle (gpt-5.3-codex, xhigh reasoning)
- [x] Implementation started
- [x] Phase 1: Audio thread safety (Tasks #1, #2, #3) - COMPLETE
- [x] Phase 2: Peak memory reduction (Tasks #4, #5) - COMPLETE
- [x] Phase 3: Memory leak fixes (Tasks #6, #7) - COMPLETE
- [x] Phase 5: Verification (#8) - COMPLETE

## Baseline Metrics

### Raw Profiling Numbers (Debug builds with TSan)

| Metric | Before (PID 54652) | After (PID 170) | Verification (PID 82863) |
|--------|-------------------|-----------------|--------------------------|
| `footprint` reported | 264.9 MB | 301 MB | 293 MB |
| `footprint` peak | 594.4 MB | 553 MB | 554 MB |
| Sanitizer overhead | ~217 MB | ~262 MB | ~254 MB |
| Heap nodes | 86,379 / 3.8 MB | 71,416 / 2.7 MB | 72,365 / 2.7 MB |
| Leaks | 47 / 508,256 bytes | 0 / 0 bytes | 0 / 0 bytes |

### Actual App Metrics (Sanitizer subtracted)

| Metric | Before | After | Delta | Status |
|--------|--------|-------|-------|--------|
| Actual Footprint | **~48 MB** | **~39 MB** | **-19%** | IMPROVED |
| Actual Peak | **~377 MB** | **~291 MB** | **-23%** | IMPROVED |
| Leaked Bytes | **496 KB (47)** | **0 (0)** | **-100%** | FIXED |
| Heap Nodes | **86,379** | **71,416** | **-17%** | IMPROVED |
| Heap Bytes | **3.8 MB** | **2.7 MB** | **-29%** | IMPROVED |
| Audio Thread Allocs/sec | **~150-170** | **0** | **-100%** | FIXED (by design) |
| CPU at Idle | 0.0% | 0.0% | — | MAINTAINED |

### Sanitizer Overhead Explained

The TSan (Thread Sanitizer) runtime is a **debug-only** instrumentation library. It is:
- Enabled in the Xcode scheme for Debug builds (`-enableThreadSanitizer YES`)
- Embedded as `libclang_rt.tsan_osx_dynamic.dylib` in the app's Frameworks/
- Adds ~217-262 MB of shadow memory for thread-safety tracking
- **Completely removed** in Release and Archive (distribution) builds
- Has zero presence in the `.app` bundle distributed via DMG or App Store

In production (Release build), the actual footprint would be ~39 MB steady-state with ~291 MB peak during skin loading. This is competitive with comparable macOS audio players (VLC ~80 MB, Colibri ~20-30 MB, Swinsian ~40-60 MB).

## LLDB Session Info
- **Original Session:** 02e3e46b-652c-4227-a9d8-63d28e78b6af (PID 54652, BEFORE metrics)
- **Post-Implementation:** 497f60be-11e5-4c4e-b75e-8c84986d217d (PID 170, AFTER metrics)
- **Final Verification:** CLI `footprint` + `leaks` on PID 82863 (fresh launch, all metrics confirmed)
- **Build:** Debug with TSan (scheme-level setting; removed in Release/Archive)
- **Profiling Tools Used:** `footprint`, `leaks`

## Key Decisions
1. TSan removed from debug builds due to AppKit false positives and LLDB interference
2. BMP format must be retained for Winamp skin compatibility
3. Default skin fallback mechanism is architecturally necessary (some skins miss sprites)
4. Audio tap frequency of 21.5 Hz is correct for visualization smoothness
5. `os_unfair_lock_trylock()` chosen over blocking lock or atomic SPSC (Oracle recommendation)
6. Lazy fallback extraction chosen over keeping full default skin in memory
7. CGContext copies return nil on failure (no silent fallback to shared buffer)

## Blockers
- None currently identified

## Known Cosmetic Issues

All cosmetic issues have been resolved:
- ~~Stale visualizer data during video playback~~ — FIXED (commit 0887c28): Added `clearData()` method on `VisualizerPipeline`, called from `removeVisualizerTapIfNeeded()` in `AudioPlayer`.

## Oracle Final Code Review (gpt-5.3-codex, xhigh reasoning)

### Findings Addressed
1. **HIGH — removeTap() nil-mixer early return skips timer cleanup:** When `mixerNode` weak ref is nil but `tapInstalled` is true, the old guard returned early without invalidating the poll timer. **FIXED:** Restructured guard to check `tapInstalled` only, handle nil mixer gracefully.
2. **MEDIUM — consume() allocates under lock:** Array copies (`Array(rms.prefix(...))`) happen while holding the lock. **ACCEPTED:** Audio thread uses non-blocking `trylock` so is never affected. Main thread lock hold time is bounded (5 small array copies at 30 Hz). Double-buffering would add complexity for minimal gain.
3. **LOW — MainActor.assumeIsolated in timer callback:** Timer callback uses `dispatchPrecondition(.main)` before `MainActor.assumeIsolated`. Safe in practice as `Timer.scheduledTimer` always fires on main run loop.
4. **LOW — frameCount > 4096 causes reallocation:** By design — AVAudioEngine buffer size is 2048, the 4096 cap is a safety net that should never execute in normal operation.

### Overall Assessment
- SPSC design is sound (single producer tap + single consumer timer + generation counter)
- `@unchecked Sendable` usages justified by confinement/locking
- Audio thread path is allocation-free in steady state
- Tap lifecycle changes are functionally correct

---

## Architecture Changes

### 1. Audio Visualization Data Transport (BEFORE)

```
┌──────────────────────────────────────────────────────────────┐
│                    AUDIO THREAD (real-time)                   │
│                                                              │
│  AVAudioEngine Tap Callback (~21.5 Hz)                       │
│  ┌────────────────────────────────────────────────────────┐  │
│  │ 1. scratch.prepare(buffer)                             │  │
│  │ 2. FFT + Goertzel computation                          │  │
│  │ 3. snapshotRms()          → NEW Array  ⚠️ ALLOC       │  │
│  │ 4. snapshotSpectrum()     → NEW Array  ⚠️ ALLOC       │  │
│  │ 5. waveformSnapshot       → NEW Array  ⚠️ ALLOC       │  │
│  │    (stride.prefix.map)                                 │  │
│  │ 6. butterchurnSpectrum    → NEW Array  ⚠️ ALLOC       │  │
│  │ 7. butterchurnWaveform    → NEW Array  ⚠️ ALLOC       │  │
│  │ 8. VisualizerData(...)    → struct w/ 5 arrays         │  │
│  │ 9. Task { @MainActor }    → NEW TASK   ⚠️ ALLOC+ARC   │  │
│  └────────────────┬───────────────────────────────────────┘  │
│                   │                                          │
│         ~7-8 heap allocations per callback                   │
│         = ~150-170 allocations/second                        │
│         = ARC ref counting = potential lock acquisition      │
│         = AUDIO THREAD STALL = SKIP                          │
└───────────────────┼──────────────────────────────────────────┘
                    │ Task dispatch (heap alloc)
                    ▼
┌──────────────────────────────────────────────────────────────┐
│                    MAIN THREAD                                │
│  Task { @MainActor in                                        │
│      pipeline.visualizerData = data   ← triggers @Observable │
│      pipeline.butterchurnFrame = ...  ← triggers @Observable │
│  }                                                           │
└──────────────────────────────────────────────────────────────┘
```

**Problems:** 7-8 heap allocations per callback on the audio thread. Any allocation can trigger ARC reference counting (which acquires locks), potentially stalling the real-time audio thread and causing buffer underruns (audible skips).

### 1b. Audio Visualization Data Transport (AFTER)

```
┌──────────────────────────────────────────────────────────────┐
│                    AUDIO THREAD (real-time)                   │
│                                                              │
│  AVAudioEngine Tap Callback (~21.5 Hz)                       │
│  ┌────────────────────────────────────────────────────────┐  │
│  │ 1. scratch.prepare(buffer)          ← no alloc         │  │
│  │ 2. FFT + Goertzel computation       ← no alloc         │  │
│  │ 3. sharedBuffer.tryPublish(scratch) ← no alloc         │  │
│  │    ├─ os_unfair_lock_trylock()   (non-blocking)        │  │
│  │    ├─ if locked: memcpy into pre-allocated arrays      │  │
│  │    ├─ waveform: direct stride copy (no map/iterator)   │  │
│  │    ├─ generation += 1                                  │  │
│  │    └─ unlock                                           │  │
│  │    └─ if contention: drop frame (inaudible, invisible) │  │
│  └────────────────┬───────────────────────────────────────┘  │
│                   │                                          │
│         ZERO heap allocations per callback                   │
│         trylock = non-blocking (never stalls audio thread)   │
└───────────────────┼──────────────────────────────────────────┘
                    │ Shared memory (VisualizerSharedBuffer)
                    │ Pre-allocated arrays, atomic generation
                    ▼
┌──────────────────────────────────────────────────────────────┐
│                    MAIN THREAD (30 Hz Timer)                  │
│                                                              │
│  pollVisualizerData() ← Timer.scheduledTimer @ 30 Hz        │
│  ┌────────────────────────────────────────────────────────┐  │
│  │ 1. sharedBuffer.consume()                              │  │
│  │    ├─ os_unfair_lock_lock()    (OK to block here)      │  │
│  │    ├─ check generation > lastConsumed                   │  │
│  │    ├─ create VisualizerData from pre-allocated storage  │  │
│  │    └─ unlock, return data                              │  │
│  │ 2. self.visualizerData = data  ← triggers @Observable  │  │
│  │ 3. self.butterchurnFrame = ... ← triggers @Observable  │  │
│  └────────────────────────────────────────────────────────┘  │
│                                                              │
│  Array allocation happens HERE (main thread = safe)          │
└──────────────────────────────────────────────────────────────┘
```

**Key change:** Zero allocations on the audio thread. All Array creation happens on the main thread (30 Hz poll timer), where heap allocations and ARC operations are safe. The `os_unfair_lock_trylock()` is non-blocking - if the main thread holds the lock, the audio thread simply drops that frame (imperceptible at 21.5 Hz).

### 2. Skin Loading Pipeline (BEFORE)

```
┌─────────────────────────────────────────────────────────────┐
│                    APP STARTUP                                │
│                                                              │
│  SkinManager.loadInitialSkin()                               │
│  ┌───────────────────────────────────────────────────────┐   │
│  │ Step 1: loadDefaultSkinIfNeeded()                     │   │
│  │   ├─ SkinArchiveLoader.load(Winamp.wsz)               │   │
│  │   │   └─ Extract ALL BMP sheets from ZIP              │   │
│  │   ├─ parseDefaultSkin(payload)                        │   │
│  │   │   ├─ For EACH sheet: NSImage(data:) ⚠️ PEAK      │   │
│  │   │   └─ For EACH sprite: crop → NSImage  ⚠️ PEAK    │   │
│  │   └─ defaultSkin = Skin(images: ~200 sprites)         │   │
│  │       └─ ~15-20 MB of NSImages PERMANENTLY in memory  │   │
│  │                                                       │   │
│  │ Step 2: switchToSkin(selectedSkin)                     │   │
│  │   ├─ SkinArchiveLoader.load(selected.wsz)             │   │
│  │   │   └─ Extract ALL BMP sheets from ZIP  ⚠️ DOUBLE   │   │
│  │   ├─ applySkinPayload(payload)                        │   │
│  │   │   ├─ For EACH sheet: NSImage(data:)               │   │
│  │   │   └─ For EACH sprite: crop → NSImage              │   │
│  │   └─ currentSkin = Skin(images: ~200 sprites)         │   │
│  │                                                       │   │
│  │ PEAK MEMORY: default sprites + selected sprites       │   │
│  │              + intermediate CGImage buffers            │   │
│  │              + float pixel backing stores              │   │
│  │              = ~594 MB PEAK                            │   │
│  └───────────────────────────────────────────────────────┘   │
│                                                              │
│  At rest: defaultSkin (~15-20 MB) + currentSkin (~15-20 MB)  │
│         = ~30-40 MB of sprite images always in memory        │
└─────────────────────────────────────────────────────────────┘
```

### 2b. Skin Loading Pipeline (AFTER)

```
┌─────────────────────────────────────────────────────────────┐
│                    APP STARTUP                                │
│                                                              │
│  SkinManager.loadInitialSkin()                               │
│  ┌───────────────────────────────────────────────────────┐   │
│  │ Step 1: loadDefaultSkinIfNeeded()                     │   │
│  │   ├─ SkinArchiveLoader.load(Winamp.wsz)               │   │
│  │   └─ defaultSkinPayload = payload  (~200 KB ZIP data) │   │
│  │       └─ NO sprite parsing, NO NSImage creation       │   │
│  │       └─ Sprites extracted LAZILY on demand            │   │
│  │                                                       │   │
│  │ Step 2a: IF selected == "bundled:Winamp"              │   │
│  │   └─ parseDefaultSkinFully(payload)                   │   │
│  │       ├─ Parse sprites with autoreleasepool            │   │
│  │       ├─ Populate defaultSkinSpriteCache              │   │
│  │       └─ currentSkin = Skin(...)                       │   │
│  │       └─ PEAK: only ONE skin parsed (not two)         │   │
│  │                                                       │   │
│  │ Step 2b: IF selected != default                       │   │
│  │   ├─ switchToSkin(selectedSkin)                        │   │
│  │   ├─ applySkinPayload() with autoreleasepool per crop │   │
│  │   │   └─ Missing sheets → lazy fallback:              │   │
│  │   │       fallbackSpritesFromDefaultSkin()             │   │
│  │   │       ├─ Extract ONLY the missing sheet from ZIP  │   │
│  │   │       ├─ Cache in defaultSkinSpriteCache          │   │
│  │   │       └─ Only ~5-10 sprites per missing sheet     │   │
│  │   └─ currentSkin = Skin(...)                           │   │
│  │                                                       │   │
│  │ PEAK MEMORY: payload (~200 KB) + ONE skin's sprites   │   │
│  │              + autoreleasepool cleans intermediates    │   │
│  │              = MUCH LOWER PEAK                        │   │
│  └───────────────────────────────────────────────────────┘   │
│                                                              │
│  At rest: payload (~200 KB) + spriteCache (lazy, partial)    │
│         + currentSkin (~15-20 MB)                            │
│         = ~15-20 MB total (was ~30-40 MB)                    │
└─────────────────────────────────────────────────────────────┘
```

### 3. CGImage Cropping Pipeline (BEFORE vs AFTER)

```
BEFORE:
  NSImage.cropped(to: rect)
  ├─ self.cgImage(forProposedRect:)  → creates float-format backing store
  ├─ cgImage.cropping(to:)           → child CGImage SHARES parent buffer
  └─ NSImage(cgImage:, size:)        → wraps child, parent buffer RETAINED
      └─ Parent's full float pixel buffer stays alive as long as
         ANY cropped sprite references it (~136 KB per parent sheet)

AFTER:
  NSImage.cropped(to: rect)
  ├─ self.cgImage(forProposedRect:)  → creates float-format backing store
  ├─ cgImage.cropping(to:)           → child CGImage references parent
  ├─ CGContext(sRGB, RGBA8, 8bpc)    → independent context
  ├─ context.draw(croppedCGImage)    → copies pixels into new buffer
  ├─ context.makeImage()             → independent CGImage (no parent ref)
  └─ NSImage(cgImage:, size:)        → wraps independent image
      └─ Parent float buffer is released when autorelease pool drains
      └─ Each sprite owns only its own pixel data (~width*height*4 bytes)
```

### 4. Pause Tap Policy (NEW)

```
BEFORE:
  play()  → installVisualizerTapIfNeeded()
  pause() → (tap stays active, callbacks continue at 21.5 Hz)
  stop()  → removeVisualizerTapIfNeeded()

AFTER:
  play()  → installVisualizerTapIfNeeded()  + startPollTimer()
  pause() → removeVisualizerTapIfNeeded()   ← NEW
  stop()  → removeVisualizerTapIfNeeded()
            (removeTap also stops poll timer)
```

---

## Files Modified

| File | Changes | Task(s) |
|------|---------|---------|
| `VisualizerPipeline.swift` | Complete rewrite: SPSC shared buffer, pre-allocated arrays, poll timer, zero audio-thread allocations | #1, #2 |
| `AudioPlayer.swift` | Added `removeVisualizerTapIfNeeded()` in `pause()` | #3 |
| `SkinManager.swift` | Lazy payload storage, on-demand fallback extraction, autoreleasepool, lockFocus defer, default skin reuse | #4, #5, #6, #7 |
| `ImageSlicing.swift` | Independent RGBA8 CGContext copy, nil on failure (no shared-buffer fallback) | #7 |
