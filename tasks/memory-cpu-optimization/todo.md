# Task List - Memory & CPU Optimization

> **Purpose:** Track all work items for this optimization effort, ordered by priority/severity.
> **Branch:** `perf/memory-cpu-optimization`
> **Oracle Review:** Corrections integrated from gpt-5.3-codex evaluation on 2026-02-14.
> **Last Updated:** 2026-02-14 (Phase 1-3 implementation complete)

## Phase 1: Critical - Audio Thread Safety (fixes audio skips)

- [x] **1.1** Pre-allocate snapshot buffers in `VisualizerScratchBuffers`
  - Added `VisualizerSharedBuffer` class with pre-allocated arrays for all 5 data channels
  - `tryPublish()` uses memcpy via `withUnsafeBufferPointer` (zero allocation on audio thread)
  - Waveform downsampling done via direct stride copy (no map/iterator)
  - Files: `VisualizerPipeline.swift:36-141`

- [x] **1.2** Replace `Task { @MainActor }` with lock-free SPSC pattern
  - `os_unfair_lock_trylock()` on audio thread (non-blocking, drops frame on contention)
  - `os_unfair_lock_lock()` on main thread (safe to block briefly)
  - 30 Hz poll timer on main thread calls `consume()` → `VisualizerData` created on main thread
  - `Unmanaged.passUnretained(self)` and `VisualizerTapContext` removed entirely
  - Files: `VisualizerPipeline.swift:36-141`, `VisualizerPipeline.swift:403-430`

- [x] **1.3** Add pause tap policy (Oracle addition)
  - `removeVisualizerTapIfNeeded()` added to `pause()` in AudioPlayer
  - Tap reinstalled automatically via `installVisualizerTapIfNeeded()` in `play()`
  - Files: `AudioPlayer.swift:460`

## Phase 2: High - Peak Memory Reduction

- [x] **2.1** Quick-win: skip re-parse if selected skin is default Winamp (Oracle addition)
  - Check `selectedID == "bundled:Winamp"` in `loadInitialSkin()`
  - Parse from already-loaded payload instead of re-extracting ZIP
  - Files: `SkinManager.swift:298-303`

- [x] **2.2** Lazy default skin fallback extraction
  - `defaultSkin: Skin?` replaced with `defaultSkinPayload: SkinArchivePayload?` (~200 KB)
  - `defaultSkinSpriteCache` + `defaultSkinExtractedSheets` for on-demand per-sheet extraction
  - `fallbackSpritesFromDefaultSkin()` extracts only requested sheet, caches results
  - `parseDefaultSkinFully()` for when default IS the selected skin
  - Files: `SkinManager.swift:112-116`, `SkinManager.swift:120-139`, `SkinManager.swift:527-565`

- [x] **2.3** Autorelease pool in BOTH sprite cropping loops (Oracle-corrected)
  - Added `autoreleasepool { }` in `parseDefaultSkinFully()` loop
  - Added `autoreleasepool { }` in `applySkinPayload()` loop
  - Added `autoreleasepool { }` in `fallbackSpritesFromDefaultSkin()` lazy extraction
  - Files: `SkinManager.swift`

## Phase 3: Medium - Memory Leak Fixes

- [x] **3.1** Add `defer { image.unlockFocus() }` to all lockFocus patterns
  - `preprocessMainBackground()` - defer added
  - `createFallbackSprite()` - defer added
  - Files: `SkinManager.swift`

- [x] **3.2** Break CGImage parent-child reference chain with canonical RGBA8 context (Oracle-enhanced)
  - Independent copy via CGContext with sRGB + premultiplied alpha (8 bpc, RGBA8)
  - Returns nil on CGContext failure (no fallback to shared cropped CGImage)
  - Files: `ImageSlicing.swift:27-51`

- [x] ~~**3.3** Explicit visualizer tap removal on stop~~ **ALREADY IMPLEMENTED** (Oracle finding)
  - `removeVisualizerTapIfNeeded()` called in `stop()` at line 490
  - `eject()` calls `stop()` which handles removal

## Phase 4: Low Priority - Polish (DEFERRED)

- [ ] **4.1** Gate verbose sprite logging behind `#if DEBUG`
  - Files: `SkinManager.swift` (multiple locations)

- [ ] **4.2** Precompute spectrum band coefficients (Oracle addition)
  - Move Goertzel frequency coefficient computation out of tap callback
  - Files: `VisualizerPipeline.swift`

## Phase 5: Verification

- [x] **5.1** Re-run `leaks`, `footprint` after fixes
  - 0 leaks / 0 bytes from MacAmp code (51 leaks are Apple Core Audio internals)
  - Actual footprint ~39 MB (was ~48 MB), peak ~291 MB (was ~377 MB)
  - Heap nodes: 71,416 / 2.7 MB (was 86,379 / 3.8 MB)
- [x] **5.2** Audio skip test — user tested playback, skin switching during playback, pause/resume
  - No skips during skin switching or pause/resume
  - Extremely rare skip during normal playback — Oracle (gpt-5.3-codex, xhigh) confirmed this is Debug+TSan overhead, not an app bug
- [x] **5.3** Visual regression test — user tested all bundled skins
  - No missing sprites, no color shifts, no rendering issues
- [x] **5.4** Skin switching stress test — user tested rapid switching
  - App remained responsive, memory settled back to baseline after switching
  - Post-test footprint returned to ~34-35 MB actual (lower than initial)
- [x] **5.5** Update `state.md` with after metrics — complete

### Post-verification fixes (Oracle findings)
- [x] **5.6** Fixed poll timer not stopped on `removeTap()` (Oracle #1)
  - `AudioPlayer.removeVisualizerTapIfNeeded()` now calls both `removeTap()` and `stopPollTimer()`
  - Prevents 30 Hz timer from firing during pause/stop

- [x] **5.7** Goertzel coefficient precomputation (Oracle #2, user-refined)
  - `GoertzelCoefficients` struct with `updateIfNeeded(bars:sampleRate:)` — recomputes only on sample rate change
  - Handles variable sample rates (44100, 48000, 96000, etc.) instead of hardcoded 44100
  - Eliminates 20x pow() + 20x cos() calls per tap callback (~21.5 Hz)
  - Files: `VisualizerPipeline.swift:149-178`

- [x] **5.8** Prepare reallocation guard (Oracle #3)
  - Changed `prepare()` to use `<` instead of `!=` — only grows buffers, never re-allocates for same size
  - Pre-allocated at max capacity (4096 frames, 20 bars) in `init()`
  - Files: `VisualizerPipeline.swift:238-260`

### Post-verification fixes (Oracle Review #2 — gpt-5.3-codex xhigh)
- [x] **5.9** Waveform uses buffer capacity instead of valid frame count (Oracle Review #2, Finding #1 — High)
  - `tryPublish()` now takes `validFrameCount` parameter
  - Waveform downsampling uses actual frame count, not pre-allocated capacity (4096)
  - Prevents stale/zero tail data in oscilloscope display
  - Files: `VisualizerPipeline.swift:53,82-84,664`

- [x] **5.10** `removeTap()` now also stops poll timer (Oracle Review #2, Finding #2 — High)
  - `removeTap()` invalidates `pollTimer` directly (Timer.invalidate is thread-safe)
  - `pollTimer` changed to `nonisolated(unsafe)` to allow access from nonisolated `removeTap()`
  - Fixes orphaned 30 Hz wakeups in deinit path
  - Files: `VisualizerPipeline.swift:360,437-449`

- [x] **5.11** Audio-to-video transition removes visualizer tap (Oracle Review #2, Finding #3 — Medium)
  - `playTrack()` now calls `removeVisualizerTapIfNeeded()` when switching from audio to video
  - Prevents tap/timer from running during video playback
  - Files: `AudioPlayer.swift:346-355`

- [x] **5.12** Poll timer avoids unnecessary Task allocation (Oracle Review #2, Finding #6 — Low)
  - Replaced `Task { @MainActor }` with `MainActor.assumeIsolated` in timer callback
  - Timer fires on main RunLoop, already on MainActor — no need for Task hop
  - Files: `VisualizerPipeline.swift:467-470`

- [x] **5.13** `consume()` moves Array allocation outside lock (Oracle Review #2, Finding #4 — Medium)
  - Added pre-allocated consumer staging buffers (`cRms`, `cSpec`, `cWave`, `cBcSpec`, `cBcWave`)
  - Lock held only for memcpy into staging buffers; Array creation happens after unlock
  - Reduces lock hold time → fewer dropped frames from audio thread `tryPublish()`
  - Files: `VisualizerPipeline.swift:36-55,131-199`

- [x] **5.14** Goertzel sample rate uses threshold comparison (Oracle Review #2, Finding #5 — Low)
  - Changed `sampleRate != self.sampleRate` to `abs(sampleRate - self.sampleRate) > 1.0`
  - Robust against Float representation variance while still detecting real sample rate changes
  - Files: `VisualizerPipeline.swift:219-222`
