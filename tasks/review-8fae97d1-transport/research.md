# Research

- Reviewed merge commit `8fae97d1d31ac8a4404519f5c14b348f82efb956` against first parent `ad434499353514136fb58a7aaabcc72311493a8b`.
- Inspected source changes in `AudioPlayer.swift`, new `AudioEngineController.swift`, and related coordinator/tests.
- Verified the current tree still builds/tests via XcodeBuildMCP (`build_macos`, `test_macos`).
- Main regression candidate found: `scheduleFrom()` no longer re-synchronizes `currentDuration` from the file length, while `addTrack()` can still overwrite `currentDuration` from async metadata with `0`/stale values.
