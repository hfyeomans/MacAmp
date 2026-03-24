# Research: Per-App AirPlay Routing with AVAudioEngine (macOS 15+ & 26)

**Context:** Routing *only* this app's audio (per-app) to an AirPlay device without changing the macOS system default. The app uses `AVAudioEngine` for EQ (10-band) and visualization (tap on main mixer), and supports both local files and streaming via `LockFreeRingBuffer` -> `AVAudioSourceNode`. 

**Constraint Reminder:** `AVRoutePickerView` natively integrates with `AVPlayer`, NOT `AVAudioEngine`. Clicking an AirPlay device in the picker when using `AVAudioEngine` without a linked player often results in no actual route change or affects the system default.

---

## 1. AVAudioEngine outputNode AU-level device selection
**Concept:** Finding the Core Audio `AudioDeviceID` for the AirPlay target and assigning it to the `audioEngine.outputNode.audioUnit` using `kAudioOutputUnitProperty_CurrentDevice`.

*   **Does it work for per-app AirPlay?** Technically yes, but practically very fragile. You can enumerate `kAudioHardwarePropertyDevices`, find the one with `kAudioDeviceTransportTypeAirPlay`, and set it on the `outputNode`. It routes *only* the engine's audio.
*   **API Availability:** macOS 10.0+ (Core Audio HAL)
*   **Code Example:**
    ```swift
    let outputUnit = audioEngine.outputNode.audioUnit!
    var deviceID: AudioDeviceID = targetAirPlayDeviceID 
    AudioUnitSetProperty(outputUnit, 
                         kAudioOutputUnitProperty_CurrentDevice, 
                         kAudioUnitScope_Global, 
                         0, 
                         &deviceID, 
                         UInt32(MemoryLayout<AudioDeviceID>.size))
    ```
*   **EQ & Visualizer Compatibility:** **Yes.** The entire `AVAudioEngine` graph remains intact.
*   **Risks & Limitations:** 
    *   **AirPlay 1 Only:** This bypasses Apple's modern AirPlay 2 stack. It does not support multi-room audio, enhanced buffering, or HomePod stereo pairs reliably.
    *   **Instability:** If the network drops, `AVAudioEngine` throws an exception and stops.
    *   **No UI:** You have to build a custom menu to list Core Audio devices; you cannot easily link this to the native `AVRoutePickerView`.

## 2. AVSampleBufferAudioRenderer + AVSampleBufferRenderSynchronizer
**Concept:** Apple's documented "custom player" path. You feed it `CMSampleBuffer`s of PCM data.

*   **Does it work for per-app AirPlay?** **Yes.** This is the *officially supported* way to do per-app AirPlay. It exposes `audioOutputDeviceUniqueID` which allows you to pin the audio to a specific route without changing the system default. It seamlessly integrates with `AVRoutePickerView`.
*   **API Availability:** macOS 10.13+
*   **EQ & Visualizer Compatibility:** **Poor.** 
    *   `AVSampleBufferAudioRenderer` does *not* accept `AVAudioNode` inserts. To use your 10-band EQ, you would have to run the audio through an offline `AVAudioEngine` (in manual rendering mode), pull the processed buffers out, convert them to `CMSampleBuffer`, and feed them to the renderer. 
    *   Visualizer taps would have to happen in the manual render loop.
*   **Risks & Limitations:** High architectural rewrite. You lose the real-time push/pull simplicity of `AVAudioEngine`.

## 3. Core Audio HAL (kAudioHardwarePropertyDefaultOutputDevice)
**Concept:** Using `AudioObjectSetPropertyData` to change the default output.

*   **Does it work for per-app AirPlay?** **NO.** Setting `kAudioHardwarePropertyDefaultOutputDevice` changes the global macOS system default output. This violates your core constraint. There is no `kAudioHardwarePropertyDefaultAppOutputDevice` API.

## 4. AVPlayer with MTAudioProcessingTap
**Concept:** Abandon `AVAudioEngine` for playback. Use `AVPlayer` for both local files and custom streams (via custom scheme / local HTTP server), and use `MTAudioProcessingTap` to intercept the audio for EQ/Visualization.

*   **Does it work for per-app AirPlay?** **Yes.** `AVPlayer` natively handles per-app AirPlay and wires perfectly to `AVRoutePickerView`.
*   **API Availability:** macOS 10.15+ (MTAudioProcessingTap is older, but reliable)
*   **EQ Compatibility:** **Poor.** You cannot drop an `AVAudioUnitEQ` inside a C-based `MTAudioProcessingTap`. You would have to rewrite your 10-band EQ using vDSP (Accelerate framework) or raw biquad filters in C/Swift inside the tap callback.
*   **Visualizer Compatibility:** **Yes.** You can read the PCM samples in the tap to drive the spectrum analyzer.
*   **Risks:** Moving the streaming pipeline to AVPlayer requires running a local HTTP server for the custom stream, as AVPlayer cannot easily play raw PCM from a ring buffer without a custom URL scheme handler (which has caching/seeking quirks).

## 5. macOS 26 (Tahoe) New APIs
*   **Findings:** There are no newly introduced `AVAudioEngine` routing APIs in Tahoe that solve this. Apple's focus for macOS 26 media routing remains strictly on `AVPlayer` and `AVKit`. Tahoe actually tightened sandbox restrictions (as seen in the WebKit crashes), making custom Core Audio HAL manipulation slightly more prone to audit failures if entitlements aren't perfect.

## 6. How Spotify and Apple Music achieve per-app AirPlay
*   **Apple Music:** Uses private, internal frameworks (`MediaExperience.framework`) that have deep system hooks allowing per-app routing that third-party developers cannot access.
*   **Spotify:** Uses a combination of `AVPlayer` (for DRM handling and AirPlay handover) and `AVRoutePickerView`. When a user selects a device via the picker or Spotify's custom "Connect" UI, Spotify leverages the `AVSampleBufferAudioRenderer`'s `audioOutputDeviceUniqueID` (or a similar internal wrapper) to stream *only* its decoded buffers to the target, bypassing the system default. 
*   **The "Airfoil" Approach:** Apps like Rogue Amoeba's Airfoil achieve per-app routing by installing a custom HAL audio capture driver (.driver plugin) to intercept app audio and stream it manually. This is out of scope for a standard Mac App Store app.

## 7. AudioUnit Hosting
**Concept:** Wrap the engine inside an AudioUnit or host an AU graph manually.

*   **Does it work?** **No.** Even if you drop down to the `AUGraph` C-API (which is deprecated in favor of `AVAudioEngine`), the output node (`kAudioUnitSubType_DefaultOutput`) still relies on the Core Audio HAL. Setting the device ID on the raw AU has the exact same limitations and AirPlay 1 restrictions as Approach #1.

---

## Conclusion & Recommendation

You are caught in an architectural paradox defined by Apple's framework boundaries:
1.  **You MUST use `AVAudioEngine`** to keep your 10-band `AVAudioUnitEQ` and real-time visualizer tap.
2.  **`AVAudioEngine` CANNOT cleanly do modern per-app AirPlay** (it lacks `AVRoutePickerView` support and AirPlay 2 buffering).

**The Only Viable Path Forward (Given constraints):**
Proceed with the approach outlined in your existing `plan.md` (Phase 1.3), which relies on **System-Wide AirPlay**. 
Because `AVRoutePickerView` triggers a system-level route change when not explicitly bound to an `AVPlayer`, you must accept that selecting an AirPlay device will change the Mac's output. To support this gracefully:
*   Listen for `AVAudioEngineConfigurationChangeNotification`.
*   Stop the engine, reconstruct the graph (re-attach `AVAudioSourceNode` format if needed), and restart.
*   The EQ and Visualizer will survive the transition. 

*If true per-app AirPlay is strictly mandatory*, you must rewrite the playback engine using `AVPlayer` and reimplement the 10-band EQ using low-level vDSP mathematics inside an `MTAudioProcessingTap`.