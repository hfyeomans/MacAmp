# Plan

1. Validate each requested race timeline against current control flow:
   - same-URL replay
   - stop during await
   - playTrack different URL during await
   - deinit during await
2. Check cancellation hygiene and lifecycle ownership boundaries (`AudioPlayer` vs `VideoPlaybackController` vs `AudioEngineController`).
3. Classify findings as MUST-FIX or NICE-TO-HAVE with file/line evidence.
4. Produce pass-2 score and residual risk summary.
