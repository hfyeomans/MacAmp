# AirPods Route Gate Validation Research

## Code Findings

- `AudioEngineConfigurationObserver` only listens to `AVAudioEngineConfigurationChange` for the specific `AVAudioEngine` instance.
- `AudioPlayer.handleEngineWillReconfigure` is the only production path that opens `videoReconfigureGateUntilHost` as an indefinite burst gate (`UInt64.max`).
- `AudioPlayer.handleEngineDidReconfigure` is the only production path that converts that burst gate into the bounded post-burst settle window.
- The video tap watchdog demotes on either `tap.fallbackRequested` or host-time callback stall after 1 second, unless `mach_absolute_time() < videoReconfigureGateUntilHost`.
- Therefore, if `AVAudioEngineConfigurationChange` is not delivered before the AirPods route interruption, the watchdog can demote before any gate is armed.

## Apple Platform Findings

- Xcode 26.4 SDK `AVAudioEngine.h` documents `AVAudioEngineConfigurationChangeNotification` as being issued when the engine I/O unit observes input/output hardware channel-count or sample-rate changes.
- The same header says the engine stops itself and nodes remain attached/connected with prior formats.
- `AVAudioSessionRouteChangeNotification` is marked unavailable on macOS in `AVAudioSessionTypes.h`.
- Xcode 26.4 SDK `AudioHardware.h` documents `kAudioHardwarePropertyDefaultOutputDevice` as the `AudioObjectID` of the default output `AudioDevice`.
- `kAudioHardwarePropertyDefaultSystemOutputDevice` is specifically for system-related sounds, not normal media output.
- `kAudioHardwarePropertyDevices` is the array of all currently available devices, so it is not the precise signal for "selected default output changed".

## Duplicate-Path Check

- No competing production path currently arms the video reconfigure watchdog gate.
- No existing HAL-level route observer exists in `MacAmpApp/Audio`.
- Existing bridge teardown and fallback ownership is single-path for watchdog demotion (`engageVideoTapFallback`).
