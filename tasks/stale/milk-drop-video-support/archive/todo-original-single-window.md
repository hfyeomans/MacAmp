# TODO: V Button Implementation (6-Day Plan)

**Status**: Ready to begin  
**Timeline**: 6 days  
**Last Updated**: 2025-11-08

---

## Day 1: State + Plumbing ⏳

### 1.1 AppSettings Extension
- [ ] Add `showVisualizerPanel: Bool` property with `didSet` persistence
- [ ] Add `visualizerMode: VisualizerMode` enum with persistence
- [ ] Add `lastUsedPresetIndex: Int` with persistence
- [ ] Add `visualizerWindowFrame: CGRect?` with persistence
- [ ] Create `VisualizerMode` enum (butterchurn, video, none)
- [ ] Add init/load logic for new properties from UserDefaults

### 1.2 AppCommands Extension
- [ ] Add "Toggle Visualization" command to CommandGroup
- [ ] Implement Ctrl+V keyboard shortcut
- [ ] Wire shortcut to `appSettings.showVisualizerPanel.toggle()`
- [ ] Test shortcut in app menu

### 1.3 WinampMainWindow Integration
- [ ] Add conditional view for `showVisualizerPanel`
- [ ] Inject `@Environment(appSettings)` to visualization view
- [ ] Position visualization view in window layout
- [ ] Test toggle show/hide

### 1.4 Placeholder View
- [ ] Create `VisualizationContainerView.swift`
- [ ] Add placeholder text/background
- [ ] Set frame size (275x116 - Winamp viz dimensions)
- [ ] Test view appears/disappears on toggle

### 1.5 Testing & Verification
- [ ] Build and run app
- [ ] Verify Ctrl+V toggles visualization
- [ ] Verify state persists across app restart
- [ ] Verify no build warnings/errors

**Day 1 Complete**: ✅ All checkboxes above must be checked

---

## Day 2: Video Path ⏳

### 2.1 AVPlayerViewRepresentable
- [ ] Create `AVPlayerViewRepresentable.swift`
- [ ] Implement `NSViewRepresentable` protocol
- [ ] Create `makeNSView` returning `AVPlayerView`
- [ ] Set `controlsStyle = .none` (Winamp-style)
- [ ] Set `videoGravity = .resizeAspect`
- [ ] Implement `updateNSView` to sync player
- [ ] Test with sample MP4 file

### 2.2 AudioPlayer Video Support
- [ ] Add `videoPlayer: AVPlayer?` property
- [ ] Add `currentMediaType: MediaType` enum property
- [ ] Create `MediaType` enum (audio, video)
- [ ] Implement `detectMediaType(url:)` method
- [ ] Add video file extensions array ["mp4", "mov", "m4v", "avi"]
- [ ] Implement `loadVideoFile(url:)` method
- [ ] Modify `loadMedia(url:)` to detect and route file types
- [ ] Test video loading logic

### 2.3 VisualizationContainerView Update
- [ ] Add `@Environment(AudioPlayer.self)` injection
- [ ] Add `switch audioPlayer.currentMediaType` logic
- [ ] Render `AVPlayerViewRepresentable` for video mode
- [ ] Show placeholder for audio mode (Day 3-4)
- [ ] Test video rendering in visualization window

### 2.4 Playlist Integration
- [ ] Identify playlist file loading code
- [ ] Add video extensions to supported formats
- [ ] Add 🎬 emoji icon for video files in playlist
- [ ] Ensure double-click triggers `loadMedia()` for videos
- [ ] Display video metadata (duration, resolution) if available
- [ ] Test video files appear in playlist

### 2.5 Eject Button Integration
- [ ] Update file picker to accept video extensions
- [ ] Test "Add File" accepts MP4/MOV files
- [ ] Test Eject button opens file picker with video support

### 2.6 Testing & Verification
- [ ] Build and run app
- [ ] Test MP4 playback
- [ ] Test MOV playback
- [ ] Verify video shows in visualization window
- [ ] Verify audio files still work (placeholder shown)
- [ ] Verify no memory leaks (Instruments)

**Day 2 Complete**: ✅ All checkboxes above must be checked

---

## Day 3: Butterchurn Foundation ⏳

### 3.1 Butterchurn Resource Bundle
- [ ] Create `MacAmpApp/Resources/Butterchurn/` directory
- [ ] Download `butterchurn.min.js` from NPM
- [ ] Download `butterchurn-presets.min.js` from NPM
- [ ] Create `index.html` with canvas element
- [ ] Create `bridge.js` for Swift ↔ JS communication
- [ ] Add CSS to hide scrollbars and set background
- [ ] Add Butterchurn resources to Xcode project
- [ ] Verify resources bundle in app target

### 3.2 HTML Structure
- [ ] Write `index.html` with proper DOCTYPE
- [ ] Add canvas element with id="canvas"
- [ ] Link to butterchurn.min.js
- [ ] Link to butterchurn-presets.min.js
- [ ] Link to bridge.js
- [ ] Test HTML loads in browser (standalone test)

### 3.3 Bridge JavaScript
- [ ] Initialize Butterchurn visualizer in `initButterchurn()`
- [ ] Create AudioContext
- [ ] Load 5-8 curated presets from preset library
- [ ] Implement `loadPreset(index)` function
- [ ] Implement `updateAudioData(fftData)` function
- [ ] Add auto-cycle timer (30s interval)
- [ ] Expose initialization to Swift via message handler
- [ ] Test JavaScript logic in browser console

### 3.4 WKWebView Wrapper
- [ ] Create `ButterchurnWebView.swift`
- [ ] Implement `NSViewRepresentable` protocol
- [ ] Configure `WKWebViewConfiguration`
- [ ] Add script message handler for "ready" event
- [ ] Load local HTML from Resources bundle
- [ ] Set `drawsBackground = false` for transparency
- [ ] Implement `makeCoordinator()` for message handling
- [ ] Test WebView loads HTML

### 3.5 Testing & Verification
- [ ] Build and run app
- [ ] Verify WebView loads Butterchurn HTML
- [ ] Verify "ready" message received in Swift
- [ ] Verify canvas renders (blank for now, no audio data)
- [ ] Check for console errors in Safari Web Inspector
- [ ] Verify no build warnings

**Day 3 Complete**: ✅ All checkboxes above must be checked

---

## Day 4: Butterchurn Audio Bridge ⏳

### 4.1 AudioAnalyzer Implementation
- [ ] Create `AudioAnalyzer.swift`
- [ ] Add `@Observable @MainActor` annotations
- [ ] Import AVFoundation and Accelerate
- [ ] Create `fftData: [Float]` published property
- [ ] Initialize `vDSP_DFT_Setup` for FFT processing
- [ ] Implement `installTap()` on `AVAudioEngine.mainMixerNode`
- [ ] Set buffer size to 1024, FFT size to 512
- [ ] Implement `processPCMBuffer()` method
- [ ] Perform FFT using Accelerate framework
- [ ] Compute magnitudes from FFT output
- [ ] Downsample to 64-128 bins
- [ ] Update `fftData` on `@MainActor`
- [ ] Implement `deinit` to remove tap and cleanup FFT setup

### 4.2 AudioPlayer Integration
- [ ] Add `audioAnalyzer: AudioAnalyzer?` property to AudioPlayer
- [ ] Initialize AudioAnalyzer with `audioEngine` in init
- [ ] Add computed property `currentFFTData: [Float]`
- [ ] Ensure analyzer starts when audio plays
- [ ] Test FFT data updates during playback

### 4.3 VisualizationContainerView FFT Wiring
- [ ] Add `@State private var fftData: [Float] = []`
- [ ] Create Timer publisher (16ms / ~60fps)
- [ ] Update local `fftData` from `audioPlayer.currentFFTData`
- [ ] Pass `fftData` binding to `ButterchurnWebView`
- [ ] Test data flows from audio to view

### 4.4 ButterchurnWebView FFT Update
- [ ] Add `@Binding var fftData: [Float]` parameter
- [ ] Implement `updateNSView()` to send data to JavaScript
- [ ] Serialize FFT array to comma-separated string
- [ ] Call `webView.evaluateJavaScript("updateAudioData([...])")`
- [ ] Test JavaScript receives FFT data

### 4.5 Butterchurn Rendering
- [ ] Verify `updateAudioData()` in bridge.js receives data
- [ ] Call `visualizer.render()` in animation loop
- [ ] Test visualization animates to audio
- [ ] Verify smooth 60fps rendering
- [ ] Test preset transitions work (2.7s)

### 4.6 Testing & Verification
- [ ] Build and run app
- [ ] Play audio file
- [ ] Verify visualization animates in sync with audio
- [ ] Test preset auto-cycles every 30s
- [ ] Pause audio → verify visualization pauses
- [ ] Resume audio → verify visualization resumes
- [ ] Profile CPU/GPU usage (should be <20% CPU)
- [ ] Test for memory leaks (Instruments, 10min playback)

**Day 4 Complete**: ✅ All checkboxes above must be checked

---

## Day 5: Polish & Persistence ⏳

### 5.1 Skin Integration
- [ ] Inject `@Environment(SkinManager.self)` to ButterchurnWebView
- [ ] Extract current skin colors in `makeNSView()`
- [ ] Create Color extension for `.hex` string conversion
- [ ] Build JavaScript object with skin colors
- [ ] Execute `evaluateJavaScript()` to inject colors
- [ ] Update bridge.js to apply skin colors to canvas/background
- [ ] Test visualization updates when skin changes
- [ ] Test with light and dark skins

### 5.2 Window Frame Persistence
- [ ] Add `.frame()` modifier to VisualizationContainerView
- [ ] Load saved frame from `appSettings.visualizerWindowFrame`
- [ ] Use default (275x116) if no saved frame
- [ ] Add `.onAppear` to restore frame
- [ ] Add `.onChange` to save frame on resize (future: if resizable)
- [ ] Test frame persists across app restarts

### 5.3 Preset Selection UI
- [ ] Create `PresetSelectorMenu.swift`
- [ ] Define preset names array (5-8 presets)
- [ ] Create SwiftUI `Menu` with preset buttons
- [ ] Wire button actions to update `appSettings.lastUsedPresetIndex`
- [ ] Send JavaScript message to change preset in WebView
- [ ] Add preset menu to V button context menu OR Options menu
- [ ] Test manual preset selection works

### 5.4 Keyboard Shortcuts
- [ ] Add "Next Preset" command to AppCommands
- [ ] Add Ctrl+] keyboard shortcut for next preset
- [ ] Add "Previous Preset" command to AppCommands
- [ ] Add Ctrl+[ keyboard shortcut for previous preset
- [ ] Implement preset cycling logic (wrap around)
- [ ] Notify WebView to change preset
- [ ] Test keyboard shortcuts work

### 5.5 Optional: Chromeless Mode
- [ ] Add `chromelessVisualization: Bool` to AppSettings
- [ ] Add toggle to Options menu
- [ ] Conditionally hide borders/chrome in VisualizationContainerView
- [ ] Update WebView CSS for chromeless mode
- [ ] Test chromeless mode toggle

### 5.6 Testing & Verification
- [ ] Build and run app
- [ ] Test skin colors applied to visualization
- [ ] Switch skins → verify visualization updates
- [ ] Test frame persistence (restart app)
- [ ] Test preset menu selection
- [ ] Test Ctrl+[ / Ctrl+] shortcuts
- [ ] Verify all persistence works
- [ ] Check for visual glitches

**Day 5 Complete**: ✅ All checkboxes above must be checked

---

## Day 6: Verification & Documentation ⏳

### 6.1 Comprehensive Testing

#### Video Playback Tests
- [ ] Test MP4 playback (H.264 codec)
- [ ] Test MOV playback (QuickTime)
- [ ] Test M4V playback (iTunes video)
- [ ] Test AVI playback (limited support)
- [ ] Verify video stops when switching tracks
- [ ] Verify video scales in double-size mode
- [ ] Test seek/scrub functionality (if implemented)

#### Audio Visualization Tests
- [ ] Test FFT updates in real-time
- [ ] Verify sync with audio playback
- [ ] Test all 5-8 presets render correctly
- [ ] Verify 30s auto-cycle timer works
- [ ] Test manual preset selection
- [ ] Test preset keyboard shortcuts
- [ ] Verify visualization pauses with audio
- [ ] Test 1+ hour continuous playback (memory leaks)

#### Integration Tests
- [ ] Playlist shows video files with 🎬 icon
- [ ] Eject button accepts video files
- [ ] File drag-and-drop supports video (if implemented)
- [ ] Ctrl+V toggles visualization window
- [ ] State persists across app restarts
- [ ] Ctrl+[ / Ctrl+] cycle presets
- [ ] Works in normal mode
- [ ] Works in double-size mode

#### Skin Tests
- [ ] Test with 3+ different skins
- [ ] Verify colors update when skin changes
- [ ] Test light and dark skin themes
- [ ] Verify chromeless mode (if implemented)

#### Performance Tests
- [ ] Profile with Instruments (CPU usage)
- [ ] Profile with Instruments (Memory usage)
- [ ] Check GPU usage (should use hardware acceleration)
- [ ] Verify no dropped frames during playback
- [ ] Verify no audio glitches during FFT processing
- [ ] Test on older Mac (performance degradation check)

### 6.2 Regression Test Suite
- [ ] Create `VisualizationTests.swift`
- [ ] Write test: `testMediaTypeDetection()`
- [ ] Write test: `testFFTDataGeneration()`
- [ ] Write test: `testPresetPersistence()`
- [ ] Write test: `testVisualizationToggle()`
- [ ] Run all tests → verify passing
- [ ] Add tests to CI pipeline (if exists)

### 6.3 Bug Fixes
- [ ] Fix any bugs discovered during testing
- [ ] Address performance issues if CPU/GPU > targets
- [ ] Fix skin theming edge cases
- [ ] Resolve memory leaks if found
- [ ] Polish visual glitches

### 6.4 Documentation
- [ ] Create `docs/features/v-button-visualization.md`
- [ ] Document usage (toggle, shortcuts, presets)
- [ ] Document supported formats (video + audio)
- [ ] Document technical architecture
- [ ] Document future enhancements
- [ ] Update main `README.md` with V button feature
- [ ] Add to feature list with checkmark
- [ ] Update screenshots (if applicable)

### 6.5 Code Review
- [ ] Review all new Swift files for style consistency
- [ ] Ensure `@MainActor` annotations correct
- [ ] Verify no force unwraps (`!`) in production code
- [ ] Check for TODO/FIXME comments → resolve or document
- [ ] Verify all errors handled gracefully
- [ ] Run SwiftLint (if configured)

### 6.6 Final Polish
- [ ] Test on fresh install (no existing UserDefaults)
- [ ] Verify default behavior sensible
- [ ] Check for console warnings/errors
- [ ] Optimize bundle size (compress presets if needed)
- [ ] Update version number/changelog
- [ ] Prepare release notes

**Day 6 Complete**: ✅ All checkboxes above must be checked

---

## Post-Implementation (Future Enhancements)

### V2.0 Enhancements
- [ ] Independent window (requires magnetic-docking task)
- [ ] FFmpeg integration for AVI/MKV/FLV support
- [ ] Full preset browser UI
- [ ] Preset favorites system
- [ ] Preset search/filter

### V3.0 Enhancements
- [ ] Metal-native visualization renderer
- [ ] Custom preset creation tool
- [ ] Preset sharing/upload platform
- [ ] Advanced visualization effects
- [ ] Multi-monitor support

---

## Blockers / Issues

**Current Blockers**: None

**Known Issues**:
- None (Day 1 pending)

**Dependencies**:
- Butterchurn JS library (available, to be bundled)
- Butterchurn presets (available, to be bundled)

---

## Notes

- All tasks follow Swift 6 concurrency patterns
- Each day's work is self-contained (can pause/resume)
- Testing is continuous (not just Day 6)
- Documentation happens as we build (inline comments)

**Last Updated**: 2025-11-08  
**Next Update**: End of Day 1
