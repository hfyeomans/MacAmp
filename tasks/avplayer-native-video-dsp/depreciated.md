# Depreciated: AVPlayer-Native Video DSP

> **Task:** `tasks/avplayer-native-video-dsp/`
> **Status:** POPULATED — implementation Phases 1-8 complete (Phase 8 automated gates ✅ 2026-06-27; manual/hardware gates pending). Last revised 2026-09-05.

Per project convention, deprecated/replaced code is removed entirely (not marked with `// Deprecated`) and its removal documented here. This file tracks what gets removed during the implementation, not what's preserved on the saved branch (`feat/video-audio-engine-routing`).

The saved branch itself is the canonical record of what the engine-routing approach looked like. See `tasks/video-audio-engine-routing/state.md` for the PAUSED-AS-REFERENCE banner that points at the saved branch's commits.

## Code removed during this task

| Removed | Phase | Replaced by |
|---|---|---|
| The withdrawn **ADR-4 A/B-swap install method** (`installCoefficientSet`) plus the `coefficientBlockA`/`coefficientBlockB` double-buffer and its manual alloc/dealloc on `VideoTapContext` | 3 (install method already withdrawn before the Phase 2 close per Oracle BLOCKER) | `let coefficients: Mutex<BiquadCoefficientSet?>` + `installCoefficients(_:)` hand-off (ADR-4 amendment #2); render reads via `withLockIfAvailable` into a render-owned `BiquadCascade` cache |
| The Phase-2 **`attachVideoTap` / `detachVideoTap` facades** on `AudioPlayer` | 2 (Oracle Option C structural fix) | `startVideoLoad(track:)` orchestration — generation counter + `audioMixBuilder` + `isStillRelevant`, installing `audioMix` during `AVPlayerItem` construction (ADR-7 amendment) |
| **`wasVideoBridge`** field on `PreReconfigureSnapshot` (forward-looking leftover cherry-picked from the engine-routing branch) | Step 1, commit `ffd77c1` | Nothing — the field belonged to the abandoned engine-routing design |

No legacy code was preserved with `// Deprecated` / `// Legacy` markers.
