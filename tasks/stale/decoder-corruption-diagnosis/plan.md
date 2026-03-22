# Plan: Decoder Corruption Recommendation Set

Date: 2026-03-14

## Objective
Recommend the fastest next diagnostic step for warped/corrupted stream PCM and assess the five specific suspicions without changing code.

## Steps
1. Trace the current parser → packet → converter callback path in code.
2. Verify Apple’s `AudioConverterComplexInputDataProc` contract from local SDK headers.
3. Rank options A/B/C and define a better D if available.
4. Evaluate the five specific suspicions against the current implementation.
5. Deliver recommendation-only guidance.

## Expected Output
- Best next step for root-cause isolation
- Why that step beats the alternatives
- Specific ranking of the five suspected fault areas
