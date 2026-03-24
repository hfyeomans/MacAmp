# Research: AVRoutePickerView Failure Modes on macOS

**Date:** March 2026
**Topic:** Why `AVRoutePickerView` fails to route audio or change system defaults when used with `AVAudioEngine` or empty `AVPlayer` instances.

---

## Analysis of the Test Results

Your test matrix perfectly illustrates the strict boundaries Apple has placed around AirPlay on macOS:

| What we tested | Result | Why it happened |
| :--- | :--- | :--- |
| `AVRoutePickerView` alone (no player) | UI only, no routing | On macOS, the picker *requires* a `player` property to know what to route. Without it, it acts as a "dummy" button. |
| `AVRoutePickerView` + empty `AVPlayer` | TV connects but system default unchanged | The picker established a dedicated AirPlay 2 video/audio route for *that specific AVPlayer*. Because the player was empty, nothing played. System audio stays on the Mac. |
| `AVRoutePickerView` + silent playing `AVPlayer` | FigFilePlayer errors, no routing | `AVPlayer` aggressively optimizes out "silent" or empty tracks. The underlying `FigFilePlayer` (CoreMedia) refused to negotiate an AirPlay connection for a track with no data. |
| AirPlay devices in HAL before/after | Not visible | Confirmed by previous research: AirPlay devices are hidden from the HAL until a *system-wide* route is established. Because you used `AVPlayer`, you established a *per-app* route, which bypasses the HAL entirely. |
| Engine config / System default change | Never fires | Because the system default was never changed, `AVAudioEngine` never saw a hardware sample rate change, and the notification never fired. |

## The Core Problem

**You are trying to force a UI component designed for `AVPlayer` (per-app routing) to act as a system-wide output switcher for `AVAudioEngine`.**

Apple explicitly designed `AVRoutePickerView` on macOS to bind to an `AVPlayer` instance and route *only that player's audio* over AirPlay 2. It is not designed to be a generic "Change my Mac's Sound Output" button.

When you link `picker.player = myAVPlayer`, macOS says: "Okay, I will send the decoded buffers from `myAVPlayer` directly to the Apple TV over the network." It does not touch the Core Audio HAL, it does not change the system default, and it completely ignores your `AVAudioEngine`.

### Why does this work on iOS but not macOS?
*   **iOS:** `AVAudioSession` is global per app. If `AVRoutePickerView` changes the route, the entire app's audio session (including `AVAudioEngine`) is moved to the AirPlay device.
*   **macOS:** There is no global `AVAudioSession` routing. `AVPlayer` routing is isolated to the specific player instance. `AVAudioEngine` routing is tied to the Core Audio HAL (hardware devices).

## What This Means for MacAmp

If `AVRoutePickerView` without a player doesn't change the system output, **Phase 1.3 of your plan is fundamentally broken.** You cannot use `AVRoutePickerView` to magically redirect an `AVAudioEngine`.

### Your Options Now

You have hit the wall of macOS framework limitations. You must choose one of three paths:

#### Path A: The "System Audio" Shortcut (CoreAudio HAL + Custom UI)
If you want to keep the 10-band EQ and route audio to AirPlay, you must change the **System Default Output Device** using Core Audio, and you must build your own UI to do it.
1.  **Drop `AVRoutePickerView`.**
2.  Build a custom menu in MacAmp.
3.  When opened, trigger a Bonjour/mDNS scan (using `NSNetServiceBrowser` for `_airplay._tcp`) to find AirPlay devices.
4.  When a user selects one, use an AppleScript or a private API workaround to ask the macOS System to switch its global output to that device. (Note: Changing system output programmatically via public APIs was heavily restricted in recent macOS versions).

#### Path B: The AVPlayer Rewrite (True Per-App, No EQ)
Accept that `AVAudioEngine` cannot do this.
1.  Rip out `AVAudioPlayerNode` and the 10-band EQ.
2.  Use `AVPlayer` for all playback.
3.  Bind `AVRoutePickerView` to the `AVPlayer`.
4.  Result: Perfect per-app AirPlay. No EQ.

#### Path C: The Airfoil / Rogue Amoeba Path (Out of Scope)
To intercept an `AVAudioEngine` and send it over AirPlay without changing the system default, you have to write a custom virtual audio driver (`.driver`), capture the buffers, and encode/transmit them over the AirPlay protocol yourself. This is how Airfoil works. This is completely out of scope for MacAmp.

### Immediate Recommendation
**Halt Phase 1 of the AirPlay plan.** 
The foundational assumption that `AVRoutePickerView` could act as a trigger for `AVAudioEngine` (by forcing a system route change) has been disproven by your tests.

If keeping the 10-band EQ is non-negotiable, you must abandon native AirPlay integration inside the app's UI and instruct users to use the macOS Control Center to route their audio.