```markdown
# Task State – Memory Management (2025-10-24)

## Implemented Today
- **Audio tap lifecycle**: Added explicit teardown via `removeVisualizerTapIfNeeded()` and ensured `play()` reinstalls the tap when restarting playback (`MacAmpApp/Audio/AudioPlayer.swift:226`, :632, :688, :861`). Tap now detaches on `stop()` and when playback ends without advancing.
- **Visualizer allocations**: Introduced `VisualizerScratchBuffers` to reuse mono/RMS/spectrum buffers inside the AVAudioEngine tap (`AudioPlayer.swift:11`). Per-frame heap churn for 1k-sample buffers has been eliminated.
- **Timer ergonomics**: Scroll/pause timers now register under `.common` run-loop mode and obey an `isViewVisible` guard; async restarts bail out once the view is dismissed (`MacAmpApp/Views/WinampMainWindow.swift:28`, :100, :614, :640). Visualizer timer also joins `.common` (`MacAmpApp/Views/VisualizerView.swift:65`).
- **Skin extraction peak usage**: Pre-size temporary `Data` buffers and gate verbose logging behind `#if DEBUG`, reducing release-build allocations and console overhead (`MacAmpApp/ViewModels/SkinManager.swift:372`, :486, :500).

## Current Risk Snapshot
| Area | Status | Notes |
| ---- | ------ | ----- |
| Audio engine taps | ✅ addressed | Tap removed when idle; remaining work is to profile long playback sessions for hidden retain cycles. |
| Visualizer scratch buffers | ✅ addressed | Buffers reused per render. Need runtime verification that no regressions occur in spectrum output. |
| UI timers | ✅ addressed | Timers cleaned up and more resilient. Monitor for any regressions in scrolling restart logic. |
| Skin loading | ⚠️ partial | Memory spike reduced, but still loads entire sheet in-memory; streaming decode remains future work. |
| Legacy references (EqualizerWindowView, image cache LRU) | ✅ resolved | Documentation updated; no active code paths rely on removed windows or cache state. |

### Known Outstanding Leaks (from Xcode Memory Graph)
- `ParameterListenerBinding` (75 instances) and `ListenerBinding` (100 instances) leak signatures were captured after playback sessions on macOS 26.0. These objects originate from AVFAudio’s parameter observer stack (likely `AVAudioUnitEQ` bindings). The owning path still needs to be confirmed; schedule a follow-up investigation to snapshot the “Path to Root” and test whether bypassing the EQ node or reusing observers clears the bindings.
- Instruments traces (`baseline-leaks-test.trace`, runs 1–3) consistently show **124 live `Malloc 64 Bytes` blocks** with truncated stacks. This matches the binding counts and will be addressed in a later memory-optimization pass once feature work stabilizes.

## Outstanding Work
1. **Profiling**: Capture Instruments (Leaks + Allocations) runs on macOS 26.0 build to confirm lower allocations and absence of leaked taps. Future deep dive should re-record with `MallocStackLogging` enabled (or equivalent) to obtain full call stacks for the AU parameter bindings once we pick up advanced memory optimization.
2. **Playback edge cases**: Test stop→play, eject, and playlist end-of-queue flows to ensure visualizer reconnects as expected.
3. **Large skin stress test**: Load multiple >10 MB skins sequentially to measure heap ceiling after `Data(capacity:)` optimization.
4. **Telemetry/Monitoring**: Optional follow-up for lightweight memory metrics in debug builds.

## Testing Status
- Unit/automated tests: not run (no suite provided).
- Manual smoke: pending – requires integration build on macOS Tahoe 26.0.
```
