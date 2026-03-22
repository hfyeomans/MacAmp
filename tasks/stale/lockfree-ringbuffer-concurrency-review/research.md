# Research: LockFreeRingBuffer Concurrency + Test Host Crashes

## Scope
- `MacAmpApp/Audio/LockFreeRingBuffer.swift`
- `Tests/MacAmpTests/LockFreeRingBufferTests.swift`

## Findings

1. `flush()` violated monotonic head invariants.
- Previous behavior reset `readHead` to 0 then `writeHead` to 0.
- Because heads are separate atomics, readers/writers can observe mixed snapshots (e.g. old `readHead`, new `writeHead`) where `writeHead < readHead`.
- This creates wrapped distances (`wh &- rh`) that are huge and invalid for `Int` conversion.

2. `Int(wh &- rh)` is trap-prone in transient invalid states.
- Converting large `UInt64` distances to `Int` can trap if value is not representable.
- In this code, that can happen during invalid snapshots from head resets.

3. Oversized writes (`frameCount > capacity`) could overrun storage.
- The previous `write` path could set `framesToWrite = frameCount` and compute `secondChunk` > `sampleCount`.
- This can lead to `memcpy` writing beyond ring buffer bounds.

4. `readHead` update race under overrun policy.
- Reader used `readHead.store(rh + framesToRead)`.
- Writer overrun path used RMW increment on `readHead`.
- Mixed store + RMW to same atomic can lose updates when interleaved.

5. Concurrency stress tests had non-terminating completion criteria.
- Tests expected reader to consume exact produced frame count.
- Buffer deliberately drops data on overrun (drop-oldest), so exact-equality completion can deadlock.
- This explains host hang/freeze cascade when one test never finishes.

6. Wrap-around second-chunk source in `read()`
- Reading second chunk from `storage` base pointer is correct.
- `storage + startSample + firstChunk` would be incorrect because wrapped region starts at index 0.

## Constraints encountered
- `xcodebuild test` cannot run in this sandbox due restricted system cache/service paths.
- `swift test --disable-sandbox` starts but workspace has unrelated pre-existing build issue (`multiple producers` in `VideoWindowChromeView.swift.o`).

