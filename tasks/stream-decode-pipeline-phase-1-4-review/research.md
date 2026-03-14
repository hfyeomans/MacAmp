# Research

Scope: Code review of StreamDecodePipeline Phase 1.4 and supporting streaming/decode components.

Files reviewed:
- MacAmpApp/Audio/Streaming/StreamDecodePipeline.swift
- MacAmpApp/Audio/Streaming/ICYFramer.swift
- MacAmpApp/Audio/Streaming/AudioFileStreamParser.swift
- MacAmpApp/Audio/Streaming/AudioConverterDecoder.swift
- MacAmpApp/Audio/LockFreeRingBuffer.swift

Focus areas validated:
1. MainActor/decode queue isolation boundaries
2. Generation token stale-work guards
3. C API dispose ordering
4. Prebuffer threshold and format-ready behavior
5. SessionDelegateProxy @unchecked Sendable
6. DecodeContext @unchecked Sendable
7. Retain cycle risk
8. URLSession lifecycle
9. Decode queue thread safety pattern
10. End-to-end state handling and teardown

Key findings:
- `stop()` does not advance pipeline generation. Stale callbacks from the stopped run can still pass generation checks and mutate state (`.buffering` / `.playing`) after stop.
- Response handling is deferred to MainActor via Task before framer configuration, while data callbacks can proceed immediately after `completionHandler(.allow)`. This can allow data parsing before ICY metaint setup.
- Decode shutdown is asynchronous; pending decode blocks can still run and write to ring buffer before shutdown closure executes. No decode-path generation guard exists.
- HTTP error and completion paths update state but do not call teardown (`stopInternal`), leaving session/context objects alive longer than intended.
- `SessionDelegateProxy` Sendable safety depends on convention (callbacks set once) but mutable vars do not enforce that contract.

Validated non-issues:
- Converter-before-parser disposal ordering is correct in `DecodeContext.shutdown()`.
- `DecodeContext` queue confinement is mostly consistent.
- No obvious retain cycles in closure captures.
