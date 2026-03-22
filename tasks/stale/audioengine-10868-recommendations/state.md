# State: AVAudioEngine -10868 Recommendation Set

Date: 2026-03-14

## Status
- Research complete
- Recommendation set ready
- No code changes requested or made

## Conclusions
- `-10868` is `kAudioUnitErr_FormatNotSupported`.
- The strongest current hypothesis is a local-file graph format regression introduced during unified-pipeline work:
  - `rewireForCurrentFile()` now uses a fixed stereo hardware-format graph.
  - local files are not guaranteed to match that assumption.
- The pasted log is also explained by current failure handling:
  - engine start errors are logged but not propagated
  - tap install and `playerNode.play()` still proceed

## Additional Risks
- Missing `AVAudioEngineConfigurationChange` handling
- Duplicate engine-start attempts in the local playback path
- Incomplete verification tasks in `tasks/unified-audio-pipeline/`, especially local-file regression and stream/local switching

## User-Facing Answer Direction
- Say that incomplete phases can absolutely be the reason.
- Recommend finishing graph-management hardening before treating the issue as a one-off runtime quirk.
- Prioritize local-file format negotiation, engine-start gating, and configuration-change recovery.
