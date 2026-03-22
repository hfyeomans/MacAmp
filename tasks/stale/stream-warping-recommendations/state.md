# State: Stream Audio Warping Recommendation Set

Date: 2026-03-14

## Status
- Research complete
- Recommendation-only answer ready
- No code changes made

## Current Conclusion
- Apple’s `AVAudioSourceNode` API is designed to support a different block format and output format, including sample-rate conversion.
- That makes the current 44.1k block + 48k graph design conceptually correct.
- Recommendation: choose **B** as the architectural direction.

## Caveat
- If runtime measurements prove the render block is actually being driven at device-rate frame demand, then the implementation or assumptions need revision.
- That should be established with instrumentation before redesigning the decoder around hardware-rate output.

## Additional Suspects
- `AudioConverterDecoder` packet/callback accounting
- Ring-buffer underrun behavior masked as pitch/warp
- Incomplete verification of the unified stream path under non-44.1k output devices
