# Gemini Research Prompts for Playlist Window Resize

Use these prompts with Gemini CLI to conduct deep analysis of the codebase.

---

## Prompt 1: Analyze webamp_clone Playlist Resize Implementation

```bash
cd /Users/hank/dev/src/MacAmp

gemini -p "@webamp_clone/packages/webamp/js/components/PlaylistWindow/ @webamp_clone/packages/webamp/css/playlist-window.css

Analyze the playlist window resize implementation in webamp_clone:

1. **Three-Section Layout:**
   - How does the bottom section implement left/center/right layout?
   - What CSS technique is used for the center section (absolute positioning vs flexbox)?
   - How does the center section expand/contract with window width?

2. **Top Section Layout:**
   - How does the top bar handle the center expandable area?
   - What's the difference between top (flex) vs bottom (absolute) positioning strategies?

3. **Resize Mechanism:**
   - How does PlaylistResizeTarget work?
   - What are the minimum/maximum window dimensions?
   - How does it constrain resize to valid ranges?

4. **Skin Graphics:**
   - Which PLEDIT.BMP sprites are used for center sections?
   - How are background images tiled/repeated in expandable areas?
   - What CSS properties control the tiling behavior?

5. **State Management:**
   - How does window size state flow through the component tree?
   - What triggers re-layout when size changes?
   - Are there any performance optimizations for resize operations?

Provide specific code references with file paths and line numbers."
```

---

## Prompt 2: Compare MacAmp vs webamp_clone Playlist Layouts

```bash
cd /Users/hank/dev/src/MacAmp

gemini -p "@MacAmpApp/Views/WinampPlaylistWindow.swift @webamp_clone/packages/webamp/js/components/PlaylistWindow/index.tsx @webamp_clone/packages/webamp/css/playlist-window.css

Compare the playlist window implementations between MacAmp and webamp_clone:

1. **Current MacAmp Implementation:**
   - How is the bottom section currently structured? (HStack vs ZStack vs other)
   - What layout strategy is used for positioning left/right sections?
   - Why was PLAYLIST_BOTTOM_TILE disabled? (Reference: tasks/playlist-state-sync/CODEX_RENDERING_SUGGESTION.md)

2. **webamp_clone Reference:**
   - Identify the exact CSS that makes the center section expand
   - How do absolute-positioned elements interact with the center gap?
   - What's the calculation: 275px total = 125px left + ? center + 150px right?

3. **Gap Analysis:**
   - What's missing in MacAmp that exists in webamp_clone?
   - Which components need to be added for resize support?
   - What layout changes are required?

4. **Implementation Strategy:**
   - What's the SwiftUI equivalent of webamp's CSS approach?
   - Should we use GeometryReader, HStack with Spacer(), or custom layout?
   - How do we handle the skin sprite tiling in the center section?

List the specific files and line numbers that need modification in MacAmp."
```

---

## Prompt 3: Deep Dive into PLEDIT.BMP Sprite Structure

```bash
cd /Users/hank/dev/src/MacAmp

gemini -p "@tmp/Winamp/PLEDIT.TXT @MacAmpApp/Parsers/SkinSprites.swift @webamp_clone/packages/webamp/js/components/PlaylistWindow/

Analyze the PLEDIT.BMP sprite sheet structure:

1. **Sprite Dimensions:**
   - PLEDIT.BMP is 280×72 pixels total
   - Which sprites are used for the bottom section?
   - What are the exact coordinates for left, center-tile, and right sections?

2. **Center Section Graphics:**
   - Which sprite(s) should tile in the playlist-bottom-center area?
   - What's the tile size (1px wide? 2px? full pattern)?
   - How does webamp_clone reference these sprites?

3. **Current MacAmp Sprite Definitions:**
   - Review SkinSprites.swift PLAYLIST_* definitions
   - Are all necessary sprites defined?
   - What's missing for center section support?

4. **Top Section Tiling:**
   - Which sprites tile in the top bar's expandable areas?
   - Compare top-left-fill vs top-right-fill vs top-center patterns

5. **Recommended Sprite Additions:**
   - What new sprite definitions should be added to SkinSprites.swift?
   - Provide exact x, y, width, height coordinates
   - Include both static sprites and tileable patterns

Show sprite sheet coordinates in this format:
```
Sprite(name: \"PLAYLIST_BOTTOM_CENTER_TILE\", x: ?, y: ?, width: ?, height: ?)
```"
```

---

## Prompt 4: SwiftUI Window Resizing Best Practices

```bash
# This one searches the web and Apple documentation
gemini -p "

Research SwiftUI window resizing for macOS applications:

1. **Window Resize APIs:**
   - What are the modern SwiftUI window resizing modifiers?
   - How do you set minimum/maximum window sizes?
   - What's the difference between .windowResizability() options?

2. **Dynamic Layout:**
   - How do you create layouts that respond to window size changes?
   - Best practices for GeometryReader vs @State window size tracking
   - How to animate layout changes during resize?

3. **Drag Handle Implementation:**
   - How to create a bottom-right corner resize handle in SwiftUI?
   - Should it use .gesture() or built-in window controls?
   - How to constrain drag to minimum/maximum sizes?

4. **Performance Considerations:**
   - How to optimize layout recalculation during resize?
   - Should we debounce resize events?
   - How to prevent sprite re-loading on every size change?

5. **Skin Graphics + Resize:**
   - How to tile/repeat NSImage patterns in expandable areas?
   - Best approach for background sprite tiling?
   - How to ensure pixel-perfect alignment at different window sizes?

Provide code examples for macOS 15+ (Sequoia) using modern SwiftUI."
```

---

## Prompt 5: Verify Current Playlist-State-Sync Implementation

```bash
cd /Users/hank/dev/src/MacAmp

gemini -p "@MacAmpApp/Views/WinampPlaylistWindow.swift @tasks/playlist-state-sync/

Review the current playlist window implementation from playlist-state-sync task:

1. **Bottom Section Analysis:**
   - Read lines 120-135 of WinampPlaylistWindow.swift
   - Identify the current layout structure (HStack? ZStack?)
   - Why does it only have LEFT + RIGHT without CENTER?

2. **PLAYLIST_BOTTOM_TILE Issue:**
   - Why was this sprite disabled? (see CODEX_RENDERING_SUGGESTION.md)
   - What was it blocking/overlapping?
   - How would a center section fix this problem?

3. **Current Dimensions:**
   - What's the total width of the playlist bottom section?
   - Left section: 125px (verify)
   - Right section: 154px or 150px? (conflicting info in task docs)
   - Missing center: How many pixels when at minimum width?

4. **Workaround vs Proper Fix:**
   - Document the current workaround (no center, disabled tile)
   - Explain why the workaround prevents resizing
   - What needs to change for proper three-section layout?

5. **Integration Points:**
   - Where would the resize functionality hook into the current code?
   - Which methods/properties need to be added?
   - What state management is needed for window size?

Provide a step-by-step migration plan from current workaround to proper resize support."
```

---

## Prompt 6: End-to-End Resize Implementation Plan

```bash
cd /Users/hank/dev/src/MacAmp

gemini --all_files -p "

Create a comprehensive implementation plan for playlist window resizing:

**Context:**
- Current state: Fixed-size playlist window (no resize)
- Goal: Resizable window like classic Winamp
- Three-section layout: LEFT (125px) + CENTER (expandable) + RIGHT (154px)
- Minimum width: 275px (no center visible)
- Maximum width: ~1000px (reasonable limit)

**Analysis Tasks:**

1. **Review Entire Codebase:**
   - Identify all files that reference WinampPlaylistWindow
   - Find window size management code
   - Locate skin sprite loading/rendering logic

2. **Required Changes:**
   List every file that needs modification with:
   - Exact line numbers
   - Current code that needs changing
   - Proposed new code
   - Rationale for change

3. **New Components:**
   Identify components to create:
   - Resize handle view?
   - Center section view?
   - Window size manager?

4. **Testing Strategy:**
   - How to test minimum/maximum size constraints?
   - How to verify sprite tiling?
   - How to test with multiple skins?

5. **Potential Issues:**
   - What could break in other windows?
   - Performance concerns with frequent resize?
   - Skin compatibility (what if PLEDIT.BMP differs)?

6. **Implementation Phases:**
   Break into 5-6 phases with:
   - Clear deliverables
   - Dependencies between phases
   - Estimated time per phase
   - Verification criteria

**Output Format:**
```markdown
## Phase 1: [Name] (X hours)
### Files to Modify:
- File: path/to/file.swift:123-145
  - Current: [code snippet]
  - New: [code snippet]
  - Why: [explanation]

### New Files:
- File: path/to/new/file.swift
  - Purpose: [explanation]
  - Content: [outline or skeleton]

### Testing:
- [ ] Checklist item 1
- [ ] Checklist item 2

### Success Criteria:
- Specific measurable outcome
```

Make this plan ready for immediate implementation - include all necessary code snippets and references."
```

---

## Usage Instructions

1. **Run prompts sequentially** - Each builds on the previous
2. **Save outputs** to individual markdown files:
   ```bash
   gemini -p "@..." > tasks/playlist-window-resize/gemini-1-webamp-analysis.md
   ```
3. **Review findings** before moving to next prompt
4. **Synthesize** all outputs into final plan.md
5. **Create subtasks** based on implementation phases

---

## Expected Outputs

After running all prompts, you should have:

- ✅ Complete understanding of webamp_clone's resize mechanism
- ✅ Exact sprite coordinates for all needed PLEDIT.BMP elements
- ✅ SwiftUI implementation strategy for window resizing
- ✅ File-by-file change list with line numbers
- ✅ Step-by-step migration plan from current code
- ✅ Comprehensive implementation roadmap with time estimates

---

## Next Steps After Research

1. Review all Gemini outputs
2. Create plan.md with consolidated findings
3. Update state.md with current architecture understanding
4. Generate implementation checklist
5. Defer actual implementation to P4 milestone

---

**Created:** 2025-10-23
**For Task:** playlist-window-resize
**Priority:** P4 (Deferred)
