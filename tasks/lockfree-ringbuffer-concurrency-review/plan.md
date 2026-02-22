# Plan: Stabilize SPSC Ring Buffer + Concurrency Tests

1. Preserve monotonic counters in `flush()`.
- Represent flush/empty as `readHead = writeHead`.
- Do not reset heads to zero.

2. Make distance math non-trapping.
- Guard against invalid snapshots (`distance > capacity`) before converting to `Int`.
- Treat invalid snapshot as transient empty state in reader and telemetry accessor.

3. Harden write path for oversized inputs.
- Cap one write operation to `capacity` frames.
- Keep newest tail from source when input exceeds capacity.

4. Avoid lost updates on `readHead`.
- Use RMW increment in reader (`wrappingIncrementThenLoad`) instead of plain store.

5. Rewrite concurrent tests to terminate robustly.
- Use `writerDone` atomic signal.
- Reader exits after writer completion and repeated empty reads, not exact frame-count equality.
- Keep assertions focused on no crash/hang and generation-change observability.

6. Verify via available local tooling and report limits.
- Attempt sandbox-safe test commands.
- If full run remains blocked, report exactly why and what was validated statically.

