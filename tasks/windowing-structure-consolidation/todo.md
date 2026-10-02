# Todo: Windowing Structure Consolidation

> **Description:** Checklist for preparing and executing the windowing ownership cleanup. Deferred to post-S3 Structure Sprint (D-STRUCTURE decision 2026-03-15).
> **Purpose:** Keep the work bounded, mechanical where possible, and easy to verify.

---

- [ ] Produce a source-to-target mapping for all candidate windowing files
- [ ] Decide which `Models/*Window*` files are truly generic windowing types vs feature-local state
- [ ] Decide whether `WindowCoordinator` belongs wholly in `Windowing/Coordination/` or needs partial decomposition first
- [ ] Move the agreed generic files into `Windowing/`
- [ ] Update project/resource metadata if required
- [ ] Regenerate Xcode project if paths change
- [ ] Build and manually verify multi-window behaviors
- [ ] Document any deferred or ambiguous files in `placeholder.md`

## Follow-ups from `window-docking-78` (#78) design review, 2026-09-28 (owner: planned for this task)

Deferred from the #78 branch because each touches code the owner verified by hand; do them while the files move. Details: `tasks/done/window-docking-78/verification.md` (Phase 7) and the design-review invariants summarized in `docs/MULTI_WINDOW_ARCHITECTURE.md` §Docking, Recovery, Minimize & Windowshade.

- [ ] **Inject the minimize action into `BorderlessWindow`** instead of it reading `WindowCoordinator.shared`: `var onPerformMiniaturize: (() -> Void)?` and a `canMinimize` hook, wired once in `WindowCoordinator+Layout.configureWindows()`; keep the `validateUserInterfaceItem` override (not OR'd with super).
- [ ] **Extract the screen-guard restore policy into `ScreenClamp`** as a pure `restore(snapshot:current:visible:oldDisplays:newDisplays:anchorOrder:)` (rigid when a display was added, otherwise translate); `WindowScreenGuard.settle()` keeps the live-height `setFrameOrigin` and its clamp → end → displays → persist order. Add 2–3 `ScreenClampTests`.
- [ ] **One helper for the shaded Playlist's pixel size**: `PlaylistWindowSizeState.pixelSize(for:shaded:)`, used by `WinampPlaylistWindow.windowPixelSize`, both `PlaylistResizeHandle` sites (preview uses the candidate size) and the literal 14s in `WinampPlaylistWindow`; don't store shade state in the size model.
- [ ] **One top-anchored-origin helper**: nonisolated `DockGraph`/`ScreenClamp` helper `topAnchoredOrigin(keepingTopOf:height:)` for `WindowFramePersistence` and `WindowScreenGuard.settle` (live height); leave `WindowResizeController.topLeftAnchoredFrame` (it rounds).
- [ ] **Verify Option+Cmd+M** (`NSApp.miniaturizeAll`) on a running app: if it minimizes Main without hiding the group, move the hide loop to Main's typed `.willMiniaturize` message as the single hide path.
- [ ] **Consolidate TEXT.BMP glyph naming** (seven `CHARACTER_` sites incl. `MainWindowShadeLayer`, `PlaylistShadeView`, `MainWindowTrackInfoLayer`, `VideoWindowChromeView`, `PlaylistBitmapText`) into one `SkinSprites.characterSpriteName(for:)` with the missing-glyph → space rule. Also covers `MainWindowIndicatorsLayer.swift` (×2) and `SpriteResolver.swift` (amp review 2026-10-02).
- [ ] **Docs (pre-existing, found during #78):** `docs/context/xcode-testing-context.md` `.audio`/`.concurrency`/`.parsing` tag rows are incomplete; `MACAMP_ARCHITECTURE_GUIDE.md` Key Implementation Point 4 says every window's visibility persists (Main's doesn't); `VIDEO_WINDOW.md`/`MILKDROP_WINDOW.md` say those windows "move with" a cluster (only a Main drag moves the group).

## Follow-ups from the amp code review, 2026-10-02

- [ ] **One quantized-resize helper** (25×29 segments): `Size2D.quantizedDelta(base:translation:)` backed by shared segment constants, used at the 6 sites in the Playlist/Video/Milkdrop resize handles. Do it alongside the shaded-Playlist pixel-size helper above.
- [ ] **Add to the candidate list:** `Utilities/WinampWindowConfigurator.swift` and `Utilities/WindowResizePreviewOverlay.swift` (AppKit window code living in `Utilities/`).
