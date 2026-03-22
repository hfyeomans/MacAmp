# Plan: Stream Audio Warping Recommendation Set

Date: 2026-03-14

## Objective
Recommend the correct fix direction for stream audio warping in the unified pipeline without making code changes.

## Steps
1. Verify how decoder sample rate, source-node block format, graph format, and ring buffer interact in current code.
2. Check Apple’s `AVAudioSourceNode` contract from local SDK headers.
3. Decide whether decoder-side SRC or engine-side SRC is the intended architecture.
4. Identify the most plausible non-SRC causes if the current architecture is already valid.
5. Deliver recommendation-only guidance, including what to instrument next.

## Expected Output
- Clear answer to A vs B
- Explicit statement on render-block `frameCount`
- Short list of the most likely alternative fault areas
