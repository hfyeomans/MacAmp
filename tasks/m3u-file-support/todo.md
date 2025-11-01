# M3U File Support - Implementation Checklist

**Task:** Enable M3U/M3U8 playlist file support
**Priority:** P0 (Blocker for internet radio feature)
**Status:** Research complete, ready for implementation
**Branch:** `feature/m3u-file-support` (to create)

---

## Phase 1: Fix File Selection (CRITICAL) ⚡

**Time:** 30 minutes
**Priority:** P0

- [ ] Open `MacAmpApp/Views/WinampPlaylistWindow.swift`
- [ ] Locate `openFileDialog()` function
- [ ] Change `allowedContentTypes = [.audio]` to `[.audio, .m3uPlaylist]`
- [ ] Build and run app
- [ ] Test: Open file dialog
- [ ] Verify: M3U files are no longer grayed out
- [ ] Verify: M3U files are selectable
- [ ] Verify: Audio files still work

**Files Modified:** 1
**Lines Changed:** ~1 line

---

## Phase 2: Add UTI Import Declaration (RECOMMENDED) 📋

**Time:** 15 minutes
**Priority:** P1

- [ ] Open `MacAmpApp/Info.plist`
- [ ] Find `<key>NSPrincipalClass</key>` section
- [ ] Add `UTImportedTypeDeclarations` section after it
- [ ] Include M3U UTI with extensions (.m3u, .m3u8)
- [ ] Include MIME types (audio/x-mpegurl, audio/mpegurl)
- [ ] Declare conformance to public.text and public.playlist
- [ ] Clean build folder (Product → Clean Build Folder)
- [ ] Rebuild app
- [ ] Test: Right-click M3U file in Finder
- [ ] Verify: "Open With" shows MacAmp
- [ ] Verify: MacAmp can be set as default app for M3U

**Files Modified:** 1
**Lines Added:** ~20 lines

---

## Phase 3: Implement M3U Parser (CORE FEATURE) 🔧

**Time:** 2-3 hours
**Priority:** P1

### Step 3.1: Create M3UEntry Model

- [ ] Create `MacAmpApp/Models/M3UEntry.swift`
- [ ] Define struct with properties:
  - [ ] `url: URL`
  - [ ] `title: String?`
  - [ ] `duration: Int?`
  - [ ] `isRemoteStream: Bool` (computed)
- [ ] Add initializer
- [ ] Add Equatable conformance (for testing)

**Files Created:** 1
**Lines Added:** ~30 lines

### Step 3.2: Create M3UParser

- [ ] Create `MacAmpApp/Parsers/M3UParser.swift`
- [ ] Implement `parse(fileURL: URL) throws -> [M3UEntry]`
  - [ ] Read file content with UTF-8 encoding
  - [ ] Call parse(content:) method
- [ ] Implement `parse(content: String) -> [M3UEntry]`
  - [ ] Split content by newlines
  - [ ] Check for #EXTM3U header
  - [ ] Parse #EXTINF lines for metadata
  - [ ] Extract URLs/paths
  - [ ] Associate metadata with URLs
- [ ] Implement `resolveURL(_ urlString: String, relativeTo: URL) -> URL?`
  - [ ] Handle HTTP/HTTPS URLs (absolute)
  - [ ] Handle absolute file paths
  - [ ] Handle relative paths (resolve from M3U location)
  - [ ] Handle Windows paths (C:\ format)
- [ ] Add error handling:
  - [ ] M3UParseError.invalidFormat
  - [ ] M3UParseError.fileNotFound
  - [ ] M3UParseError.encodingError
  - [ ] M3UParseError.emptyPlaylist
- [ ] Add comments and documentation

**Files Created:** 1
**Lines Added:** ~150-200 lines

### Step 3.3: Create Unit Tests (Optional but Recommended)

- [ ] Create `MacAmpAppTests/M3UParserTests.swift`
- [ ] Test: Parse simple M3U (no metadata)
- [ ] Test: Parse extended M3U (#EXTM3U + #EXTINF)
- [ ] Test: Parse internet radio M3U
- [ ] Test: Handle empty playlist
- [ ] Test: Handle comments
- [ ] Test: Handle Windows line endings (\r\n)
- [ ] Test: Handle UTF-8 characters
- [ ] Test: Handle malformed EXTINF
- [ ] Test: Handle invalid URLs
- [ ] Test: Relative path resolution

**Files Created:** 1
**Lines Added:** ~200-300 lines

---

## Phase 4: Integrate M3U Loading (INTEGRATION) 🔗

**Time:** 1-2 hours
**Priority:** P1

### Step 4.1: Update Playlist Window

- [ ] Open `MacAmpApp/Views/WinampPlaylistWindow.swift`
- [ ] Locate file selection handler in `openFileDialog()`
- [ ] Add M3U file detection:
  - [ ] Check if file extension is .m3u or .m3u8
- [ ] Create `loadM3UPlaylist(_ url: URL)` method:
  - [ ] Call M3UParser.parse(fileURL: url)
  - [ ] Iterate through entries
  - [ ] For local files: Add to appState.tracks
  - [ ] For remote streams: Log for now (P5 will handle)
  - [ ] Handle parse errors (show alert)
- [ ] Add error alert dialog for parse failures
- [ ] Update UI to show loading state

**Files Modified:** 1
**Lines Added:** ~50-80 lines

### Step 4.2: Update AudioPlayer (if needed)

- [ ] Open `MacAmpApp/Audio/AudioPlayer.swift`
- [ ] Check if URL type detection needed
- [ ] Add `isStreamURL(_ url: URL) -> Bool` helper
- [ ] Prepare for P5 integration (stream handling)

**Files Modified:** 0-1
**Lines Added:** ~10-20 lines

---

## Phase 5: Internet Radio Integration (FUTURE) 🌐

**Time:** Handled by P5 task
**Priority:** P5 (existing task)

**Note:** This phase is covered by the existing **P5: Internet Radio Streaming** task.

- [ ] Implement InternetRadioPlayer (P5)
- [ ] Create RadioStationLibrary (P5)
- [ ] Update loadM3UPlaylist() to add streams to library
- [ ] Enable stream playback from M3U

**Dependencies:** P5 task must be implemented first

---

## Phase 6: M3U Export (OPTIONAL) 💾

**Time:** 1-2 hours
**Priority:** P3

- [ ] Create `MacAmpApp/Parsers/M3UWriter.swift`
- [ ] Implement `write(entries: [M3UEntry], to: URL) throws`
- [ ] Implement `generate(entries: [M3UEntry]) -> String`
- [ ] Add "Save Playlist..." menu item
- [ ] Show NSSavePanel with .m3u extension
- [ ] Convert current playlist to M3U format
- [ ] Write to selected location
- [ ] Test: Save and reload playlist

**Files Created:** 1
**Lines Added:** ~80-100 lines

---

## Testing Checklist

### Phase 1 Testing
- [ ] Build succeeds
- [ ] File dialog opens
- [ ] M3U files are NOT grayed out
- [ ] M3U files are selectable
- [ ] Audio files still work
- [ ] Can cancel dialog

### Phase 2 Testing
- [ ] Build succeeds after Info.plist change
- [ ] Right-click M3U in Finder shows "Open With MacAmp"
- [ ] Can set MacAmp as default for M3U files
- [ ] Quick Look works for M3U files (system feature)

### Phase 3 Testing
- [ ] Parser handles simple M3U
- [ ] Parser handles extended M3U (#EXTM3U)
- [ ] Parser extracts titles from #EXTINF
- [ ] Parser extracts durations from #EXTINF
- [ ] Parser handles comments (#)
- [ ] Parser handles empty lines
- [ ] Parser detects HTTP/HTTPS URLs
- [ ] Parser resolves relative paths
- [ ] Parser handles UTF-8 (M3U8)
- [ ] Error handling works for invalid files
- [ ] Unit tests pass (if implemented)

### Phase 4 Testing
- [ ] Load M3U with local files → Files added to playlist
- [ ] Load M3U with URLs → URLs logged/detected
- [ ] Play local files from loaded M3U
- [ ] Error shown for corrupted M3U
- [ ] Error shown for missing files in M3U
- [ ] Multiple M3U loads work correctly
- [ ] Relative paths resolve from M3U location

### Phase 5 Testing (P5 Task)
- [ ] Load internet radio M3U → Streams playable
- [ ] Station names display correctly
- [ ] Buffering works
- [ ] Metadata displays

### Phase 6 Testing (Optional)
- [ ] Save current playlist as M3U
- [ ] Reload saved M3U → Matches original
- [ ] Metadata preserved in save/load cycle
- [ ] File paths are relative when possible

---

## Test Files Needed

Create these test files in `MacAmpApp/TestData/`:

**1. simple.m3u** (Basic format)
```m3u
song1.mp3
song2.mp3
song3.mp3
```

**2. extended.m3u** (With metadata)
```m3u
#EXTM3U
#EXTINF:211,Artist - Track 1
song1.mp3
#EXTINF:321,Artist - Track 2
song2.mp3
```

**3. radio.m3u** (Internet radio)
```m3u
#EXTM3U
#EXTINF:-1,SomaFM: Groove Salad
http://ice1.somafm.com/groovesalad-256-mp3
#EXTINF:-1,Radio Paradise
http://stream.radioparadise.com/mp3-192
```

**4. mixed.m3u** (Local + Remote)
```m3u
#EXTM3U
#EXTINF:211,Local Song
../Music/song.mp3
#EXTINF:-1,Internet Radio
http://stream.example.com/radio.mp3
```

**5. relative.m3u** (Relative paths)
```m3u
#EXTM3U
#EXTINF:180,Track 1
../Music/track1.mp3
#EXTINF:200,Track 2
../../OtherFolder/track2.mp3
```

---

## Success Criteria

### Must Have (Phases 1-4)
- [x] M3U files selectable in file dialogs
- [ ] M3U files can be opened
- [ ] Local tracks from M3U load into playlist
- [ ] Playback works for loaded tracks
- [ ] Basic error handling
- [ ] Relative paths resolve

### Should Have (Phase 2 + 4)
- [ ] UTI properly declared in Info.plist
- [ ] Finder shows MacAmp for M3U files
- [ ] Extended M3U metadata parsed
- [ ] Internet radio URLs detected (not played yet)

### Nice to Have (Phase 6)
- [ ] M3U export functionality
- [ ] Save current playlist as M3U
- [ ] Metadata preserved

### Future (Phase 5 / P5)
- [ ] Internet radio streams playable
- [ ] Station library integration
- [ ] "Now Playing" metadata

---

## Estimated Total Time

| Phase | Time | Status |
|-------|------|--------|
| Phase 1: Fix Selection | 30 min | ⏸️ Ready |
| Phase 2: UTI Declaration | 15 min | ⏸️ Ready |
| Phase 3: Parser | 2-3 hours | ⏸️ Ready |
| Phase 4: Integration | 1-2 hours | ⏸️ Ready |
| **Total (Critical Path)** | **4-6 hours** | ⏸️ Ready |
| Phase 5: Radio (P5) | (P5 task) | 🔗 Linked |
| Phase 6: Export | 1-2 hours | ⏸️ Optional |

---

## Notes

- **Quick Win:** Phase 1 can be done in 30 minutes
- **Low Risk:** Well-understood problem with clear solution
- **Standards Compliant:** Follows M3U specification
- **Winamp Compatible:** Matches classic Winamp behavior
- **Future-Proof:** Integrates with P5 (Internet Radio)
- **No Breaking Changes:** Additive feature only

---

**Created:** 2025-10-23
**Status:** ✅ Ready for implementation
**Waiting On:** User approval to begin implementation
