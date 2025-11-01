# Auto EQ Investigation Notes

## Summary
- **Feature:** Equalizer “Auto” button (per-track auto preset generation)
- **Status:** Auto analysis disabled (manual presets still apply). Full implementation deferred to a future task.

## Errors Encountered
1. **Task 97 – SIGABRT**  
   - **Queue:** `com.apple.root.user-initiated-qos.cooperative`  
   - **Location:** `AutoEQAnalyzer.analyze` closure (AudioPlayer.swift:146)  
   - **Cause (suspected):** Unsafe pointer management inside the FFT pipeline when analysing background audio buffers.

2. **Main Thread – EXC_BREAKPOINT (0x19c5b6b5c)**  
   - **Queue:** `com.apple.main-thread`  
   - **Presentation:** Crash shortly after toggling the Auto button while playback continued.  
   - **Cause (suspected):** Main-thread memory guard triggered after asynchronous analysis returned, likely due to race conditions when applying generated presets.

3. **Main Thread – EXC_BREAKPOINT (0x19c5b6b5c)** *(recurring)*  
   - Occurred again after pointer fixes; points to the same CF abort path, indicating the background analysis approach remains fragile in the current implementation.

## Interim Resolution
- Disabled automatic EQ analysis in `generateAutoPreset(for:)` (logs and exits).  
- Auto button still toggles state and applies cached per-track presets, but no new presets are generated.  
- Left detailed instrumentation notes so future work can resume from this state without regression.

## Follow-Up
- Create a dedicated task to reintroduce auto EQ with a safer analysis pipeline (buffer management, concurrency model, and error handling).  
- Ensure future implementation includes unit/integration tests covering preset generation and graceful failure paths.
