# Research: AVPlayer Rewrite for True Per-App AirPlay

**Context:** Evaluating the feasibility of dropping `AVAudioEngine` (and the 10-band EQ) in favor of a pure `AVPlayer` architecture to achieve *true* per-app AirPlay routing without changing the macOS system-wide audio default.

---

## The AVPlayer Approach to Per-App AirPlay

If we drop the requirement to use `AVAudioEngine` (and thus forfeit `AVAudioUnitEQ`), we can use the exact method Apple designed for per-app media routing.

### 1. How It Works
When you use `AVRoutePickerView` natively, you must associate it with an `AVPlayer` instance:

```swift
let routePickerView = AVRoutePickerView()
routePickerView.player = self.myAVPlayer // This is the magic link
```

When the user clicks the AirPlay button and selects a HomePod:
1. macOS sees the picker is bound to `myAVPlayer`.
2. It establishes a dedicated AirPlay 2 stream for *that player only*.
3. System sounds (Slack pings, YouTube in Safari) continue to play through the Mac's built-in speakers.

### 2. Required Configuration (macOS 15+)
To make this work flawlessly on the Mac, you must configure the app's Info.plist and Audio Session (even though Audio Session is primarily an iOS concept, it affects routing on macOS):

1.  **Info.plist:** Add `AVInitialRouteSharingPolicy` set to `LongformAudio`.
2.  **Player Config:** `myAVPlayer.allowsExternalPlayback = true`.

### 3. Impact on MacAmp's Architecture

If we transition to this model, the architecture changes drastically:

#### Local File Playback
*   **Current:** `AVAudioPlayerNode` -> `AVAudioUnitEQ` -> `AVAudioEngine`
*   **New:** `AVPlayer(url: localFileURL)`
*   **Status:** Trivial to implement. `AVPlayer` is highly optimized for local files.

#### Internet Radio Streaming (The Hard Part)
*   **Current:** Custom `URLSession` -> `AudioFileStream` parser -> `AudioConverter` -> `LockFreeRingBuffer` -> `AVAudioSourceNode`.
*   **New:** `AVPlayer(url: streamURL)`
*   **Status:** `AVPlayer` *can* play HTTP streams (like ICY/Shoutcast) natively. However, it is notoriously bad at handling infinite streams, dropping connections, or extracting ICY metadata (stream titles).
*   **The Catch:** If we use native `AVPlayer` for streams, we lose our custom robust reconnection logic and metadata parsing. If we keep our custom `URLSession` pipeline, we cannot easily feed raw PCM from a ring buffer into an `AVPlayer`. We would have to run a local HTTP server inside MacAmp to serve the decoded stream back to `AVPlayer`, which is incredibly complex.

#### The Visualizer (Butterchurn)
*   **Current:** An `AVAudioEngine` tap on the main mixer node provides real-time PCM samples to the spectrum analyzer.
*   **New:** We would have to attach an `MTAudioProcessingTap` to the `AVPlayerItem`.
*   **Status:** Feasible, but requires writing the tap callbacks in C-convention Swift, managing pointer memory, and ensuring it doesn't break the AirPlay 2 encrypted stream (sometimes taps disable AirPlay or force fallback to AirPlay 1).

## Conclusion
If you exclude the 10-band EQ, achieving true per-app AirPlay is absolutely possible using `AVPlayer` + `AVRoutePickerView`. 

**However, the cost is immense:**
1.  You lose the 10-band EQ.
2.  You likely have to scrap the custom `StreamDecodePipeline` you built for internet radio, falling back to `AVPlayer`'s native (and flaky) stream handling, losing ICY metadata.
3.  You have to rewrite the visualizer data source using `MTAudioProcessingTap`.

**Recommendation:** Stick to the current `plan.md` (Phase 1.3). While it changes the system-wide output, it preserves the EQ, the custom stream pipeline, and the visualizer, which are far more critical to a "Winamp" clone than isolated audio routing. Users who want true isolated routing on macOS typically use third-party tools like Airfoil anyway.