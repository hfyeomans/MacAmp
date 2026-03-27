# Plan

1. Inspect the 5 target docs and the 4 updating commits.
2. Cross-check named APIs/symbols/files against current code:
   - `supportsAudioProcessing`
   - `MenuActionTarget`
   - `toPixels`
   - deleted files list from cleanup
3. Validate document metadata and embedded line counts against the filesystem.
4. Check for impossible or stale `.swift:line` references.
5. Compare docs against S2 / Phase 2.5 implementation coverage:
   - PR #66 `os_workgroup`
   - PR #67 playlist ops
   - PR #68 stream counter
   - PR #69 AirPlay / Now Playing / remote commands
   - cleanup PRs #71 / #72
6. Deliver findings ordered by severity, with exact doc/code references.
