# Research: Swift Decomposition Best Practices

**Context:** MacAmp (macOS 15, Swift 6.2, SwiftUI). 112 files currently, growing to ~140 after splitting five 700+ line files.

---

## 1. Swift File Count Best Practices for macOS Apps
**Is 140 files reasonable for this complexity?**
Yes, 140 files is remarkably conservative and highly manageable for an app handling audio pipelines, skin parsing, streaming, visualizers, and multi-window UI. 

**Industry Norms:**
*   **Small Apps (1-5 screens):** 20-50 files.
*   **Medium Apps (Like MacAmp):** 100-300 files.
*   **Enterprise Apps:** 1,000+ files.
*   The modern Swift community emphasizes **Feature-Based Grouping** over raw file count limits. As long as those 140 files are grouped logically (e.g., `Audio/`, `Skins/`, `Windows/MainWindow/`), navigating them via Xcode's "Quick Open" (Cmd+Shift+O) or fuzzy finding will remain instant. A jump to 140 files is a sign of a healthy, maturing architecture, not bloat.

## 2. File Decomposition Best Practices in Swift

**When splitting a 700+ line file, what is the recommended approach?**
You should choose between **One-Type-Per-File** and **Extension-Based** depending on the nature of the code:

*   **One-Type-Per-File (Primary Strategy):** If the 700-line file contains multiple distinct structs (e.g., `MainWindowFullLayer`, `MainWindowShadeLayer`, `TimeDisplayView`), extract each to its own file (`MainWindowFullLayer.swift`).
    *   *Granularity:* Yes, a 22-line `struct` (like a highly customized Button component) absolutely deserves its own file if it is reused or represents a distinct logical component. 
*   **Extension-Based Splitting (For massive single types):** If the 700 lines belong to a single massive class (like `AudioPlayer`), split it by functional domain using extensions.
    *   *Example:* Keep `AudioPlayer.swift` for stored properties and core lifecycle. Create `AudioPlayer+Seeking.swift`, `AudioPlayer+Playlist.swift`, and `AudioPlayer+Routing.swift`.
    *   *Warning:* You cannot declare stored properties in extensions. All state must remain in the primary file.

**Downsides of Over-Splitting:**
"Spaghetti Folders" — if you split a single 50-line view into five 10-line sub-views and put each in its own file, you increase "jump-to-definition" fatigue. Only split if the extracted piece has a distinct lifecycle, independent state, or is reused elsewhere.

## 3. Deduplication Timing in a Phased Migration

**When should deduplication happen?**
**Option B (After file moves / Post-Phase 1/2) is strongly recommended.**

*   **The Risk of Deferring (or Doing it Early):** If you try to deduplicate *while* decomposing (Phase 2), you mix two highly complex cognitive tasks: structural refactoring and logic refactoring. If a test breaks, you won't know if it was caused by the move (missing `internal` access) or the logic change (a bad dedup).
*   **The Correct Flow:**
    1.  **Decompose First:** Extract the code exactly as it is written. Make it compile. Run tests. Commit.
    2.  **Deduplicate Second:** Now that the components are isolated, side-by-side comparison is easier. You can see the duplication clearly across the new file boundaries. Deduplicate, test, commit.

## 4. Common Pitfalls When Decomposing Swift Files

**1. The "Pass-Through" Middleman (Prop Drilling)**
*   *What goes wrong:* You split a large view into Parent -> Middle -> Child. `Middle` doesn't need the `PlaybackState` object, but it has to accept it in its `init` just to pass it to `Child`.
*   *How to avoid:* Use SwiftUI's `@Environment`. Inject the state at the Parent level, let `Middle` ignore it, and have `Child` read it directly via `@Environment(AudioPlayer.self)`.

**2. Visibility / Encapsulation Leaks**
*   *What goes wrong:* When you extract a helper struct from a large file into its own file, its `private` properties/methods suddenly prevent the parent from calling them. The developer lazily changes everything to `internal`.
*   *How to avoid:* Be deliberate. If the helper is only used by one file, keep them in the same file but separated, or use `fileprivate`. If it must be in a new file, expose *only* the minimum `internal` surface area required.

**3. State Fragmentation**
*   *What goes wrong:* Splitting too aggressively can lead developers to move `@State` into child views when the parent still needs to know about it, causing synchronization nightmares.
*   *How to avoid:* Honor the "Source of Truth" rule. State stays at the lowest common ancestor. Pass `@Binding` or `@Bindable` down to the extracted child files.