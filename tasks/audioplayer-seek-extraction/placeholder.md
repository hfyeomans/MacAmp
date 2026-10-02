# Placeholders: AudioPlayer Seek Extraction

Updated: 2026-10-02

Cleanup targets flagged for this task (flag, don't fix until the listed condition holds).

| Target | Location (`AudioPlayer.swift`, `b3894d9`) | Fix and condition |
|---|---|---|
| Guard-clear `Task.sleep` delays | `playTrack` 50 ms (`:527`); `seek` 150 ms delayed `onPlaybackEnded` after a failed schedule (`:835`) and 100 ms guard clear (`:843`); `handleEngineDidReconfigure` 100 ms (`:950`) and 200 ms (`:954`); `onPlaybackEnded` 200 ms unlock (`:1035`). Two sleep APIs are mixed: `nanoseconds:` at `:527/:835/:843/:1035`, `.milliseconds` at `:950/:954`. | Replace with one structured guard-clear. The delays are timing-sensitive, so change them only after the seek characterization tests pass, and in a commit separate from the extraction. |
| Force-unwrapped engine | `@ObservationIgnored private var engine: AudioEngineController!` (`:16`) | Make it non-optional if the init order allows. A new `SeekController` must not copy the pattern (`plan.md` step 3). |
