# Plan

1. Read all target files with line numbers and identify concurrency/state ownership boundaries.
2. Trace generation token use through all callback/queue entry points.
3. Audit lifecycle teardown ordering (decoder/parser/C API, URLSession, delegate).
4. Evaluate prebuffer and format-ready logic for duplicate or stale emissions.
5. Check Sendable justifications and queue confinement assumptions.
6. Report findings by severity with concrete file:line references.
