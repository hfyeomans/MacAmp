# AirPods Route Gate Validation State

Status: analysis complete; no production code edits requested or made.

Decision: diagnosis is supported. `AVAudioEngineConfigurationChange` is not a general macOS route-change signal; it is tied to engine I/O configuration changes such as channel count or sample rate.

Implementation caution: a HAL listener must arm a bounded video route-change gate directly. It should not call the existing engine will-handler unless that path is refactored to avoid an indefinite `UInt64.max` gate when no engine did-handler follows.
