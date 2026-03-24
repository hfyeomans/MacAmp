# Research: AirPlay Integration for MacAmp

> **Purpose:** Consolidated research from `tasks/airplay/` and `tasks/winamp-airplay-overlay/` plus new findings on the Winamp logo as AirPlay trigger button. All research sources, API findings, Oracle corrections, and codebase analysis live here.

**Date:** 2026-02-07 (consolidated from 2025-10-30 originals)
**Sources:** Gemini, Oracle (Codex), webamp_clone codebase analysis, MacAmp codebase analysis
**Prior Tasks:** `tasks/airplay/`, `tasks/winamp-airplay-overlay/`

---

## 0. Oracle Review (2026-02-07) - gpt-5.3-codex, reasoningEffort: xhigh

**Overall Feasibility Rating:** 8.5/10 - No show-stoppers found

### Corrections Applied

1. **[High] NSLocalNetworkUsageDescription is NOT iOS-only.** It is a valid macOS key (referenced in NSNetServices.h). However, it is NOT required for AVRoutePickerView-only integration. Only needed if app performs direct Bonjour/local network browsing. Corrected wording below.

2. **[High] AVRoutePickerView macOS API has more customization than previously stated.**
   - `isRoutePickerButtonBordered` exists (not `isBordered`)
   - `setRoutePickerButtonColor(_:for:)` and `routePickerButtonColor(for:)` are available
   - Previous claim of "no customization" was overstated

3. **[Medium] AVPlayer has `audioOutputDeviceUniqueID` for device pinning.** This is not a full AirPlay discovery UI replacement but means AVPlayer can be explicitly pinned to devices. Not needed for our approach (system routing applies automatically), but worth noting.

4. **[Medium] Engine restart strategy needs implementation guardrails.** Must reuse MacAmp's existing seek/completion guards (AudioPlayer.swift ~lines 823, 941) to avoid accidental `onPlaybackEnded` side effects during reconfiguration.

5. **[Low] Internal inconsistency about logo location.** Summary said logo is in MAIN_TITLE_BAR; the clickable WA mark is actually in the body area at (253, 91). Fixed below.

### Oracle Confirmations

- AVRoutePickerView is the correct primary approach
- Custom AVAudioEngine device-selection APIs do NOT exist (confirmed)
- Transparent overlay (alphaValue = 0.01) is feasible and hit-testable
- Logo coordinates (253, 91) map correctly in MacAmp's 275x116 coordinate space
- Entitlements are sufficient (network.client + audio-output)
- System routing applies to both AVAudioEngine and AVPlayer backends
- No title bar drag handle interference at (253, 91)

---

## 1. Executive Summary

AirPlay integration for MacAmp is **feasible** using the existing AVAudioEngine architecture. The only viable implementation path is `AVRoutePickerView` from AVKit (system UI). Custom device selection UIs are **not possible** with public macOS APIs.

A creative UX solution positions a transparent AVRoutePickerView over the Winamp logo in the title bar, matching the webamp "about" link overlay pattern. This maintains Winamp aesthetics while adding AirPlay functionality.

**Key Constraints:**
- AVRoutePickerView is the only practical unified route chooser for both backends
- AVPlayer has `audioOutputDeviceUniqueID` for explicit device pinning but is not a full AirPlay discovery UI
- Must handle AVAudioEngineConfigurationChange (engine stops on route change)
- Logo clickable area is in the main window body at ~(253, 91), not in the title bar
- No entitlement or Info.plist changes needed for AVRoutePickerView approach

---

## 2. API & Framework Research

### 2.1 AVRoutePickerView (Primary Solution)

**Framework:** AVKit (NOT AVFoundation - Oracle-corrected)

```swift
import AVKit
let picker = AVRoutePickerView()
```

**Behavior:**
- System-managed NSView that presents AirPlay device chooser popover
- Must be interacted with directly (no programmatic open/close)
- Handles device discovery, connection, multi-room automatically
- Minimal customization available on macOS (can't style button)
- Minimum recommended hit area: 22x22 points for accessibility

**What Works:**
- Creating and positioning the view
- Setting frame size
- Making it transparent (alphaValue = 0.01)
- Setting clear background
- `isRoutePickerButtonBordered = false` to hide default glyph (Oracle-corrected API name)
- `setRoutePickerButtonColor(_:for:)` for button color customization
- `routePickerButtonColor(for:)` to read current color

**What Doesn't Work on macOS:**
- `isRouteDetectionEnabled` (doesn't exist)
- `routePickerButtonStyle` (doesn't exist)
- `isBordered` (wrong name - use `isRoutePickerButtonBordered`)
- Programmatic presentation (`performClick` is private/unsupported)

### 2.2 AVAudioEngine & AirPlay Routing

**Current MacAmp Architecture:**
```
AVAudioPlayerNode -> AVAudioUnitEQ (10-band) -> mainMixerNode -> outputNode -> System Audio
```

**With AirPlay:**
- outputNode routes to whichever device the user selects via system picker
- EQ processing happens BEFORE routing (preserved on AirPlay)
- No changes to audio graph needed
- AVAudioEngine natively supports AirPlay routing

**CRITICAL: Engine Configuration Change Handling**
When user switches audio output (e.g., to AirPlay), the hardware sample rate changes. AVAudioEngine stops processing automatically. Without explicit restart logic, audio goes silent.

```swift
// REQUIRED observer in AudioPlayer.swift
NotificationCenter.default.addObserver(
    forName: .AVAudioEngineConfigurationChange,
    object: audioEngine,
    queue: .main
) { [weak self] _ in
    self?.handleEngineConfigurationChange()
}
```

### 2.3 APIs That DON'T Exist or Are Mischaracterized (Oracle Corrections)

| Gemini Claimed | Reality |
|---|---|
| `audioEngine.outputNode.setDeviceID()` | Method doesn't exist (compile-checked) |
| `AVAudioDevice.outputDevices` for AirPlay | No `AVAudioDevice` type in AVFoundation (compile-checked) |
| `AVRouteDetector` exposes AirPlay devices | Only reports `multipleRoutesDetected` boolean |
| Custom device selection menu | Not possible with public APIs for AVAudioEngine |
| `NSLocalNetworkUsageDescription` iOS-only | Actually valid on macOS, but NOT needed for AVRoutePickerView |
| `isBordered` on AVRoutePickerView | Correct API is `isRoutePickerButtonBordered` |
| AVPlayer has `audioOutputDeviceUniqueID` | TRUE - exists for explicit device pinning (not a full route picker) |

### 2.4 Entitlements & Permissions

**Already Present in MacAmp:**
- `com.apple.security.network.client` (Line 32, MacAmp.entitlements)
- `com.apple.security.device.audio-output` (Line 22, MacAmp.entitlements)

**NOT Required for AVRoutePickerView approach:**
- NSLocalNetworkUsageDescription - valid on macOS (not iOS-only as previously claimed) but not needed for AVRoutePickerView-only integration. Only required if app performs direct Bonjour/local network browsing.
- No additional entitlements required

### 2.5 MPNowPlayingInfoCenter / MPRemoteCommandCenter

**Framework:** MediaPlayer

**Purpose:** System media integration (Control Center, menu bar, keyboard media keys)

**Relevant for Phase 2:**
- Display track title/artist/artwork in Control Center
- Respond to keyboard play/pause/next/previous
- Update progress bar
- Verify MediaPlayer framework works on macOS (needs testing)

---

## 3. Winamp Logo as AirPlay Button

### 3.1 Webamp Reference Implementation

**The Pattern:** Webamp places an invisible clickable `<a>` element over the Winamp logo to open the "about" page.

**File:** `webamp_clone/packages/webamp/js/components/MainWindow/index.tsx` (Lines 129-134)
```tsx
<a
  id="about"
  target="_blank"
  href="https://webamp.org/about"
  title="About"
/>
```

**CSS:** `webamp_clone/packages/webamp/css/main-window.css` (Lines 394-400)
```css
#webamp #about {
  position: absolute;
  top: 91px;
  left: 253px;
  height: 15px;
  width: 13px;
}
```

**Key Details:**
- Invisible clickable area positioned absolutely over the logo
- Located at bottom-right of the 275x116 main window
- Size: 13x15 pixels (small but clickable)
- The logo is NOT a separate sprite - it's baked into `MAIN_WINDOW_BACKGROUND`
- Skin-independent positioning (hardcoded CSS)

### 3.2 MacAmp Title Bar Architecture

**File:** `MacAmpApp/Views/WinampMainWindow.swift` (Lines 100-106)
```swift
WinampTitlebarDragHandle(windowKind: .main, size: CGSize(width: 275, height: 14)) {
    SimpleSpriteImage(isWindowActive ? "MAIN_TITLE_BAR_SELECTED" : "MAIN_TITLE_BAR",
                    width: 275,
                    height: 14)
}
.at(CGPoint(x: 0, y: 0))
```

**Title Bar Sprites (from SkinSprites.swift Lines 102-125):**
```swift
"TITLEBAR": [
    Sprite(name: "MAIN_TITLE_BAR", x: 27, y: 15, width: 275, height: 14),
    Sprite(name: "MAIN_TITLE_BAR_SELECTED", x: 27, y: 0, width: 275, height: 14),
]
```

**Existing Title Bar Buttons:**
- Minimize: (x: 244, y: 3) - 9x9
- Shade: (x: 254, y: 3) - 9x9
- Close: (x: 264, y: 3) - 9x9

**Important Architectural Notes:**
- Title bar is wrapped in `WinampTitlebarDragHandle` which captures drag events
- The sprite content has `.allowsHitTesting(false)` - events go to the drag capture layer
- Title bar is only 14 pixels tall (vs webamp's full 116px window with logo at y:91)
- The Winamp logo/text in MacAmp is embedded in the title bar bitmap, NOT at webamp's (253, 91) coordinates

### 3.3 Logo Position Analysis

**Critical Difference from Webamp:**
- Webamp: Logo is at (253, 91) - near bottom-right of 275x116 window (part of MAIN.bmp body)
- MacAmp: The "WINAMP" text is in the TITLE BAR (y: 0-14), not in the body

**Winamp Classic Skin Layout:**
```
+--[Title Bar: 275 x 14]-------------------+  y: 0-14
|  "WINAMP" text is HERE in the title bar   |
+-------------------------------------------+
|  [Clutter Bar]  [Track Info Display]      |  y: 14-57
|  O  A  I  D  V  [Song Title Ticker]      |
+-------------------------------------------+
|  [Visualization]  [Time]  [Volume]        |  y: 58-87
+-------------------------------------------+
|  [Transport Controls]    [EQ/PL/Repeat]   |  y: 88-116
|  <<  >  >>  []  [|||]   [Mono/Stereo/EQ] |
+---+---------------------------------------+
         ^ Winamp logo is down HERE
           at approximately (253, 91) in webamp
```

**Where the Winamp Logo Actually Is:**
The classic Winamp 2.x "Winamp" branding text appears in two places:
1. **Title bar** (y: 0-14): Small "Winamp" text (skin-dependent)
2. **Bottom-right corner** (approx 253, 91): The small stylized "WA" logo mark

The webamp overlay targets the bottom-right logo mark (253, 91), which is in the main body area, NOT the title bar.

### 3.4 Sprite Resolution for Logo Presence

**SpriteResolver (SpriteResolver.swift Lines 348-355):**
```swift
case .mainTitleBar:
    return ["MAIN_TITLE_BAR"]
case .mainTitleBarSelected:
    return ["MAIN_TITLE_BAR_SELECTED", "MAIN_TITLE_BAR"]
```

**No separate logo sprite exists.** The Winamp logo/branding is embedded in:
- `MAIN_TITLE_BAR` / `MAIN_TITLE_BAR_SELECTED` bitmaps (title bar text)
- The main window background bitmap (bottom-right logo mark)

Every skin includes the MAIN_TITLE_BAR sprite (it's required for the window to render), so there is always some form of Winamp branding present, even if visually different across skins.

### 3.5 Main Window Body Sprites

The webamp logo position (253, 91) corresponds to the main window body area. In MacAmp, the main window body is composed of multiple sprite regions:

**From SkinSprites.swift - MAIN entries:**
The `MAIN_WINDOW_BACKGROUND` equivalent in MacAmp is composed from MAIN.bmp sprite regions. The small Winamp logo in the bottom-right area (near the stereo/mono indicator region around y:88-116) is embedded in these background sprites.

**Key Finding:** The logo area at approximately (253, 91) in the classic skin is near the EQ/PL toggle buttons and the stereo/mono indicator area. This is in the body of the window, below the title bar.

### 3.6 Coordinate Mapping (Webamp -> MacAmp)

**Webamp coordinates (CSS):**
- Logo "about" link: left: 253, top: 91, size: 13x15

**MacAmp coordinate system:**
- Uses `.at(CGPoint)` modifier for absolute positioning
- All elements positioned in a ZStack
- Title bar: (0, 0) - 275x14
- Transport buttons: y: 88
- The body area uses the same pixel coordinate system as webamp

**For the logo overlay, the MacAmp position should be approximately:**
- `CGPoint(x: 253, y: 91)` with frame `width: 13, height: 15`
- But expanded to minimum 22x22 for accessibility (centered on logo)

---

## 4. Feasibility Assessment

### 4.1 AVRoutePickerView Over Logo (Primary Approach)

**Feasibility:** HIGH

**How It Works:**
1. Create a transparent AVRoutePickerView (NSViewRepresentable)
2. Set `alphaValue = 0.01` (invisible but hit-testable)
3. Position at approximately (253, 91) using `.at()` modifier
4. Frame: 24x24 (accessibility minimum, centered on logo area)
5. User clicks logo area -> system AirPlay picker popover appears

**Advantages:**
- Maintains Winamp aesthetic (no visible system icon)
- Matches webamp "about" link pattern
- Simple implementation (~20 lines)
- Logo sprite provides visual, picker provides functionality

**Considerations:**
- Logo position is skin-dependent (baked into bitmap)
- Title bar drag handle may intercept clicks if overlay is in title bar area
- The logo at (253, 91) is in the body, NOT the title bar, so drag handle is not a concern
- Need to verify the exact pixel coordinates for MacAmp's rendering of the logo area

### 4.2 Standard Placement (Fallback)

**Feasibility:** HIGH

**Where:** Near volume/balance sliders or in clutter bar area.

**Advantages:**
- Visible system AirPlay icon (discoverable)
- Standard UX (users know what it is)

**Disadvantages:**
- Doesn't match Winamp aesthetic
- Takes up UI real estate

### 4.3 Engine Configuration Handling

**Feasibility:** HIGH (CRITICAL requirement)

**Implementation:** ~30 lines in AudioPlayer.swift
- Observe `.AVAudioEngineConfigurationChange`
- Restart engine on route change
- Resume playback from current position

### 4.4 Custom Device Menu

**Feasibility:** IMPOSSIBLE (public APIs don't exist)

Oracle confirmed: `outputNode.setDeviceID()` doesn't exist, AVAudioDevice doesn't enumerate AirPlay endpoints.

---

## 5. Dual Backend Consideration

MacAmp has a dual audio backend:
- **AVAudioEngine:** Local file playback (supports EQ)
- **AVPlayer:** Internet radio streams (no EQ)

**AirPlay Impact:**
- AVAudioEngine: Needs engine configuration change handler
- AVPlayer: System routing applies automatically. AVPlayer also has `audioOutputDeviceUniqueID` for explicit device pinning, but this is NOT needed - system routing handles it.
- PlaybackCoordinator: No changes needed (system routing applies to active backend)

**Oracle Note:** Engine restart handler should only apply to the local-audio (AVAudioEngine) path. Must reuse existing seek/completion guards in AudioPlayer.swift (~lines 823, 941) to avoid accidental `onPlaybackEnded` side effects during reconfiguration.

---

## 6. Oracle Review History

### First Oracle Review (2025-10-30)
- **Gemini accuracy:** 60% (conceptually correct, technically wrong)
- **5 critical corrections** applied
- **Custom UI path removed** (APIs don't exist)
- **Engine restart logic added** (CRITICAL missing piece)

### Second Oracle Review (2025-10-30) - Logo Overlay
- **User's idea validated:** "Drop transparent AVRoutePickerView over logo" - confirmed feasible
- **Code pattern provided** for transparent picker
- **Positioning guidance** based on webamp reference

---

## 7. References

### Codebase Files
- `MacAmpApp/Audio/AudioPlayer.swift` - AVAudioEngine implementation
- `MacAmpApp/Views/WinampMainWindow.swift` - Main window UI (Lines 42-91 Coords, Lines 100-106 title bar)
- `MacAmpApp/Models/SkinSprites.swift` - Sprite definitions (Lines 102-125 TITLEBAR)
- `MacAmpApp/Models/SpriteResolver.swift` - Semantic sprite resolution (Lines 348-355)
- `MacAmpApp/Views/Shared/WinampTitlebarDragHandle.swift` - Title bar drag handling
- `MacAmpApp/Views/Components/SimpleSpriteImage.swift` - Sprite rendering (Lines 98-107 WinampSizes)
- `MacAmpApp/MacAmp.entitlements` - App entitlements (Lines 22, 32)

### Webamp Reference
- `webamp_clone/packages/webamp/js/components/MainWindow/index.tsx` (Lines 129-134) - About link
- `webamp_clone/packages/webamp/css/main-window.css` (Lines 394-400) - Logo overlay CSS
- `webamp_clone/packages/webamp/js/skinSprites.ts` (Lines 136-138) - Sprite definitions

### Prior Task Files
- `tasks/airplay/research.md` - Original Gemini + Oracle research
- `tasks/airplay/ORACLE_REVIEW.md` - Oracle corrections
- `tasks/winamp-airplay-overlay/research.md` - Overlay pattern research
- `tasks/winamp-airplay-overlay/plan.md` - Overlay plan

### Apple Frameworks
- AVKit: AVRoutePickerView
- AVFoundation: AVAudioEngine, AVRouteDetector, AVSampleBufferAudioRenderer
- MediaPlayer: MPNowPlayingInfoCenter, MPRemoteCommandCenter

---

## 8. Phase 1 Implementation Failure (2026-03-24)

### What We Attempted

Implemented transparent `AVRoutePickerView` overlays at two positions (top-left bolt icon, bottom-right WA logo) in the main window. The picker was correctly rendered and clickable. Added engine configuration change observer to `AudioEngineController` with will/did callbacks for `AudioPlayer` seek guard coordination.

### What Failed

**AVRoutePickerView does not route AVAudioEngine audio on macOS.** Testing revealed:

| Test | Result | Why |
|---|---|---|
| AVRoutePickerView alone (no player) | UI appears, no routing | Picker requires `.player` property — without it, it's a dummy button |
| AVRoutePickerView + empty AVPlayer | AirPlay device connects, system default unchanged | Establishes per-app route for that AVPlayer only — AVAudioEngine untouched |
| AVRoutePickerView + silent AVPlayer | FigFilePlayer errors | AVPlayer optimizes out silent/empty tracks |
| AirPlay devices in Core Audio HAL | Not visible | AirPlay devices hidden from HAL until system-wide route is established |
| Engine config notification | Never fires | System default never changed, so AVAudioEngine sees no hardware change |

### Root Cause: iOS vs macOS Audio Architecture

- **iOS:** `AVAudioSession` is global per app. Route changes affect everything including `AVAudioEngine`.
- **macOS:** No global `AVAudioSession`. `AVPlayer` routing is isolated per-instance. `AVAudioEngine` routing is tied to Core Audio HAL (hardware devices). They are completely separate worlds.

Apple explicitly designed `AVRoutePickerView` on macOS to bind to an `AVPlayer` instance and route only that player's audio over AirPlay 2. It is NOT a generic "change system output" button.

### Industry Validation

| Player | AirPlay Support | How |
|---|---|---|
| **Apple Music** | Full per-app AirPlay 2 + multi-room | Private frameworks (MediaExperience.framework) — not available to third parties |
| **Spotify macOS** | No native per-app AirPlay 2 | Uses Spotify Connect for device targeting; AirPlay only via system Control Center |
| **VLC / IINA** | No per-app AirPlay 2 | Core Audio HAL output only — falls back to AirPlay 1 if device visible, no multi-room |
| **Safari / WebKit** | Per-app AirPlay via SPI | Uses `AVOutputContext` + `showRoutePickingControlsForOutputContext` (private API, not App Store safe) |
| **Rogue Amoeba Airfoil** | Full AirPlay 2 capture | Installs custom HAL audio driver — out of scope for standard app |

### Paths Evaluated

#### Path A: System-Wide AirPlay (Current Recommendation)
- Users switch output via macOS Control Center
- AVAudioEngine fires `configurationChangeNotification` when system default changes
- Engine restarts with new output format
- **Preserves:** 10-band EQ, visualizer, custom stream pipeline, ICY metadata
- **Trade-off:** Not per-app — all system audio goes to AirPlay

#### Path B: AVPlayer Rewrite (Rejected — Too Costly)
- Replace AVAudioEngine with AVPlayer for all playback
- Bind AVRoutePickerView to the player for native per-app routing
- **Loses:** 10-band AVAudioUnitEQ, custom StreamDecodePipeline, ICY metadata parsing, robust reconnection
- **Adds:** Need local HLS proxy for infinite radio (4-10s latency), rewrite visualizer with MTAudioProcessingTap
- **Risk:** MTAudioProcessingTap stops producing data under AirPlay 2 on macOS 15+ (silent failures, AirPlayXPCHelper crashes)

#### Path C: AVSampleBufferAudioRenderer (Future Architecture — Large Effort)
- Apple's official "custom player" path for apps that own sourcing/parsing
- `AVSampleBufferAudioRenderer` + `AVSampleBufferRenderSynchronizer`
- Feed decoded PCM as CMSampleBuffers with strictly incrementing PTS
- `audioOutputDeviceUniqueID` property enables per-app routing
- EQ: reimplement with vDSP.Biquad cascades (Accelerate framework) — sub-0.5ms on Apple Silicon
- Visualizer: PCM available pre-enqueue, no MTAudioProcessingTap needed
- **AirPlay picker:** Use "dummy AVPlayer" KVO harvesting technique — bind AVRoutePickerView to empty AVPlayer, observe `audioOutputDeviceUniqueID` via KVO, propagate to renderer
- **Trade-off:** Massive architectural rewrite. Entire AVAudioEngine graph replaced. New CMSampleBuffer packaging pipeline. New vDSP-based EQ.
- **Advantage:** Only architecture that satisfies ALL constraints (per-app AirPlay 2, EQ, visualizer, infinite streams)

#### Path D: Core Audio HAL Device Selection (Partial — AirPlay 1 Only)
- `kAudioOutputUnitProperty_CurrentDevice` on `audioEngine.outputNode.audioUnit`
- Routes only engine audio, not system-wide
- **Limitation:** AirPlay 1 only (no enhanced buffering, no multi-room). Fragile on disconnect. Custom UI needed (devices hidden from HAL until connected). No AirPlay 2 features.

#### Path E: Custom Virtual Audio Driver (Out of Scope)
- Install `.driver` plugin to capture app audio and transmit over AirPlay protocol
- How Rogue Amoeba Airfoil works
- Requires system-level installation, breaks sandbox

### WebKit Source Code Evidence

Apple's own WebKit uses SPI (private API) for AirPlay routing:
```objc
// From WebKit: MediaPlayerPrivateAVFoundationObjC.mm
m_avPlayer.get().audioOutputDeviceUniqueID = audioOutputDeviceId.createNSString().get();
```

WebKit's `AVKitSPI.h` declares a category on `AVRoutePickerView`:
- `showRoutePickingControlsForOutputContext:relativeToRect:ofView:` — targets a specific `AVOutputContext`
- `AVOutputContext` exists in runtime headers but is NOT a public API

This confirms: per-app AirPlay routing on macOS is mediated by output contexts, not Core Audio HAL. The mechanism exists but is private/SPI.

### macOS 26 (Tahoe) Assessment

No new public APIs in macOS 26 that bridge `AVRoutePickerView` to non-AVPlayer audio. The gap between Apple's internal SPI and the public API surface remains.

### Decision

**Accept system-wide AirPlay routing (Path A)** for the current architecture. EQ, visualizer, and custom streaming pipeline are non-negotiable for a Winamp clone.

**Document Path C (AVSampleBufferAudioRenderer)** as future architecture for per-app AirPlay 2 if the requirement becomes critical. This would be a separate sprint-level effort.

### Lessons Learned

1. **Test framework assumptions early.** The AVRoutePickerView approach was planned for 5+ months before testing. First real-device test revealed the fundamental incompatibility in minutes.
2. **macOS ≠ iOS for audio routing.** iOS `AVAudioSession` provides global per-app routing. macOS has no equivalent — `AVPlayer` and `AVAudioEngine` are in completely separate routing worlds.
3. **Industry leaders can't solve this either.** Spotify, VLC, and IINA all lack per-app AirPlay 2 on macOS. Only Apple Music has it (via private frameworks). This isn't a gap in our research — it's a platform limitation.
4. **The only public path to per-app AirPlay 2 is AVSampleBufferAudioRenderer.** This preserves PCM access for visualization and allows custom EQ, but requires a complete audio architecture rewrite.
5. **Oracle and Gemini both missed the fundamental issue.** Multiple rounds of AI review (Oracle 7/10 → 8/10, Gemini validation) did not catch the AVRoutePickerView + AVAudioEngine incompatibility. Only hands-on testing revealed it. Always prototype critical assumptions.

---

## 9. References: Phase 1 Research Sources

### Gemini Research Files (saved in task folder)
- `research-gemini-avroutepicker-failure.md` — Why AVRoutePickerView fails with AVAudioEngine
- `research-gemini-airplay-hal.md` — AirPlay devices hidden from Core Audio HAL
- `research-avplayer-rewrite.md` — AVPlayer rewrite evaluation (rejected)
- `research-per-app-routing.md` — Per-app routing options (7 approaches evaluated)

### Oracle Deep Research
- `deep-research-report.md` (external) — Comprehensive analysis of per-app AirPlay on macOS, MTAudioProcessingTap regressions, AVSampleBufferAudioRenderer architecture, WebKit SPI analysis, Spotify/VLC/IINA comparison

### Gemini Deep Research
- `Per-App AirPlay for Mac Media Player.md` (external) — AVSampleBufferAudioRenderer definitive architecture, vDSP biquad EQ implementation, CMSampleBuffer packaging, dummy AVPlayer KVO harvesting technique, industry analysis (55 citations)
