# TODO: Video & Milkdrop Windows (Two-Window Architecture)

**Status**: Days 1-8 Complete + 2x Chrome Scaling ✅
**Timeline**: 10 days
**Last Updated**: 2025-11-14

**CURRENT**: VIDEO Window 100% Complete (with 2x chrome scaling)
**NEXT**: Milkdrop Window (Days 9-10) or Ready for Merge

---

## VIDEO WINDOW COMPLETION (Before Moving to Milkdrop)

### Remaining Items for Video Window:

#### 1. Video Metadata Display in Bottom Bar ✅ COMPLETE
- [x] Research what video metadata to display (filename, type, resolution)
- [x] Extract metadata from AVPlayer (AVURLAsset.load(.tracks))
- [x] Use TEXT.bmp sprites to render metadata (like main window track display)
- [x] Position metadata text in bottom bar black area (x:170, y:213)
- [x] Make text scroll if too long (115px display width, scrolls at 5px/0.15s)
- [x] Format: "filename (M4V): Video: 1280x720"
- [x] Fixed MainActor concurrency warning in timer
- [x] Tested and working!

#### 2. Window Position Persistence ✅ COMPLETE
- [x] Added video to persistAllWindowFrames()
- [x] Added video to applyPersistedWindowPositions()
- [x] WindowFrameStore.frame(for: .video) saves/loads
- [x] Video window position persists across app restarts
- [x] Same pattern as Main/EQ/Playlist
- [x] Tested and working!

#### 3. Docking with Double-Size Mode (Ctrl+D) ✅ COMPLETE
- [x] Reviewed `tasks/magnetic-docking-foundation/` for playlist docking pattern
- [x] Added VideoAttachmentSnapshot structure
- [x] Added makeVideoDockingContext() function
- [x] Added moveVideoWindow() function
- [x] Integrated into resizeMainAndEQWindows()
- [x] Video can dock to Main, EQ, or Playlist
- [x] Video stays docked when Ctrl+D pressed
- [x] Cluster-aware positioning working
- [x] Build succeeded - ready for testing!

#### 4. VIDEO Window 2x Chrome Scaling ✅ COMPLETE (2025-11-14)
- [x] Implement independent 2x chrome scaling (videoWindowSizeMode)
- [x] Add Ctrl+1 keyboard shortcut (normal size)
- [x] Add Ctrl+2 keyboard shortcut (double size)
- [x] Use scaleEffect pattern matching Main/EQ windows
- [x] Add WinampSizes.video constant
- [x] Fix chrome rendering delay (Group wrapper)
- [x] Fix startup sequence bug (Oracle guidance)
- [x] Implement clickable 1x button overlay (31.5, 212)
- [x] Implement clickable 2x button overlay (46.5, 212)
- [x] Fix Environment access error (struct-level @Environment)
- [x] Remove stuck blue focus ring (.focusable(false))
- [x] User tested and verified working!

#### 5. Document Baked-On Buttons (Partially Complete)
- [x] 1x and 2x buttons now clickable and functional
- [ ] Fullscreen button (deferred to future)
- [ ] TV/Misc button (deferred to future)
- [ ] Dropdown button (deferred to future)

#### 6. FUTURE: Video Volume Control (Post-MVP) - 1-2 Hours
- [ ] Update AudioPlayer.volume didSet to sync with videoPlayer.volume
- [ ] Update loadVideoFile() to apply initial volume
- [ ] Update mute functionality to set videoPlayer.isMuted
- [ ] Test volume slider controls video audio level
- [ ] Test mute button mutes video audio
- [ ] Test volume changes apply immediately during playback
- [ ] Test volume persists when switching audio↔video
- [ ] Test volume restored on app relaunch

#### 7. FUTURE: Video Time Display (Post-MVP)
- [ ] Show video elapsed/remaining time in main window timer display
- [ ] Show video time in playlist window (like audio tracks)
- [ ] Sync video playback time with main window display
- [ ] Update as video plays

#### 8. FUTURE: VIDEO Window Full Resize (Post-MVP) - 8 Hours

**Phase 1: Size2D Integration (2 hours)** ✅ COMPLETE
- [x] Create VideoWindowSizeState.swift observable wrapping Size2D
- [x] Define Size2D.videoMinimum = [0,0] → 275×116px (matches Main/EQ)
- [x] Define Size2D.videoDefault = [0,4] → 275×232px (current VIDEO size)
- [x] Define Size2D.video2x = [11,12] → 550×464px (2x default)
- [x] Implement toPixels() formula: width = 275 + w*25, height = 116 + h*29
- [x] Add UserDefaults persistence for Size2D
- [x] Test size conversions verified

**Phase 2: Chrome Dynamic Sizing (2 hours)** ✅ COMPLETE
- [x] Replace VideoWindowLayout constants with Size2D calculations
- [x] Implement three-section bottom bar (LEFT 125px + CENTER tiles + RIGHT 125px)
- [x] Calculate centerWidth = pixelSize.width - 250
- [x] Add ForEach to tile VIDEO_BOTTOM_TILE (25px) in center section
- [x] Update titlebar to tile VIDEO_TITLEBAR_STRETCHY based on width
- [x] Calculate stretchyTilesPerSide with ceil() for full coverage (3 per side at 275px)
- [x] Update vertical border tiling based on height segments
- [x] Test chrome - titlebar gap fixed with proper tile calculation

**Phase 3: Resize Handle (1 hour)** ✅ COMPLETE
- [x] Add buildVideoResizeHandle() in VideoWindowChromeView
- [x] Create 20×20px invisible drag area in bottom-right corner
- [x] Position at (pixelSize.width - 10, pixelSize.height - 10)
- [x] Implement quantized DragGesture (25×29 segments)
- [x] Preview pattern - commit size only at drag end
- [x] AppKit overlay window for preview visibility
- [x] Test drag resizing works with visible preview

**Phase 4: Button Migration (1 hour)** ✅ COMPLETE
- [x] Update 1x button action: videoSize = .videoDefault ([0,4])
- [x] Update 2x button action: videoSize = .video2x ([11,12])
- [x] Remove VideoWindowSizeMode enum from AppSettings
- [x] Remove scaleEffect logic from WinampVideoWindow
- [x] Remove Ctrl+1/Ctrl+2 keyboard shortcuts
- [x] Test buttons set Size2D correctly - working perfectly

**Phase 5: Integration & Testing (2 hours)** ✅ COMPLETE
- [x] Remove WinampVideoWindow.scaleEffect code
- [x] Remove old WindowCoordinator.resizeVideoWindow() method
- [x] Fix WindowSnapManager to exclude invisible windows (phantom fix)
- [x] Fix titlebar gap with correct tile calculation
- [x] Implement AppKit preview overlay (shows in both directions)
- [x] Test chrome aligns at multiple sizes
- [x] Verify 1x/2x buttons work perfectly
- [x] Resolve resize jitter with preview pattern + AppKit overlay
- [ ] Test size persists across app restarts (deferred)
- [ ] Test docking with resized windows (deferred)

#### 5. Active/Inactive Titlebar (Infrastructure Complete)
- [x] VIDEO titlebar has ACTIVE/INACTIVE sprite infrastructure ✅
- [x] SkinSprites.swift defines both states ✅
- [x] VideoWindowChromeView switches sprites based on isWindowActive ✅
- [ ] FUTURE: Wire `isWindowActive` to NSWindow.didBecomeKeyNotification
- [ ] FUTURE: Apply pattern to Main/EQ windows

---

## Days 1-6: Foundation (Shared Infrastructure) ✅ COMPLETE

### Day 1: AppSettings & Commands

#### 1.1 AppSettings Extension
- [ ] Add `showVideoWindow: Bool` with `didSet` persistence
- [ ] Add `videoWindowFrame: CGRect?` with `didSet` persistence
- [ ] Add `videoWindowShaded: Bool` with `didSet` persistence
- [ ] Add `showMilkdropWindow: Bool` with `didSet` persistence
- [ ] Add `milkdropWindowFrame: CGRect?` with `didSet` persistence
- [ ] Add `milkdropMode: MilkdropMode` enum with persistence
- [ ] Add `lastUsedPresetIndex: Int` with persistence
- [ ] Create `MilkdropMode` enum (butterchurn, fullscreen, desktop)
- [ ] Add init/load logic for all new properties

#### 1.2 AppCommands Extension
- [ ] Add "Toggle Video Window" command to CommandGroup
- [ ] Implement Ctrl+V keyboard shortcut for video
- [ ] Add "Toggle Milkdrop Window" command
- [ ] Implement Ctrl+Shift+M keyboard shortcut for milkdrop
- [ ] Wire shortcuts to AppSettings toggles
- [ ] Test shortcuts in app menu

#### 1.3 WinampMainWindow Integration
- [ ] Add conditional view for `showVideoWindow`
- [ ] Add conditional view for `showMilkdropWindow`
- [ ] Inject `@Environment(appSettings)` to both views
- [ ] Inject `@Environment(skinManager)` to both views
- [ ] Inject `@Environment(audioPlayer)` to both views
- [ ] Position windows in layout
- [ ] Test independent toggle of both windows

**Day 1 Complete**: ✅ All above checkboxes checked

### Day 2: Window Stubs & Testing

#### 2.1 Create Window Directory Structure
- [ ] Create `MacAmpApp/Views/Windows/` directory
- [ ] Create `VideoWindowView.swift` stub
- [ ] Create `MilkdropWindowView.swift` stub
- [ ] Add files to Xcode project

#### 2.2 VideoWindowView Stub
- [ ] Create struct VideoWindowView: View
- [ ] Add `@Environment(AppSettings.self)` injection
- [ ] Add `@Environment(SkinManager.self)` injection
- [ ] Add `@Environment(AudioPlayer.self)` injection
- [ ] Create placeholder body (black background, "Video" text)
- [ ] Set default frame size (275x116)
- [ ] Test window appears/disappears

#### 2.3 MilkdropWindowView Stub
- [ ] Create struct MilkdropWindowView: View
- [ ] Add `@Environment` injections (same as video)
- [ ] Create placeholder body (black background, "Milkdrop" text)
- [ ] Set default frame size (400x300)
- [ ] Test window appears/disappears

#### 2.4 Integration Testing
- [ ] Build and run app
- [ ] Test Ctrl+V toggles video window
- [ ] Test Ctrl+Shift+M toggles milkdrop window
- [ ] Test both windows can be open simultaneously
- [ ] Test state persists across app restart
- [ ] Verify no build warnings/errors
- [ ] Verify no console errors

**Day 2 Complete**: ✅ All above checkboxes checked

---

## Day 3: VIDEO.bmp Sprite Parsing ⏳

### 3.1 SkinManager Data Structures

#### VideoWindowSprites Struct
- [ ] Create `VideoWindowSprites` struct in SkinManager
- [ ] Add titlebar sprite properties (active, inactive)
- [ ] Add border sprite properties (top, left, right, bottom)
- [ ] Add corner sprite properties (TL, TR, BL, BR)
- [ ] Add button sprite arrays (normal, hover, pressed)
- [ ] Add playback control sprites (play, pause, stop, prev, next)
- [ ] Add seek bar sprites (track, thumb)
- [ ] Make all properties optional (for fallback)

#### SkinManager Extension
- [ ] Create `loadVideoWindowSprites(from:)` method
- [ ] Add VIDEO.bmp loading logic
- [ ] Verify image dimensions (typical: 233x119)
- [ ] Handle missing VIDEO.bmp gracefully

### 3.2 Sprite Region Extraction

#### Titlebar Sprites
- [ ] Extract titlebar active (y=0-13, full width)
- [ ] Extract titlebar inactive (y=14-27, full width)
- [ ] Test with Internet-Archive skin

#### Border Sprites
- [ ] Extract top border segment
- [ ] Extract left border segment
- [ ] Extract right border segment
- [ ] Extract bottom border segment
- [ ] Extract 4 corner pieces

#### Button Sprites
- [ ] Extract close button (3 states: normal, hover, pressed)
- [ ] Extract minimize button (3 states)
- [ ] Extract shade button (3 states)
- [ ] Map sprite positions (typically row 4-6)

#### Playback Control Sprites
- [ ] Extract play button
- [ ] Extract pause button
- [ ] Extract stop button
- [ ] Extract previous button
- [ ] Extract next button
- [ ] Map sprite positions (typically row 7)

#### Seek Bar Sprites
- [ ] Extract seek track background
- [ ] Extract seek thumb/slider
- [ ] Map sprite positions (typically row 8)

### 3.3 Fallback Chrome

#### Default Chrome Assets
- [ ] Create `MacAmpApp/Resources/DefaultVideoChrome/` directory
- [ ] Design default classic-style chrome (gray, neutral)
- [ ] Create fallback titlebar sprite
- [ ] Create fallback button sprites
- [ ] Create fallback seek bar sprites
- [ ] Add to Xcode project

#### Fallback Logic
- [ ] Implement fallback when VIDEO.bmp missing
- [ ] Test with skin that lacks VIDEO.bmp
- [ ] Ensure video window always renders

### 3.4 Testing & Verification
- [ ] Build and run app
- [ ] Load Internet-Archive skin
- [ ] Verify VIDEO.bmp sprites load correctly
- [ ] Inspect sprite dimensions match expectations
- [ ] Test with default skin (no VIDEO.bmp)
- [ ] Verify fallback chrome loads
- [ ] Check for sprite loading errors in console

**Day 3 Complete**: ✅ All above checkboxes checked

---

## Day 4: Video Window Chrome & Layout ⏳

### 4.1 VideoWindowChromeView

#### Main Chrome Container
- [ ] Create `VideoWindowChromeView.swift`
- [ ] Add sprites parameter
- [ ] Create VStack layout (titlebar, content, controls)
- [ ] Add window border overlay
- [ ] Test basic layout renders

#### Content Slot
- [ ] Add content parameter (ViewBuilder)
- [ ] Position content area between titlebar and controls
- [ ] Add black background for video area
- [ ] Test content slot accepts child views

### 4.2 Titlebar Component

#### VideoWindowTitlebar.swift
- [ ] Create `VideoWindowTitlebar.swift`
- [ ] Add sprites parameter
- [ ] Create HStack layout (title text, spacer, buttons)
- [ ] Add titlebar background image
- [ ] Set height to 14 pixels

#### Title Text
- [ ] Add "Video Window" text label
- [ ] Set font to system size 8
- [ ] Set foreground color to white
- [ ] Position left-aligned

#### Window Buttons
- [ ] Create minimize button
- [ ] Create shade button
- [ ] Create close button
- [ ] Wire button actions to AppSettings
- [ ] Add hover states (if sprites support)
- [ ] Test button clicks

#### Drag Gesture
- [ ] Add DragGesture to titlebar
- [ ] Implement window drag logic
- [ ] Save position to AppSettings
- [ ] Test window dragging works

### 4.3 Control Bar Component

#### VideoWindowControlBar.swift
- [ ] Create `VideoWindowControlBar.swift`
- [ ] Add sprites parameter
- [ ] Add `@Environment(AudioPlayer.self)`
- [ ] Create HStack layout for buttons
- [ ] Set height to ~40 pixels

#### Playback Buttons
- [ ] Create play button
- [ ] Create pause button (toggle with play)
- [ ] Create stop button
- [ ] Create previous track button
- [ ] Create next track button
- [ ] Wire to AudioPlayer actions
- [ ] Test buttons trigger playback

#### Seek Bar
- [ ] Create `VideoSeekBar.swift`
- [ ] Add seek track background
- [ ] Add draggable thumb
- [ ] Wire to video playback position
- [ ] Update thumb position during playback
- [ ] Handle thumb drag events
- [ ] Test seeking works

### 4.4 Border Components

#### VideoWindowBorders.swift
- [ ] Create `VideoWindowBorders.swift`
- [ ] Add sprites parameter
- [ ] Create border overlay (top, left, right, bottom)
- [ ] Add corner images (TL, TR, BL, BR)
- [ ] Position borders around content
- [ ] Test borders render correctly

### 4.5 Integration & Testing
- [ ] Integrate all components into VideoWindowChromeView
- [ ] Add to VideoWindowView
- [ ] Build and run app
- [ ] Open video window
- [ ] Verify chrome renders with VIDEO.bmp sprites
- [ ] Test titlebar drag
- [ ] Test buttons (minimize, shade, close)
- [ ] Verify layout matches Winamp Classic
- [ ] Test with multiple skins

**Day 4 Complete**: ✅ All above checkboxes checked

---

## Day 5: AVPlayerView Integration ⏳

### 5.1 AVPlayerViewRepresentable

#### Create Wrapper
- [ ] Create `AVPlayerViewRepresentable.swift`
- [ ] Import AVKit framework
- [ ] Implement NSViewRepresentable protocol
- [ ] Add player parameter (AVPlayer)

#### makeNSView Implementation
- [ ] Create AVPlayerView instance
- [ ] Set player property
- [ ] Set controlsStyle = .none (use our controls)
- [ ] Set videoGravity = .resizeAspect
- [ ] Disable fullScreenToggleButton
- [ ] Disable native controls
- [ ] Return configured view

#### updateNSView Implementation
- [ ] Update player if changed
- [ ] Test view updates correctly

### 5.2 AudioPlayer Video Support

#### Media Type Detection
- [ ] Add `MediaType` enum (audio, video)
- [ ] Add `currentMediaType` property
- [ ] Create `detectMediaType(url:)` method
- [ ] Define video extensions array: ["mp4", "mov", "m4v", "avi"]
- [ ] Test detection logic

#### Video Player Property
- [ ] Add `videoPlayer: AVPlayer?` property
- [ ] Ensure @MainActor isolation

#### loadMedia Method
- [ ] Modify `loadMedia(url:)` to detect type
- [ ] Route to `loadAudioFile()` or `loadVideoFile()`
- [ ] Test routing logic

#### loadVideoFile Method
- [ ] Create `loadVideoFile(url:)` method
- [ ] Stop existing audio playback
- [ ] Create AVPlayer with URL
- [ ] Start playback
- [ ] Update isPlaying state
- [ ] Set currentMediaType = .video
- [ ] Test video loads and plays

#### Playback Control Methods
- [ ] Ensure playPause() works with video
- [ ] Ensure stop() stops video
- [ ] Ensure next()/previous() work
- [ ] Add seek functionality for video

### 5.3 Complete VideoWindowView

#### Update VideoWindowView
- [ ] Add @Environment(AudioPlayer.self)
- [ ] Check if currentMediaType == .video
- [ ] Get videoPlayer from AudioPlayer
- [ ] Render AVPlayerViewRepresentable if video
- [ ] Show "No video loaded" placeholder otherwise

#### Content Area
- [ ] Embed AVPlayerView in chrome content slot
- [ ] Ensure video fills available space
- [ ] Maintain aspect ratio
- [ ] Add black letterboxing if needed

### 5.4 Testing & Verification
- [ ] Build and run app
- [ ] Load MP4 file via playlist
- [ ] Verify video window opens
- [ ] Verify AVPlayerView renders video
- [ ] Test playback controls (play, pause, stop)
- [ ] Test seek bar updates during playback
- [ ] Test dragging seek bar
- [ ] Load MOV file, verify playback
- [ ] Load M4V file, verify playback
- [ ] Test switching between audio and video files
- [ ] Verify video stops when audio file plays

**Day 5 Complete**: ✅ All above checkboxes checked

---

## Day 6: Video Window Polish & Integration ⏳

### 6.1 Playlist Integration

#### Video File Support
- [ ] Identify playlist file loading code
- [ ] Add video extensions to supported formats
- [ ] Update file type detection in playlist
- [ ] Add 🎬 emoji icon for video files
- [ ] Test video files appear in playlist

#### Metadata Display
- [ ] Extract video duration
- [ ] Extract video resolution (if available)
- [ ] Display in playlist row
- [ ] Format duration (HH:MM:SS)

#### Double-Click Handling
- [ ] Ensure double-click loads video file
- [ ] Verify VideoPlayer.loadMedia() called
- [ ] Verify video window opens automatically
- [ ] Test switching between playlist items

### 6.2 Window Positioning & Persistence

#### Position Restoration
- [ ] Implement onAppear handler
- [ ] Load saved frame from AppSettings
- [ ] Position window at saved location
- [ ] Use default position if no saved frame (x=0, y=232)

#### Position Saving
- [ ] Detect window frame changes
- [ ] Save new frame to AppSettings
- [ ] Debounce saves (avoid excessive writes)
- [ ] Test position persists across restarts

#### Bounds Checking
- [ ] Ensure window stays on screen
- [ ] Handle multi-monitor setups
- [ ] Clamp position to visible area
- [ ] Test with different screen configurations

### 6.3 Shade Mode

#### Shade Button Implementation
- [ ] Wire shade button to `videoWindowShaded` toggle
- [ ] Collapse window to titlebar when shaded
- [ ] Expand window when unshaded
- [ ] Animate transition (optional)

#### Shaded State Persistence
- [ ] Save shaded state to AppSettings
- [ ] Restore shaded state on app launch
- [ ] Test shaded state persists

#### Shaded Layout
- [ ] Show only titlebar when shaded
- [ ] Hide content and control bar
- [ ] Maintain window width, collapse height
- [ ] Test shade/unshade toggle

### 6.4 V Button Final Wiring

#### V Button Integration
- [ ] Locate V button in ClutterBar (or create)
- [ ] Wire click action to `showVideoWindow.toggle()`
- [ ] Add tooltip: "Video Window (Ctrl+V)"
- [ ] Test V button opens/closes video window
- [ ] Verify V button highlights when window open

#### Keyboard Shortcut
- [ ] Verify Ctrl+V shortcut works
- [ ] Test shortcut with window open/closed
- [ ] Test shortcut focus handling

### 6.5 Eject Button Support

#### File Picker Integration
- [ ] Update file picker to accept video extensions
- [ ] Test "Add File" accepts MP4/MOV
- [ ] Test Eject button opens picker with video support

### 6.6 Comprehensive Testing

#### Video Window Tests
- [ ] MP4 playback (H.264 codec)
- [ ] MOV playback (QuickTime)
- [ ] M4V playback (iTunes video)
- [ ] AVI playback (limited support)
- [ ] Video stops when switching tracks
- [ ] Video scales in double-size mode (if applicable)
- [ ] Window positioning works
- [ ] State persists across restarts
- [ ] Shade mode functional
- [ ] V button opens/closes window

#### Integration Tests
- [ ] Video files show in playlist with 🎬
- [ ] Double-click plays video
- [ ] Eject button accepts video files
- [ ] File drag-and-drop supports video (if implemented)
- [ ] Ctrl+V toggles window
- [ ] Window can be dragged
- [ ] Playback controls work

#### Visual Tests
- [ ] VIDEO.bmp sprites render correctly
- [ ] Titlebar looks correct
- [ ] Buttons look correct
- [ ] Seek bar looks correct
- [ ] Borders and corners align properly
- [ ] Fallback chrome works when no VIDEO.bmp

#### Bug Fixes
- [ ] Fix any bugs discovered
- [ ] Address visual glitches
- [ ] Polish animations (if any)

**Day 6 Complete**: ✅ VIDEO WINDOW FULLY FUNCTIONAL

---

## Day 7: Milkdrop Foundation ✅ COMPLETE

### 7.1 MilkdropWindowView Structure

#### Update Stub
- [x] Open `MilkdropWindowView.swift`
- [x] Add proper titlebar (GEN.bmp letters)
- [x] Create content area for visualization
- [x] Add basic window chrome (GEN.bmp sprites)

#### Titlebar
- [x] Add "MILKDROP" letter sprites (8 letters, two-piece)
- [x] Add active/inactive focus states
- [x] Add minimal controls (preset selector deferred)
- [x] Window draggable via WinampTitlebarDragHandle

#### Content Area
- [x] Black background placeholder (256×198)
- [x] Full-size content area
- [x] Ready for visualization (Butterchurn deferred)

### 7.2 Window Lifecycle

#### Open/Close
- [x] Wire to `showMilkdropWindow` toggle
- [x] Test window opens/closes independently
- [x] Verify Ctrl+Shift+K shortcut works (changed from M)

#### Positioning
- [x] WindowFrameStore persistence integrated
- [x] Default position handled by WindowCoordinator
- [x] Save position on frame change
- [x] Test position persists

### 7.3 Testing Independence

#### Simultaneous Windows Test
- [x] Open video window
- [x] Open milkdrop window
- [x] Verify both render correctly
- [x] Verify both can be dragged independently
- [x] Verify both can be closed independently
- [x] Test with video playing in video window
- [x] Confirm no interference between windows

**Day 7 Complete**: ✅ All above checkboxes checked

### 7.4 Sprite Research (Day 7 Extended)

#### GEN.BMP Letter Discovery
- [x] Discovered two-piece sprite structure (TOP + BOTTOM)
- [x] Verified 32 letter sprites (8 letters × 4 variants)
- [x] Extracted coordinates with ImageMagick
- [x] Added to SkinSprites.swift
- [x] Documented in research.md Part 15

#### Window Dimensions
- [x] Finalized: 275×232 pixels
- [x] Content cavity: 256×198
- [x] Chrome overhead documented

**Day 7 Extended**: ✅ Research complete, coordinates verified

---

## Day 8: Window Focus Architecture ✅ COMPLETE

### 8.1 WindowFocusState Infrastructure

#### Create WindowFocusState.swift
- [x] Create @Observable singleton class
- [x] Add activeWindow: WindowKind? property
- [x] Add setActive() method
- [x] Add setInactive() method
- [x] Test state tracking

#### Create WindowFocusDelegate.swift
- [x] Create NSWindowDelegate implementation
- [x] Handle windowDidBecomeKey notification
- [x] Handle windowDidResignKey notification
- [x] Update WindowFocusState singleton
- [x] Test delegate integration

### 8.2 WindowCoordinator Integration

#### Add Focus Delegates
- [x] Create WindowFocusDelegate instances (Video, Milkdrop)
- [x] Add to delegate multiplexers
- [x] Test focus events propagate
- [x] Verify no conflicts with WindowSnapManager

### 8.3 VIDEO Window Focus Sprites

#### Add Active/Inactive Sprite Infrastructure
- [x] Define VIDEO_TITLEBAR_ACTIVE sprites in SkinSprites.swift
- [x] Define VIDEO_TITLEBAR_INACTIVE sprites in SkinSprites.swift
- [x] Update VideoWindowChromeView to switch sprites
- [x] Add @Environment(WindowFocusState.self)
- [x] Test titlebar changes on focus

### 8.4 Milkdrop Window Focus Sprites

#### Add Active/Inactive Letter Rendering
- [x] Update MilkdropWindowChromeView with focus state
- [x] Switch between GEN_TEXT_SELECTED_* and GEN_TEXT_*
- [x] Test letter brightness changes on focus
- [x] Verify two-piece sprite rendering

### 8.5 VIDEO Window Enhancements

#### Keyboard Shortcuts
- [x] Add Ctrl+1 shortcut (normal 1x size)
- [x] Add Ctrl+2 shortcut (double 2x size)
- [x] Test shortcuts work
- [x] Verify state persists

### 8.6 Testing
- [x] Build and run app
- [x] Open VIDEO and Milkdrop windows
- [x] Click between windows, verify focus changes
- [x] Verify titlebars switch active/inactive sprites
- [x] Test keyboard shortcuts
- [x] Verify no console errors

**Day 8 Complete**: ✅ All above checkboxes checked

### 8.7 Butterchurn Integration DEFERRED

**Decision**: Defer Butterchurn visualization to future task

**Blockers**:
- [x] WKWebView evaluateJavaScript() failures documented
- [x] Script message handler issues documented
- [x] File access sandbox problems documented
- [x] Blockers documented in BUTTERCHURN_BLOCKERS.md

**Alternative**:
- [ ] Future: Native Metal visualization (V2.0 enhancement)

**Day 8 Butterchurn**: ⏳ DEFERRED (foundation complete, visualization future)

---

## Day 9: FFT Audio Bridge ⏳ DEFERRED (Butterchurn blockers)

### 9.1 AudioAnalyzer Implementation

#### Create AudioAnalyzer.swift
- [ ] Create `MacAmpApp/Models/AudioAnalyzer.swift`
- [ ] Add `@Observable @MainActor` annotations
- [ ] Import AVFoundation and Accelerate

#### Properties
- [ ] Add `engine: AVAudioEngine` reference
- [ ] Add `fftSetup: vDSP_DFT_Setup?`
- [ ] Add `fftData: [Float]` published property
- [ ] Set buffer size constant (1024)
- [ ] Set FFT size constant (512)

#### Initialization
- [ ] Create init with AVAudioEngine parameter
- [ ] Initialize FFT setup with vDSP_DFT_zop_CreateSetup
- [ ] Call installTap()

#### installTap Method
- [ ] Get mainMixerNode from engine
- [ ] Get output format
- [ ] Install tap with buffer size 1024
- [ ] Set closure to call processPCMBuffer

#### processPCMBuffer Method
- [ ] Extract float channel data
- [ ] Get frame length
- [ ] Create real/imaginary arrays (512 floats each)
- [ ] Copy PCM samples to real array
- [ ] Execute FFT with vDSP_DFT_Execute
- [ ] Compute magnitudes (sqrt(real² + imag²))
- [ ] Downsample to 64-128 bins
- [ ] Update fftData on @MainActor

#### Cleanup
- [ ] Implement deinit
- [ ] Remove tap from mixer node
- [ ] Destroy FFT setup

### 9.2 AudioPlayer Integration

#### Add AudioAnalyzer
- [ ] Add `audioAnalyzer: AudioAnalyzer?` property to AudioPlayer
- [ ] Initialize in AudioPlayer.init()
- [ ] Pass audioEngine to AudioAnalyzer

#### Expose FFT Data
- [ ] Add computed property `currentFFTData: [Float]`
- [ ] Return `audioAnalyzer?.fftData ?? []`

### 9.3 Wire to MilkdropWindowView

#### Add State
- [ ] Add `@State private var fftData: [Float] = []`
- [ ] Add `@Environment(AudioPlayer.self)`

#### Create Timer
- [ ] Create Timer publisher (every 0.016s = ~60fps)
- [ ] Use `.onReceive()` modifier
- [ ] Update local fftData from audioPlayer.currentFFTData
- [ ] Pass fftData to ButterchurnWebView binding

### 9.4 Testing & Verification

#### Audio Analysis Test
- [ ] Build and run app
- [ ] Play audio file (MP3)
- [ ] Open milkdrop window
- [ ] Verify FFT data is being generated
- [ ] Check console for FFT data updates
- [ ] Verify data has correct format (64-128 floats)

#### Visualization Test
- [ ] Verify Butterchurn visualization animates
- [ ] Verify sync to audio playback
- [ ] Test with different audio files
- [ ] Verify visualization pauses when audio paused
- [ ] Verify visualization resumes when audio resumed

#### Performance Test
- [ ] Profile CPU usage (should be <20%)
- [ ] Profile GPU usage (WebGL should be accelerated)
- [ ] Check for frame drops
- [ ] Test 10+ minute continuous playback
- [ ] Verify no memory leaks (Instruments)

**Day 9 Complete**: ✅ All above checkboxes checked

---

## Day 10: Milkdrop Polish & Final Testing ⏳ DEFERRED (Butterchurn blockers)

### 10.1 Preset Selection

#### Preset Menu
- [ ] Create `PresetSelectorMenu.swift`
- [ ] List all preset names (5-8)
- [ ] Add Menu with preset buttons
- [ ] Wire to appSettings.lastUsedPresetIndex
- [ ] Notify WebView via JavaScript bridge
- [ ] Test manual preset selection

#### Keyboard Shortcuts
- [ ] Add "Next Preset" command
- [ ] Implement Ctrl+] shortcut
- [ ] Add "Previous Preset" command
- [ ] Implement Ctrl+[ shortcut
- [ ] Implement preset cycling logic (wrap around)
- [ ] Send preset change to WebView
- [ ] Test shortcuts work

#### Auto-Cycle Verification
- [ ] Verify 30s auto-cycle timer works
- [ ] Test transitions between presets
- [ ] Verify smooth fade transitions (2.7s)

### 10.2 Skin Integration

#### Color Injection
- [ ] Get current skin colors from SkinManager
- [ ] Create Color.hex extension
- [ ] Build JavaScript object with skin colors
- [ ] Execute evaluateJavaScript to inject colors
- [ ] Update bridge.js to apply skin colors

#### Test with Skins
- [ ] Test with 3+ different skins
- [ ] Verify colors update when skin changes
- [ ] Test light and dark themes

### 10.3 Comprehensive Testing

#### Video Window Final Tests
- [ ] MP4 playback (H.264)
- [ ] MOV playback (QuickTime)
- [ ] M4V playback (iTunes)
- [ ] AVI playback (limited)
- [ ] VIDEO.bmp skinning works
- [ ] Playback controls functional
- [ ] Seek bar works
- [ ] Window positioning persists
- [ ] Shade mode works
- [ ] V button (Ctrl+V) toggles window

#### Milkdrop Window Final Tests
- [ ] FFT visualization syncs to audio
- [ ] All 5-8 presets work
- [ ] Auto-cycle every 30s
- [ ] Manual preset selection
- [ ] Keyboard shortcuts (Ctrl+[, Ctrl+])
- [ ] Skin colors applied
- [ ] Window positioning persists
- [ ] Ctrl+Shift+M toggles window

#### Integration Tests
- [ ] Both windows open simultaneously
- [ ] Video plays while milkdrop visualizes audio
- [ ] Windows move independently
- [ ] Windows close independently
- [ ] State persists across app restart
- [ ] No crashes or errors
- [ ] Playlist shows video files (🎬)
- [ ] Double-click loads video
- [ ] Eject button supports video

#### Performance Tests
- [ ] Profile CPU usage (both windows open)
- [ ] Profile GPU usage
- [ ] Profile memory usage
- [ ] Test 1+ hour continuous playback
- [ ] Verify no memory leaks (Instruments)
- [ ] Check frame rate (should be 60fps)

#### Visual Tests
- [ ] VIDEO.bmp chrome looks correct
- [ ] Milkdrop visualization looks good
- [ ] Both windows match Winamp Classic style
- [ ] Skins apply correctly
- [ ] No visual glitches

### 10.4 Bug Fixes & Polish
- [ ] Fix any bugs discovered during testing
- [ ] Address performance issues
- [ ] Polish animations
- [ ] Improve error handling
- [ ] Add logging for debugging

### 10.5 Documentation

#### Feature Documentation
- [ ] Create `docs/features/video-window.md`
- [ ] Document VIDEO.bmp sprite format
- [ ] Document video formats supported
- [ ] Document playback controls
- [ ] Create `docs/features/milkdrop-window.md`
- [ ] Document Butterchurn integration
- [ ] Document preset system
- [ ] Document FFT audio analysis

#### Update README
- [ ] Add Video Window feature to README
- [ ] Add Milkdrop Window feature to README
- [ ] Update feature list
- [ ] Add screenshots (optional)

#### Code Documentation
- [ ] Add inline comments to complex code
- [ ] Document VideoWindowSprites struct
- [ ] Document AudioAnalyzer FFT logic
- [ ] Document bridge.js functions

### 10.6 Regression Test Suite
- [ ] Create `MacAmpTests/VideoMilkdropTests.swift`
- [ ] Write test: `testVideoWindowToggle()`
- [ ] Write test: `testMilkdropWindowToggle()`
- [ ] Write test: `testMediaTypeDetection()`
- [ ] Write test: `testFFTDataGeneration()`
- [ ] Write test: `testPresetPersistence()`
- [ ] Write test: `testBothWindowsSimultaneous()`
- [ ] Run all tests → verify passing

**Day 10 Complete**: ✅ FEATURE FULLY COMPLETE!

---

## Post-Implementation (Future V2.0)

### Video Window Enhancements
- [ ] FFmpeg integration (AVI, MKV, FLV, WebM)
- [ ] Advanced playback controls (speed, filters)
- [ ] Subtitle support
- [ ] Video effects

### Milkdrop Window Enhancements
- [ ] MILKDROP.bmp skinning (if exists in skins)
- [ ] Fullscreen mode
- [ ] Desktop mode (live wallpaper)
- [ ] .milk2 preset support (requires Metal renderer)
- [ ] Metal-native visualization renderer
- [ ] Custom preset creation UI
- [ ] Preset sharing/upload platform

### Both Windows
- [ ] Independent NSWindow mode (post magnetic-docking)
- [ ] Multi-monitor support
- [ ] Advanced window snapping

---

## PART 21: Video Control Unification (2025-11-15)

**Goal**: Extend audio controls to also manage video playback
**Estimated Time**: 3-4 hours
**Oracle Validation**: Grade A (all edge cases and patterns addressed)

### Task 1: Video Volume Control (15 min) ⏳
- [ ] Update volume didSet to include video (Line ~160):
  ```swift
  var volume: Float = 1.0 {
      didSet {
          playerNode.volume = volume
          if currentMediaType == .video {
              videoPlayer?.volume = volume
          }
      }
  }
  ```
- [ ] Add volume sync in loadVideoFile() after AVPlayer creation (Line ~382):
  ```swift
  videoPlayer = AVPlayer(url: url)
  videoPlayer?.volume = volume  // Sync volume at creation
  ```
- [ ] Test: Load video, adjust volume slider → video sound changes
- [ ] Test: Load video when volume already at 50% → video starts at 50%

**File:** `MacAmpApp/Audio/AudioPlayer.swift`

### Task 2: Video Time Display (1 hour) ⏳
- [ ] Add observer property (Line ~175):
  ```swift
  @ObservationIgnored private var videoTimeObserver: Any?
  ```
- [ ] Implement `setupVideoTimeObserver()` with Task { @MainActor in }
- [ ] Observer must update THREE values: `currentTime`, `currentDuration`, `playbackProgress`
- [ ] Implement `tearDownVideoTimeObserver()` (cleanup function)
- [ ] Implement `cleanupVideoPlayer()` (shared cleanup for all video resources)
- [ ] Call `setupVideoTimeObserver()` in loadVideoFile() BEFORE play()
- [ ] Replace manual cleanup in loadAudioFile() with `cleanupVideoPlayer()`
- [ ] Replace manual cleanup in stop() with `cleanupVideoPlayer()`
- [ ] Test: Main window timer shows video elapsed time
- [ ] Test: Position slider moves during video playback
- [ ] Test: No memory leaks (proper cleanup on audio switch)

**File:** `MacAmpApp/Audio/AudioPlayer.swift`

### Task 3: Video Seeking Support (1 hour) ⏳
- [ ] Add video branch at TOP of `seek(to:resume:)` (Line ~1179):
  ```swift
  if currentMediaType == .video {
      // ... video seek logic with completion handler
      return  // Exit early
  }
  ```
- [ ] Use proper timescale from currentItem
- [ ] Update all THREE values in completion: currentTime, currentDuration, playbackProgress
- [ ] Handle resume semantics (play/pause state)
- [ ] Use Task { @MainActor in } for state updates
- [ ] Test: Drag position slider during video → video seeks
- [ ] Test: Seek while paused → stays paused
- [ ] Test: Seek while playing → continues playing

**File:** `MacAmpApp/Audio/AudioPlayer.swift`

### Task 4: Metadata Display Growth (30 min) ⏳
- [ ] Add `dynamicDisplayWidth` computed property
- [ ] Calculate: max(115, windowWidth - leftSection - margins)
- [ ] Use dynamic width in metadata scroll view
- [ ] Test: Resize video window → metadata area grows
- [ ] Test: Small window → 115px minimum preserved

**File:** `MacAmpApp/Views/Windows/VideoWindowChromeView.swift`

### Task 5: Integration Testing (1 hour) ⏳
- [ ] Load video, adjust volume → video sound changes
- [ ] Load video, drag slider → video seeks
- [ ] Main window shows video time (not stale audio time)
- [ ] Metadata area grows proportionally with window
- [ ] Switch audio→video→audio cleanly
- [ ] Video ends → proper cleanup
- [ ] No Thread Sanitizer warnings

### Success Criteria
- [ ] Volume slider affects video playback sound
- [ ] Position slider seeks within video file
- [ ] Time display shows video elapsed/remaining time
- [ ] Metadata area grows proportionally with window width
- [ ] No memory leaks from video time observer
- [ ] Smooth seeking without frame drops
- [ ] Clean switch between audio and video playback

---

## Blockers / Issues

**Current Blockers**: None

**Known Issues**: 
- None (Day 1 pending)

**Dependencies**:
- Butterchurn JS library (available)
- Butterchurn presets (available)
- VIDEO.bmp in skins (available, with fallback)

---

## Notes

- All tasks follow Swift 6 concurrency patterns
- Each day's work is self-contained (can pause/resume)
- Testing is continuous (not just Day 10)
- Documentation happens as we build

**Priority**: Video window first, then Milkdrop
**Milestone**: Day 6 (Video window complete)
**Completion**: Day 10 (Both windows complete)

**Last Updated**: 2025-11-08 (Two-window architecture)  
**Next Update**: End of Day 1
