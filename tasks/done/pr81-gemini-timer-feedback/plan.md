# PR 81 Gemini Timer Feedback Plan

## Recommendation

Treat both Gemini threads as one actionable cleanup.

## Proposed Code Change

In `ButterchurnPresetManager.startCycling()` and `ButterchurnPresetManager.startTrackTitleTimer()`:

1. Keep the current manual `Timer(timeInterval:repeats:)` construction.
2. Keep `RunLoop.main.add(timer, forMode: .common)`.
3. Replace the `Task { @MainActor in ... }` blocks with:

```swift
dispatchPrecondition(condition: .onQueue(.main))
MainActor.assumeIsolated {
    self?.nextPreset()
}
```

and the equivalent `showCurrentTrackTitle()` callback.

## PR Thread Handling

Because PR #81 is already merged, resolve via follow-up:

1. Apply the tiny follow-up patch on the current active branch or a short branch off `main`.
2. Build/test the app target.
3. Commit with a message that references PR #81 / Gemini timer feedback.
4. Reply to the two open PR #81 review threads with the follow-up commit or PR reference.
5. Resolve both threads with `scripts/resolve-pr-comments.sh`.
