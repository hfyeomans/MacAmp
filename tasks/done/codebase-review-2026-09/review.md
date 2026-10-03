# MacAmp Codebase Review — September 2026

Read-only review. No source changes. Branch: `review/codebase-audit-2026-09` (throwaway; `feat/avplayer-native-video-dsp` untouched).

Lens requested: Swift 6.2 strict concurrency, modern SwiftUI, macOS 26+ floor, YAGNI, duplication, code tightening, `.swift` structure, naming and Xcode folder containment.

Scale: ~20,400 lines Swift in `MacAmpApp/`, ~2,970 in `Tests/MacAmpTests` (21 files, Swift Testing). 22 `@Observable` types, zero `ObservableObject`, zero `print`, zero `try!`/`as!`. SwiftLint 0.65.1: ~180 violations, 3 errors.

Every finding cites `file:line` as of HEAD `0de0a58`.

---

## 1. Executive summary

The codebase is in good shape for a Swift 6 strict-concurrency app: Observation is adopted everywhere, AppKit bridging is consistently `@MainActor`, the real-time audio paths are careful about allocation and actor hops, and tests are on Swift Testing with tags. The problems are structural, not stylistic.

Top findings, in priority order:

1. **Window visibility and shade state have three competing owners** (`DockingController.panes`, `WindowVisibilityController`, `NSWindow.isVisible`). Result: "Show/Hide Main" menu item does nothing, Cmd+Opt+2/3 (shade EQ/Playlist) are no-ops, and menu titles can read "Show Equalizer" while the EQ is visible. The whole `DockingController` / `DockLayoutV1` "unified container" model is vestigial and should be removed, not fixed.
2. **Deployment floor is inconsistent.** `project.yml` (the real build path) says macOS 15.0; `Package.swift` says 26.0; the user says 26+. `Package.swift` is also invalid as a SwiftPM target (mixed Swift + ObjC sources). Decide whether `Package.swift` is a source of truth or delete it.
3. **120 MB of compiled module cache (`module-cache/`, 157 `.pcm` files) and a 40 KB Mach-O binary (`weak_struct`) are tracked in git**, both from commit `6c98ddb`. Plus a 9,665-line chat transcript. Purge.
4. **Keyboard shortcut collision**: Cmd+Shift+1/2/3 bound by both `AppCommands` (show/hide windows) and `SkinsCommands` (bundled skins).
5. **`LockFreeRingBuffer` has a documented but real data race** (producer overwrites storage the consumer is `memcpy`-ing). Undefined behavior under Swift's memory model; TSan is right to flag it.
6. **`Skin: @unchecked Sendable` wraps `[String: NSImage]`** — an unsound Sendable conformance propagated through `SpriteResolver: Sendable`.
7. **Two dependency access paths everywhere**: `AppSettings.instance()` singleton alongside `@Environment(AppSettings.self)`; `WindowCoordinator.shared` (22 View call sites) alongside constructor injection. Pick injection.
8. **Facade layers that add no policy**: `AudioPlayer` (~25 one-line forwarders), `WindowCoordinator` (~30 forwarders), `PlaybackCoordinator → AudioPlayer → AudioEngineController` stream-bridge chain.
9. **Dead settings feature**: Material integration / Liquid Glass preferences are read only by `PreferencesView` itself.
10. **Folder containment drift**: `Models/` holds window geometry and view state; `ViewModels/` holds window coordinators, a WebKit bridge and the skin service; `Utilities/` holds AppKit window delegates; `Audio/` holds the playlist model. A concrete target layout is in §8.

---

## 2. Bugs and correctness risks

Severity: **High** = user-visible broken behavior or UB; **Med** = latent crash/drift; **Low** = edge case.

### Window management

| Sev | Location | Finding | Recommendation |
|---|---|---|---|
| High | `ViewModels/DockingController.swift:74,103-106`; `AppCommands.swift:14-15` | `toggleMain()` only flips `panes[].visible`; unlike `togglePlaylist/toggleEqualizer` (`:75-101`) it never calls `WindowCoordinator`. "Show/Hide Main Window" is dead. | Route through `WindowVisibilityController.showMain/hideMain` (`Windows/WindowVisibilityController.swift:93-94`), or delete pane state (preferred, see §3). |
| High | `DockingController.swift:15,61-63,111-114`; `AppCommands.swift:25-28` | `toggleShade(.playlist/.equalizer)` writes `DockPaneState.isShaded`, the only production read/write of that field. Real EQ shade is a private `@State isShadeMode` (`Views/WinampEqualizerWindow.swift:13,70,114,147`); playlist shade is `PlaylistWindowInteractionState.isShadeMode` (`Views/PlaylistWindow/PlaylistWindowInteractionState.swift:9`); main shade is `AppSettings.isMainWindowShaded`. Cmd+Opt+2/3 do nothing. | One injected `@Observable` per-window state that both menu and view read. |
| High | `DockingController.swift:32-66`; `Windows/WindowVisibilityController.swift:11-12,43,55,76,88`; `ViewModels/WindowCoordinator+Layout.swift:104-109,119-125` | Visibility lives in three places. Startup `showAllWindows()` sets AppKit + visibility-controller flags but never `DockingController`, so persisted `false` defaults label visible windows "Show …". EQ/PL close buttons (`WinampEqualizerWindow.swift:155-163`, `WinampPlaylistWindow.swift:48-54,107-112`) update two of three. Main clutter-bar buttons read `WindowCoordinator.visibility` (`Views/MainWindow/MainWindowFullLayer.swift:179-192`); menus read `DockingController`. | Make `NSWindow.isVisible` the mechanism truth, mirrored into one observable via `NSWindowDelegate`. Drop persisted visibility from `DockLayoutV1`. |
| Med | `AppCommands.swift:14-19`; `SkinsCommands.swift:24-29,79-86`; `MacAmpApp.swift:85-89` | Cmd+Shift+1/2/3 registered by both command groups; dispatch order is not user-visible. | Give one family unique shortcuts (e.g. skins on Cmd+Ctrl+N or a submenu without key equivalents). |
| Med | `Views/PlaylistWindow/PlaylistWindowInteractionState.swift:16-19,42-53` | App-wide `NSEvent` local monitor consumes Cmd+A, Cmd+D, Esc whenever the playlist view exists, regardless of key window. | `.focusable()` + `onKeyPress` scoped to the playlist list, or check `window.isKeyWindow`. |
| Med | `Views/PlaylistWindowActions.swift:164-165,56-63` | "Add Directory" delegates to `addFile`, whose panel sets `canChooseDirectories = false`. Cannot add directories. | Directory panel + recursive enumeration of supported media, or remove the item. |
| Med | `Utilities/WindowSnapManager.swift:103-109,137-140,278-301`; `Models/SnapUtils.swift:78-86` | `snapToMany` picks the first eligible snap per axis; candidate order comes from dictionary iteration, so results vary with several nearby windows. | Rank candidates by smallest absolute movement. |
| Med | `Views/WinampMilkdropWindow.swift:62-70` | `bridge.setSize` only runs inside `if let WindowCoordinator.shared`. If the global is not installed the canvas never sizes. | Move sizing outside the conditional; inject the coordinator. |
| Low | `Models/WindowFocusState.swift:10-12`; `Utilities/WindowFocusDelegate.swift:17-39`; `WindowCoordinator.swift:93-95,134-140` | `isMainKey` defaults `true` before AppKit reports it; delegates wired after presentation. | Init all `false`; let the delegate establish truth. |
| Low | `Views/WinampEqualizerWindow.swift:321-348` | EQ curve path applies `EQCoords.graphArea` offset a second time inside an overlay already positioned at that offset. | Draw in local coordinates. |

### Audio

| Sev | Location | Finding | Recommendation |
|---|---|---|---|
| High | `Audio/LockFreeRingBuffer.swift:12-16,77-84,95-100,135-154` | Documented "accepted race": producer advances `readHead` and overwrites storage while consumer `memcpy`s. Not merely a glitch — UB under Swift's memory model. | True SPSC: producer never mutates consumer-owned slots; drop new frames on overflow or use atomic slot ownership. |
| Med | `Audio/AudioEngineController.swift:153,404,471,543` | Four force-unwrapped `AVAudioFormat` inits. `:543` (route change) can see a transient zero sample rate during hardware reconfiguration. | `guard let` + validate sampleRate/channelCount; log and defer rewiring. |
| Med | `Audio/VisualizerPipeline.swift:65,297-309` | `peaks` fixed at 20 elements; `updateLevels` indexes over `used.count` from arbitrary `VisualizerData`. | Derive/resize peaks from band count or make the shape a typed invariant. |
| Med | `Audio/Streaming/StreamDecodePipeline.swift:685-693` | Workgroup loaded on join and again on leave; `setAudioWorkgroup` can interleave, leaving a token on the wrong workgroup. | Return `(workgroup, token)` from join and leave with that pair. |
| Med | `Audio/AudioPlayer.swift:518-535` | `seekGuardActive = true`, 50 ms Task to clear it, then synchronously `seekGuardActive = false` at `:535`. The Task is dead. Similar sleep-based guards at `:797-827`, `:885-929`, `:1010` (50/100/150/200 ms). | Replace time-based guards with an explicit seek/completion state machine keyed on `currentSeekID`. |
| Low | `Audio/VideoDSP/VideoTapContext.swift:186-193` | `elapsedNanos * 10` / `* 2` can overflow (method is exercised with synthetic values). | Divide instead of multiply, or `multipliedReportingOverflow`. |
| Low | `Audio/VisualizerScratchBuffers.swift:148-192` | `processButterchurnFFT` accepts `validCount == 0` then computes `sampleCount - 1`. | Guard `sampleCount > 0`. |
| Low | `Audio/Streaming/AudioConverterDecoder.swift:47,206` | `packetQueue.removeFirst()` is O(n) under sustained streaming. | Deque or read-index with periodic compaction. |

### Models / concurrency

| Sev | Location | Finding | Recommendation |
|---|---|---|---|
| High | `Models/Skin.swift:9-25`; `Models/SpriteResolver.swift:97-101` | `Skin: @unchecked Sendable` holds `[String: NSImage]` and `[String: NSCursor]`; `SpriteResolver: Sendable` carries it across isolation. The "confined to MainActor" comment is not enforced. | Make `Skin`/`SpriteResolver` `@MainActor`, or store `CGImage`/value metadata and materialize `NSImage` on main. |
| Med | `Models/EQF.swift:13,67-93` | `bandsDB` unconstrained; serializer writes `prefix(10)` without padding, so short arrays produce malformed EQF. | Validate at init or pad/clamp to exactly 10 + preamp. |
| Med | `ViewModels/SkinManager+Import.swift:101-106` | `ensureDestination` string-prefix check accepts `/…/Skins-Evil` for base `/…/Skins`. | Compare standardized path components (or append trailing separator); resolve symlinks. |
| Low | `Models/SnapUtils.swift:153-168` | `boundingBox([])` traps via `precondition`. | Return `Box?` or take a non-empty type. |
| Low | `Models/M3UParser.swift:104-108` | `C:\foo` becomes relative `C:/foo`, not a valid macOS path. | Reject explicitly or map drive letters. |
| Low | `Utilities/AppLogger.swift:20-41` | All interpolations `privacy: .public`; skin paths and error text logged (`SkinManager.swift:258-259,432-439`; `SkinManager+Import.swift:65,73-75`). | Keep OSLog default privacy; mark only safe fields public. |
| Low | `Views/SkinnedText.swift:22` | `ForEach(Array(text), id: \.self)` — duplicate letters share IDs. View is unused (see §3). | Delete; `PlaylistBitmapText` already does this correctly (`Views/Components/PlaylistBitmapText.swift:37`). |

---

## 3. YAGNI — code that should go

**Whole subsystems**

- **`DockingController` "unified docking container"** (`ViewModels/DockingController.swift:4-46`): `DockPaneType`, `DockPaneState`, `panes`, `DockLayoutV1`, `snapDistance` (`:43-44`, unread — runtime uses `SnapUtils.SNAP_DISTANCE`), `DockPaneState.position` (`:18-25`, zero readers). Only consumers are menu labels/actions in `AppCommands.swift:6,14-28` and DI plumbing. It models a single-container design the app no longer has (five independent `NSWindow`s). Remove after routing menu commands to live window state.
- **Material integration / Liquid Glass settings** (`Models/AppSettings.swift:5-25,57-65,118-132`; `Views/PreferencesView.swift:18-72`): `MaterialIntegrationLevel`, `materialIntegration`, `enableLiquidGlass`, `shouldUseContainerBackground`, `shouldPreserveWinampChrome`, `shouldUseFullSystemMaterials`. Only `PreferencesView` reads them; only `shouldUseContainerBackground` has any effect, and only on the preferences window itself (`PreferencesView.swift:65`). Two of the three derived flags have zero readers. Remove until a window consumes them.
- **Test seams in production** (`#if DEBUG` but a large alternate API surface): `Audio/StreamPlayer.swift:629-686` (~12 `…ForTesting` members plus invocation counters at `:200,435,576` in production control paths), `Audio/Streaming/StreamDecodePipeline.swift:483-513,768-782`, `Audio/LockFreeRingBuffer.swift:140-142,209-217`, `Audio/AudioEngineController.swift:372-380`, `Audio/VideoDSP/VideoTap.swift:200-205,245-259`, `Audio/VideoDSP/VideoTapContext.swift:218-224`. Prefer injected collaborators (transport, clock) or a single DEBUG harness type.
- **Deadline telemetry** (`Audio/VideoDSP/VideoTapContext.swift:53-64,133-146,180-207`): described as production diagnostics, used only by tests.

**Dead members**

- `Audio/EqualizerController.swift:46` + `Audio/AudioPlayer.swift:316-318` — `useLogScaleBands` has no reader and no effect.
- `Audio/EqualizerController.swift:58,244-256` — `autoEQTask` is never assigned; `generateAutoPreset` only cancels it and logs "disabled".
- `Audio/AudioEngineController.swift:548-549` — `// TODO Phase 3` (repo policy forbids TODOs; pre-commit hook enforces it).
- `Audio/AudioEngineController.swift:505-523` vs `AudioPlayer.swift:869-880` — `PreReconfigureSnapshot.wasPlaying/currentTime` are known-invalid placeholders immediately overridden.
- `Utilities/WindowSnapManager.swift:69-72` — `areConnected` has no caller.
- `Windows/WindowResizeController.swift:26,59-70` — `animated:` parameter ignored.
- `Windows/WindowDockingTypes.swift:3-11` — `VideoAttachmentSnapshot` duplicates `PlaylistAttachmentSnapshot`'s shape.
- `Utilities/WindowDelegateMultiplexer.swift:33-84` — forwards main/resign-main, close, miniaturize, screen/backing events that no installed delegate implements.
- `Models/Skin.swift:78-79,93` — `SkinMetadata.thumbnailURL`, `SkinSource.temporary` unused.
- `Views/SkinnedText.swift:4-37` — no call sites; superseded by `PlaylistBitmapText`.
- `Views/PreferencesView.swift:106-115` — `conditionalPreferencesBackground(enabled:)` always called with `true`.
- `Views/PlaylistWindow/PlaylistMenuPresenter.swift:113-118`; `Views/PlaylistWindowActions.swift:216-231` — menu items whose only behavior is "Not supported yet" (one claims multi-select is planned though Shift-select exists at `PlaylistWindowInteractionState.swift:29-39`).
- Unused environment/state reads: `MainWindowFullLayer.swift:6,10`; `MainWindowShadeLayer.swift:7-8`; `WinampMainWindow.swift:8,10` (including the injected `dockingController`); `WinampMilkdropWindow.swift:15,17`; `isDragging` written never read at `MilkdropWindowChromeView.swift:15`, `VideoWindowChromeView.swift:22`.
- `PlaybackCoordinator` "Legacy State Queries" (`streamTitle`, `streamArtist`, `isBuffering`, `error`) — verify consumers before removal (not independently confirmed dead).
- Stale history comments: `Utilities/WinampWindowConfigurator.swift:3-4`; `Utilities/WindowSnapManager.swift:7-8,104,147`; `Windows/WinampMainWindowController.swift:7-22`; `ViewModels/SkinManager.swift:7-9` ("It will be an ObservableObject" — it is `@Observable`).

**`.legacy(String)` in `SimpleSpriteImage`** (`Views/Components/SimpleSpriteImage.swift:3-5,41-43,75-76`) is *not* removable yet: 81 string-keyed call sites vs 11 semantic. Either rename it to the honest "direct key" API or finish the migration to `SpriteResolver` first.

---

## 4. Duplication clusters

Each cluster: occurrences → proposed single home.

**A. Persistence boilerplate.** 14 identical `didSet { UserDefaults.standard.set(…) }` in `Models/AppSettings.swift:58,64,198,208,219,235,257,269,285,294,301,308,316,358` plus a separate computed path for `selectedSkinIdentifier` (`:138-147`). Window-size dictionary codecs repeated in `PlaylistWindowSizeState.swift:155-171`, `VideoWindowSizeState.swift:77-93`, `MilkdropWindowSizeState.swift:100-115`. → One `@ObservationIgnored`-backed `UserDefault<Value>` property helper (or `@Entry`-style storage wrapper) taking an injected `UserDefaults`; `Size2D: Codable` through one `WindowSizeStore`.

**B. Dependency access.** `AppSettings.instance()` in `AudioPlayer.swift:30-32,294-295,378`, `PlaylistController.swift:64-65`, `SkinManager.swift:157,168`, `SkinsCommands.swift:14`, and previews (`VisualizerView.swift:227`, `WinampPlaylistWindow.swift:219`, `PreferencesView.swift:122`) while `MacAmpApp.swift:5-29` injects the same instance. `WindowCoordinator.shared` at 22 View sites (`MilkdropWindowChromeView.swift:182,202`; `VideoWindowChromeView.swift:250,269,313,334`; `WinampVideoWindow.swift:56`; `WinampPlaylistWindow.swift:51,53,65,69,109,111`; `WinampMilkdropWindow.swift:62`; `PlaylistMenuPresenter.swift:14`; `PlaylistResizeHandle.swift:35,53`; `WinampEqualizerWindow.swift:137,157`; `MainWindowFullLayer.swift:59,179`; `MainWindowShadeLayer.swift:109`). → Constructor/environment injection only; `@Environment(WindowCoordinator.self)`.

**C. Window controller construction.** Same 7-parameter init + borderless window + configurator + environment chain in `Windows/WinampMainWindowController.swift:6-48`, `WinampEqualizerWindowController.swift:6-45`, `WinampPlaylistWindowController.swift:6-50`, `WinampVideoWindowController.swift:6-39`, `WinampMilkdropWindowController.swift:12-70`; list repeated at `WindowCoordinator.swift:26-63`. Main/EQ/PL set both `contentViewController` and `contentView` (`:36-43`, `:33-40`, `:38-45`) while Video/Milkdrop comment that doing so breaks lifecycle (`:30-34`, `:57-63`). → `WindowDependencies` value + one hosting-window factory enforcing the correct `NSHostingController` pattern.

**D. Window level assignment.** `Utilities/WinampWindowConfigurator.swift:34-35`, `WindowCoordinator+Layout.swift:14-18`, `WindowCoordinator.swift:97-104`, `WindowCoordinator.swift:198-205`. → `WindowRegistry.forEachWindow` + one `updateWindowLevels`. Also `debugLogWindowPositions` ×6 in init (`WindowCoordinator.swift:87,91,95,104,132,140`) while the logger reports 3 of 5 windows (`+Layout.swift:113-128`).

**E. Snapping/docking geometry.** One runtime stack split across three folders: primitives `Models/SnapUtils.swift:4-192`; live registration/drag `Utilities/WindowSnapManager.swift:11-379`; resize-time attachment `Windows/WindowDockingGeometry.swift:3-109` + `WindowResizeController.swift:103-205`; plus dead `DockingController.snapDistance`. Top-left-anchored frame math duplicated in `WindowResizeController.swift:17-22` and `Utilities/WindowResizePreviewOverlay.swift:34-40,54-65`. Playlist/video attachment contexts parallel at `WindowResizeController.swift:105-149` vs `:151-177`, movement at `:181-205`. → `Windows/Docking/{SnapGeometry, WindowSnapCoordinator, WindowDockingGeometry, WindowAttachmentSnapshot}`.

**F. Title-bar control triplet** (minimize/shade/close): `MainWindowFullLayer.swift:55-85`, `MainWindowShadeLayer.swift:105-135`, `WinampEqualizerWindow.swift:132-165`, `PlaylistWindow/PlaylistTitleBarButtons.swift:3-32`. → `WinampTitleBarButtons(positions:onMinimize:onShade:onClose:)`.

**G. Resizable tiled chrome** (top caps, 25×20 tiles at `y: 10`, 29 px sides, bottom caps, resize corner; 19 direct `.position(x:…, y: 10)` calls): `WinampPlaylistWindow.swift:140-205`, `Windows/VideoWindowChromeView.swift:96-174,285-350`, `Windows/MilkdropWindowChromeView.swift:60-150,154-219`, `WinampVideoWindow.swift:89-135`. → `WinampWindowChrome(spriteSet:)` parameterized by `WindowKind`.

**H. Quantized resize handle** (start-size capture, 25×29 delta, preview, commit, window sync): `PlaylistWindow/PlaylistResizeHandle.swift:11-64`, `VideoWindowChromeView.swift:285-350`, `MilkdropWindowChromeView.swift:154-219`. → `QuantizedWindowResizeHandle`.

**I. Bitmap text rendering** (`CHARACTER_<ASCII>` loops): `MainWindowIndicatorsLayer.swift:53-80`, `MainWindowTrackInfoLayer.swift:34-47`, `VideoWindowChromeView.swift:176-213`, existing reusable `Components/PlaylistBitmapText.swift:29-51`. Scrolling-text timers duplicated at `WinampMainWindowInteractionState.swift:30-69` and `VideoWindowChromeView.swift:176-240`. → one `WinampBitmapText` (color, case map, clip, scroll) driven by `TimelineView`.

**J. Transport controls**: `MainWindowTransportLayer.swift:12-55`, `MainWindowShadeLayer.swift:27-61`, `PlaylistBottomControlsView.swift:75-97`. → data-driven transport actions through one button primitive.

**K. Visualizer DSP.** RMS + Goertzel implemented twice with a comment demanding manual lockstep: `Audio/VisualizerPipeline.swift:331-403` and `Audio/VideoDSP/VideoTapVisualizerRender.swift:30-120`. Constants 20/76/1024/2048 repeated across `VisualizerPipeline.swift:12-13,65,73-74,122-123,151-152,331,374,412`, `VisualizerFeed.swift:21-25`, `VisualizerScratchBuffers.swift:63-64,82-83`, `VideoTapVisualizerRender.swift:30,95,128`. → One allocation-free DSP method on `VisualizerScratchBuffers`; one `VisualizerFormat` constants type.

**L. Stream buffer configuration.** `LockFreeRingBuffer(capacity: 32768, channelCount: 2)` ×4 (`StreamPlayer.swift:130,197,471,573`); threshold `8192` ×5 (`StreamPlayer.swift:187,545,563`; `StreamDecodePipeline.swift:552,761`). → factory + pipeline-owned readiness event.

**M. Video-tap context registries.** EQ weak registry `EqualizerController.swift:74-89,101-131`; balance registry `AudioPlayer.swift:26,110-127`; registered/unregistered together at `AudioPlayer.swift:209-210,268-269`. → one registry owned by the video DSP layer.

**N. Playback state mirrors.** `StreamPlayer.swift:37-43`, `VideoPlaybackController.swift:42-46`, `AudioPlayer.swift:51-53,64-65,149` (`isPlaying`/`isPaused` alongside `playbackState`; `currentTrackURL` = `currentTrack?.url`), `PlaybackCoordinator.swift:45-66`. Title formatting `"\(title) - \(artist)"` in `AudioPlayer.swift:528` and `PlaybackCoordinator.formattedLocalDisplayTitle`. → derive from one `PlaybackState` snapshot.

**O. Forwarding facades.** `AudioPlayer` ~25 one-liners to `equalizer`/`visualizerPipeline`/`playlistController`/`videoPlaybackController`/engine (repeat mode also via `PlaylistController.swift:63-66` and `AudioPlayer.swift:293-295`); stream bridge chain `PlaybackCoordinator.swift:154,167,237,375 → AudioPlayer.swift:741-748 → AudioEngineController.swift:390,452`; `WindowCoordinator.swift:147-194,207-217` alongside public `visibility`/`resizeController` (`:13-15`). → expose the collaborator or the intent-level API, not both.

**P. Sprite vocabulary.** Names owned by both `Models/SkinSprites.swift:54-439` and `Models/SpriteResolver.swift:133-376`, while views bypass the resolver with raw strings (`MainWindowTransportLayer.swift:15-51`, `WinampEqualizerWindow.swift:73-243`, `WinampPlaylistWindow.swift:145-204`, `VideoWindowChromeView.swift:109-172`, `MilkdropWindowChromeView.swift:69-148`). → typed `SpriteID` used by atlas, resolver and views.

---

## 5. Tightening

| Location | Current | Suggested |
|---|---|---|
| `Models/SpriteResolver.swift:133-377` | 189-line `switch`, complexity 49 (SwiftLint error) | Table `[SemanticSprite: [SpriteID]]`; only `.digit`/`.character` computed; generate selected/base variants by helper |
| `Utilities/WindowSnapManager.swift:74-163` | `windowDidMove` 90 lines, complexity 17 | Extract coordinate conversion, visible-window snapshot, cluster translation, snap application |
| `Windows/WindowResizeController.swift:26-85` | Capture + infer + resize + move + persist-suppress + log in one method | Build a layout transaction value, then apply in one short mutation phase |
| `ViewModels/WindowCoordinator.swift:26-141` | `init` does composition, layout, presentation, levels, observation, delegate wiring | Factory for controllers; focused setup methods |
| `ViewModels/SkinManager.swift:287-394`, `:53-85` | `applySkinPayload` does extraction/fallback/aliases/diagnostics/styles/publish; `parseDefaultSkinFully` duplicates sheet iteration | Pure extraction pipeline with explicit fallback policy + short main-actor publish |
| `ViewModels/SkinManager.swift:258-284` | `loadSkin` unowned Task; supersession by UUID only | Store and cancel the previous load task |
| `Windows/WindowSettingsObserver.swift:8-16,24-40,50-112` | Four string-keyed tasks that only install sync observation | Enum keys or a reusable tracked-property helper; `stop()` before restart |
| `Windows/WindowVisibilityController.swift:25-89` | EQ and PL show/hide/toggle duplicated | `show/hide/toggle(kind:makeKey:)` |
| `Audio/StreamPlayer.swift:171-225,488-594` | Resume = parallel booleans + generations + task chain + stored continuation + 1 s timeout task (`:532-565`) that can restart the pipeline on slow buffering | One transport/warmup state machine; pipeline emits readiness; timeout via task group |
| `Audio/EqualizerController.swift:167-176` | Preset apply mutates 11 observable props, reconfigures bands and fans out per mutation | Apply validated snapshot once, one band pass, one fan-out |
| `Audio/PlaylistController.swift:271-285` | `findCurrentTrackIndex()` reads `currentTrack`, itself derived from `currentIndex` → can never recover a nil index | Resolve from a supplied `Track` |
| `Audio/PlaylistController.swift:88-97` | `addTrack`/`addPlaceholder` identical except log text | One append; placeholder is `Track` data |
| `Audio/AudioPlayer.swift:16` | `engine: AudioEngineController!` IUO | `let` |
| `Audio/VideoDSP/BiquadCoefficientSet.swift:33-34,47-107,112-115` | 10-tuple with manual equality/conversion; `normalized` takes 6 scalars | Fixed-capacity storage type; raw-coefficient value parameter |
| `Audio/VideoDSP/VideoTapVisualizerRender.swift:22-129` | 87 lines, complexity 19: traversal + downmix + RMS + Goertzel + FFT + publish | Producer-specific downmix; shared DSP; separate publish |
| `Models/PLEditParser.swift:44-55` | `(r:g:b:)` tuple | `RGBComponents` struct or init `Color` directly |
| `Models/VideoWindowSizeState.swift:49-52` | Tuple returning same value twice | Expose `stretchyTilesPerSide` |
| `Models/Size2D.swift:9-40` | Aliases with identical values (`videoMinimum`, `playlistMinimum`, `milkdropMinimum`, three defaults) | Keep semantic names only if expected to diverge |
| `Models/Skin.swift:41-67` | Two near-identical `PlaylistStyle` defaults | One factory with the differing color named |
| `Views/WinampMilkdropWindow.swift:94-244` | 120-line menu builder | Menu-item descriptors per section |
| `Views/PreferencesView.swift:11-86` | Monolithic nested body (lint error + 2 warnings) | Extract appearance/footer views |
| `Views/Windows/ButterchurnWebView.swift:51-142` | 68-line `makeNSView` | Extract script/config/load |
| `Views/WinampPlaylistWindow.swift:42-59`; `Views/VisualizerView.swift:135-154` | `GeometryReader` with unused proxy | Remove |
| `Views/MainWindow/MainWindowFullLayer.swift:122-129`; `MainWindowShadeLayer.swift:84-91` | Two consecutive identical `if shouldShowDigits` blocks each | Combine / render indexed digits |
| `Views/Components/EQPresetPickerView.swift:92-96` | Hover shows a checkmark (reads as selection) | Highlight on hover; checkmark only for the selected preset |
| `ViewModels/WindowCoordinator+Layout.swift:84-101`; `Windows/WindowSettingsObserver.swift:50-112` | Recursive `Task { @MainActor }` from every `withObservationTracking` callback | Centralize the bridge; retain handles for cancellation |

SwiftLint totals by rule (whole repo): trailing_comma 21, closure_parameter_position 14, comma 13, force_unwrapping 18 (all tests), closure_body_length 8, multiple_closures_with_trailing_closure 8, vertical_whitespace_closing_braces 4, trailing_newline 3, function_body_length 3, cyclomatic_complexity 2 (1 error), implicitly_unwrapped_optional 3, large_tuple 3, superfluous_disable_command 2, and singletons (unneeded_break, for_where, legacy aspect ratio, unused closure param). Most are mechanical; `swiftlint --fix` would clear roughly half.

---

## 6. Swift 6.2 / macOS 26 modernization

**Deployment floor (blocking).** `project.yml:5,19` → macOS `15.0`; `Package.swift:7` → `"26.0"`. Xcode/XcodeGen is the real build path, so the shipped floor is 15. Set `project.yml` to 26 and delete the now-redundant checks: `Utilities/WinampWindowConfigurator.swift:30` (`#available(macOS 11.0)`), `Views/Windows/ButterchurnWebView.swift:106` (`13.3`), `Views/PreferencesView.swift:95,108` (`26.0`).

**Concurrency**

- `Skin: @unchecked Sendable` (`Models/Skin.swift:10`) — see §2; actor isolation is the correct fit.
- Add `Sendable` to pure values that cross task boundaries: `Size2D` (`Models/Size2D.swift:5`), `M3UEntry` (`Models/M3UEntry.swift:4`), `RadioStation`/`.Source` (`Models/RadioStation.swift:3,10`).
- `Windows/BorderlessWindow.swift:3-6` lacks `@MainActor`; the five controller classes are not `final`.
- `Audio/Streaming/StreamDecodePipeline.swift:79-82` `nonisolated(unsafe)` to smuggle the C workgroup type → tiny audited `@unchecked Sendable` holder or extend the ObjC shim.
- `ViewModels/ButterchurnBridge.swift:59-81` `nonisolated` + `MainActor.assumeIsolated` for `WKScriptMessageHandler` — defensible; prefer an isolated conformance if the SDK permits.
- The serial decode `DispatchQueue` + `QueueConfined` (`Streaming/QueueConfined.swift:3-18`; `StreamDecodePipeline.swift:87,148-232,517-783`) is justified by AudioToolbox C callbacks and workgroup joins. Do not replace with ad-hoc Tasks. A custom serial executor is the long-term option.

**Timers → structured**

- `Timer` + `MainActor.assumeIsolated`: `Audio/AudioEngineController.swift:43,252-274`; `Audio/StreamPlayer.swift:54,347-378`; `Audio/VisualizerPipeline.swift:48,186-202`; `ViewModels/ButterchurnPresetManager.swift:74-78,203-216,235-251`; `Views/MainWindow/WinampMainWindowInteractionState.swift:17,30-69`; `Views/Windows/VideoWindowChromeView.swift:20,216-240`. → `Task` loops with `ContinuousClock` / `Task.sleep(for:)`, or `TimelineView` for render cadence. `ButterchurnBridge.swift:143-157` already shows the pattern.
- `Timer.publish` + `.onReceive` is the only reason for `import Combine` in `Views/VisualizerView.swift:1,39,73,237,262` and `Views/MainWindow/WinampMainWindow.swift:2,18,88`. → `TimelineView(.animation(minimumInterval:))`; drop both imports.
- `Audio/EqualizerController.swift:223` `Task.sleep(nanoseconds: 2_000_000_000)`; `AudioPlayer.swift:524` etc. → `Task.sleep(for:)` (rest of the codebase already uses `Duration`).
- `Audio/VideoPlaybackController.swift:144-157` block-based end observer → `NotificationCenter.notifications(named:)` as `AudioEngineConfigurationObserver.swift:20-23,51-61` already does.
- Callback panels wrapped in nested `Task { @MainActor }`: `AppCommands.swift:96-114`; `SkinsCommands.swift:92-107` → async helper/continuation.

**SwiftUI**

- Inject `WindowCoordinator` via typed `@Environment` (no `@Entry` needed — no custom keys exist).
- `Views/PlaylistWindow/PlaylistTrackListView.swift:15-34` imperative `ScrollViewReader.scrollTo` → scroll position API.
- `Views/Components/SimpleSpriteImage.swift:58` `.aspectRatio(contentMode: .fill)` → `.scaledToFill()`.
- `Views/Windows/ButterchurnWebView.swift:32,38` `WKNavigation!` → `WKNavigation?`.
- `MacAmpApp.swift:61-83`: invisible placeholder `WindowGroup`, empty `Settings` scene, and a second `WindowGroup` for Preferences replacing `.appSettings`. At a 26 floor use a real `Settings` scene + `SettingsLink`.
- Already modern (leave alone): all seven `onChange` use the two-parameter form; no `AnyView`, no legacy observation wrappers, no `DispatchQueue.main.async` in Views; `@Bindable` used correctly in `PreferencesView.swift:8-9`.

---

## 7. Tests

Strengths: 20 `@Suite`, 116 `@Test`, central tags (`Tests/MacAmpTests/TestTags.swift:3-9`), one intentional `withKnownIssue` (`LockFreeRingBufferTests.swift:440`), strong audio/concurrency coverage.

Idiom fixes:

- Force unwraps → `try #require`: `StreamPauseTailTests.swift:24,31,83,124,156,176,199,213,244,281`; `BiquadNumericalMatchTests.swift:64,76,155,164,185,188,194,216,227,238,254,265`.
- `BiquadNumericalMatchTests.swift` lacks `@Suite`.
- Only one parameterized test (`SpriteResolverTests.swift:25`). Numeric matrices in Biquad, `WindowDockingGeometryTests`, EQ conversion and telemetry boundary tests are natural `@Test(arguments:)`.
- No `confirmation` usage; `SkinManagerTests.swift:85-92` polls at 50 ms.
- `SkinManagerTests.swift:45-53` asserts only `!= .clear` — nearly any fallback passes.
- `VideoTapSendableContractTests.swift:54-120` regex-over-source architecture tests are brittle; prefer compiler-enforced wrappers, keep as CI audit at most.

Zero-reference production types in `Tests/`: `WindowVisibilityController`, `PlaylistController`, `PLEditParser`, `M3UParser`/`M3UWriter`, `RadioStationLibrary`, `WindowFocusState`, `PlaylistWindowSizeState`, `VideoWindowSizeState`, `MilkdropWindowSizeState`, `SnapUtils`, `ImageSlicing`, `VisColorParser`. `AppSettingsTests.swift:8-34` tests no persistence. `SpriteResolverTests.swift:25-41` covers digits only, not `_EX` precedence.

Test fixtures in `clapperboard-videos/` at repo root → move to `Tests/MacAmpTests/Resources/`.

---

## 8. Architecture, naming, and folder containment

### Current misplacements

| Path | What it actually is | Belongs in |
|---|---|---|
| `Models/SnapUtils.swift` | Window snap geometry; `SNAP_DISTANCE`, generic `Point`/`Box`/`Diff` | `Windows/Docking/SnapGeometry.swift`; Swift-case constant; consider `CGPoint`/`CGRect` |
| `Models/WindowFocusState.swift`, `Models/*WindowSizeState.swift`, `Models/Size2D.swift` | Window/presentation state | `Windows/State/`, `Windows/Geometry/` |
| `Models/SpriteResolver.swift` (+ `:394-420` SwiftUI env glue), `SkinSprites.swift`, `ImageSlicing.swift`, `PLEditParser.swift`, `VisColorParser.swift`, `Skin.swift` | Skin format, atlas, rendering | `Skins/{Model,Atlas,Parsing,Rendering}/` (currently `Skins/` holds only `.wsz` resources) |
| `Models/M3UParser.swift` (also defines `M3UWriter`), `Models/EQF.swift` (defines `EqfPreset`, `EQFCodec`) | File codecs | `ImportExport/`, `Audio/EQ/Codec/`; one primary type per file |
| `Models/AppSettings.swift` | Settings + skins-directory filesystem logic | `Settings/AppSettings.swift`; paths → `Skins/SkinLibraryPaths.swift` |
| `Audio/PlaylistController.swift` | Playlist model/navigation | `Models/Playlist/` |
| `Audio/MetadataLoader.swift` | Audio+video metadata utility | `Utilities/Media/MediaMetadataLoader.swift` |
| `Audio/RenderThreadSafe.swift` | VideoTap storage-audit marker | `Audio/VideoDSP/VideoTapRenderSafe.swift` |
| `Audio/StreamPlayer.swift` | Retry/warmup/transport policy | rename `StreamPlaybackController` |
| `Audio/VisualizerFeed.swift:4` | Says "lock-free", uses `os_unfair_lock` (`:7-9,30`) | Fix the doc comment |
| `ViewModels/WindowCoordinator*.swift`, `DockingController.swift` | NSWindow composition/coordination (and vestigial state) | `Windows/Coordination/`; delete `DockingController` |
| `ViewModels/SkinManager*.swift`, `SkinArchiveLoader.swift` | Skin domain service / loader | `Skins/` |
| `ViewModels/ButterchurnBridge.swift`, `ButterchurnPresetManager.swift` | WebKit bridge / Milkdrop domain | `Milkdrop/` |
| `Utilities/WindowSnapManager.swift`, `WindowDelegateMultiplexer.swift`, `WindowFocusDelegate.swift`, `WindowResizePreviewOverlay.swift`, `WinampWindowConfigurator.swift` | AppKit window infrastructure | `Windows/{Docking,Delegates,Focus,Resize,Configuration}/` |
| `Views/PlaylistWindowActions.swift`, `Views/Components/PlaylistMenuDelegate.swift`, `SpriteMenuItem.swift`, `Views/MainWindow/MainWindowOptionsMenuPresenter.swift`, `Views/PlaylistWindow/PlaylistMenuPresenter.swift` | AppKit menus/services | `Windows/<Feature>/Menus/` |
| `Views/*InteractionState.swift` | Presentation state | `Views/<Feature>/State/` or `PresentationState/` |
| `Views/WinampEqualizerWindow.swift`, `WinampMilkdropWindow.swift`, `WinampPlaylistWindow.swift`, `WinampVideoWindow.swift` at top level; `Views/Windows/` holds only Video/Milkdrop chrome | Inconsistent feature grouping | One folder per window feature |

`ViewModels/` ends up nearly empty after this, which is correct for an Observation-era app: the "view model" role is filled by `@Observable` state types living next to their feature.

### Proposed target layout

```text
MacAmpApp/
├── App/                       MacAmpApp.swift, AppCommands.swift, SkinsCommands.swift
├── Settings/                  AppSettings.swift, UserDefaultStorage.swift
├── Models/
│   ├── Playback/              Track.swift, PlaybackState.swift
│   ├── Playlist/              PlaylistController.swift, M3UEntry.swift
│   ├── Radio/                 RadioStation.swift, RadioStationLibrary.swift
│   └── EQ/                    EQPreset.swift
├── ImportExport/              M3UParser.swift, M3UWriter.swift, EQFCodec.swift
├── Audio/
│   ├── Engine/                AudioEngineController, AudioEngineConfigurationObserver, EqualizerController, EQPresetStore
│   ├── Local/                 AudioPlayer, VideoPlaybackController
│   ├── Streaming/             StreamPlaybackController, StreamDecodePipeline, ICYFramer, AudioFileStreamParser, AudioConverterDecoder, QueueConfined
│   ├── Visualizer/            VisualizerPipeline, VisualizerFeed, VisualizerScratchBuffers, VisualizerFormat
│   ├── VideoDSP/              VideoTap*, BiquadCoefficientSet, VideoTapRenderSafe
│   ├── ObjCBridge/            AUAudioUnitWorkgroupShim.{h,m}
│   ├── PlaybackCoordinator.swift
│   └── LockFreeRingBuffer.swift
├── Skins/
│   ├── Model/                 Skin, PlaylistStyle, SkinMetadata, SkinSource
│   ├── Atlas/                 SpriteID, Sprite, SkinSpriteAtlas (per-sheet files)
│   ├── Parsing/               PLEditParser, VisColorParser
│   ├── Rendering/             SpriteResolver, SpriteResolver+Environment, NSImage+Cropping
│   ├── Loading/               SkinManager, SkinManager+Import, SkinArchiveLoader, SkinLibraryPaths
│   └── Resources/             *.wsz
├── Milkdrop/                  ButterchurnBridge, ButterchurnPresetManager
├── Windows/
│   ├── Composition/           WindowDependencies, WinampWindowFactory
│   ├── Controllers/           Winamp*WindowController (5)
│   ├── Coordination/          WindowCoordinator(+Layout), WindowRegistry
│   ├── Visibility/            WindowVisibilityController
│   ├── State/                 WindowFocusState, *WindowSizeState
│   ├── Geometry/              WindowGridSize (Size2D)
│   ├── Docking/               SnapGeometry, WindowSnapCoordinator, WindowDockingGeometry, WindowAttachmentSnapshot
│   ├── Resize/                WindowResizeController, WindowResizePreviewOverlay
│   ├── Delegates/             WindowDelegateWiring, WindowDelegateMultiplexer, WindowFocusDelegate
│   ├── Persistence/           WindowFramePersistence, WindowFrameStore, WindowSettingsObserver
│   └── Menus/                 PlaylistWindowActions, PlaylistMenuPresenter, MainWindowOptionsMenuPresenter, PlaylistMenuDelegate, SpriteMenuItem
├── Views/
│   ├── Components/
│   │   ├── BitmapText/        WinampBitmapText
│   │   ├── Controls/          SkinnedButton, SkinnedSlider, SkinnedToggleButton, SimpleSpriteImage
│   │   └── WindowChrome/      WinampWindowChrome, WinampTitleBarButtons, QuantizedWindowResizeHandle, WinampTitlebarDragHandle
│   ├── MainWindow/            (existing 10 files + WinampMainWindowInteractionState)
│   ├── EqualizerWindow/       WinampEqualizerWindow
│   ├── PlaylistWindow/        (existing 7 + WinampPlaylistWindow + PlaylistWindowInteractionState)
│   ├── VideoWindow/           WinampVideoWindow, VideoWindowChromeView
│   ├── MilkdropWindow/        WinampMilkdropWindow, MilkdropWindowChromeView, ButterchurnWebView, MilkdropVisualizationView
│   ├── Visualizer/            VisualizerView
│   └── Preferences/           PreferencesView, SkinSelectorView
└── Utilities/                 AppLogger, MenuActionTarget, TimeFormatting, WeakBox, WinampAlertHelper, Media/MediaMetadataLoader
```

XcodeGen folder-backed groups already mirror the filesystem, so moving files keeps the navigator honest. Keep one primary type per file with file name == type name (currently violated in `Skin.swift`, `EQF.swift`, `M3UParser.swift`, `SpriteResolver.swift`).

### Naming nits

`SNAP_DISTANCE` → `snapDistance`; `EQF.swift` → `EQFCodec.swift`; `PlaylistScrollSlider.swift:7` references a non-existent `PlaylistManager`; `StreamPlayer` → `StreamPlaybackController`; `RenderThreadSafe` → `VideoTapRenderSafe`; `SimpleSpriteImage.Source.legacy` → `.key`.

---

## 9. Project configuration and repository hygiene

### Configuration

- `project.yml:38-44` is correct: Swift 6.2, complete strict concurrency, bridging header. It is the real source of truth (README, docs, and every script use `xcodegen`/`xcodebuild`).
- `Package.swift:23-30` excludes only `Info.plist`/entitlements, so the executable target includes `Audio/ObjCBridge/*.{h,m}` and `MacAmpApp-Bridging-Header.h`. SwiftPM forbids mixed Swift/ObjC targets; this manifest cannot build as declared. Nothing in `scripts/` or `.githooks/` invokes `swift build`/`swift test`. Either split the shim into a Clang target or delete `Package.swift` + `Package.resolved` and stop listing it as source of truth in `AGENTS.md`.
- `.githooks/pre-commit:19-173` runs secret scan, thread-pattern warnings, strict SwiftLint and TODO discipline — good. The LFS hooks are orphaned (no `.gitattributes`, no LFS objects).
- `scripts/README.md:88` links a non-existent `DEVELOPMENT_TESTING.md`. `scripts/dev-install.sh:36-42` claims XcodeBuildMCP but calls `quick-install.sh` (`xcodebuild`).
- `package.json`'s only dependency is `@ast-grep/cli`; no script references it.

### Tracked clutter

| Path | Size | Referenced by | Recommendation |
|---|---:|---|---|
| `module-cache/` (157 `.pcm`) | 120 MB | nothing | **Purge from history** (`git filter-repo`) and add `module-cache/` to `.gitignore` |
| `weak_struct` | 40 KB Mach-O arm64 | nothing | Remove |
| `new-architecture-convresation.md` | 620 KB / 9,665 lines | nothing | Remove |
| `BUILDING_RETRO_MACOS_APPS_SKILL.md` | 284 KB / 7,469 lines | `docs/README.md:333,611,705-708` | Move under `docs/` and fix links, or remove |
| `clapperboard-videos/` | ~80 KB | video tests | Move to `Tests/MacAmpTests/Resources/` |
| `package.json` / lock | 4 KB | nothing | Remove or document |
| `Butterchurn/` | 1.7 MB | `project.yml:25-27` | Keep; document upstream/license |
| `MacAmpApp/Resources/` | empty | — | Remove |

Untracked local residue (already ignored, just noise): `READY_FOR_NEXT_SESSION.md`, `macamp-converstion-1.md` (660 KB), `MILKDROP3_ANALYSIS.md`, `codex-review-findings.md`, `code_review.md`, `amp_code_review.md`, three `*.backup.hfy.*`, `.tmp_avroute.swift`, root PNGs, `MacAmp-1.0.6.dmg`, `webamp_clone/` (219 MB), `MilkDrop3/` (142 MB), `spikes/` (89 MB), `archives/`. `.gitignore` covers these via `.*`, `build/`, `dist/`, `tmp/`, `*.dmg`, root PNGs; add explicit `module-cache/`, `.derivedData/`, `.build-cache/`, `.xcode-cache/` for clarity.

### Docs drift

`docs/README.md` index matches the 11 companion docs. `docs/MULTI_WINDOW_ARCHITECTURE.md:55,108` still describes `UnifiedDockView`; `:704-720,1247` describes a `DockingController` extension plan — both contradict the current five-`NSWindow` design. `.ai-shared/macamp/project.md` says "ViewModels/ Legacy ObservableObject VMs (migrating to @Observable)" — migration is complete.

---

## 10. What is done well (do not touch)

- Observation adoption is complete and idiomatic: typed `@Environment`, `@Bindable` in body scope, `@State` roots in `MacAmpApp.swift:3-53`.
- `AudioEngineConfigurationObserver.swift:20-91`: `AsyncSequence`, `Duration`, cancellation, `isolated deinit` — the reference pattern for the rest of the codebase.
- Real-time paths avoid actor hops and allocation: `VisualizerFeed.swift:47-81` non-blocking publish, `VideoTap.swift:119-132` try-lock cache, `StreamDecodePipeline.swift:191-205` response/data ordering with generation checks.
- The ObjC workgroup shim is narrow and justified.
- Window delegate ownership is explicit and correct (`WindowDelegateWiring.swift:3-8,43-52`); frame persistence is cancellable-task debounced (`WindowFramePersistence.swift:45-52`).
- `ButterchurnWebView.swift:148-154` removes its script message handler on dismantle.
- Sprite atlas coordinates are centralized; `Track` and playback enums are explicitly `Sendable`.
- Pre-commit hook enforces lint, secrets and TODO policy.

---

## 11. Suggested sequencing (if acted on)

Recommendation only; ordered by value ÷ risk.

1. Hygiene (zero code risk): purge `module-cache/`, `weak_struct`, transcript; fix `project.yml` floor to 26; delete or fix `Package.swift`; `swiftlint --fix`.
2. Delete `DockingController` and route the four menu commands to `WindowVisibilityController` + per-window shade state; resolve the Cmd+Shift collision. Fixes three user-visible bugs.
3. Remove dead features (material settings, `useLogScaleBands`, `autoEQTask`, unused views/params, `TODO Phase 3`).
4. Fix `Skin` Sendable and `LockFreeRingBuffer` race.
5. Collapse singletons to injection (`AppSettings.instance()`, `WindowCoordinator.shared`).
6. Extract `WinampWindowChrome` / `WinampTitleBarButtons` / `WinampBitmapText` / `QuantizedWindowResizeHandle`.
7. Folder moves per §8 (one `xcodegen generate` after).
8. Replace `Timer`s and `Combine` publishers with structured tasks / `TimelineView`.
9. `SpriteResolver` table refactor; typed `SpriteID`.
10. Test gaps (§7) and `#require` cleanup.
