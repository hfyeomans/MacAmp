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

## Oracle-Caught Behavior Regressions (Fixed)

These were behavior changes introduced by the dedup that the Oracle caught during review. Both follow the same pattern: two code paths had intentionally different fallbacks, and naive dedup collapsed them into one. The fix in both cases was to add a `fallback:` parameter preserving the original per-path behavior.

### P2: Viscolor fallback for custom skins (commit d113fde)

**What happened:** `parseVisualizerColors` was initially extracted without a `fallback:` parameter, returning `defaultVisualizerColors` (24 green entries) for ALL skins when `viscolor.txt` is missing.

**Why it's wrong:** The original `applySkinPayload` (custom skins) fell back to an empty array `[]`, which causes `VisualizerView` to skip rendering (it guards on `!colors.isEmpty`). Returning 24 greens instead would render an all-green monochrome visualizer for skins that intentionally omit viscolor.txt.

**Fix:** Restored `fallback:` parameter. Call sites:
- `parseDefaultSkinFully` → `fallback: Self.defaultVisualizerColors` (24 greens — default Winamp skin always has a valid palette)
- `applySkinPayload` → `fallback: []` (custom skins — VisualizerView handles empty gracefully)

**Future note:** The empty-array fallback for custom skins may itself be a latent bug — Winamp 2.x uses its default green palette when a skin lacks viscolor.txt, not "no visualizer." If we ever want to fix that, change the `applySkinPayload` call to pass `Self.defaultVisualizerColors` instead of `[]`. That would be a separate intentional behavior change, not a dedup side-effect.

### P3: Playlist style fallback for custom skins (commit 8e2469b)

**What happened:** `parsePlaylistStyle` was initially extracted returning `.winampDefault` (green `#00FF00` text) for ALL skins when `pledit.txt` is missing.

**Why it's wrong:** The original `applySkinPayload` (custom skins) used white text as the fallback — matching `PLEditParser`'s own per-key defaults (white/white/black/#0000C6). A skin with no `pledit.txt` at all would get green text instead of white, which is a user-visible change.

**Fix:** Added `PlaylistStyle.pleditParserDefault` (white/white/black/#0000C6) matching the old custom-skin behavior. Call sites:
- `parseDefaultSkinFully` → `fallback: .winampDefault` (green text — for the bundled Winamp.wsz)
- `applySkinPayload` → `fallback: .pleditParserDefault` (white text — preserves old behavior)

**Future note:** There are now THREE playlist style fallback levels:
1. `PlaylistStyle.winampDefault` — green text, used when the default Winamp skin's pledit.txt is missing (shouldn't happen — Winamp.wsz includes it)
2. `PlaylistStyle.pleditParserDefault` — white text, used when a custom skin lacks pledit.txt entirely
3. `PLEditParser` per-key fallbacks — white text per missing key, used when pledit.txt exists but is incomplete (e.g., has `[Text]` section but missing `Normal=` line)

Levels 2 and 3 intentionally match (both white). Level 1 uses green because that's the canonical Winamp 2.x default. If we ever see playlist color issues with specific skins, check which fallback level is being triggered by adding logging to `parsePlaylistStyle(from:fallback:)`.
