# Research: Core Audio HAL and Discovered AirPlay Devices

**Date:** March 2026
**Topic:** Do discovered-but-not-connected AirPlay receivers appear in `kAudioHardwarePropertyDevices` with `kAudioDeviceTransportTypeAirPlay`?

---

## The Reality: They Are Hidden by Default

Contrary to what older Apple documentation implied, **AirPlay targets do NOT appear as individual `AudioDeviceID`s in `kAudioHardwarePropertyDevices` by default** unless they are actively selected as the system's output.

Your output confirms exactly how the modern macOS Core Audio HAL behaves:

```text
AudioDeviceRouter UNFILTERED: 7 total AudioDeviceIDs
id:102 'dprt' alive:1 out:2 in:0 LG HDR WQHD+
id:117 'ccwd' alive:1 out:0 in:1 Hank’s 17 Pro Microphone
id:98 'usb ' alive:1 out:0 in:2 Logitech StreamCam
id:93 'bltn' alive:1 out:0 in:1 MacBook Pro Microphone
id:86 'bltn' alive:1 out:2 in:0 MacBook Pro Speakers
id:180 'grup' alive:1 out:2 in:2 CADefaultDeviceAggregate-68970-0
id:76 'virt' alive:1 out:1 in:1 Microsoft Teams Audio
```

Notice there is absolutely no `airp` (AirPlay) transport type in that list, even though you have AirPlay receivers on your network.

### Why does this happen?

1.  **The Single "Virtual" Device:** macOS implements AirPlay as a single virtual proxy device. This proxy device is typically *not registered in the global device list* until an AirPlay connection is actively initiated (via the Control Center or `AVRoutePickerView`).
2.  **Destinations are "Data Sources":** If you were to select a HomePod via the macOS Control Center, and *then* run your Core Audio query, you would see a new `AudioDeviceID` appear with the `'airp'` transport type. The actual name of the specific speaker (e.g., "Living Room HomePod") is technically exposed as a "Data Source" (`kAudioDevicePropertyDataSources`) of that virtual proxy device, not as a standalone `AudioDeviceID`.
3.  **Cross-Process Abstraction:** macOS abstracts AirPlay discovery into a separate network daemon (`mDNSResponder` and `coreaudiod`). Core Audio hardware layers (which look at USB, PCI, and Built-in hardware) are intentionally shielded from network targets until they are activated.

### What This Means for Development

*   **You Cannot Build a Custom Picker via Core Audio:** You cannot use `kAudioHardwarePropertyDevices` to populate a custom menu of available AirPlay devices. The system simply hides them from that API.
*   **AVRoutePickerView is Mandatory for per-app routing:** This behavior reinforces why Apple pushes developers to use `AVRoutePickerView` from `AVKit`. That UI component bypasses the Core Audio HAL and directly talks to the network discovery daemon to populate its list of available receivers.
*   **(SUPERSEDED) ~~The Plan is Correct~~:** Phase 1.3 was attempted and failed — AVRoutePickerView on macOS routes per-AVPlayer only and cannot redirect AVAudioEngine audio. The HAL finding remains valid (AirPlay devices hidden), but the conclusion that AVRoutePickerView + AVAudioEngine is viable was disproven by testing. See `research.md` section 8.