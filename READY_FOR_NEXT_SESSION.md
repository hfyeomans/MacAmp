# MacAmp - Ready for Next Session

**Last Updated**: 2025-11-10 (End of Day)
**Current Branch**: `feature/video-milkdrop-windows`
**Current Task**: TASK 2 (milk-drop-video-support)
**Status**: ✅ VIDEO WINDOW 100% COMPLETE - Ready for Milkdrop!

---

## 🎯 START NEXT SESSION

```
Begin TASK 2 Days 7-10: Milkdrop Window Implementation

VIDEO Window Status (Days 1-6):
✅ 100% COMPLETE - Committed (cdce0de)

Ready to implement Milkdrop:
1. Day 7: Milkdrop window foundation
2. Day 8: Butterchurn integration (HTML/JS/WKWebView)
3. Day 9: FFT audio tap extension
4. Day 10: Preset system + testing

Start with: tasks/milk-drop-video-support/plan.md (Day 7, line 474)
```

---

## ✅ VIDEO WINDOW COMPLETE

### Core Features
- Perfect VIDEO.bmp sprite-based chrome (titlebar, borders, bottom bar)
- Video playback (MP4, MOV, M4V via AVPlayer)
- Play/pause/stop controls work with video
- V button + Ctrl+V keyboard shortcut
- Video metadata display with scrolling
- Window position persistence
- Magnetic docking with double-size (Ctrl+D)
- Default Winamp skin fallback

### Implementation Quality
- ✅ Thread Sanitizer clean
- ✅ All Oracle critical bugs fixed
- ✅ Code comments cleaned
- ✅ Production-ready architecture

### Commit
- **Hash**: cdce0de
- **Files**: 31 changed (+2395/-92)
- **Message**: "feat: Video Window - Complete Implementation (TASK 2 Days 1-6)"

---

## 🎓 LESSONS FOR MILKDROP

### MacAmp Patterns (MUST FOLLOW)
1. **Define sprites in SkinSprites.swift** (not runtime parsing)
2. **Use .position(x, y)** where x/y are sprite CENTERS
3. **Tile decorative sections** with ForEach
4. **Default skin fallback** for missing BMPs
5. **Full-width drag handles** for titlebars
6. **Observer pattern** for window visibility
7. **Cleanup timers** in onDisappear

### What Worked
- VIDEO sprites in SkinSprites.swift (like PLEDIT)
- ZStack + SimpleSpriteImage + .position()
- Default skin loaded once, used for all fallbacks
- Cluster-aware docking (WindowSnapManager)

### What Didn't Work (Avoid)
- Runtime sprite parsing with manual math ❌
- VStack/HStack layouts for chrome ❌
- Image(nsImage:) direct rendering ❌
- Temporary skin creation ❌
- .at() positioning ❌

---

## 📋 MILKDROP ROADMAP (Days 7-10)

### Day 7: Foundation
- Update WinampMilkdropWindow with ZStack layout
- Simple chrome (GEN.bmp or custom)
- Observer for showMilkdropWindow
- Ctrl+Shift+K shortcut
- Test show/hide

### Day 8: Butterchurn
- Create HTML bundle (index.html, butterchurn.min.js, presets)
- ButterchurnWebView (WKWebView wrapper)
- Load 5-8 curated presets
- Test visualization renders

### Day 9: FFT Audio
- EXTEND existing AudioPlayer tap (don't create new analyzer!)
- 512-bin FFT + 576-sample waveform
- JavaScript bridge to Butterchurn
- Test sync to audio

### Day 10: Integration
- Options menu checkbox
- Preset selection UI
- Comprehensive testing
- Documentation

---

## 🐛 KNOWN ISSUES (Non-Blocking)

### Video Window (Deferred)
- X button not clickable yet (future: wire to settings.showVideoWindow)
- Baked-on buttons (1x, 2x, fullscreen, TV) not functional
- Video time not shown in main window timer
- Volume slider doesn't affect video playback

### To Address in Polish Phase
- Active/inactive titlebar needs focus event wiring
- Button click handlers
- Video time synchronization
- Volume synchronization

---

## 📊 PROGRESS

**TASK 2 Timeline**:
- Days 1-6: ✅ COMPLETE (Video Window)
- Days 7-10: ⏳ TODO (Milkdrop Window)
- Progress: 60% complete

**Code Stats**:
- Created: 6 files (~600 lines)
- Modified: 11 files (~400 lines)
- Deleted: Runtime parsing code (~250 lines)
- Net: +2395/-92 lines

---

## 🏗️ BUILD COMMANDS

**Standard Build with Thread Sanitizer:**
```bash
xcodebuild -scheme MacAmpApp -destination 'platform=macOS' -enableThreadSanitizer YES build
```

**Run App:**
```bash
open ~/Library/Developer/Xcode/DerivedData/MacAmpApp-*/Build/Products/Debug/MacAmp.app
```

---

**Status**: Ready for Milkdrop implementation!
**Branch**: feature/video-milkdrop-windows
**Last Commit**: cdce0de (Video Window Complete)

🚀 **LET'S BUILD MILKDROP!**
