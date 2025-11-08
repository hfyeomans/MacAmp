# Oracle Code Review - Three-State Repeat Mode

**Date:** 2025-11-07
**Oracle Grade:** B- (Solid direction, structural gaps to address)
**Reviewer:** Codex CLI (Oracle)

---

## Summary

The overall direction is solid—upgrading from boolean repeat to a three-state enum matches Winamp 5 behavior and improves UX. However, **critical integration issues** must be resolved before implementation to avoid dual sources of truth and broken playback logic.

---

## Critical Issues Found

### 🔴 MAJOR Issue #1: Two Sources of Truth

**Problem:** Plan creates `AppSettings.repeatMode` enum but doesn't remove `AudioPlayer.repeatEnabled` boolean.

**Impact:** UI toggles AppSettings, but playback logic reads AudioPlayer → settings ignored, broken functionality.

**Current Code:**
- `AudioPlayer.repeatEnabled: Bool` (line 153-159)
- `AudioPlayer.nextTrack()` uses `repeatEnabled` boolean (line 1230-1287)
- Button toggles boolean, not enum

**Plan Assumption:**
- `AppSettings.repeatMode: RepeatMode` enum
- No migration path specified

**Solution:**
```swift
// IN AudioPlayer.swift - REMOVE:
@Published var repeatEnabled: Bool = false

// IN AudioPlayer.swift - ADD:
// Observe AppSettings for repeat mode
var repeatMode: RepeatMode {
    appSettings.repeatMode  // Single source of truth
}

// OR promote to AudioPlayer property:
@Published var repeatMode: RepeatMode = .off {
    didSet {
        appSettings.repeatMode = repeatMode  // Sync to persistence
    }
}
```

**Recommendation:** Promote `repeatMode` to `AudioPlayer`, backed by `AppSettings` for persistence only.

---

### 🔴 MAJOR Issue #2: Navigation Logic Incomplete

**Problem:** Plan proposes new `getNextTrackId()` in hypothetical `PlaylistManager`, but ignores:
- `PlaybackCoordinator` (streams vs local files)
- `currentPlaylistIndex` tracking
- `shuffle` interaction
- Existing `nextTrack()` logic in AudioPlayer.swift:1234-1287

**Impact:** Reimplementing navigation from scratch will:
- Break internet radio streaming
- Desync playlist cursor
- Lose shuffle integration
- Duplicate 50+ lines of working code

**Current nextTrack() Handles:**
```swift
MacAmpApp/Audio/AudioPlayer.swift:1234-1287
- Checks hasNextTrack (boundaries)
- Handles shuffle (random selection)
- Updates currentPlaylistIndex
- Routes streams through PlaybackCoordinator
- Handles local files through AVAudioEngine
- Wraps around if repeatEnabled
```

**Plan's Proposed Logic:**
```swift
// Oversimplified - doesn't handle real-world constraints
func getNextTrackId(offset: Int = 1) -> Track? {
    switch appSettings.repeatMode {
    case .off: return stopAtBoundary()
    case .all: return wrapAround()
    case .one: return currentTrack  // ❌ Doesn't restart playback!
    }
}
```

**Solution:** **Modify existing `nextTrack()`** instead of creating new function.

```swift
// IN AudioPlayer.swift - UPDATE nextTrack()
func nextTrack() {
    switch repeatMode {  // ← Add this switch
    case .off:
        // Use existing hasNextTrack logic
        guard hasNextTrack else { return }
        // ... existing next logic ...

    case .all:
        // Use existing wraparound logic (already present)
        if !hasNextTrack {
            currentPlaylistIndex = 0  // Wrap to start
        } else {
            // ... existing next logic ...
        }

    case .one:
        // Restart current track
        if let current = currentTrack {
            if current.isStream {
                // Route through coordinator
                Task { await coordinator.play(track: current) }
            } else {
                // Seek to beginning
                seek(to: 0, resume: true)
            }
        }
    }
}
```

**Recommendation:** Insert `RepeatMode` switch into `nextTrack()`, reuse existing stream/shuffle/index handling.

---

### 🔴 MAJOR Issue #3: Repeat-One Doesn't Restart Playback

**Problem:** Plan's `.one` case returns `currentTrack` but doesn't trigger playback restart.

**Current Behavior:**
```swift
// previousTrack() shows the right pattern:
MacAmpApp/Audio/AudioPlayer.swift:1310-1320
func previousTrack() {
    seek(to: 0)  // Rewinds to start
}
```

**Plan's Proposed:**
```swift
case .one:
    return currentTrack  // ❌ Just returns reference, doesn't play!
```

**Impact:** Track finishes → returns currentTrack reference → nothing happens → playback stops.

**Solution:** Repeat-one needs to **restart playback**, not just return a reference.

```swift
case .one:
    // For local files: seek to start
    if let current = currentTrack, !current.isStream {
        seek(to: 0, resume: true)
    }
    // For streams: reload through coordinator
    else if let current = currentTrack {
        Task { await coordinator.play(track: current) }
    }
```

**Recommendation:** Repeat-one must actively restart playback on track end.

---

### ⚠️ MINOR Issue #4: Migration Loses User Preference

**Problem:** Plan defaults all migrations to `.off`, but users with `repeatEnabled = true` expect `.all`.

**Current Plan:**
```swift
// plan.md lines 89-91
if let savedMode = UserDefaults.standard.string(forKey: "repeatMode"),
   let mode = RepeatMode(rawValue: savedMode) {
    self.repeatMode = mode
} else {
    self.repeatMode = .off  // ❌ Ignores previous boolean state
}
```

**Impact:** User with repeat ON → upgrades app → repeat becomes OFF → confusing UX.

**Solution:** Migrate boolean to equivalent enum value.

```swift
// Backward-compatible migration
if let savedMode = UserDefaults.standard.string(forKey: "repeatMode"),
   let mode = RepeatMode(rawValue: savedMode) {
    self.repeatMode = mode
} else {
    // Migrate from old boolean key
    let oldRepeat = UserDefaults.standard.bool(forKey: "repeatEnabled")  // or whatever key
    self.repeatMode = oldRepeat ? .all : .off
}
```

**Recommendation:** Map `true → .all`, `false → .off` to preserve user expectations.

---

### ⚠️ MINOR Issue #5: Badge May Not Be Pixel-Perfect

**Problem:** SwiftUI `Text` with `.font(.system(size: 8))` anti-aliases, scales non-uniformly, may clip.

**Plan's Approach:**
```swift
Text("1")
    .font(.system(size: 8, weight: .bold))
    .foregroundColor(.white)
    .shadow(color: .black.opacity(0.8), radius: 1, x: 0, y: 0)
    .offset(x: 8, y: 0)  // ⚠️ Not tied to double-size mode
```

**Issues:**
- Text anti-aliases differently per display scale
- Offset `x:8, y:0` doesn't adapt to double-size mode (2x scaling)
- Not pixel-perfect like sprite-based UI

**Winamp 5 Approach:** Pre-rendered sprite glyph for "1" badge.

**Acceptable Prototype:** Current Text approach works for MVP.

**Production Recommendation:**
1. **Option A:** Create sprite "REPEAT_ONE_BADGE.bmp" (8×8px white "1")
2. **Option B:** Render Text at exact pixel coordinates, snap to integers
3. **Option C:** Use bitmap font through `SimpleSpriteImage`

**For Double-Size Compatibility:**
```swift
// Tie offset to button coordinates
.offset(
    x: Coords.repeatButton.x + 20,  // Top-right corner
    y: Coords.repeatButton.y - 2
)
```

**Recommendation:** Ship with Text for MVP, upgrade to sprite if fidelity matters.

---

## Answers to Key Questions

### 1. Enum Design

**Q:** Is `RepeatMode` well-designed? Should we use `CaseIterable`?

**A:** ✅ Enum is good. **Add `CaseIterable`** for safer cycling:

```swift
enum RepeatMode: String, Codable, CaseIterable {  // ← Add CaseIterable
    case off, all, one

    func next() -> RepeatMode {
        let cases = Self.allCases
        guard let index = cases.firstIndex(of: self) else { return self }
        let nextIndex = (index + 1) % cases.count
        return cases[nextIndex]
    }

    var isActive: Bool {  // ← Add computed property
        self != .off
    }
}
```

**Benefit:** If you add `.count` mode later, `next()` automatically includes it.

---

### 2. Playlist Navigation Logic

**Q:** Review proposed `getNextTrackId()` switch statement.

**A:** ❌ **Don't create new function.** Modify existing `nextTrack()` to avoid:
- Duplicating stream/shuffle logic
- Breaking PlaybackCoordinator integration
- Losing `currentPlaylistIndex` tracking

**Edge Cases to Handle:**
- Empty playlist: All modes return early (already handled)
- Single track: Off stops, All replays, One replays
- Shuffle + Repeat One: **Disable shuffle** or document that One takes precedence

**Recommendation:** Insert `RepeatMode` switch at top of `nextTrack()`, reuse rest.

---

### 3. Visual Indicator (Badge Overlay)

**Q:** Is ZStack + Text the right approach?

**A:** ✅ **Acceptable for MVP**, but:
- Text will anti-alias (not pixel-perfect)
- Offset doesn't scale with double-size mode
- Sprite would be more authentic

**Badge Positioning:** `x:8, y:0` is reasonable starting point.
**Shadow:** `radius: 1, opacity: 0.8` sufficient for most skins.

**If Sony MP3 (white skin) fails:** Increase radius to 1.5 or use outlined text.

---

### 4. Integration with Existing Code

**Q:** Where should repeat logic live?

**A:** **Keep in `AudioPlayer`** because:
- It's already next to shuffle, `trackHasEnded`, coordinator hooks
- Avoids cross-object state synchronization
- All audio logic in one place

**Pattern:**
```swift
// AppSettings: Persistence only
var repeatMode: RepeatMode = .off {
    didSet { UserDefaults... }
}

// AudioPlayer: Authoritative state (injected from AppSettings)
@Published var repeatMode: RepeatMode {
    get { appSettings.repeatMode }
    set { appSettings.repeatMode = newValue }
}
```

**Threading:** Already `@MainActor`, no new concerns.

---

### 5. Winamp 5 Accuracy

**Q:** Does single enum deviate from Winamp 5 problematically?

**A:** ✅ **No, this is better UX.**

**Winamp 5 Classic:** Repeat ON + MPA ON = Repeat One (confusing)
**Winamp 5 Modern Skins:** Three-state button (what we're doing)
**Modern Players:** iTunes, Spotify, etc. all use three-state

**Your approach matches Winamp 5 Modern + industry standard.**

---

### 6. Potential Bugs

**Q:** What could go wrong?

**A:**
- ✅ **Threading:** Already `@MainActor`, safe
- ✅ **Security:** No injection/memory issues
- ⚠️ **Performance:** ZStack adds minimal overhead
- ⚠️ **Race Conditions:** Guard against `currentTrack == nil` in repeat-one
- ⚠️ **State Drift:** Unit test persistence round-trip

**Specific Checks:**
```swift
// Guard in repeat-one case
case .one:
    guard let current = currentTrack else { return }  // ← Don't crash
    // ... restart playback ...
```

**Swift 6 / @Observable:** No issues if you keep state in AudioPlayer.

---

## Recommendations Summary

### Must Fix Before Implementation

1. ✅ **Promote `repeatMode` to `AudioPlayer`** (single source of truth)
2. ✅ **Modify existing `nextTrack()`** (don't create new function)
3. ✅ **Repeat-one must restart playback** (seek to 0 or reload stream)
4. ✅ **Migrate `true → .all`, `false → .off`** (preserve user preference)

### Nice to Have

5. ⚠️ **Use sprite for badge** (better pixel accuracy)
6. ⚠️ **Add `CaseIterable` to enum** (safer future-proofing)
7. ⚠️ **Unit tests** for repeat logic across scenarios

---

## Final Grade: B-

**Why B- not A:**
- Major integration gaps (dual state, missing playback restart)
- Navigation logic reinvents wheel instead of reusing existing code
- Migration plan loses user preference

**Why not lower:**
- Enum design is sound
- Research is thorough
- Visual approach matches Winamp 5
- Overall direction is correct

**Path to A:**
1. Fix dual state (10 min)
2. Use existing nextTrack() (20 min)
3. Add playback restart to repeat-one (15 min)
4. Fix migration (5 min)

**Estimated fix time:** 50 minutes

---

## Updated Implementation Plan

### Revised Phase 1: Data Model (20 minutes)

**File:** `MacAmpApp/Audio/AudioPlayer.swift`

1. **REMOVE existing boolean:**
```swift
// DELETE:
@Published var repeatEnabled: Bool = false
```

2. **ADD enum with computed property:**
```swift
// ADD after shuffle property:
@Published var repeatMode: RepeatMode {
    get { appSettings.repeatMode }
    set { appSettings.repeatMode = newValue }
}
```

3. **Update AppSettings.swift:**
```swift
enum RepeatMode: String, Codable, CaseIterable {
    case off, all, one

    func next() -> RepeatMode {
        let cases = Self.allCases
        guard let index = cases.firstIndex(of: self) else { return self }
        return cases[(index + 1) % cases.count]
    }

    var label: String {
        switch self {
        case .off: return "Repeat: Off"
        case .all: return "Repeat: All"
        case .one: return "Repeat: One"
        }
    }

    var isActive: Bool { self != .off }
}

var repeatMode: RepeatMode = .off {
    didSet {
        UserDefaults.standard.set(repeatMode.rawValue, forKey: "repeatMode")
    }
}

// In init():
if let savedMode = UserDefaults.standard.string(forKey: "repeatMode"),
   let mode = RepeatMode(rawValue: savedMode) {
    self.repeatMode = mode
} else {
    // Migrate from old boolean
    let oldRepeat = UserDefaults.standard.bool(forKey: "audioPlayerRepeatEnabled")
    self.repeatMode = oldRepeat ? .all : .off
}
```

---

### Revised Phase 2: Navigation Logic (30 minutes)

**File:** `MacAmpApp/Audio/AudioPlayer.swift`

**Modify existing `nextTrack()` function:**

```swift
func nextTrack() {
    // INSERT AT TOP:
    switch repeatMode {
    case .off:
        // Use existing hasNextTrack check
        guard hasNextTrack else {
            stop()
            return
        }
        // Fall through to existing logic below

    case .all:
        // Wrap around if at end
        if !hasNextTrack {
            currentPlaylistIndex = 0
        }
        // Fall through to existing logic below

    case .one:
        // Restart current track
        guard let current = currentTrack else { return }
        if current.isStream {
            Task { @MainActor [weak self] in
                await self?.coordinator?.play(track: current)
            }
        } else {
            seek(to: 0, resume: true)
        }
        return  // Don't advance playlist
    }

    // ... rest of existing nextTrack() logic ...
}
```

**Add to `previousTrack()` if needed (already seeks to 0):**

```swift
func previousTrack() {
    // Repeat-one: just rewind (existing behavior is correct)
    if repeatMode == .one {
        seek(to: 0)
        return
    }

    // ... rest of existing previousTrack() logic ...
}
```

---

### Revised Phase 3: UI Button (15 minutes)

**File:** `MacAmpApp/Views/WinampMainWindow.swift`

**Update repeat button (around line 431):**

```swift
Button(action: {
    audioPlayer.repeatMode = audioPlayer.repeatMode.next()
}) {
    let isActive = audioPlayer.repeatMode.isActive
    let spriteKey = isActive ? "MAIN_REPEAT_BUTTON_SELECTED" : "MAIN_REPEAT_BUTTON"

    ZStack {
        SimpleSpriteImage(spriteKey, width: 28, height: 15)

        if audioPlayer.repeatMode == .one {
            Text("1")
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.8), radius: 1, x: 0, y: 0)
                .offset(x: 8, y: 0)
        }
    }
}
.buttonStyle(.plain)
.help(audioPlayer.repeatMode.label)
```

---

## Conclusion

**Oracle's Verdict:** Implementation plan is **structurally sound** but needs **critical integration fixes** before coding.

**With these changes:**
- ✅ Single source of truth (AudioPlayer)
- ✅ Reuses existing navigation logic
- ✅ Properly restarts playback in repeat-one
- ✅ Preserves user preferences during migration
- ✅ Matches Winamp 5 Modern behavior

**Grade after fixes:** Estimated **A-** (production-ready)

**Ready to implement:** After updating plan.md with Oracle's recommendations.
