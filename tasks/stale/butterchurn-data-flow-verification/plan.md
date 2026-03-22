# Plan

1. Summarize the end-to-end data flow from AVAudioEngine tap through VisualizerPipeline to ButterchurnBridge JS calls.
2. List lightweight verification points (tap install log, ButterchurnBridge update log, debugger inspection of butterchurn arrays, gating in snapshot method).
3. Call out potential breaks introduced by extraction (tap installation, audioPlayer configuration, playback mode gating, main thread dispatch).
4. Provide a minimal, non-permanent debugging approach (lldb or temporary log snippet guidance) and ask for any needed clarifications (local audio vs stream/video).
