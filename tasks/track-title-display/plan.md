# Plan

1. Add a helper inside `PlaybackCoordinator` to build a stable display string for local tracks that mirrors legacy behavior (prefer metadata title + artist, fall back to filename/station name).
2. Update `play(track:)` and `play(url:)` to capture the formatted local display title via the helper so `currentTitle` is never empty.
3. Adjust `displayTitle` to use the formatted `currentTitle` for `.localTrack` cases, trimming empty output and falling back to the source URL's filename when needed.
4. Verify no other code paths depend on the old `currentTitle` format and ensure streams retain their existing behavior.
5. Run targeted reasoning checks (code review, optional unit coverage if available) to confirm display logic now returns "Title - Artist" for local tracks and "MacAmp" only when nothing is playing.
