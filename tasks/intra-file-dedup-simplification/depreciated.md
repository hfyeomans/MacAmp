# Deprecated/Legacy Code: Intra-File Dedup & Simplification

> **Description:** Track deprecated or legacy code removed during this task.
> **Purpose:** Per project conventions, deprecated code is removed rather than marked with comments, and findings are recorded here.

---

## Dead Code Removed

| File | Symbol | Lines (pre-edit) | Reason |
|------|--------|-------------------|--------|
| `SkinManager.swift` | `import Combine` | 2 | Zero Combine usage — class is `@Observable`, not `ObservableObject` |
| `VisualizerPipeline.swift` | `if rms.count < bars { rms = ... }` + `if spectrum.count < bars { spectrum = ... }` in `prepare()` | 255-261 | Dead branch — `rms` and `spectrum` pre-allocated at `maxBars=20` in `init()`, only caller passes `bars=20`. Would also violate "no allocation on audio thread" if reached. |
| `StreamDecodePipeline.swift` | `static func formatHint(forContentType:) -> AudioFileTypeID` | 457-462 | Zero callers in entire codebase. Vestigial from early stream development. The companion `formatHint(for url:)` remains actively used. |
| `WinampEqualizerWindow.swift` | `private let thumbWidth: CGFloat = 11` | 65 | Never referenced — literal `11` used directly at call site (line 393). `thumbHeight` is the only slider dimension used by `WinampVerticalSlider`. |

## Duplicated Code Consolidated (not removed, refactored)

| File | What | Before | After |
|------|------|--------|-------|
| `SkinManager.swift` | Playlist style parsing (2 locations with different fallback defaults) | `parseDefaultSkinFully` lines 177-188 + `applySkinPayload` lines 744-753 each had inline `PLEditParser.parse` with hand-written `PlaylistStyle(...)` fallbacks | Shared `parsePlaylistStyle(from:)` static helper + `PlaylistStyle.winampDefault` canonical defaults in `Skin.swift` |
| `SkinManager.swift` | Visualizer color parsing (2 locations with different fallbacks) | `parseDefaultSkinFully` lines 190-195 + `applySkinPayload` lines 755-758 each had inline `VisColorParser.parse` with different fallbacks (24 greens vs empty) | Shared `parseVisualizerColors(from:fallback:)` static helper |
| `SkinManager.swift` | Dictionary merge loops (3 locations) | Three `for (name, image) in dict { extractedImages[name] = image }` loops in `applySkinPayload` | Replaced with `extractedImages.merge(dict) { _, new in new }` |
| `VisualizerPipeline.swift` | Nearest-neighbor resampling (2 locations) | `getRMSData` lines 493-500 + `getWaveformSamples` lines 514-521 had identical `(i * source.count) / targetCount` loop | Shared `resample(_:to:)` private method; both callers now one-liners |
| `VisualizerPipeline.swift` | memcpy blocks (4 locations) | 4 near-identical `withUnsafeBufferPointer`/`memcpy` blocks in `tryPublish` | Shared `copyFloatBuffer(from:to:count:)` private method |
| `WinampEqualizerWindow.swift` | normalizedValue computation (3 locations) | `(value - range.lowerBound) / (range.upperBound - range.lowerBound)` computed inline in `sliderColor`, `thumbPosition`, `calculateFrameIndex` | Extracted `normalizedValue` computed property |

## Bug Fixed

| File | Bug | Fix |
|------|-----|-----|
| `SkinManager.swift` | Two code paths had inconsistent playlist color defaults — `parseDefaultSkinFully` used `Color.green`/`Color.blue`, `applySkinPayload` used `.white`/`Color(r:0,g:0,b:0.776)`. Neither fully matched Winamp 2.x. | Created `PlaylistStyle.winampDefault` with correct Winamp 2.x colors: green `#00FF00`, white, black, deep blue `#0000C6`. Both paths + `WinampPlaylistWindow` fallback now use it. |
