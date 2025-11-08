# Repeat Mode Research - Webamp vs Classic Winamp

**Research Date:** 2025-11-07
**Source:** webamp_clone/ codebase analysis
**Question:** How does Webamp implement repeat mode (off/one/all)?

---

## Key Finding: Webamp Only Implements Boolean Repeat (On/Off)

**TL;DR:** Webamp does **NOT** implement the classic Winamp three-state repeat mode (Off/Repeat All/Repeat One). It only has a boolean toggle: repeat on/off.

---

## Implementation Details

### State Management

**File:** `webamp_clone/packages/webamp/js/reducers/media.ts`

```typescript
export interface MediaState {
  timeMode: TimeMode;
  timeElapsed: number;
  volume: number;
  balance: number;
  shuffle: boolean;
  repeat: boolean;  // ⚠️ BOOLEAN, not enum
  status: PlayerMediaStatus;
}

const defaultState = {
  // ...
  repeat: false,
  // ...
};
```

**Reducer:**

```typescript
case "TOGGLE_REPEAT":
  return { ...state, repeat: !state.repeat };
```

Simple boolean flip - no three-state logic.

---

### UI Component

**File:** `webamp_clone/packages/webamp/js/components/MainWindow/Repeat.tsx`

```tsx
const Repeat = memo(() => {
  const repeat = useTypedSelector(Selectors.getRepeat);
  const handleClick = useActionCreator(Actions.toggleRepeat);
  return (
    <ContextMenuWraper
      renderContents={() => (
        <Node
          checked={repeat}
          label="Repeat"
          onClick={handleClick}
          hotkey="(R)"
        />
      )}
    >
      <WinampButton
        id="repeat"
        className={classnames({ selected: repeat })}
        onClick={handleClick}
        title="Toggle Repeat"
      />
    </ContextMenuWraper>
  );
});
```

- Binary state: `selected` or not
- Simple toggle action
- Context menu shows checkmark when enabled

---

### Behavior with Playlist Navigation

**File:** `webamp_clone/packages/webamp/js/selectors.ts:193-226`

```typescript
export const getNextTrackId = (state: AppState, n = 1) => {
  const {
    playlist: { trackOrder },
    media: { repeat, shuffle },
  } = state;

  if (shuffle) {
    return getRandomTrackId(state);
  }

  const trackCount = getTrackCount(state);
  if (trackCount === 0) {
    return null;
  }

  const currentIndex = getCurrentTrackIndex(state);

  let nextIndex = currentIndex + n;

  if (repeat) {
    // 🔁 REPEAT MODE: Wrap around using modulo
    nextIndex = nextIndex % trackCount;
    if (nextIndex < 0) {
      // Handle wrapping around backwards
      nextIndex += trackCount;
    }
    return trackOrder[nextIndex];
  }

  // 🛑 NO REPEAT: Stop at playlist boundaries
  if (currentIndex === trackCount - 1 && n > 0) {
    return null;  // End of playlist going forward
  } else if (currentIndex === 0 && n < 0) {
    return null;  // Start of playlist going backward
  }

  nextIndex = Utils.clamp(nextIndex, 0, trackCount - 1);
  return trackOrder[nextIndex];
};
```

**Behavior:**
- **Repeat ON:** Loops entire playlist (modulo wrapping)
- **Repeat OFF:** Stops at playlist end (returns null)
- **No "Repeat One" logic:** Would need to check if nextIndex === currentIndex and re-queue same track

---

### Sprites Available

**File:** `webamp_clone/packages/webamp/js/skinSprites.ts:530-546`

```typescript
{ name: "MAIN_REPEAT_BUTTON", x: 0, y: 0, width: 28, height: 15 },
{ name: "MAIN_REPEAT_BUTTON_DEPRESSED", x: 0, y: 15, width: 28, height: 15 },
{ name: "MAIN_REPEAT_BUTTON_SELECTED", x: 0, y: 30, width: 28, height: 15 },
{ name: "MAIN_REPEAT_BUTTON_SELECTED_DEPRESSED", x: 0, y: 45, width: 28, height: 15 },
```

Only **two visual states** (normal/selected), not three. Classic Winamp skins don't provide separate sprites for "repeat one" mode.

---

## Classic Winamp Behavior (Historical Reference)

Based on TODO comment in `selectors.ts:177`:

```typescript
// TODO: Sigh... Technically, we should detect if we are looping only repeat if we are.
// I think this would require pre-computing the "random" order of a playlist.
```

This suggests the developer was aware of missing "repeat one" functionality but chose not to implement it.

---

## API Surface

**File:** `webamp_clone/packages/webamp/js/webampLazy.tsx:290-298`

```typescript
/**
 * Check if repeat is enabled.
 */
isRepeatEnabled(): boolean {
  return Selectors.getRepeat(this.store.getState());
}

/**
 * Toggle repeat mode between enabled and disabled.
 */
toggleRepeat(): void {
  this.store.dispatch(Actions.toggleRepeat());
}
```

Public API only exposes binary repeat state.

---

## MacAmp Current State

**File:** `MacAmpApp/Models/AppSettings.swift` (from READY_FOR_NEXT_SESSION.md)

```swift
// Current implementation (Boolean)
var repeatMode: Bool = false {
    didSet {
        UserDefaults.standard.set(repeatMode, forKey: "repeatMode")
    }
}
```

MacAmp mirrors Webamp's boolean approach.

---

## Recommendation: Three-State Repeat Mode for MacAmp

### Why Deviate from Webamp?

1. **Classic Winamp Parity:** Original Winamp 2.x had repeat-one mode
2. **User Expectation:** Modern music players (iTunes, Spotify, etc.) all have repeat-one
3. **UX Improvement:** Repeat-one is essential for studying languages, practicing music, etc.

### Proposed Implementation

#### 1. State Model

```swift
enum RepeatMode: String, Codable {
    case off = "off"
    case all = "all"
    case one = "one"
}

// In AppSettings.swift
var repeatMode: RepeatMode = .off {
    didSet {
        UserDefaults.standard.set(repeatMode.rawValue, forKey: "repeatMode")
    }
}

// Load in init:
if let savedMode = UserDefaults.standard.string(forKey: "repeatMode"),
   let mode = RepeatMode(rawValue: savedMode) {
    self.repeatMode = mode
} else {
    self.repeatMode = .off
}
```

#### 2. Button Behavior

**Click cycling:**
- Click 1: Off → All (button lights up)
- Click 2: All → One (button shows different indicator?)
- Click 3: One → Off (button dims)

**Visual challenge:** Classic skins only have two button states (normal/selected).

**Solutions:**
- **Option A:** Use same "selected" sprite for both All and One, rely on tooltip to show mode
- **Option B:** Add small "1" overlay when in repeat-one mode (like modern players)
- **Option C:** Alternate button brightness/color programmatically

#### 3. Playlist Logic

```swift
// In PlaybackCoordinator or PlaylistManager
func getNextTrackId(offset: Int = 1) -> TrackID? {
    switch appSettings.repeatMode {
    case .off:
        // Stop at playlist boundaries
        let nextIndex = currentIndex + offset
        guard nextIndex >= 0 && nextIndex < playlist.count else {
            return nil
        }
        return playlist[nextIndex]

    case .all:
        // Wrap around using modulo
        let nextIndex = (currentIndex + offset) % playlist.count
        let wrappedIndex = nextIndex < 0 ? nextIndex + playlist.count : nextIndex
        return playlist[wrappedIndex]

    case .one:
        // Always return current track
        return currentTrackId
    }
}
```

#### 4. Keyboard Shortcut

Keep existing `Ctrl+R` but make it cycle through three states:

```swift
// In AppCommands.swift
Button(repeatModeLabel) {
    settings.repeatMode = settings.repeatMode.next()
}
.keyboardShortcut("r", modifiers: [.control])

// RepeatMode extension
extension RepeatMode {
    func next() -> RepeatMode {
        switch self {
        case .off: return .all
        case .all: return .one
        case .one: return .off
        }
    }

    var label: String {
        switch self {
        case .off: return "Repeat: Off"
        case .all: return "Repeat: All"
        case .one: return "Repeat: One"
        }
    }
}
```

#### 5. Context Menu (O Button)

```swift
// In Options menu
Menu {
    Button(action: { settings.repeatMode = .off }) {
        Label("Repeat: Off", systemImage: settings.repeatMode == .off ? "checkmark" : "")
    }
    Button(action: { settings.repeatMode = .all }) {
        Label("Repeat: All", systemImage: settings.repeatMode == .all ? "checkmark" : "")
    }
    Button(action: { settings.repeatMode = .one }) {
        Label("Repeat: One", systemImage: settings.repeatMode == .one ? "checkmark" : "")
    }
}
```

---

## Visual Indicator Challenge

### Problem
Classic Winamp skins only provide two sprite states:
- `MAIN_REPEAT_BUTTON` (off)
- `MAIN_REPEAT_BUTTON_SELECTED` (on)

No third sprite for "repeat one" vs "repeat all".

### Solution Options

#### Option A: Tooltip-Only Distinction (Simplest)
- Off: Unlit button, tooltip "Repeat: Off"
- All: Lit button, tooltip "Repeat: All"
- One: Lit button, tooltip "Repeat: One"

**Pros:** No visual changes, clean implementation
**Cons:** No visual distinction between All/One without hovering

#### Option B: SwiftUI Overlay Badge (Recommended)
```swift
ZStack {
    SimpleSpriteImage(repeatSpriteName, width: 28, height: 15)

    if settings.repeatMode == .one {
        Text("1")
            .font(.system(size: 8, weight: .bold))
            .foregroundColor(.white)
            .offset(x: 8, y: 0)  // Position in corner
    }
}
```

**Pros:** Clear visual distinction, modern UX
**Cons:** Slight deviation from pure skin rendering

#### Option C: Programmatic Brightness (Complex)
- Off: Normal sprite
- All: Selected sprite (full brightness)
- One: Selected sprite + 80% opacity or color tint

**Pros:** Uses only skin sprites
**Cons:** May look inconsistent with skin design

---

## Migration Path

1. **Phase 1:** Change `repeatMode` from `Bool` to `RepeatMode` enum
2. **Phase 2:** Update button click handler to cycle three states
3. **Phase 3:** Update `getNextTrackId()` logic with three behaviors
4. **Phase 4:** Add visual indicator (choose Option A, B, or C)
5. **Phase 5:** Update keyboard shortcut label dynamically
6. **Phase 6:** Update Options menu with three choices

**Estimated Time:** 2-3 hours (including testing)

---

## Testing Scenarios

### Manual Test Cases
1. **Off Mode:** Next button stops at end of playlist
2. **All Mode:** Next button wraps to first track
3. **One Mode:** Next button replays current track
4. **Backward Navigation:** Previous button respects repeat mode
5. **Keyboard Shortcut:** Ctrl+R cycles Off → All → One → Off
6. **Persistence:** Mode survives app restart
7. **Stream Playback:** Repeat-one for radio streams (interesting edge case!)

### Edge Cases
- **Empty Playlist:** All modes return nil
- **Single Track:** Off vs All behave identically, One replays
- **Shuffle + Repeat One:** Shuffle should be ignored (or disabled) in repeat-one mode?

---

## Conclusion

**Webamp does NOT implement three-state repeat mode.**

It uses a simple boolean toggle (off/all), despite classic Winamp supporting repeat-one.

**For MacAmp:** Implementing proper three-state repeat (off/all/one) would:
- ✅ Exceed Webamp's functionality
- ✅ Match modern music player UX
- ✅ Provide better user experience
- ⚠️ Require visual indicator design decision

**Recommended:** Implement three-state with SwiftUI overlay badge (Option B) for clearest UX.

---

## References

- Webamp repeat reducer: `webamp_clone/packages/webamp/js/reducers/media.ts:65-66`
- Webamp next track logic: `webamp_clone/packages/webamp/js/selectors.ts:193-226`
- Webamp repeat component: `webamp_clone/packages/webamp/js/components/MainWindow/Repeat.tsx`
- MacAmp current state: Boolean in `AppSettings.swift`

**Oracle Consultation Recommended:** Verify this approach against Winamp 2.x behavior screenshots/docs.
