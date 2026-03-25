# Research: Intra-File Deduplication & Simplification

> **Description:** Analysis of intra-file duplications and dead code across the 5 decomposition targets.
> **Purpose:** Provides the evidence base for the dedup-first-pass before structural extraction.

---

## Research Sources

- **Responsibility maps:** All 5 target files fully mapped (2026-03-24)
- **Gemini research:** Swift file decomposition best practices, hybrid dedup timing
- **Oracle review:** gpt-5.3-codex xhigh (2026-03-24) — confirmed Phase 2a dedup before extraction for intra-file duplications

## Gemini Hybrid Dedup Guidance (2026-03-24)

> "If you have two nearly identical 50-line view builders sitting right next to each other in a massive file, the duplication is obvious. If you move one to FileA.swift and the other to FileB.swift, you might never notice the duplication again."

**Recommended approach:**
1. Phase 2a: Intra-file dedup FIRST (consolidate within each large file)
2. Phase 2b: Structural extraction (move code to new files)
3. Phase 2c: Cross-file dedup AFTER (deduplicate between new files)

## Oracle Classification (2026-03-24)

**Do Phase 2a (before extraction) for:**
- (a) SkinManager playlist parsing — highly localized, same file, different defaults
- (b) SkinManager viscolor parsing — highly localized, same file
- (d) VisualizerPipeline resampling — identical pattern, same class
- (e) VisualizerPipeline memcpy blocks — identical pattern, same class

**Defer to Phase 2c (after extraction) for:**
- (c) SkinManager sprite extraction loops — too behavior-coupled to fallback/preprocess/cache paths

**Remove during decomposition (trivially dead):**
- `formatHint(forContentType:)` — zero callers
- `thumbWidth` — zero callers
- `prepare()` dead guards — can never trigger

## Identified Duplications

### SkinManager.swift — Playlist Style Parsing (POSSIBLE BUG)

| Location | Fallback Normal | Fallback Current | Fallback BG | Fallback Highlight |
|----------|----------------|-----------------|-------------|-------------------|
| `parseDefaultSkinFully` (line 177) | `Color.green` | `Color.white` | `Color.black` | `Color.blue` |
| `applySkinPayload` (line 744) | `.white` | `.white` | `.black` | `Color(r:0,g:0,b:0.776)` |

The default Winamp skin `pledit.txt` defines specific colors. When `pledit.txt` is missing, the fallback should match Winamp's hardcoded defaults. One of these paths has the wrong defaults. Characterization test needed before fixing.

### SkinManager.swift — Viscolor Parsing

| Location | Fallback |
|----------|----------|
| `parseDefaultSkinFully` (line 190) | 24 green colors |
| `applySkinPayload` (line 755) | Empty array |

Different fallbacks may be intentional: default skin has known-good visualizer colors, custom skins without `viscolor.txt` get no colors (uses a system default). Need to verify this is correct behavior.

### VisualizerPipeline.swift — Resampling

`getRMSData` and `getWaveformSamples` both do:
```swift
let index = (i * source.count) / targetCount
result.append(source[index])
```

Identical nearest-neighbor resampling. Trivial extraction.

### VisualizerPipeline.swift — memcpy in tryPublish

4 blocks of nearly identical `withUnsafeBufferPointer`/`memcpy` code. Pattern:
```swift
source.withUnsafeBufferPointer { srcBuf in
    destination.withUnsafeMutableBufferPointer { dstBuf in
        memcpy(dstBuf.baseAddress!, srcBuf.baseAddress!, count * MemoryLayout<Float>.stride)
    }
}
```

Extractable to shared helper. Audio-thread safe since the helper would be called within the same lock scope.

## Dead Code Inventory

| File | Symbol | Line | Callers | Action |
|------|--------|------|---------|--------|
| SkinManager.swift | `import Combine` | 2 | 0 | Remove |
| VisualizerPipeline.swift | `prepare()` resize guards | 255-261 | 0 (dead branch) | Remove |
| StreamDecodePipeline.swift | `formatHint(forContentType:)` | 457 | 0 | Remove |
| WinampEqualizerWindow.swift | `thumbWidth` | 65 | 0 | Remove |
