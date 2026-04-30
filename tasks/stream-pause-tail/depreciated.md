# Deprecated/Legacy Code: Stream Pause Tail

> **Purpose:** Track deprecated or legacy code removed during this task.

## Removed during implementation

### `StreamDecodePipeline.pause()` / `StreamDecodePipeline.resume()` — sync wrappers

**Reason:** Replaced by async `pauseByUser()` / `resumeByUser()` barriers that await the decode-queue producer-quiesce step. The sync wrappers fired untracked `Task { ... }` and bypassed `StreamPlayer.chainTransport`, making them an unsafe future entry point.

**Caller audit before removal:** `rg "pipeline\.pause\(\)|pipeline\.resume\(\)" MacAmpApp/` returned zero hits — all internal callers already migrated to the async forms.

### `Task.sleep(for: .milliseconds(30))` heuristic in `pauseByUser()`

**Reason:** Initial fix for the consumer-side render-vs-flush race. The 30 ms wait was sized for built-in output (~12–23 ms render quantum) but fails on AirPlay / HDMI configurations where Core Audio can use a 4096-frame buffer (~93 ms quantum). Replaced by a structural fix in `LockFreeRingBuffer`: seqlock counter + `compareExchange` on `readHead` advance, which detects a concurrent flush regardless of timing.

**No code remained from this approach** — the sleep was removed in the same change that introduced the seqlock + CAS.

---

## Not removed (intentional retention)

### `LockFreeRingBuffer.flush(newGeneration:)` `newGeneration` parameter

The user-pause path calls `flush(newGeneration: false)` (no generation bump — the format hasn't changed, just want to drop stale PCM). The format-change path (post-T7 unified pipeline) still uses `newGeneration: true`. Both paths remain valid; the parameter stays.
