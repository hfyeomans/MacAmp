# Plan: AirPlay Integration for MacAmp

> **Purpose:** Implementation plan for adding AirPlay output routing, Now Playing system integration, and UX discoverability to MacAmp. All three phases plus prerequisite bugfix. Derived from Oracle-corrected research, updated for current codebase.

**Date:** 2026-02-07 (original), **Updated:** 2026-03-23
**Status:** HISTORICAL — Phase 1 (AirPlay triggers) DEFUNCT, Phase 2 (Now Playing) COMPLETE. See state.md for current status.
**Oracle Reviews:** Plan: 7→8→8/10. Implementation: 6→7→6→7→9/10.
**Estimated Effort:** 5-7 hours total (all phases incl. bugfix)

---

## Approach

**Dual-trigger AirPlay activation:**

1. **Primary trigger — top-left bolt icon (~6, 3):** Transparent `AVRoutePickerView` overlay on the classic Winamp bolt/menu icon in the titlebar. Fixed position across all skins, works in both full and shade mode.

2. **Secondary trigger — bottom-right WA logo (~253, 91):** Same transparent overlay on the WA logo mark in the main window body. Full mode only. Most skins have an icon in this area; the overlay remains clickable regardless of skin visual.

**Why dual triggers:**
- Top-left bolt is skin-independent (titlebar layout is standardized) and works in shade mode
- Bottom-right logo matches the established webamp "about" link pattern
- Both are invisible (zero visual impact, 100% skin fidelity)
- Covers all scenarios: full mode, shade mode, any skin

**Prerequisite:** Fix pre-existing time display toggle hit area bug (`.contentShape()` after `.at()`) in both full and shade modes, which currently places the clickable area at (0, 0) instead of over the time digits.

---

## Three-Layer Architecture Alignment

```text
Mechanism Layer:
├─ AudioEngineController — engine config change observer, engine restart
├─ StreamPlayer — stream metadata (streamTitle, streamArtist), elapsed time
├─ AudioPlayer — playback state, seek guards, playlist navigation

Bridge Layer:
├─ PlaybackCoordinator — Now Playing info center, remote command center
│  ├─ displayTime / displayDuration (already exists)
│  ├─ displayTitle / displayArtist (already exists)
│  ├─ play/pause/stop/next/previous (already exists)
│  ├─ updateNowPlayingInfo() (NEW — called at all state transitions)
│  ├─ setupRemoteCommands() (NEW — wires media keys through coordinator)
│  └─ onEngineReconfigured wiring (NEW — refreshes stream workgroup)

Presentation Layer:
├─ AirPlayRoutePicker (NEW — transparent AVRoutePickerView NSViewRepresentable)
├─ WinampMainWindow — primary trigger at top-left bolt (both modes)
├─ MainWindowFullLayer — secondary trigger at bottom-right WA logo (full mode only)
├─ MainWindowOptionsMenuPresenter — AirPlay hint in options menu
```

---

## Phase 0: Prerequisite — Fix Time Display Hit Area Bug

### Problem

Both `MainWindowFullLayer.buildTimeDisplay()` and `MainWindowShadeLayer.buildShadeTimeDisplay()` have `.contentShape(Rectangle())` and `.onTapGesture` applied AFTER `.at()`. Since `.at()` is `.offset()` under the hood, it moves the visual but NOT the layout frame. The hit area stays at (0, 0) instead of following the visual to the time digit position.

**Full mode:** Hit area is a ~21x13 rect at (0, 0) — lands on the bolt icon at (~6, 3). Visual is at (39, 26).
**Shade mode:** Same bug — hit area displaced from visual at (150, 7).

### Fix

> **Oracle correction (MEDIUM):** Reordering alone is insufficient. The ZStack's intrinsic size only covers the leftmost child (~21px wide), not the full rendered MM:SS span (~56px). Need an explicit `.frame()` for the full time display bounds BEFORE `.contentShape()` and `.onTapGesture`, then `.at()`.

**File:** `MacAmpApp/Views/MainWindow/MainWindowFullLayer.swift` (lines 91-119)

```swift
// BEFORE (buggy):
ZStack(alignment: .leading) { ... }
.at(Layout.timeDisplay)
.contentShape(Rectangle())
.onTapGesture { settings.toggleTimeDisplayMode() }

// AFTER (fixed):
ZStack(alignment: .leading) { ... }
.frame(width: 56, height: 13)       // full MM:SS visual bounds
.contentShape(Rectangle())           // hit area covers all digits
.onTapGesture { settings.toggleTimeDisplayMode() }
.at(Layout.timeDisplay)              // THEN move to final position
```

**File:** `MacAmpApp/Views/MainWindow/MainWindowShadeLayer.swift` (lines 67-107)

```swift
// BEFORE (buggy):
ZStack(alignment: .leading) { ... }
.at(Layout.timeDisplay)
.scaleEffect(0.7)
.at(CGPoint(x: 150, y: 7))
.contentShape(Rectangle())
.onTapGesture { settings.toggleTimeDisplayMode() }

// AFTER (fixed):
ZStack(alignment: .leading) { ... }
.frame(width: 56, height: 13)       // full MM:SS visual bounds
.contentShape(Rectangle())           // hit area covers all digits
.onTapGesture { settings.toggleTimeDisplayMode() }
.at(Layout.timeDisplay)
.scaleEffect(0.7)
.at(CGPoint(x: 150, y: 7))
```

### Verification

- Click the time digits in full mode — should toggle elapsed/remaining
- Click the bolt icon area — should NOT toggle time display (bolt is now free for AirPlay)
- Click the time digits in shade mode — should toggle elapsed/remaining
- Click elsewhere in shade titlebar — should NOT toggle time display

---

## Phase 1: Core AirPlay + Engine Restart — REQUIRED

### 1.1 Create AirPlayRoutePicker Component

**File:** `MacAmpApp/Views/Components/AirPlayRoutePicker.swift` (NEW)

Create an NSViewRepresentable wrapper for a transparent AVRoutePickerView. Follow the pattern in `MacAmpApp/Views/Windows/AVPlayerViewRepresentable.swift` (25 lines, minimal wrapper):

```swift
import SwiftUI
import AVKit

struct AirPlayRoutePicker: NSViewRepresentable {
    func makeNSView(context: Context) -> AVRoutePickerView {
        let picker = AVRoutePickerView()
        picker.isRoutePickerButtonBordered = false
        picker.alphaValue = 0.01  // invisible but hit-testable
        picker.setRoutePickerButtonColor(.clear, for: .normal)
        picker.toolTip = "AirPlay"
        return picker
    }

    func updateNSView(_ nsView: AVRoutePickerView, context: Context) {}
}
```

- Import AVKit (NOT AVFoundation — Oracle-corrected)
- `isRoutePickerButtonBordered = false` (correct API name — Oracle-corrected from `isBordered`)
- `setRoutePickerButtonColor(.clear, for: .normal)` (available on macOS)
- `alphaValue = 0.01` — invisible but receives clicks
- `toolTip = "AirPlay"` — discoverability built in

### 1.2 Position Dual Triggers

**Add layout constants:**

**File:** `MacAmpApp/Views/MainWindow/WinampMainWindowLayout.swift` (modify)

```swift
// AirPlay triggers
static let airPlayBolt = CGPoint(x: 3, y: 1)        // top-left bolt icon (primary)
static let airPlayBoltSize = CGSize(width: 12, height: 12)
static let airPlayLogo = CGPoint(x: 249, y: 87)      // bottom-right WA logo (secondary)
static let airPlayLogoSize = CGSize(width: 26, height: 20)
```

**Primary trigger — top-left bolt (both modes):**

**File:** `MacAmpApp/Views/MainWindow/WinampMainWindow.swift` (modify)

> **Oracle correction (MEDIUM):** The bolt picker must be the topmost layer to reliably receive clicks in both modes. Inserting between the drag handle and the full/shade conditional is risky — the shade layer draws a full-width background that would sit above it. Place the bolt picker as the LAST child of the ZStack, or use `.overlay(alignment: .topLeading)`.

Add the AirPlay overlay as the LAST child of the ZStack (highest z-order, above both drag handle and full/shade layers):

```swift
ZStack(alignment: .topLeading) {
    // Background
    SimpleSpriteImage("MAIN_WINDOW_BACKGROUND", ...)

    // Titlebar drag handle
    WinampTitlebarDragHandle(...)
        .at(CGPoint(x: 0, y: 0))

    // Full or shade layer
    if !settings.isMainWindowShaded {
        MainWindowFullLayer(...)
    } else {
        MainWindowShadeLayer(...)
    }

    // AirPlay primary trigger — LAST in ZStack = topmost z-order
    // Receives clicks above drag handle AND shade/full layers
    AirPlayRoutePicker()
        .frame(width: Layout.airPlayBoltSize.width, height: Layout.airPlayBoltSize.height)
        .at(Layout.airPlayBolt)
}
```

This works because:
- Last child in ZStack = highest z-order (above everything)
- It receives clicks before the drag handle or shade background can intercept them
- It renders in BOTH full and shade mode (it's outside the conditional)
- Fixed position across all skins (titlebar layout is standardized)

**Secondary trigger — bottom-right WA logo (full mode only):**

**File:** `MacAmpApp/Views/MainWindow/MainWindowFullLayer.swift` (modify)

Add at the end of the `Group` body:

```swift
// AirPlay secondary trigger — WA logo area (full mode only)
AirPlayRoutePicker()
    .frame(width: Layout.airPlayLogoSize.width, height: Layout.airPlayLogoSize.height)
    .at(Layout.airPlayLogo)
```

This auto-hides in shade mode (MainWindowFullLayer is not rendered).

**Double-size mode:** No special handling needed. `scaleEffect(2.0, anchor: .topLeading)` at the parent ZStack level transforms both visual and hit-test areas uniformly.

**Coordinate verification:** Visual inspection required after first build. The bolt position is highly consistent across skins. The WA logo position may need ±5px fine-tuning per skin, but the overlay area is generous (26x20).

### 1.3 Add Engine Configuration Observer (CRITICAL)

> **Oracle correction (HIGH):** Stream bridge does NOT auto-recover from engine restart. Apple's `AVAudioEngine.h` says config change stops the engine, leaves nodes attached with their previous formats, and the app must reestablish connections when formats change. Must explicitly reconnect the bridge path and refresh the workgroup.
>
> **Oracle correction (HIGH):** Recovery policy must NOT live entirely in AudioEngineController. AudioPlayer owns seek guards, playback position, and completion filtering. Need `willReconfigure`/`didReconfigure` callbacks so AudioPlayer can arm guards BEFORE any restart work.

**File:** `MacAmpApp/Audio/AudioEngineController.swift` (modify — mechanism layer)

Register notification observer (observer registration belongs here — engine is owned here):

```swift
NotificationCenter.default.addObserver(
    forName: AVAudioEngine.configurationChangeNotification,
    object: engine,
    queue: nil  // fires on arbitrary queue
) { [weak self] _ in
    Task { @MainActor [weak self] in
        self?.handleEngineConfigurationChange()
    }
}
```

Add will/did callbacks for AudioPlayer coordination:

```swift
var onWillReconfigure: (() -> Void)?   // AudioPlayer arms seek guards
var onDidReconfigure: (() -> Void)?    // AudioPlayer re-applies settings, resumes
```

**`handleEngineConfigurationChange()` flow:**
1. Fire `onWillReconfigure()` — AudioPlayer arms seekGuardActive + isHandlingCompletion guards
2. Save engine running state
3. Stop the engine (`engine.stop()`)
4. If stream bridge was active:
   - Disconnect and reconnect the AVAudioSourceNode with the new output format
   - Node graph: sourceNode → eqNode → mainMixerNode → outputNode
   - The ring buffer continues to hold data; source node render callback resumes reading
5. If local file was playing:
   - Reconnect player node → EQ → mixer → output with new format if needed
6. Restart engine (`try engine.start()`)
7. Fire `onDidReconfigure()` — AudioPlayer resumes playback, re-applies volume/balance

**File:** `MacAmpApp/Audio/AudioPlayer.swift` (modify — bridge coordination)

Wire `engine.onWillReconfigure` and `engine.onDidReconfigure` in init():

**`onWillReconfigure`:**
- Set `seekGuardActive = true` (prevents onPlaybackEnded from firing during restart)
- Set `isHandlingCompletion = true` (blocks same-seekID completions fired by engine restart — `seekGuardActive` alone only blocks nil-seekID completions per `shouldIgnoreCompletion` at line 219)
- Save `currentTime` for resume position
- If stream bridge is active: save bridge state for reactivation

**`onDidReconfigure`:**
- Re-apply volume: `engine.setVolume(volume)` and `engine.setBalance(balance)`
- If was playing local file: seek to saved position, schedule resume
- Fire `onEngineReconfigured` callback so PlaybackCoordinator can refresh stream workgroup
- Clear `seekGuardActive` after 100ms delay (matches existing seek pattern at line 618)
- Clear `isHandlingCompletion` after 200ms delay (matches existing completion pattern at line 675)

**File:** `MacAmpApp/Audio/PlaybackCoordinator.swift` (modify — bridge coordination for streams)

Wire `audioPlayer.onEngineReconfigured` callback in init():
- AudioPlayer does NOT own StreamPlayer — PlaybackCoordinator does
- When engine reconfigures with active stream bridge:
  - Call `streamPlayer.setAudioWorkgroup(audioPlayer.audioWorkgroup)` to refresh the workgroup on the decode thread
  - The ring buffer data is preserved; the source node render callback resumes after engine restart

**Why this split:**
- **AudioEngineController** (mechanism): owns the AVAudioEngine, registers observer, performs stop/reconnect/start
- **AudioPlayer** (mechanism+bridge): owns seek guards and playback state, arms guards before restart, resumes after
- **PlaybackCoordinator** (bridge): refreshes stream workgroup since it owns the stream lifecycle

### 1.4 Dual Backend Considerations

- **AVAudioEngine (local files):** Needs the engine config observer. Engine stops automatically on route change due to sample rate mismatch. Must restart with format reconnection.
- **StreamDecodePipeline (streams):** The stream bridge runs through AVAudioSourceNode which IS part of the engine graph. On engine config change, the source node's format may become stale. AudioEngineController must disconnect and reconnect the source node path. The ring buffer data is preserved (lock-free, independent of engine state). The workgroup must be refreshed via PlaybackCoordinator.
- **PlaybackCoordinator:** Must refresh workgroup on stream bridge after engine reconfiguration. System routing otherwise applies automatically to whichever backend is active.
- **Entitlements:** No additional entitlements needed. `com.apple.security.network.client` and `com.apple.security.device.audio-output` already present.

### 1.5 Build & Test

- XcodeBuildMCP build with Thread Sanitizer
- XcodeBuildMCP test — all existing tests pass
- Verify Phase 0 bugfix: time toggle clicks time digits, not bolt
- Click top-left bolt — verify AirPlay picker popover appears
- Click bottom-right WA logo — verify AirPlay picker popover appears
- Test with real AirPlay device (user has AirPlay devices)
- Verify audio routes to AirPlay device (local file playback)
- Verify EQ processing maintained on AirPlay
- Switch back to built-in speakers — verify seamless
- Test engine restart: switch output while music is playing
- Test stream playback over AirPlay (stream bridge path)
- Test AirPlay in shade mode (bolt trigger)
- Edge case: AirPlay device disconnection during playback
- Edge case: switch output while paused, then resume

---

## Phase 2: Now Playing Integration — REQUIRED

### 2.1 Now Playing Info Center

**File:** `MacAmpApp/Audio/PlaybackCoordinator.swift` (modify — bridge layer)

The coordinator is the correct place for Now Playing because it already has:
- `displayTitle` / `displayArtist` — unified across both backends
- `displayTime` / `displayDuration` — unified time display
- `play()` / `pause()` / `stop()` / `next()` / `previous()` — all state transitions
- `currentSource` — knows which backend is active
- `currentTrack` — metadata for local files

Add `import MediaPlayer` and implement:

**`updateNowPlayingInfo()`** — called at every state transition point:

> **Oracle correction (HIGH):** macOS requires explicit `MPNowPlayingInfoCenter.default().playbackState` updates alongside `nowPlayingInfo`. Without this, remote control behavior may not work correctly.

```swift
private func updateNowPlayingInfo() {
    let center = MPNowPlayingInfoCenter.default()

    var info = [String: Any]()
    info[MPMediaItemPropertyTitle] = displayTitle
    info[MPMediaItemPropertyArtist] = displayArtist
    info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = displayTime
    info[MPMediaItemPropertyPlaybackDuration] = displayDuration  // 0 for streams
    info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
    center.nowPlayingInfo = info

    // REQUIRED on macOS — explicit playback state
    // Use coordinator state, not audioPlayer.playbackState,
    // because stream pause/buffering is owned by StreamPlayer/PlaybackCoordinator
    if isPlaying {
        center.playbackState = .playing
    } else if isPaused {
        center.playbackState = .paused
    } else if isStreamBuffering {
        // Stream buffering: not playing but not stopped — keep as paused
        // to avoid losing the Now Playing item during reconnect
        center.playbackState = .paused
    } else {
        center.playbackState = .stopped
    }
}
```

**`clearNowPlayingInfo()`** — called from `stop()`:
```swift
private func clearNowPlayingInfo() {
    let center = MPNowPlayingInfoCenter.default()
    center.nowPlayingInfo = nil
    center.playbackState = .stopped  // must set explicitly on macOS
}
```

> **Oracle correction (MEDIUM):** Apple auto-extrapolates elapsed time from the last provided value + playback rate. No periodic timer needed — just update at state transitions.

**State transition call sites** (choke points + stream hooks):

PlaybackCoordinator methods:
1. `play(track:)` — line ~190 (new track, either backend)
2. `play(station:)` — line ~215 (new station)
3. `pause()` — line ~227 (rate → 0, state → paused)
4. `stop()` — line ~238 (clear all info via `clearNowPlayingInfo()`)
5. `resume()` — line ~270 (rate → 1, state → playing)
6. `handlePlaylistAdvance(action:)` — line ~302 (auto-advance)
7. `updateTrackMetadata(_:)` — line ~333 (async metadata loaded)

Stream hooks (via callbacks from StreamPlayer):
8. `streamPlayer.onStateChange` — line ~173 (buffering/playing/error state changes)
9. `streamPlayer.onMetadata` (ICY metadata) — line ~213 (title/artist changes)

These 9 choke points cover all playback state changes.

### 2.2 Remote Command Center

**File:** `MacAmpApp/Audio/PlaybackCoordinator.swift` (modify)

Add `setupRemoteCommands()` called from init:

> **Oracle correction (MEDIUM):** ALL remote command handlers fire on an arbitrary thread. PlaybackCoordinator, AudioPlayer, and StreamPlayer are all `@MainActor`. Every handler needs `Task { @MainActor }` dispatch.

```swift
private func setupRemoteCommands() {
    let center = MPRemoteCommandCenter.shared()

    center.playCommand.addTarget { [weak self] _ in
        Task { @MainActor [weak self] in self?.resume() }
        return .success
    }
    center.pauseCommand.addTarget { [weak self] _ in
        Task { @MainActor [weak self] in self?.pause() }
        return .success
    }
    center.togglePlayPauseCommand.addTarget { [weak self] _ in
        Task { @MainActor [weak self] in self?.togglePlayPause() }
        return .success
    }
    center.nextTrackCommand.addTarget { [weak self] _ in
        Task { @MainActor [weak self] in await self?.next() }
        return .success
    }
    center.previousTrackCommand.addTarget { [weak self] _ in
        Task { @MainActor [weak self] in await self?.previous() }
        return .success
    }
    // Seek: only for local files (disable for streams)
    center.changePlaybackPositionCommand.addTarget { [weak self] event in
        guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
        Task { @MainActor [weak self] in
            self?.audioPlayer.seek(to: event.positionTime)
        }
        return .success
    }
}
```

**Seek command for streams:** Disable `changePlaybackPositionCommand` when `currentSource` is `.radioStation` (no duration). Re-enable when switching to local playback.

**Command enablement** (Gemini insight): If unused commands are left enabled, macOS may hide next/previous buttons in Control Center due to space constraints. MacAmp already has UI for repeat, shuffle, skip, and seek — some of these may be worth wiring to remote commands. **Evaluate during Phase 2 testing** which commands to enable/disable based on Control Center space and actual device behavior (AirPlay remotes, Bluetooth headphones, keyboard media keys).

**Bluetooth headphone note** (Gemini insight): `togglePlayPauseCommand` is unreliable with some Bluetooth headphones on macOS. We register explicit `playCommand` and `pauseCommand` handlers alongside `togglePlayPauseCommand` for maximum compatibility — already in the plan.

**Why PlaybackCoordinator, not AudioPlayer:**
- The coordinator already owns play/pause/stop/next/previous
- Remote commands need to work for BOTH local files and streams
- The coordinator dispatches to the active backend — bridge layer's role

### 2.3 Stream Metadata for Now Playing

When playing internet radio, Now Playing shows:
- **Title:** ICY stream title via `streamPlayer.streamTitle`
- **Artist:** ICY artist via `streamPlayer.streamArtist`
- **Duration:** 0 (live stream)
- **Elapsed:** `streamPlayer.elapsedTime` (anchor-based, already implemented)
- **Rate:** 1.0 when playing, 0.0 when paused/buffering

ICY metadata updates trigger `updateNowPlayingInfo()`:
- Add `onMetadataChanged` callback from StreamPlayer to PlaybackCoordinator
- PlaybackCoordinator wires in init alongside existing `onFormatReady`/`onStreamTerminated`
- No periodic timer needed — Apple auto-extrapolates elapsed time

### 2.4 Test System Integration

**Note (Gemini insight):** macOS WindowServer and Control Center have inherent delays — Now Playing UI updates may lag 1-2s. This is normal platform behavior, not a bug.

- Play local file — Control Center shows title/artist/progress
- Play internet radio — Control Center shows stream title
- Keyboard play/pause — works for both backends
- Keyboard next/previous — advances playlist
- Seek via Control Center — works for local files, disabled for streams
- ICY metadata change — Control Center updates title
- Switch local → stream → local — Now Playing updates each time
- Stop playback — Now Playing clears, playbackState = .stopped
- Test with AirPlay active — all remote controls work

---

## Phase 3: Discoverability & UX Polish — REQUIRED

### 3.1 Why Invisible Overlays Are Correct

A visible `AVRoutePickerView` icon cannot work with skins because:
- Every pixel of the 275x116 main window is defined by skin bitmaps
- No Winamp skin format sprite exists for "AirPlay"
- A native macOS glyph looks alien against any skin's bitmap aesthetic
- All layout regions are tightly packed and skin-specific

Invisible overlays solve this: zero visual impact, 100% skin fidelity.

### 3.2 Discoverability Strategies

**a) Tooltip on hover** (built into Phase 1 — `toolTip = "AirPlay"` on both overlays)

**b) Options menu entry**
- Add disabled/informational `NSMenuItem` to `MainWindowOptionsMenuPresenter`
- Text: "AirPlay: click bolt icon" or similar
- `isEnabled = false` — prevents accidental clicks (can't programmatically trigger AVRoutePickerView)
- Uses raw `NSMenuItem` (not the existing action-producing helper) to avoid making it clickable

**c) macOS menu bar entry**
- Add "AirPlay Devices..." to Controls or Playback menu
- Same limitation: informational only, guides user to click bolt/logo

### 3.3 Shade Mode Handling

With the dual-trigger approach, shade mode is fully covered:
- **Primary trigger (bolt at ~6, 3):** WORKS in shade mode — it's in the ZStack above the conditional full/shade switch
- **Secondary trigger (WA logo at ~253, 91):** Hidden in shade mode — it's inside MainWindowFullLayer
- **Media keys (Phase 2):** Work regardless of window mode
- No dead-space invisible buttons needed in the shade bar

### 3.4 Double-Size Mode

No special handling needed:
- `scaleEffect(2.0, anchor: .topLeading)` at the ZStack level uniformly scales all content including hit-test areas
- Coordinates are in 1x space, scaleEffect transforms them
- Verified from codebase: SimpleSpriteImage.swift lines 84-95

---

## Files to Create

| File | Phase | Lines | Purpose |
|---|---|---|---|
| `MacAmpApp/Views/Components/AirPlayRoutePicker.swift` | 1 | ~20 | Transparent AVRoutePickerView NSViewRepresentable wrapper |

## Files to Modify

| File | Phase | Changes | Purpose |
|---|---|---|---|
| `MacAmpApp/Views/MainWindow/MainWindowFullLayer.swift` | 0+1 | ~10 lines | Fix time display hit area + add secondary AirPlay overlay |
| `MacAmpApp/Views/MainWindow/MainWindowShadeLayer.swift` | 0 | ~5 lines | Fix shade time display hit area |
| `MacAmpApp/Views/MainWindow/WinampMainWindow.swift` | 1 | ~5 lines | Add primary AirPlay overlay at bolt icon |
| `MacAmpApp/Views/MainWindow/WinampMainWindowLayout.swift` | 1 | ~5 lines | Add airPlay coordinate constants |
| `MacAmpApp/Audio/AudioEngineController.swift` | 1 | ~50 lines | Engine config change observer, will/did callbacks, node reconnection |
| `MacAmpApp/Audio/AudioPlayer.swift` | 1 | ~25 lines | Wire will/did reconfigure callbacks, seek guards, volume re-apply |
| `MacAmpApp/Audio/PlaybackCoordinator.swift` | 1+2 | ~100 lines | Workgroup refresh (P1) + Now Playing info + remote commands (P2) |
| `MacAmpApp/Audio/StreamPlayer.swift` | 2 | ~10 lines | Add onMetadataChanged callback |
| `MacAmpApp/Views/MainWindow/MainWindowOptionsMenuPresenter.swift` | 3 | ~5 lines | AirPlay hint (disabled NSMenuItem) |

## Files NOT Modified

- `MacAmp.entitlements` — already has `network.client` + `audio-output`
- `Info.plist` — NSLocalNetworkUsageDescription not required for AVRoutePickerView
- `StreamDecodePipeline.swift` — stream bridge reads from ring buffer, engine restart handled by AudioEngineController
- `project.yml` — no new frameworks need explicit linking (AVKit/MediaPlayer available system-wide)

---

## Risk Assessment

| Risk | Level | Mitigation |
|---|---|---|
| Engine restart causes onPlaybackEnded | CRITICAL | will/did callbacks: AudioPlayer arms seekGuardActive + isHandlingCompletion BEFORE restart, clears after. |
| Engine restart with active stream bridge | HIGH | Disconnect/reconnect source node path. Refresh workgroup via PlaybackCoordinator. Ring buffer data preserved. (Oracle-corrected) |
| Missing MPNowPlayingInfoCenter.playbackState | HIGH | macOS requires explicit playbackState updates. Set at every transition + clearNowPlayingInfo sets .stopped. (Oracle-corrected) |
| Remote commands fire off @MainActor | MEDIUM | ALL handlers dispatch via `Task { @MainActor }`. Disable seek for streams. (Oracle-corrected) |
| Bolt overlay intercepts titlebar drag | LOW | Small 12x12 area, positioned before drag handle in ZStack. Same pattern as minimize/shade/close buttons. |
| WA logo coordinates vary with skin | LOW | Secondary trigger only. Generous 26x20 hit area. Most skins have icon in this region. |
| MediaPlayer framework macOS availability | LOW | Available macOS 10.12.2+. |

---

## Success Criteria

### Phase 0 (Bugfix)
- [ ] Clicking time digits in full mode toggles elapsed/remaining
- [ ] Clicking bolt icon area does NOT toggle time display
- [ ] Clicking time digits in shade mode toggles elapsed/remaining
- [ ] Clicking elsewhere in shade titlebar does NOT toggle time display

### Phase 1 (Core AirPlay)
- [ ] Clicking top-left bolt opens AirPlay picker (full mode)
- [ ] Clicking top-left bolt opens AirPlay picker (shade mode)
- [ ] Clicking bottom-right WA logo opens AirPlay picker (full mode)
- [ ] Audio routes to selected AirPlay device (local files)
- [ ] Audio routes to selected AirPlay device (streams)
- [ ] EQ processing maintained on AirPlay (local files)
- [ ] Engine restarts seamlessly on route change (no spurious onPlaybackEnded)
- [ ] No crashes or audio glitches during switch
- [ ] Both overlays invisible (skin unmodified)
- [ ] Switch back to built-in speakers works

### Phase 2 (Now Playing)
- [ ] Control Center shows track title/artist for local files
- [ ] Control Center shows stream title/artist for internet radio
- [ ] Keyboard media keys (play/pause/next/prev) work
- [ ] Progress bar updates for local files
- [ ] ICY metadata changes update Now Playing
- [ ] Seek via Control Center works for local files
- [ ] Seek disabled for streams

### Phase 3 (Discoverability)
- [ ] Tooltip shows "AirPlay" on bolt/logo hover
- [ ] Options menu includes AirPlay hint (disabled item)
- [ ] Shade mode: bolt trigger works, media keys work
- [ ] Double-size mode works without coordinate adjustment
- [ ] Multiple skins tested (bolt position consistent, logo position reasonable)

---

## Dependencies

- AVKit framework (available macOS 10.15+)
- MediaPlayer framework (available macOS 10.12.2+)
- Real AirPlay device for testing (user confirmed available)
- Same Wi-Fi network for testing

---

## Alternatives Considered & Rejected

1. **Standard visible AirPlay button** — Rejected. No natural home in skin-driven UI.
2. **Custom device menu** — NOT POSSIBLE (APIs don't exist per Oracle review).
3. **Menu bar integration only** — Can't programmatically trigger AVRoutePickerView.
4. **Single logo-only trigger** — Rejected. Skin-dependent position, doesn't work in shade mode.
5. **Now Playing in AudioPlayer** — Rejected. AudioPlayer only handles local files. PlaybackCoordinator is the bridge layer with unified state.
6. **Top-left bolt as system menu** — Rejected in favor of direct AirPlay trigger. AVRoutePickerView requires direct click, can't be opened from a menu action.
