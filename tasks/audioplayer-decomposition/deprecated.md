# Deprecated: AudioPlayer.swift Decomposition

> **Description:** Documents deprecated or legacy code discovered or removed during this decomposition task.
> **Purpose:** Per project conventions, deprecated code is removed rather than marked with comments, and findings are recorded here.

---

## Patterns to Remove

### 1. SwiftLint Inline Suppressions

**File:** `MacAmpApp/Audio/AudioPlayer.swift`
**Status:** Pending removal (after decomposition brings file within thresholds)

```swift
// Line 1:
// swiftlint:disable file_length

// Line 28:
final class AudioPlayer { // swiftlint:disable:this type_body_length
```

**Replacement:** Decomposition into `EqualizerController.swift` + visualizer consolidation should bring the file below the `file_length` error threshold (1,200) and the `type_body_length` error threshold (600). Suppressions can then be removed.

### 2. FourCC String Extension (Potentially Unused)

**File:** `MacAmpApp/Audio/AudioPlayer.swift` lines 8-19
**Status:** Pending usage check

```swift
extension String {
    init(fourCC: FourCharCode) {
        let bytes = [
            UInt8((fourCC >> 24) & 0xFF),
            UInt8((fourCC >> 16) & 0xFF),
            UInt8((fourCC >> 8) & 0xFF),
            UInt8(fourCC & 0xFF)
        ]
        self = String(bytes: bytes, encoding: .ascii) ?? "????"
    }
}
```

**Action:** Search for usage. If unused, delete entirely. If used, move to a shared utilities extension.

---

## Completed Removals

_(Will be updated as each phase completes)_
