# Pass-3 Video Load Task Verification Research

Commit reviewed: `d112e1b57ce005849c64f6903221156a6b0f50d7`

## Scope

- `MacAmpApp/Audio/AudioPlayer.swift`
- `MacAmpApp/Audio/PlaybackCoordinator.swift`
- `MacAmpApp/Audio/VideoPlaybackController.swift`
- Adjacent audio/video tests under `Tests/MacAmpTests`

## Findings

- `AudioPlayer` is `@MainActor`, and the stored `videoLoadTask` body is explicitly `Task { @MainActor [weak self] in ... }`.
- `startVideoTrack(_:)` stores the in-flight task, awaits `videoPlaybackController.loadVideo(...)`, then performs a stale-task guard: `guard !Task.isCancelled, self.videoAudioTap === tap else { return }`.
- The new `defer { self.videoLoadTask = nil }` is placed after the identity guard, so only the active generation that still owns `videoAudioTap` clears the slot.
- `AudioPlayer.play()` gates video playback with `guard videoLoadTask == nil else { return }`. Once the active task completes, the defer clears the slot before future resume/media-key `play()` calls.
- `PlaybackCoordinator.resume()` calls `audioPlayer.play()` for `.localTrack`; remote play commands dispatch to `@MainActor` before invoking `resume()`.
- `tearDownVideoBridge()` cancels and clears `videoLoadTask`; it is called by video teardown paths including stop, video switching, and deinit.
- Since both the task defer and `tearDownVideoBridge()` run on `@MainActor`, clear operations are serialized rather than racing.

## Verification

- `xcodebuildmcp macos test --json '{"projectPath":"MacAmpApp.xcodeproj","scheme":"MacAmpApp","derivedDataPath":".build/derived-data","extraArgs":["-skipMacroValidation","-skipPackagePluginValidation"],"preferXcodebuild":true}' --output text`
  - Result: passed, 90 total, 89 passed, 0 failed, 1 expected failure.
- `xcodebuildmcp macos test --json '{"projectPath":"MacAmpApp.xcodeproj","scheme":"MacAmpApp","derivedDataPath":".build/derived-data-tsan","extraArgs":["-skipMacroValidation","-skipPackagePluginValidation","-enableThreadSanitizer","YES"],"preferXcodebuild":true}' --output text`
  - Result: passed, 90 total, 90 passed, 0 failed.
