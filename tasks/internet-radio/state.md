# Internet Radio Streaming - Current State

**Date:** 2025-10-31
**Status:** 📋 Oracle-Reviewed Planning Complete - Ready for Implementation

---

## ⚠️ Oracle Review Summary

**Architecture:** ✅ VALIDATED - Dual backend is correct approach
**Complexity:** HIGH - 12-15 hours (not 9-11)
**Priority:** MEDIUM - Complex but valuable feature

### Critical Oracle Requirements:

1. **MUST ADD PlaybackCoordinator** (HIGH)
   - Manages AudioPlayer + StreamPlayer
   - Prevents both playing simultaneously
   - Unified API for UI
   - +2-3 hours to estimates

2. **Fix StreamPlayer Observers** (MEDIUM)
   - Cancel old observers before new
   - Add status observer for errors
   - Use RunLoop.main not DispatchQueue.main

3. **Fix Metadata Extraction** (MEDIUM)
   - Use item.commonKey and item.stringValue
   - Not value(forKey:) KVC approach

4. **RadioStationLibrary Injection** (HIGH)
   - Pass to PlaylistWindowActions
   - Or inject via environment

5. **Consider Playlist Integration** (MEDIUM)
   - Streams should appear in playlist order
   - Not just in separate library

6. **Info.plist Already Ready** ✅
   - NSAllowsArbitraryLoadsInMedia exists
   - No changes needed!

### Recommended Commit Strategy:

**7-8 commits over 12-15 hours:**
1. Models (1 hour)
2. StreamPlayer basic (2 hours)
3. StreamPlayer observers (2 hours)
4. PlaybackCoordinator (2-3 hours)
5. M3U integration (3 hours)
6. UI additions (2 hours)
7. Oracle cleanup (30 min)

**Oracle Review Checkpoints:**
- After Phase 1: Review PlaybackCoordinator
- After Phase 3: Final review before merge

---


---

## Task Status

### Research Phase
- ✅ Existing documentation reviewed
- ✅ Webamp clone analyzed
- ✅ Architecture decisions made
- ⏸️ Oracle review pending

### Implementation Phase
- ⏸️ Not started (awaiting Oracle review)

---

## What Exists (Ready to Use)

### M3U Parser Infrastructure ✅
- **File:** `MacAmpApp/Models/M3UParser.swift`
- **Status:** Complete and tested
- **Capabilities:**
  - Parses #EXTM3U format
  - Extracts EXTINF metadata
  - Detects HTTP/HTTPS URLs
  - `M3UEntry.isRemoteStream` property

### M3U Integration Hook ✅
- **File:** `MacAmpApp/Views/WinampPlaylistWindow.swift`
- **Line:** 503-506
- **Status:** TODO placeholder ready
- **Current:** Logs remote streams, doesn't play them
- **Ready for:** Integration with StreamPlayer

### Entitlements ✅
- **File:** `MacAmpApp/MacAmp.entitlements`
- **Line 32:** `com.apple.security.network.client` = true
- **Status:** ✅ All streaming protocols supported

### Info.plist (Needs Verification) ⚠️
- **Key:** `NSAllowsArbitraryLoadsInMedia`
- **Purpose:** Allow HTTP streams (90% of radio uses HTTP not HTTPS)
- **Status:** ⏸️ Need to verify exists
- **Location:** Should be in `MacAmpApp/Info.plist`

---

## What's Missing

### Core Streaming
- [ ] StreamPlayer class (AVPlayer wrapper)
- [ ] RadioStation model
- [ ] RadioStationLibrary (persistence)
- [ ] Dual backend mode switching

### M3U Integration
- [ ] Update WinampPlaylistWindow Line 503-506
- [ ] Add stations to library from M3U
- [ ] Inject RadioStationLibrary

### UI
- [ ] Station selection interface
- [ ] Add Stream URL dialog
- [ ] Buffering indicators
- [ ] Stream metadata display

---

## Architecture Decisions

### Dual Backend Approach (Planned)

**Local Files:**
- Backend: AVAudioEngine
- Features: 10-band EQ, full control
- Sources: .mp3, .flac, .m4a, etc.

**Streaming:**
- Backend: AVPlayer
- Features: HTTP streaming, metadata
- Sources: http://, https:// URLs
- Limitation: No EQ (AVPlayer can't use AVAudioUnitEQ)

**Why:**
- AVAudioEngine can't stream HTTP
- AVPlayer can't use custom audio units
- Must use both for complete feature set

**Oracle Review Needed:** Validate this architecture decision

---

## Prerequisites Checklist

### ✅ Already Have
- [x] M3U parser with remote detection
- [x] Network client entitlement
- [x] Swift 6 @Observable architecture
- [x] Existing local file playback

### ⏸️ Need to Verify
- [ ] NSAllowsArbitraryLoadsInMedia in Info.plist
  - Check MacAmpApp/Info.plist
  - Add if missing
  - Required for HTTP streams

### ⏸️ Need to Create
- [ ] StreamPlayer class
- [ ] RadioStation model
- [ ] RadioStationLibrary
- [ ] UI for streams

---

## Implementation Scope

### Phase 1: Core Streaming (4-6 hours)
- StreamPlayer with AVPlayer
- RadioStation and RadioStationLibrary
- Basic play/pause/stop
- Mode detection and switching

### Phase 2: M3U Integration (2 hours)
- Update M3U loading code
- Add stations to library
- Test with real M3U files

### Phase 3: UI Polish (3 hours)
- Add Stream URL dialog
- Station list view
- Metadata display
- Error handling

**Total: 9-11 hours**

---

## Test Resources

### Available M3U Files
- `/Users/hank/Downloads/DarkAmbientRadio.m3u`
- Can create more from SomaFM

### Test Stream URLs (From Docs)
```
http://ice1.somafm.com/groovesalad-256-mp3  # SomaFM Groove Salad
http://ice1.somafm.com/defcon-128-mp3       # DEF CON Radio
http://stream.radioparadise.com/mp3-192     # Radio Paradise
```

---

## Current Codebase Analysis

### AudioPlayer.swift
- **Lines:** 94-1200+
- **Architecture:** AVAudioEngine based
- **Graph:** playerNode → eqNode → mainMixerNode → outputNode
- **Compatibility:** Perfect for local files
- **Limitation:** Cannot stream HTTP

### M3UParser.swift
- **Status:** Complete
- **Detection:** `url.scheme == "http" || "https"`
- **Ready:** For integration

### WinampPlaylistWindow.swift
- **Integration Point:** Line 503-506
- **Status:** Placeholder ready
- **Action:** Replace TODO with library integration

---

## Integration Strategy (Oracle to Review)

### Option A: Separate Players (Recommended)
- AudioPlayer handles local files (AVAudioEngine + EQ)
- StreamPlayer handles radio (AVPlayer, no EQ)
- UI switches between them based on source
- Clean separation of concerns

### Option B: Unified Player
- AudioPlayer extended with streaming
- Internal mode switching
- Single API for UI
- More complex state management

### Option C: StreamPlayer Delegates to AudioPlayer
- StreamPlayer for streams
- Delegates local files to AudioPlayer
- Wrapper pattern
- Complex delegation

**Recommendation:** Option A for clarity

**Oracle Review Question:** Is dual backend the right approach?

---

## Risks and Concerns

### Technical Risks
- Dual backend complexity
- State synchronization between players
- Mode switching audio glitches
- No EQ for streams (user expectation)

### Implementation Risks
- AVPlayer KVO observations (Swift 6 compliance)
- Metadata extraction reliability
- Network error handling
- Buffer stalling recovery

---

## Next Steps

1. ⏸️ Verify NSAllowsArbitraryLoadsInMedia in Info.plist
2. ⏸️ Oracle review of architecture and plan
3. ⏸️ User approval to proceed
4. ⏸️ Implement Phase 1 (core streaming)
5. ⏸️ Test with real radio streams

---

**Status:** ✅ Research and planning complete
**Oracle Review:** ⏸️ Pending - architecture validation needed
**Ready:** For implementation after Oracle approval

---

## Oracle Review Findings

**Date:** 2025-10-31
**Status:** ✅ Architecture validated with required corrections

### Critical Additions Required

1. **PlaybackCoordinator** (HIGH)
   - Manages both AudioPlayer and StreamPlayer
   - Prevents simultaneous playback
   - Unified API for UI
   - Effort: +2-3 hours

2. **Observer Cleanup** (MEDIUM)
   - Cancel old observers before new ones
   - Remove timeObserver when replacing items
   - Add status observer for errors

3. **Metadata Extraction Fix** (MEDIUM)
   - Use item.commonKey and item.stringValue
   - Not value(forKey:) with KVC

### Info.plist Verification

**Oracle Found:**
> "NSAllowsArbitraryLoadsInMedia is already present (MacAmpApp/Info.plist:22-26)"

**Update:**
- [x] ✅ NSAppTransportSecurity configured
- [x] ✅ NSAllowsArbitraryLoadsInMedia = true
- [x] ✅ **No Info.plist changes needed!**

### Corrected Time Estimates

**Original:** 9-11 hours
**Oracle-Corrected:** 12-15 hours

### Recommendations

1. Add PlaybackCoordinator design to plan
2. Fix code examples per Oracle
3. Update estimates throughout
4. Implement in Oracle-suggested phase order

---

**Next Steps:** User review and approval for implementation
