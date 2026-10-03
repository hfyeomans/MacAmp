# State: AudioPlayer Seek Extraction

Updated: 2026-10-02

**Status:** DEFERRED. Roadmap slot SS-1 (`tasks/_context/plan.md`): start of the Structure Sprint, after S3-4 merges (OGG edits `AudioPlayer.swift`) and SS-0 drafts the source-to-target map. Not started; no branch.

Re-evaluates decision D8 (keep `AudioPlayer` whole) and, if the answer is go, extracts the seek state machine into a lean `SeekController`.

## D8: under re-evaluation

D8 (2026-03-25) kept `AudioPlayer` as one class (Option C): one cohesive responsibility (local-playback orchestration facade), no concrete failure mode, seek state tightly coupled to play/stop/`onPlaybackEnded` (Principle 3), and the two swiftlint suppressions read as threshold mismatches. The 6-callback `SeekController` was rejected as pass-through indirection (Principle 6); see `depreciated.md`.

D8 is under re-evaluation, not in force. Two of its three revisit triggers have fired:

| Trigger | State |
|---|---|
| File grows past 800 lines | Fired: 1,097 lines at `30d9de3` (1,097 before PR #91). |
| A genuinely new responsibility | Fired: Video Tap section (`AudioPlayer.swift:176-300`) and Engine Reconfiguration Handlers (`:848-976`); the handlers also write all three seek guards. |
| Seek logic must be testable on its own | Not fired. |

## Option under re-evaluation (Option B)

A lean `SeekController` with direct references to the engine and `videoPlaybackController` and about 2 callbacks (`onRequestNextTrack`, `onPlaylistAdvanceRequest`). Kill switch: cancel if state ownership would still be split between `SeekController` and `AudioPlayer`. Steps and open questions: `plan.md`.

## Precondition

Seek characterization tests come first (`plan.md` step 1). No test references the three guard vars or `cancelPendingReconfigure` today.

## Open decision

The `file_length` and `type_body_length` suppressions. Seek extraction alone leaves both SwiftLint counts above 600 (`research.md`, File), so it does not settle them (`plan.md` step 5).

## Blockers

None beyond sequencing (S3-4, SS-0).
