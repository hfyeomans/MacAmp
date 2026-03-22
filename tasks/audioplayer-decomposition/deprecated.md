# Deprecated: AudioPlayer.swift Decomposition

> **Description:** Documents deprecated or legacy code discovered or removed during this decomposition task.
> **Purpose:** Per project conventions, deprecated code is removed rather than marked with comments, and findings are recorded here.

---

## Still Present (Cannot Remove Yet)

### 1. SwiftLint Inline Suppressions

**File:** `MacAmpApp/Audio/AudioPlayer.swift`
**Status:** Cannot remove — file is 705 lines (above 600 warning), type body is ~690 lines (above 400 warning, above 600 error)

```swift
// Line 1:
// swiftlint:disable file_length

// Line 8:
final class AudioPlayer { // swiftlint:disable:this type_body_length
```

**Why still needed:** Phase 4 reduced the file from 1,143 to 705 lines. This is below the `file_length` error threshold (1,200) but still above the warning (600). The `type_body_length` suppression is still needed (~690 body, error is 600). These can only be removed after seek extraction (Phase 5).

**Condition for removal:** File under 600 lines and type body under 400 lines. Requires Phase 5 (seek extraction).

---

## Completed Removals

### Phase 4 Removals (PR #60, 2026-03-22)

#### 1. Direct audioEngine/playerNode/audioFile Ownership — MOVED to AudioEngineController

**From:** `MacAmpApp/Audio/AudioPlayer.swift`
**To:** `MacAmpApp/Audio/AudioEngineController.swift`

The following were moved from AudioPlayer to AudioEngineController:

- `let audioEngine = AVAudioEngine()` — engine ownership
- `let playerNode = AVAudioPlayerNode()` — player node ownership
- `var audioFile: AVAudioFile?` — loaded file state
- `var progressTimer: Timer?` — progress tracking timer
- `var playheadOffset: Double` — scheduling offset
- `var streamSourceNode: AVAudioSourceNode?` — stream bridge node
- `var streamRingBuffer: LockFreeRingBuffer?` — stream bridge buffer
- `setupEngine()` — engine initialization
- `rewireForCurrentFile()` → `rewireForFile(_:)` — graph wiring
- `scheduleFrom(time:seekID:)` — audio scheduling
- `startEngineIfNeeded()` — engine lifecycle
- `startProgressTimer()` — progress timer lifecycle
- `installVisualizerTapIfNeeded()` — visualizer tap
- `removeVisualizerTapIfNeeded()` — visualizer tap
- `makeStreamRenderBlock(ringBuffer:)` — stream render block (nonisolated static)
- `activateStreamBridge(ringBuffer:sampleRate:)` — stream bridge activation
- `deactivateStreamBridge()` — stream bridge deactivation

#### 2. No-op Async Task in scheduleFrom — REMOVED (Oracle review)

Empty `Task { @MainActor in }` block was left over from extraction. Removed per Oracle review finding.

### Phase 1-3 Removals (PR #52, 2026-02-22)

#### 3. FourCC String Extension — REMOVED (Phase 3)
Zero callers in codebase. Saved 18 lines.

#### 4. Stale Extraction Comments — REMOVED (Phase 3)
Comments marking code for future extraction addressed by Phases 1-2.

#### 5. Redundant eqNode Manual Assignments — REMOVED (Oracle #1)
Made redundant by `didSet` handlers.

#### 6. Unused Imports — REMOVED (CodeRabbit)
`import Combine` and `import Accelerate` no longer needed after EQ extraction.
