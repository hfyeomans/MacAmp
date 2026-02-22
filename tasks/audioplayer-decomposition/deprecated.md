# Deprecated: AudioPlayer.swift Decomposition

> **Description:** Documents deprecated or legacy code discovered or removed during this decomposition task.
> **Purpose:** Per project conventions, deprecated code is removed rather than marked with comments, and findings are recorded here.

---

## Still Present (Cannot Remove Yet)

### 1. SwiftLint Inline Suppressions

**File:** `MacAmpApp/Audio/AudioPlayer.swift`
**Status:** Cannot remove — file is 945 lines (above 600 warning), type body is ~905 lines (above 400 warning)

```swift
// Line 1:
// swiftlint:disable file_length

// Line ~28:
final class AudioPlayer { // swiftlint:disable:this type_body_length
```

**Why still needed:** Phases 1-3 reduced the file from 1,095 to 945 lines, but this is still above the `file_length` warning threshold (600) and `type_body_length` warning threshold (400). The suppressions prevent these from appearing as lint violations. They can only be removed after Phase 4 (engine transport extraction) brings the file below thresholds — Phase 4 is currently deferred.

**Condition for removal:** File under 600 lines and type body under 400 lines.

---

## Completed Removals

### 1. FourCC String Extension — REMOVED (Phase 3, commit `37c3598`)

**File:** `MacAmpApp/Audio/AudioPlayer.swift` (formerly lines 8-19)

```swift
// REMOVED — zero callers in codebase
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

**Reason:** Codebase search confirmed zero callers — the extension was defined but never used. Deleted entirely. Saved 18 lines.

### 2. Stale Extraction Comments — REMOVED (Phase 3, commit `37c3598`)

**File:** `MacAmpApp/Audio/AudioPlayer.swift`

Comments marking code for future extraction were removed as they were addressed or no longer applicable after Phases 1-2.

### 3. Redundant eqNode Manual Assignments — REMOVED (Oracle #1, commit `8679123`)

**File:** `MacAmpApp/Audio/EqualizerController.swift`

After adding `didSet` handlers on `preamp`, `eqBands`, and `isEqOn` to automatically sync the eqNode, the manual `eqNode.globalGain = preamp` and `eqNode.bands[i].gain = gain` assignments inside `setPreamp`, `setEqBand`, and `toggleEq` methods became redundant.

### 4. Unused Imports — REMOVED (CodeRabbit, commit `dd8866e`)

**File:** `MacAmpApp/Audio/AudioPlayer.swift`

`import Combine` and `import Accelerate` were no longer used after EQ extraction moved the Accelerate-dependent code and no Combine publishers remained.
