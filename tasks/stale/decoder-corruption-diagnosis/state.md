# State: Decoder Corruption Recommendation Set

Date: 2026-03-14

## Status
- Analysis complete
- Recommendation-ready
- No code changes made

## Current Answer
- Best immediate choice from the listed options: **A**
- Best overall approach: **D = deterministic offline capture/replay harness**

## Ranked Suspicion Summary
1. Decoder/input-callback accounting
2. ICY framing contamination testability
3. Throughput/underrun side effects
4. Packet splitting details
5. `noMoreInputData` handling
6. `retainedBuffers` as currently written
