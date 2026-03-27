# Plan: Intra-File Deduplication & Simplification

> **Description:** First-pass cleanup of duplicated logic and dead code within the 5 decomposition target files.
> **Purpose:** Consolidate obvious duplicates while they're still visible side-by-side, before structural extraction scatters them across files.

---

## Objective

Clean up intra-file duplications and dead code in the 5 decomposition targets. This is Phase 2a of the hybrid dedup approach (Gemini + Oracle, 2026-03-24). All changes are behavior-preserving.

## SkinManager.swift (783 lines) — 2 dedup targets + dead code

### Dedup 1: Playlist Style Parsing

`parseDefaultSkinFully` (lines 177-188) and `applySkinPayload` (lines 744-753) both parse `pledit.txt` into `PlaylistStyle` with **different defaults**:
- `parseDefaultSkinFully`: `Color.green` / `Color.white` / `Color.black` / `Color.blue`
- `applySkinPayload`: `.white` / `.white` / `.black` / `Color(red:0, green:0, blue:0.776)`

**Steps:**
1. Add characterization test capturing current behavior for both code paths
2. Investigate which defaults match Winamp 2.x behavior (the `applySkinPayload` defaults likely match the actual Winamp default skin pledit.txt values)
3. Extract shared `parsePlaylistStyle(from pleditData: Data?, fallback: PlaylistStyle) -> PlaylistStyle` private method
4. Both callers use the shared method with their respective fallbacks
5. If the defaults are wrong in one path, fix it (the characterization test will catch the change)

### Dedup 2: Visualizer Color Parsing

`parseDefaultSkinFully` (lines 190-195) and `applySkinPayload` (lines 755-758) both parse `viscolor.txt` with different fallbacks:
- `parseDefaultSkinFully`: 24 green colors array
- `applySkinPayload`: empty array

**Steps:**
1. Extract shared `parseVisualizerColors(from viscolorData: Data?, fallback: [Color]) -> [Color]` private method
2. Both callers use the shared method with their respective fallbacks (different fallbacks are intentional — default skin has a known-good fallback, custom skins fall back to empty)

### Dead Code: Combine Import

Remove `import Combine` (line 2) — zero usage anywhere in the file.

## VisualizerPipeline.swift (699 lines) — 2 dedup targets + dead code

### Dedup 3: Nearest-Neighbor Resampling

`getRMSData(bands:)` (lines 493-500) and `getWaveformSamples(count:)` (lines 514-521) share identical resampling logic: `(i * sourceCount) / targetCount`.

**Steps:**
1. Extract `private func resample(_ source: [Float], to targetCount: Int) -> [Float]` method on VisualizerPipeline
2. Both methods call the shared helper

### Dedup 4: tryPublish memcpy Blocks

`tryPublish` in VisualizerSharedBuffer has 4 nearly identical `withUnsafeBufferPointer`/`memcpy` blocks (lines 58-64, 69-75, 95-102, 105-112).

**Steps:**
1. Extract `private func copyBuffer(from source: [Float], to destination: inout [Float], count: Int)` method on VisualizerSharedBuffer
2. All 4 memcpy blocks call the shared helper
3. Verify no audio-thread performance regression (the helper should inline — it's a trivial wrapper)

### Dead Code: ScratchBuffers.prepare() Guards

Remove dead guards in `prepare()` (lines 255-261) — `if rms.count < bars` and `if spectrum.count < bars` can never trigger (both arrays initialized at maxBars=20 and bars is always 20).

## StreamDecodePipeline.swift (713 lines) — dead code only

### Dead Code: formatHint(forContentType:)

Remove `formatHint(forContentType:)` (line 457) — `static` function with zero callers in entire codebase. Vestigial from early stream development.

## WinampEqualizerWindow.swift (626 lines) — dead code only

### Dead Code: thumbWidth

Remove `private let thumbWidth: CGFloat = 11` (line 65) — declared but never referenced. WinampVerticalSlider takes `thumbHeight` only.

## AudioPlayer.swift (740 lines) — no changes

No intra-file duplications or dead code to address. Seek extraction is Phase 2b.

## Files Modified (no new files created)

| File | Changes | Est. Line Delta |
|------|---------|----------------|
| `SkinManager.swift` | 2 shared helpers extracted, Combine import removed | ~-20 lines (dedup reduces duplication) |
| `VisualizerPipeline.swift` | 2 shared helpers extracted, dead guards removed | ~-25 lines |
| `StreamDecodePipeline.swift` | Dead function removed | ~-15 lines |
| `WinampEqualizerWindow.swift` | Dead constant removed | ~-1 line |

**No new files created.** All changes are within existing files.

## Constraints

- All changes are behavior-preserving refactors
- Add characterization tests BEFORE changing SkinManager defaults
- Do not restructure files — this is dedup/simplify only, not extraction
- Do not touch AudioPlayer.swift (seek extraction is a separate task)
- Single branch: `refactor/intra-file-dedup-simplification`
- After this task merges, all 5 decomposition plans must be refreshed (line numbers changed)

## Verification

- All existing tests pass
- New characterization tests for playlist style defaults pass
- Visualizer still works correctly (resampling + memcpy changes are on audio path)
- Skin loading still works (parsing changes affect fallback behavior)
- Stream still works (dead code removal only)
- EQ window still renders (dead code removal only)
- `xcodegen generate` + XcodeBuildMCP build + test pass
- Thread Sanitizer clean
