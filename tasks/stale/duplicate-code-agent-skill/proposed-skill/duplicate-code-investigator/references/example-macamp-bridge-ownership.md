# Example: MacAmp Bridge Ownership Split

## Why This Example Exists

This is a repo-specific case study for a high-value failure mode:

- one subsystem owns stream startup and bridge activation
- another path can tear the bridge down directly
- direct local-play entry points bypass the coordinator
- stale async stream callbacks can later re-activate the bridge

This example is not a universal rule. Use it only when the current project has a similar
shape: split ownership, async callbacks, setup/teardown symmetry, or coordinator bypasses.

## Problem Shape

In MacAmp:

- `PlaybackCoordinator` wires stream callbacks and activates the bridge on format readiness
- `AudioPlayer` can tear the bridge down during local-file rewiring
- some UI flows call `audioPlayer.addTrack(url:)` directly instead of routing through the coordinator

That creates two related bug classes:

1. split ownership of bridge lifecycle
2. direct local handoff that does not fully stop or transfer the stream backend owner

## Why It Matters

This is not classic copy/paste duplication. It is behavioral duplication and split ownership:

- multiple places can initiate or tear down the same bridge lifecycle
- an older async owner can continue acting after a new owner took over
- direct paths can bypass the intended choke point

## Review Heuristics

When a project resembles this case, check for:

- async callback re-entry after a handoff
- stale producer still running after consumer teardown
- direct paths that bypass the main coordinator or owner
- setup and teardown split across multiple layers
- lifecycle methods that are individually guarded but collectively ownerless

## Preferred Fix Shape

Prefer:

- one owner for bridge activation and teardown
- explicit session or generation checks on async callbacks
- direct paths routed through the same coordinator or facade
- producer stop and consumer teardown performed as one ownership transfer

## MacAmp-Specific References

- `MacAmpApp/Audio/PlaybackCoordinator.swift`
- `MacAmpApp/Audio/AudioPlayer.swift`
- `tasks/audio-pipeline-duplicate-investigation/research.md`

Use these only when analyzing MacAmp or a structurally similar system.
