# Plan: AVAudioEngine -10868 Recommendation Set

Date: 2026-03-14

## Objective
Produce recommendation-only guidance for the `AVAudioEngine` initialization failure, with emphasis on graph management and unified-pipeline lifecycle interactions.

## Steps
1. Confirm what `-10868` means from local SDK headers.
2. Trace local playback graph wiring and stream-bridge graph wiring.
3. Compare current implementation against `tasks/unified-audio-pipeline/` assumptions and incomplete verification items.
4. Identify the most likely format-management regression.
5. Provide fix recommendations only, prioritized by:
   - graph format correctness
   - lifecycle/start sequencing
   - engine reconfiguration handling
   - verification gaps

## Recommendation Focus
- Separate local-file graph negotiation from stream-bridge graph negotiation.
- Make engine start failure a hard gate for tap install and `playerNode.play()`.
- Collapse graph start to a single authority.
- Add lifecycle handling for configuration changes and stream/local transitions.
