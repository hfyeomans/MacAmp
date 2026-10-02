# Plan

1. Verify each pass-1 MUST-FIX against the current diff and line-level implementation.
2. Search for duplicate or competing volume/play paths that bypass the intended choke points.
3. Check the new `videoLoadTask == nil` guard against post-load transport flows.
4. Run the smallest practical build/test command, or document environment blockers.
5. Provide a pass/fail judgment and score.

