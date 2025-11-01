```markdown
# Memory & Performance Research – MacAmp (2025-10-24)

## 1. Repository Snapshot
- **Active sources**: `MacAmpApp/Audio/AudioPlayer.swift`, `MacAmpApp/Views/WinampMainWindow.swift`, `MacAmpApp/Views/VisualizerView.swift`, `MacAmpApp/ViewModels/SkinManager.swift`
- **Legacy note**: `EqualizerWindowView.swift` referenced in earlier analysis has been removed from the build. The shipping equalizer lives in `MacAmpApp/Views/WinampEqualizerWindow.swift`.
- **Instrumentation**: Static review via `rg` walkthrough of timers, buffer lifetimes, and skin loading paths. No runtime profiling yet.

## 2. Timer Lifecycle Review
| Owner | Location | Storage | Cleanup | Notes |
| ----- | -------- | ------- | ------- | ----- |
| Playback progress | `MacAmpApp/Audio/AudioPlayer.swift:604` | `progressTimer: Timer?` | Invalidated in `stop()` and `onPlaybackEnded()` | Closure already uses `[weak self]`. ✅ |
| Track ticker | `MacAmpApp/Views/WinampMainWindow.swift:614` | `@State private var scrollTimer: Timer?` | Invalidated in `resetScrolling()` and `onDisappear` | Closure captures `audioPlayer` weakly. ✅ |
| Pause blink | `WinampMainWindow.swift:104` | `@State private var pauseBlinkTimer: Timer?` | Invalidated in `.onChange` and `onDisappear` | Fires on main run loop only. Consider `.common` to survive tracking modes – perf, not leak. |
| Visualizer refresh | `MacAmpApp/Views/VisualizerView.swift:63` | `@State private var updateTimer: Timer?` | Invalidated in `stopVisualization()` and `onDisappear` | Closure captures value semantics (no retain cycle). Consider `.common` & `[weak audioPlayer]` for polish. |

**Conclusion**: No orphaned timers found in the current SwiftUI windows. The prior “EqualizerWindowView timer leak” is obsolete.

## 3. Audio Path Findings
- `installVisualizerTapIfNeeded()` (`MacAmpApp/Audio/AudioPlayer.swift:625`) installs an AVAudioEngine tap once and never sets `visualizerTapInstalled` back to `false`. The tap is never explicitly removed when playback stops, so mixer processing (and per-buffer allocations) continues even when the UI does not need updates.
- The tap callback allocates multiple scratch buffers on every render pass:
  - `var mono = Array(repeating: 0, count: frameCount)` (`AudioPlayer.swift:638`)
  - `var rms = Array(repeating: Float(0), count: bars)` (`AudioPlayer.swift:649`)
  These short-lived allocations add measurable GC churn under heavy playback and are a better target than the previously suggested buffer pool in `tasks/.../audio-buffers.swift`.
- `visualizerLevels` / `visualizerPeaks` arrays remain populated after playback stops (`AudioPlayer.swift:70`). That is intentional for resume, but if we want deterministic release we should provide a lightweight `resetVisualizer()` instead of full-scale buffer pool copies.

## 4. Skin Loading & Image Retention
- `SkinManager.loadSkin(from:)` (`MacAmpApp/ViewModels/SkinManager.swift:327`) rebuilds the full sprite dictionary on every load and immediately replaces `currentSkin`. There is **no long-lived cache** today; memory returns once the old `Skin` is released. Prior “unbounded cache” concern does not apply.
- Temporary allocations:
  - Each sprite sheet is decompressed into a `Data` buffer (e.g., `SkinManager.swift:387`). Using `Data(capacity:)` with `entry.uncompressedSize` would reduce copying during extraction.
  - Logging (`print` / `NSLog`) dumps the entire sprite list (`SkinManager.swift:482`), which spikes console memory but not app heap. Worth gating behind `#if DEBUG`.
- Potential improvement: streaming ZIP entries to `CGImageSource` or slicing via `CGImage.cropping` could reduce the peak memory when skins exceed ~10 MB.

## 5. UI State & View Lifetime
- `WinampMainWindow` uses a handful of `@State` sets (`scrollOffset`, `buttonHovers`, etc.). They are automatically trimmed by logic inside the view and do **not** accumulate without bound.
- `WinampEqualizerWindow` contains no timers and manages state locally. The randomized EQ visualization logic referenced in the earlier analysis no longer exists.
- `VisualizerView` recalculates gradients and arrays every frame; it may warrant memoizing precomputed gradients for large displays, but that is a CPU optimization rather than memory leak.

## 6. Additional Observations
- `SimpleSpriteImage` resolves semantic sprites per body evaluation (`MacAmpApp/Views/Components/SimpleSpriteImage.swift:73`). Re-creating `SpriteResolver` each time is cheap (struct), but the dictionary lookup cost is still O(1). No obvious leak.
- `AudioPlayer.stop()` (`AudioPlayer.swift:267`) calls `scheduleFrom(time: 0)` which re-queues the track. Because the player node stays stopped, it does not re-play, but we should verify this doesn’t keep redundant buffers in AVAudioEngine’s queue.
- Debug logging uses `print` rather than structured logging; not dangerous, but hooking into `os_log` would help performance in release builds.

## 7. False Positives Cleared
- Equalizer timer leak, image cache bloat, and state accumulation issues recorded in the legacy README are tied to deleted files. The current build does not exhibit those behaviours.

## 8. Opportunities to Investigate Next
1. **Audio tap lifecycle** – add explicit removal & lazy restart to avoid unnecessary processing. (Memory + CPU)
2. **Visualizer scratch allocations** – reuse mono & spectrum buffers to cut per-frame churn. (CPU + transient allocations)
3. **Skin extraction** – pre-size `Data` and gate verbose logging to shrink peak usage when loading large skins. (Peak memory + I/O)
4. **Timer ergonomics** – add `RunLoop.main.add(_, forMode: .common)` and debug assertions, mostly resilience.
5. **Profiling gap** – run Instruments (Leaks + Allocations + Time Profiler) once code fixes land to validate impact.
```
