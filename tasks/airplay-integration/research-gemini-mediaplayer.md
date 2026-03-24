# Research: MediaPlayer Framework on macOS

**Date:** March 2026
**Topic:** `MPNowPlayingInfoCenter` and `MPRemoteCommandCenter` reliability on macOS.

---

## Evaluation of the Statement
> "MediaPlayer framework on macOS — MPNowPlayingInfoCenter and MPRemoteCommandCenter are heavily used on iOS but less battle-tested on macOS."

**Conclusion: The statement is highly accurate.**

While `MediaPlayer` is the official and *only* supported way to integrate with the macOS Control Center, Lock Screen, and hardware media keys, developers universally report that the macOS implementation is significantly quirkier, buggier, and "less battle-tested" than its iOS counterpart. 

macOS handles audio routing and background processes fundamentally differently than iOS (which relies heavily on strict `AVAudioSession` states). This architectural mismatch leads to several documented "gotchas" when using these APIs on the Mac.

## Known macOS Quirks & Required Workarounds

If you are implementing this in `@tasks/airplay-integration/`, you MUST account for the following macOS-specific behaviors:

### 1. The `playbackState` Desync Bug
*   **The Issue:** On iOS, setting the `nowPlayingInfo` dictionary's `MPNowPlayingInfoPropertyPlaybackRate` to `0.0` is usually enough to tell the system you are paused. On macOS, the system UI (Control Center) frequently ignores the rate and gets "stuck" showing a Pause button when it should show Play (or vice versa).
*   **The Fix:** As noted in your `plan.md`, macOS *requires* you to explicitly set `MPNowPlayingInfoCenter.default().playbackState` to `.playing`, `.paused`, or `.stopped`. 
*   **The "Dirty Workaround" (if it still sticks):** Some developers report that even explicit state setting fails if the app loses audio focus. The known workaround is to rapidly toggle the state (`.paused` -> `.playing` -> `.paused`) to force the system UI to update its drawing layer.

### 2. The Artwork Disappearance Bug
*   **The Issue:** Changing the `playbackRate` or `playbackState` without re-supplying the `MPMediaItemArtwork` can cause the album art to vanish from the macOS Control Center.
*   **The Fix:** Always provide the full dictionary (including the artwork) when making state changes, rather than trying to update just the rate or elapsed time keys in isolation. 

### 3. Swift 6 Concurrency Clashes
*   **The Issue:** `MPRemoteCommandCenter` targets fire on an arbitrary background thread. Your `PlaybackCoordinator` and `AudioPlayer` are `@MainActor`. 
*   **The Fix:** Your plan already catches this! Wrapping the command handlers in `Task { @MainActor }` is correct and absolutely necessary to prevent crashes in Swift 6.2.

### 4. Command Center Button Conflicts
*   **The Issue:** macOS Control Center has limited space. If you enable `skipForwardCommand` (e.g., jump 15 seconds) alongside `nextTrackCommand`, macOS will often choose to display the skip buttons and hide the next track buttons.
*   **The Fix:** Explicitly disable commands you don't want using `command.isEnabled = false`. Do not rely on simply "not adding a target" to hide a button.

### 5. The Play/Pause Toggle Command
*   **The Issue:** The `togglePlayPauseCommand` is notoriously unreliable on macOS when interacting with Bluetooth headphones (like AirPods taking them out of ear). 
*   **The Fix:** Always register explicit targets for `playCommand` and `pauseCommand` *in addition* to `togglePlayPauseCommand`. 

## Recommendations for MacAmp's Implementation

1. **Follow the Plan's explicit `playbackState` instructions:** Your plan (Section 2.1) correctly identifies the need for `center.playbackState = .playing`. This is the most crucial macOS-specific fix.
2. **Minimize Updates:** Do not set up a `Timer` to constantly update `MPNowPlayingInfoPropertyElapsedPlaybackTime`. Apple auto-extrapolates this based on the `playbackRate`. Only push new info dictionaries on distinct state changes (Play, Pause, Stop, Seek, Next Track). Constant updates can flood the macOS media queue and cause the UI to freeze.
3. **Be Defensive with `changePlaybackPositionCommand`:** The seek slider in macOS Control Center is finicky. When the user scrubs, the system sends the target time. If your `AudioPlayer` doesn't successfully seek and push a *new* `nowPlayingInfo` dictionary back to the system within a few milliseconds, the slider will snap back to where it was.

Your current plan in `tasks/airplay-integration/plan.md` actually anticipates the two biggest macOS hurdles (explicit playback state and MainActor dispatching). The approach is sound, but expect the UI testing phase to be slightly temperamental purely due to macOS window server/control center delays.