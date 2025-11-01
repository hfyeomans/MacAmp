# State Management Fixes Implementation Plan

## Priority 1: Critical Fixes

### 1. AudioPlayer State Machine
**File:** `MacAmpApp/Audio/AudioPlayer.swift`

- Introduce a `PlaybackState` enum to express mutually exclusive phases (stopped, preparing, playing, paused, seeking, ended).  
- Replace direct boolean writes with a single `playbackState` property; expose computed booleans temporarily for SwiftUI bindings.

```swift
private enum PlaybackState {
    case stopped
    case preparing(URL)
    case playing
    case paused
    case seeking
    case ended
}

@Published private var playbackState: PlaybackState = .stopped

var isPlaying: Bool { if case .playing = playbackState { return true } else { return false } }
```

- Centralise transitions inside helper methods (`transition(to:)`) to ensure completion handlers, seek logic, and UI controls stay in sync.
- Update `onPlaybackEnded` and seek completion to check the enum instead of `currentSeekID`.

### 2. SkinManager Load Lifecycle
**File:** `MacAmpApp/ViewModels/SkinManager.swift`

- Clear `loadingError` before starting a new load and after a successful result.

```swift
func loadSkin(from url: URL) {
    loadingError = nil
    Task(priority: .userInitiated) {
        let result = await parseSkinArchive(at: url)
        await MainActor.run {
            switch result {
            case .success(let skin):
                currentSkin = skin
                isLoading = false
            case .failure(let error):
                loadingError = error.localizedDescription
                isLoading = false
            }
        }
    }
}
```

- Move heavy archive parsing into a nonisolated helper (`parseSkinArchive`) that returns to the main actor only for state publication.
- Harden import validation: enforce file extensions, ensure extracted paths stay within the expected directory, and enforce a size ceiling (e.g., 50 MB).

### 3. AppSettings Persistence Validation
**File:** `MacAmpApp/Models/AppSettings.swift`

- Replace `try?` directory creation with throwing helpers and propagate errors to the caller.

```swift
private static func ensureSkinsDirectory() throws -> URL {
    let appSupport = try FileManager.default.url(
        for: .applicationSupportDirectory,
        in: .userDomainMask,
        appropriateFor: nil,
        create: true
    )
    let skinsDir = appSupport.appendingPathComponent("MacAmp/Skins", isDirectory: true)
    try FileManager.default.createDirectory(at: skinsDir, withIntermediateDirectories: true)
    return skinsDir
}
```

- Validate `UserDefaults` payloads on init (e.g., clamp `MaterialIntegrationLevel`, default booleans when decoding fails). Surface failures via logging or user notifications.

---

## Priority 2: High Priority Fixes

### 4. Skin Import Guardrails
**File:** `MacAmpApp/ViewModels/SkinManager.swift`

- Validate that the source URL is a local file with `.wsz`/`.zip` extension.  
- Check file size before copying (`>= 50 MB` rejection).  
- Wrap copy operations in `do/catch` that updates `loadingError` with actionable messages.

### 5. DockingController Persistence Debounce
**File:** `MacAmpApp/ViewModels/DockingController.swift`

- Add a Combine debounce before encoding `panes`, and log encoding failures.

```swift
$panes
    .dropFirst()
    .debounce(for: .milliseconds(150), scheduler: RunLoop.main)
    .sink { [weak self] panes in
        guard let self else { return }
        do {
            let data = try JSONEncoder().encode(panes)
            UserDefaults.standard.set(data, forKey: persistKey)
        } catch {
            NSLog("DockingController: failed to persist panes: \(error)")
        }
    }
    .store(in: &cancellables)
```

### 6. EQF Parsing Validation
**File:** `MacAmpApp/Models/EQF.swift`

- Guard on minimum byte count before slicing arrays.  
- Clamp band values to 1…64 before converting to dB to stay within Winamp’s expected range.  
- Return decoded presets via `Result<EqfPreset, EqfError>` to differentiate malformed files from logic bugs.

---

## Priority 3: Medium Fixes

1. Clamp dB conversions in `EQPreset.swift`.  
2. Add nil-safe bundle lookups and diagnostics in `Skin.swift`.  
3. Reject out-of-range digits in `SpriteResolver` helpers.  
4. Expand logging for audio completion paths to aid regression triage.

---

## Testing & Verification

- **Unit tests:**  
  - AudioPlayer transition matrix (play→pause→seek→stop).  
  - EQF parsing with valid, short, and oversized payloads.  
  - AppSettings directory creation failure cases.

- **Integration tests:**  
  - Skin import end-to-end (valid + oversized archives).  
  - DockingController persistence across relaunch (mocked defaults).

- **Manual QA:**  
  - Playback workflows (next/previous, shuffle/repeat) after state refactor.  
  - Import large community skins and verify UI responsiveness.  
  - Toggle layout panes rapidly to observe debounced persistence.

---

## Rollout Notes

- Ship the AudioPlayer refactor behind thorough regression testing; leverage analytics or logging to watch for unexpected completion loops.  
- Release SkinManager and AppSettings changes together to ensure skin imports provide accurate feedback.  
- Document new validation and background parsing patterns so future contributors follow the same approach.
