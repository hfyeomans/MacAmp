# Butterchurn Integration - Task List

**Task ID:** butterchurn-integration
**Created:** 2026-01-05

---

## Phase 1: WebView Setup (Foundation)

- [ ] Create ButterchurnWebView.swift with WKWebViewConfiguration
- [ ] Load butterchurn.min.js as String from bundle
- [ ] Load butterchurnPresets.min.js as String from bundle
- [ ] Load bridge.js as String from bundle
- [ ] Create WKUserScript for each .js file (injectionTime: .atDocumentStart)
- [ ] Add scripts to WKUserContentController
- [ ] Modify index.html to remove `<script src>` tags
- [ ] Add `butterchurnReady` event dispatch after init
- [ ] Test: Verify `butterchurn` global exists in WebView
- [ ] Test: Verify presets array loads
- [ ] Test: Render static visualization (no audio)

---

## Phase 2: Audio Bridge (Core Functionality)

- [ ] Add butterchurnSpectrum [Float] property to AudioPlayer (1024 bins)
- [ ] Add butterchurnWaveform [Float] property to AudioPlayer (1024 samples)
- [ ] Create separate audio tap for Butterchurn (2048 FFT size)
- [ ] Create ButterchurnBridge.swift (WKScriptMessageHandler)
- [ ] Implement sendAudioData() method with JSON encoding
- [ ] Add updateAudioData() receiver in bridge.js
- [ ] Create mock AnalyserNode in JavaScript (provide getByteFrequencyData)
- [ ] Connect AudioPlayer → Bridge → WebView pipeline
- [ ] Add 60 FPS timer for audio data updates
- [ ] Test: Visualization responds to music
- [ ] Test: Bass hits cause visual reactions
- [ ] Test: No perceptible audio/visual lag

---

## Phase 3: Preset Management

- [ ] Create ButterchurnPresetManager.swift (@Observable)
- [ ] Add presets array property (populated from JS)
- [ ] Add currentPresetIndex property
- [ ] Add presetHistory array for navigation
- [ ] Implement nextPreset() with random/sequential support
- [ ] Implement previousPreset() using history
- [ ] Implement selectPreset(at:) for direct selection
- [ ] Add isRandomize property (default: true)
- [ ] Add isCycling property (default: true)
- [ ] Add cycleInterval property (default: 15.0)
- [ ] Implement startCycling() with Timer
- [ ] Implement stopCycling()
- [ ] Add loadPresetAtIndex() to bridge.js
- [ ] Add getPresetNames() to bridge.js
- [ ] Test: Presets cycle automatically every 15 seconds
- [ ] Test: Random mode produces variety
- [ ] Test: Previous/next navigation works

---

## Phase 4: Integration & Polish

- [ ] Replace placeholder in WinampMilkdropWindow.swift
- [ ] Add showTrackTitle() to bridge.js
- [ ] Call showTrackTitle on track change (via PlaybackCoordinator)
- [ ] Add keyboard shortcut: Space → next preset
- [ ] Add keyboard shortcut: Backspace → previous preset
- [ ] Add keyboard shortcut: R → toggle random
- [ ] Add keyboard shortcut: T → show track title
- [ ] Add butterchurnRandomize to AppSettings.swift
- [ ] Add butterchurnCycling to AppSettings.swift
- [ ] Add butterchurnCycleInterval to AppSettings.swift
- [ ] Pause rendering when window hidden (orderOut)
- [ ] Resume rendering when window shown (orderFront)
- [ ] Clean up WebView properly on window close
- [ ] Test: Track titles appear on track change
- [ ] Test: All keyboard shortcuts work
- [ ] Test: Settings persist across app restarts

---

## Phase 5: Testing & Validation

- [ ] Build with Thread Sanitizer enabled
- [ ] Fix any data race warnings
- [ ] Run Oracle code review on new files
- [ ] Manual test: Local file playback + visualization
- [ ] Manual test: Internet radio + visualization
- [ ] Manual test: Preset cycling for 5+ minutes
- [ ] Manual test: Window focus states
- [ ] Manual test: Window position persistence
- [ ] Manual test: Memory usage over time (no leaks)
- [ ] Manual test: Performance (60 FPS target)
- [ ] Create PR
- [ ] Merge after approval

---

## Blockers

None currently (WKUserScript approach planned to bypass WKWebView restriction)

---

## Notes

- butterchurn.min.js: 238 KB
- butterchurnPresets.min.js: 230 KB
- bridge.js: 4 KB
- Total injection: ~472 KB as strings
- Content area: 256×198px
- FFT size: 2048 (1024 bins)
- Update rate: 60 FPS
- Preset transition: 2.7 seconds default
- Auto-cycle interval: 15 seconds

---

## Reference Files

| Purpose | File |
|---------|------|
| Research | tasks/butterchurn-integration/research.md |
| Plan | tasks/butterchurn-integration/plan.md |
| Existing window | MacAmpApp/Views/WinampMilkdropWindow.swift |
| Window chrome | MacAmpApp/Views/Windows/MilkdropWindowChromeView.swift |
| Controller | MacAmpApp/Windows/WinampMilkdropWindowController.swift |
| Audio player | MacAmpApp/Audio/AudioPlayer.swift |
| Settings | MacAmpApp/Models/AppSettings.swift |
| Butterchurn assets | Butterchurn/*.js, Butterchurn/*.html |
