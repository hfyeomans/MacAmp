# Depreciated: AudioPlayer Seek Extraction

Updated: 2026-10-02

Superseded designs and any code this task removes.

## Superseded designs

- **6-callback `SeekController`** (March plan): `var engine: AudioEngineController!`; callbacks `onTransition`, `onProgressUpdate`, `onRequestNextTrack`, `onPlaylistAdvanceRequest`, `onPlaybackFinished`, `onRemoveVisualizerTap`; guard API `invalidateSeekID`/`activateSeekGuard`/`clearSeekGuard`. Rejected 2026-03-25 under D8 as pass-through indirection (Principle 6). Only the lean Option B is under re-evaluation (`plan.md`).
- **Research guard API** `invalidateSeekID`/`setSeekGuardActive`/`resetCompletionGuard`: inconsistent with the plan's API; dropped with the design.
- **Goal "AudioPlayer under 600 lines through seek extraction"** (734 to ~554): unreachable at 1,101 lines; replaced by `plan.md` step 5.

## Removed code

None. Task not started.
