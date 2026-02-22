# Placeholder: Internet Streaming Volume Control

> **Purpose:** Documents intentional placeholder/scaffolding code in the codebase that is part of this planned feature. Per project conventions, we use centralized placeholder.md files instead of in-code TODO comments.

---

## Placeholder Code

### 1. StreamPlayer.balance (Stored, Not Applied)

**File:** `MacAmpApp/Audio/StreamPlayer.swift:46-50`
**Purpose:** Scaffolding for Phase 2 Loopback Bridge
**Status:** Property stores balance value but does not apply it (AVPlayer has no `.pan` property)
**Action:** Will be applied when Phase 2 routes stream audio through AVAudioEngine's playerNode.pan

### 2. PlaybackCoordinator.supportsVisualizer

**File:** `MacAmpApp/Audio/PlaybackCoordinator.swift:94-97`
**Purpose:** Scaffolding for Phase 2 visualizer dimming UI
**Status:** Flag declared and computed correctly but no UI consumer yet. Visualizer naturally shows empty during streaming (no tap data).
**Action:** Phase 2 will wire this flag to VisualizerView for proper dimming. Once Loopback Bridge is active, flag will always return true.
