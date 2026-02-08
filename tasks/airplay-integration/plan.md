# Plan: AirPlay Integration for MacAmp

> **Purpose:** Implementation plan for adding AirPlay functionality to MacAmp. Covers all phases from MVP to polished UX. Derived from Oracle-corrected research.

**Date:** 2026-02-07
**Status:** Draft - Awaiting Oracle Review & User Approval
**Estimated Effort:** 4-6 hours total (all phases)

---

## Approach

Use AVRoutePickerView (system UI) positioned as a transparent overlay on the Winamp logo in the main window body. This combines the webamp "about" link pattern with macOS AirPlay functionality. The Winamp logo serves as the AirPlay trigger button - clicking it opens the system device picker.

**Why This Approach:**
- Only viable option (custom device menus not possible with public APIs)
- Maintains Winamp aesthetic (no visible system icon)
- Matches established webamp pattern
- Simple implementation, minimal code changes
- Works across all skins (logo area is consistent)

---

## Phase 1: Core AirPlay + Engine Restart (2 hours) - REQUIRED

### 1.1 Create AirPlayRoutePicker Component

**File:** `MacAmpApp/Views/Components/AirPlayRoutePicker.swift` (new)

Create an NSViewRepresentable wrapper for a transparent AVRoutePickerView:
- Import AVKit (NOT AVFoundation)
- Set alphaValue = 0.01 (invisible but hit-testable)
- Clear background
- No customization (properties don't exist on macOS)
- Add accessibility label

### 1.2 Position Over Winamp Logo

**File:** `MacAmpApp/Views/WinampMainWindow.swift` (modify)

Add the transparent picker overlay at the Winamp logo coordinates:
- Webamp reference: (253, 91) with size 13x15
- MacAmp: Use same coordinates (body area, not title bar)
- Expand to 24x24 frame minimum for accessibility
- Use `.at()` modifier for positioning
- Add to the main ZStack alongside other overlays
- Ensure it doesn't interfere with nearby controls

**Coordinate Verification Needed:**
- Verify (253, 91) maps correctly to MacAmp's logo position
- The logo is in the body area near EQ/PL buttons and stereo indicator
- May need fine-tuning after visual inspection

### 1.3 Add Engine Configuration Observer (CRITICAL)

**File:** `MacAmpApp/Audio/AudioPlayer.swift` (modify)

Add notification observer for `.AVAudioEngineConfigurationChange`:
- Setup observer in init or setup method
- When triggered: save playback state, stop engine, restart engine, resume playback
- Handle both playing and stopped states
- Use weak self to prevent retain cycles

**This is the most important part.** Without it, audio goes silent on AirPlay switch.

### 1.4 Build & Test

- Build with Thread Sanitizer
- Verify picker overlay is positioned correctly
- Click logo area to confirm AirPlay picker appears
- Test with real AirPlay device
- Verify EQ processing maintained
- Verify engine restarts on route change
- Test device switching back to built-in speakers

---

## Phase 2: Now Playing Integration (2 hours) - OPTIONAL

### 2.1 MPNowPlayingInfoCenter

**File:** `MacAmpApp/Audio/AudioPlayer.swift` (modify)

- Import MediaPlayer framework
- Create updateNowPlayingInfo() method
- Set track title, artist, album, duration, elapsed time, playback rate
- Optional: album artwork
- Call on track changes, play/pause, time updates

### 2.2 MPRemoteCommandCenter

**File:** `MacAmpApp/Audio/AudioPlayer.swift` (modify)

- Setup handlers for play, pause, toggle, next, previous, seek
- Call setupRemoteCommands() in init
- Verify keyboard media keys respond

### 2.3 Test System Integration

- Control Center shows "Now Playing" info
- Keyboard media keys work
- Progress bar updates
- Track info correct

---

## Phase 3: Discoverability & UX Polish (1-2 hours) - OPTIONAL

**Priority:** The invisible overlay on the Winamp logo IS the primary approach. It preserves skin fidelity across all skins and matches the webamp pattern. A visible system AirPlay icon has no natural home in a skin-driven UI where every pixel is bitmap-defined. The strategies below address discoverability without compromising the invisible overlay.

### 3.1 Why Invisible Overlay Is Correct

A visible `AVRoutePickerView` icon cannot work well with skins because:
- The classic Winamp main window (275x116) has every pixel defined by skin bitmaps
- No Winamp skin format sprite exists for "AirPlay" (it didn't exist in the Winamp era)
- A native macOS glyph looks alien against any skin's bitmap aesthetic
- All layout regions (title bar, clutter bar, transport, volume) are tightly packed and skin-specific

The invisible overlay solves this: zero visual impact, 100% skin fidelity, established webamp precedent.

### 3.2 Discoverability Strategies (layered, non-exclusive)

**a) Right-click context menu entry**
- Add "AirPlay: click Winamp logo" or "AirPlay Devices..." to the main window right-click context menu
- Low effort, fits existing menu system, teaches the user where the hotspot is
- Context menus are already skin-agnostic (system NSMenu)

**b) Tooltip on hover**
- Show a native tooltip ("AirPlay") when the cursor hovers over the logo area
- Subtle, non-intrusive, standard macOS behavior
- `NSView.toolTip` or SwiftUI `.help()` modifier

**c) First-launch hint (one-time)**
- On first app launch (or first time AirPlay devices are detected), show a brief overlay or notification: "Click the Winamp logo to select AirPlay devices"
- Dismisses permanently after first interaction
- Store shown state in UserDefaults

**d) macOS menu bar entry**
- Add "AirPlay Devices..." to the Controls or Windows menu in the macOS menu bar
- Provides alternative access for keyboard/menu users
- Note: Can't programmatically open AVRoutePickerView from a menu action, so this would need to describe the logo click or use a different mechanism

**e) Keyboard shortcut**
- Cmd+Shift+A as alternative access
- Same limitation as menu bar: can't programmatically trigger AVRoutePickerView
- Could show a brief tooltip/highlight on the logo area to guide the user

### 3.3 Shade Mode Handling

When main window is in shade mode (275x14, title bar only):
- The logo at (253, 91) is not visible (body is hidden)
- Disable AirPlay overlay in shade mode
- Users can access AirPlay via right-click context menu or by exiting shade mode

### 3.4 Double-Size Mode

When double-size mode is active:
- Coordinates may need to scale 2x
- Verify picker overlay position still aligns with logo
- Test click area in both modes

---

## Files to Create

| File | Phase | Lines | Purpose |
|---|---|---|---|
| `MacAmpApp/Views/Components/AirPlayRoutePicker.swift` | 1 | ~15 | Transparent AVRoutePickerView wrapper |

## Files to Modify

| File | Phase | Changes | Purpose |
|---|---|---|---|
| `MacAmpApp/Views/WinampMainWindow.swift` | 1 | ~10 lines | Add overlay at logo coordinates |
| `MacAmpApp/Audio/AudioPlayer.swift` | 1 | ~30 lines | Engine config change observer |
| `MacAmpApp/Audio/AudioPlayer.swift` | 2 | ~50 lines | Now Playing + remote commands |

## Files NOT Modified

- `MacAmp.entitlements` - Already has required entitlements
- `Info.plist` - No changes needed (NSLocalNetworkUsageDescription not required for AVRoutePickerView)

---

## Risk Assessment

| Risk | Level | Mitigation |
|---|---|---|
| Engine restart fails | CRITICAL | Implement robust observer with playback state save/restore |
| Logo coordinates wrong | LOW | Visual testing, adjust coordinates |
| Drag handle intercepts clicks | LOW | Logo at (253,91) is in body, not title bar (0-14) |
| Shade mode hides logo | MEDIUM | Disable overlay in shade mode, offer alternative access |
| Skin-specific logo position | LOW | Classic Winamp logo position is standardized across skins |
| AirPlay picker popover clips | LOW | Position ensures enough space for system popover |

---

## Success Criteria

### Phase 1 (MVP)
- [ ] Clicking Winamp logo area opens AirPlay device picker
- [ ] Audio routes to selected AirPlay device
- [ ] EQ processing maintained on AirPlay
- [ ] Engine restarts seamlessly on route change
- [ ] No crashes or audio glitches
- [ ] Overlay invisible (logo appears unmodified)

### Phase 2 (System Integration)
- [ ] Control Center shows track info
- [ ] Keyboard media keys work
- [ ] Progress bar updates

### Phase 3 (Discoverability & Polish)
- [ ] Right-click context menu includes AirPlay hint
- [ ] Tooltip on logo hover shows "AirPlay"
- [ ] Shade mode handled (overlay disabled, context menu still works)
- [ ] Double-size mode handled
- [ ] Optional: first-launch hint (one-time)

---

## Dependencies

- AVKit framework (available macOS 10.15+)
- MediaPlayer framework for Phase 2 (verify macOS availability)
- Real AirPlay device for testing
- Same Wi-Fi network for testing

---

## Alternatives Considered & Rejected

1. **Standard visible AirPlay button** - Rejected. No natural home in a skin-driven UI. Every pixel of the 275x116 main window is defined by skin bitmaps. A native macOS glyph looks alien against any skin. No Winamp skin format sprite exists for "AirPlay." All layout regions (title bar 14px, clutter bar, transport, volume) are tightly packed and skin-specific.
2. **Custom device menu** - NOT POSSIBLE (APIs don't exist per Oracle review). `outputNode.setDeviceID()` doesn't exist, `AVAudioDevice` doesn't enumerate AirPlay endpoints.
3. **Menu bar integration** - Could supplement logo overlay for discoverability (Phase 3) but can't programmatically trigger AVRoutePickerView, so can't replace the overlay.
4. **Clutter bar button** - Viable fallback if logo overlay doesn't work out, but still has the skin-mismatch problem (no sprite for it).
