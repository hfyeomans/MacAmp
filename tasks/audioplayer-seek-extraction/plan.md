# Plan: AudioPlayer Seek Extraction

Updated: 2026-10-02

Steps for the D8 re-evaluation (SS-1) and, if go, the Option B extraction.

## Objective

Decide go/no-go on a lean `SeekController` (Option B). If go, move the seek state machine out of `MacAmpApp/Audio/AudioPlayer.swift` in one atomic step, with no behavior change. Line count is not the goal (Principle 2); the swiftlint suppressions are a separate decision (step 5).

## When and where

Start of the Structure Sprint, after S3-4 merges and SS-0 drafts the source-to-target map. Decompose in place in `Audio/`, before the `Audio/` subfolder move (SS-6).

## Step 0: Re-measure

At post-OGG HEAD, regenerate the seek map in `research.md`: every read and write of the three guard vars, the engine-reconfigure writers, every guard `Task.sleep` delay, and the SwiftLint counts for step 5.

## Step 1: Seek characterization tests (precondition)

Add these before any structural edit:

- Seek while playing: position updates and playback resumes.
- Seek while paused: position updates and playback stays paused.
- Seek to end: completion handling advances to the next track.
- Rapid seeks: only the last one takes effect; no stale completion stops playback.
- Stream: seek is a guarded no-op.
- A user action (play, pause, stop, seek, playTrack) during a pending engine reconfigure: `cancelPendingReconfigure` clears both guards, and the stale did-callback does not override the user's intent. `pendingReconfigureSnapshot` is private, so today only observer-level tests (`EngineConfigObserverTests`) cover reconfigure.

## Step 2: Go/no-go ADR

Run the pre-decomposition gate in `tasks/_context/principles.md` and write an ADR with the kill switch (Principle 7). The ADR must answer:

- **Who owns playback state?** `seek` and `onPlaybackEnded` both write `AudioPlayer`-owned state: `transition(to:)`, `currentTime`, `playbackProgress`, `visualizerPipeline.stopVideoVisualization()`, `nextTrack()`, `onPlaybackFinished`; `videoSeekCompletion` also writes `currentDuration`. If keeping that state in `AudioPlayer` needs the callbacks of the rejected 6-callback design, the kill switch fires.
- **How do the writers that stay reach the guards?** `playTrack`, `loadAudioFile`, `play`, `pause`, `stop` and the engine-reconfigure handlers (`cancelPendingReconfigure`, `handleEngineWillReconfigure`, `handleEngineDidReconfigure`) write the guards. Design one small API for them.

No-go: record it here and in `state.md`, keep `AudioPlayer` whole, then do step 5.

## Step 3: Extract (if go)

- Add `@MainActor final class SeekController` in `MacAmpApp/Audio/`.
- Pass `AudioEngineController` and `VideoPlaybackController` as non-optional init parameters. No `AudioEngineController!`.
- Limit callbacks to about 2: `onRequestNextTrack`, `onPlaylistAdvanceRequest`.
- Move these together, in one commit: `currentSeekID`, `seekGuardActive`, `isHandlingCompletion`, `shouldIgnoreCompletion(from:)`, `seek(to:resume:)`, `seekToPercent(_:resume:)`, `videoSeekCompletion`, `onPlaybackEnded(fromSeekID:)`. A partial move is the risky path.
- Keep in `AudioPlayer`: `transition(to:)`, `playTrack`, `loadAudioFile`, `play`/`pause`/`stop`, `handlePlaylistAction` (calls `seek(to: 0)`), and the engine-reconfigure handlers.
- Keep `AudioPlayer`'s public seek API as a facade, so `PlaybackCoordinator` (remote-command seek) and `WinampMainWindowInteractionState` (`seekToPercent`) do not change.
- Keep every guard delay as it is. Replacing them is a separate commit, after the step 1 tests pass (`placeholder.md`).

## Step 4: Verify and open the PR

See Verification below. Then run one `/codex:review --base main`, fix what affects correctness, and open the PR for the owner.

## Step 5: SwiftLint suppressions

Decide `// swiftlint:disable file_length` (`AudioPlayer.swift:1`) and `// swiftlint:disable:this type_body_length` (`:9`) whether or not step 3 runs. After extraction both SwiftLint counts stay near 650, so `file_length` still warns and `type_body_length` still errors (counts in `research.md`, File). Options: keep both as accepted threshold mismatches, change the thresholds, or split further along a real responsibility (Principle 2).

## Constraints

- Pure structural refactor; seek behavior does not change.
- Tests before extraction.
- `SeekController` knows nothing about playlists.
- Remote-command seek still goes through `PlaybackCoordinator`; video seek still delegates to `VideoPlaybackController`.
- In place in `Audio/`; no `Audio/Playback/` before SS-6.

## Verification

- `xcodegen generate`, then build and test with Thread Sanitizer (commands in `tasks/_context/state.md`, Process).
- swiftlint passes under the step 5 decision.
- Manual: slider seek while playing and while paused, seek to end then next track, rapid seeks, stream (no seek), Now Playing remote seek, video seek, and an output-route change (AirPlay or Control Center) during playback followed by a seek.
