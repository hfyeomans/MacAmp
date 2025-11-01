# Playlist Text Rendering Fix - Research

**Date:** 2025-10-25
**Issue:** MacAmp uses TEXT.BMP bitmap fonts for playlist tracks (incorrect)
**Priority:** P2 (Enhancement - affects UX and skin compatibility)

---

## 🐛 Problem Statement

**Current MacAmp Implementation (INCORRECT):**
- Uses `PlaylistBitmapText` component for track listings
- Renders track numbers, titles, artists, durations using TEXT.BMP sprites
- Lines 269, 278, 288 in WinampPlaylistWindow.swift

**Correct Winamp Behavior:**
- Playlist track text uses **real text rendering** (HTML/native fonts)
- TEXT.BMP is used ONLY for:
  - Main window time display
  - Playlist shade mode title/time
  - NOT for track listings

---

## ✅ Webamp Implementation (Correct Reference)

### **Track Text Rendering: HTML `<span>` Elements**

**File:** `webamp_clone/packages/webamp/js/components/PlaylistWindow/TrackTitle.tsx`

```typescript
const TrackTitle = ({ id, paddedTrackNumber }: Props) => {
  const title = useTypedSelector(Selectors.getTrackDisplayName)(id);
  return (
    <span>
      {paddedTrackNumber}. {title}
    </span>
  );
};
```

**Plain HTML text** - no bitmap sprites!

### **PLEDIT.txt Color Styling**

**File:** `webamp_clone/packages/webamp/js/components/PlaylistWindow/TrackCell.tsx` (lines 20-45)

```typescript
function TrackCell({ children, index, id }: Props) {
  const skinPlaylistStyle = useTypedSelector(Selectors.getSkinPlaylistStyle);
  const selectedTrackIds = useTypedSelector(Selectors.getSelectedTrackIdsSet);
  const currentTrackId = useTypedSelector(Selectors.getCurrentTrackId);

  const selected = selectedTrackIds.has(id);
  const current = currentTrackId === id;

  const style: React.CSSProperties = {
    backgroundColor: selected ? skinPlaylistStyle.selectedbg : undefined,
    color: current ? skinPlaylistStyle.current : undefined,
  };

  return (
    <div
      className={classnames("track-cell", { selected, current })}
      style={style}
    >
      {children}
    </div>
  );
}
```

### **PLEDIT.txt Properties**

**From:** `webamp_clone/packages/webamp/js/types.ts` (lines 93-99)

```typescript
export interface PlaylistStyle {
  normal: string;      // Normal track text color (default: "#00FF00" - green)
  current: string;     // Current playing track text color (default: "#FFFFFF" - white)
  normalbg: string;    // Normal background color (default: "#000000" - black)
  selectedbg: string;  // Selected track background color (default: "#0000FF" - blue)
  font: string;        // Font family name (default: "Arial")
}
```

### **Styling Rules**

| Track State | Text Color | Background Color | PLEDIT.txt Property |
|-------------|------------|------------------|---------------------|
| **Normal** | `normal` (#00FF00 green) | transparent | `normal="#00FF00"` |
| **Current Playing** | `current` (#FFFFFF white) | transparent | `current="#FFFFFF"` |
| **Selected** | `normal` (green) | `selectedbg` (#0000FF blue) | `selectedbg="#0000FF"` |
| **Selected + Current** | `current` (white) | `selectedbg` (blue) | Both applied |

---

## 📊 TEXT.BMP Usage Comparison

### **Webamp (Correct):**

**TEXT.BMP Used For:**
- ✅ Shade mode track title/time (`CharacterString` component)
- ✅ Running time displays in info bars
- ❌ **NOT** for track listings

**Real Text Used For:**
- ✅ Playlist track numbers
- ✅ Playlist track titles/artists
- ✅ Playlist track durations
- ✅ All track metadata display

### **MacAmp (Current - Incorrect):**

**TEXT.BMP Used For:**
- ✅ Main window time displays (correct)
- ❌ **Playlist track numbers** (WRONG - should be real text)
- ❌ **Playlist track titles/artists** (WRONG - should be real text)
- ❌ **Playlist track durations** (WRONG - should be real text)

---

## 🔍 MacAmp Current Implementation Analysis

**File:** `MacAmpApp/Views/WinampPlaylistWindow.swift` (lines 266-299)

```swift
private func trackRow(track: Track, index: Int) -> some View {
    let textColor = trackTextColor(track: track)
    HStack(spacing: 2) {
        // ❌ WRONG: Using bitmap font for track number
        PlaylistBitmapText(
            "\(index + 1).",
            color: textColor,
            spacing: 1,
            fallbackSize: 9
        )

        // ❌ WRONG: Using bitmap font for track info
        PlaylistBitmapText(
            "\(track.title) - \(track.artist)",
            color: textColor,
            spacing: 1,
            fallbackSize: 9
        )

        // ❌ WRONG: Using bitmap font for duration
        PlaylistBitmapText(
            formatDuration(track.duration),
            color: textColor,
            spacing: 1,
            fallbackSize: 9
        )
    }
}
```

**Problems:**
1. Limited character set (TEXT.BMP only has ASCII)
2. Can't display Unicode (artist names with accents, etc.)
3. Slower rendering (sprite lookup per character)
4. Doesn't match Winamp behavior
5. Ignores PLEDIT.txt font property

---

## ✅ Correct Implementation (Should Be)

```swift
private func trackRow(track: Track, index: Int) -> some View {
    let textColor = trackTextColor(track: track)
    let bgColor = trackBackground(track: track, index: index)

    HStack(spacing: 2) {
        // ✅ CORRECT: Real SwiftUI Text
        Text("\(index + 1).")
            .font(.custom(playlistStyle.font, size: 9))
            .foregroundColor(textColor)
            .frame(width: 18, alignment: .trailing)

        // ✅ CORRECT: Real text with track metadata
        Text("\(track.title) - \(track.artist)")
            .font(.custom(playlistStyle.font, size: 9))
            .foregroundColor(textColor)
            .frame(maxWidth: .infinity, alignment: .leading)
            .lineLimit(1)

        // ✅ CORRECT: Real text for duration
        Text(formatDuration(track.duration))
            .font(.custom(playlistStyle.font, size: 9))
            .foregroundColor(textColor)
            .frame(width: 38, alignment: .trailing)
    }
    .background(bgColor)
}
```

---

## 🎨 PLEDIT.txt Color Application

### **MacAmp Already Has PlaylistStyle:**

**From:** `MacAmpApp/Models/Skin.swift` (lines 26-32)

```swift
struct PlaylistStyle {
    let normalTextColor: Color
    let currentTextColor: Color
    let normalBackgroundColor: Color
    let selectedBackgroundColor: Color
}
```

**These colors are already parsed from PLEDIT.txt!** (via PLEditParser.swift)

The colors just need to be applied to **real Text** instead of bitmap sprites.

---

## 🔧 Implementation Plan

### **What to Change:**

1. **Replace PlaylistBitmapText with SwiftUI Text**
2. **Apply PLEDIT.txt colors via `.foregroundColor()`**
3. **Apply PLEDIT.txt font via `.font(.custom(playlistStyle.font, size: 9))`**
4. **Keep PlaylistBitmapText for:**
   - Main window time displays (correct usage)
   - Playlist shade mode (if implemented)

### **Benefits:**

✅ Unicode support (accented characters, emoji, etc.)
✅ Faster rendering (native text vs sprite lookup)
✅ Matches Winamp behavior exactly
✅ Uses PLEDIT.txt font property
✅ Cleaner code (no character-by-character sprite rendering)

---

## 📝 Files to Modify

**Primary:**
1. `MacAmpApp/Views/WinampPlaylistWindow.swift`
   - Lines 266-299: trackRow() function
   - Replace PlaylistBitmapText with Text
   - Apply playlistStyle colors and font

**Verify Unchanged:**
2. `MacAmpApp/Views/Components/PlaylistBitmapText.swift`
   - Keep for main window usage
   - Still valid for time displays

3. `MacAmpApp/Views/Components/PlaylistTimeText.swift`
   - Keep for playlist info bar time displays
   - This is correct usage of bitmap fonts

---

## ⏰ Estimated Time

**Simple Fix:** 30 minutes
- Replace 3 PlaylistBitmapText with 3 Text components
- Apply colors from playlistStyle
- Test with multiple skins

**With Font Support:** 1 hour
- Add font loading/registration if custom fonts needed
- Fallback to system font if PLEDIT.txt font unavailable
- Handle font edge cases

---

## 🧪 Testing Requirements

**After Fix:**
1. Track text renders correctly
2. Current track shows in white (PLEDIT.txt `current` color)
3. Normal tracks show in green (PLEDIT.txt `normal` color)
4. Selected tracks show blue background (PLEDIT.txt `selectedbg`)
5. Unicode characters display (test with accented artist names)
6. Long titles truncate properly
7. Different skins apply different colors

---

## 📚 References

**Webamp Files:**
- `webamp_clone/packages/webamp/js/skinParserUtils.ts:154-186` - PLEDIT.txt parser
- `webamp_clone/packages/webamp/js/components/PlaylistWindow/TrackCell.tsx` - Track styling
- `webamp_clone/packages/webamp/js/components/PlaylistWindow/TrackTitle.tsx` - Track title rendering
- `webamp_clone/packages/webamp/js/types.ts:93-99` - PlaylistStyle interface

**MacAmp Files:**
- `MacAmpApp/Models/Skin.swift:26-32` - PlaylistStyle (already correct!)
- `MacAmpApp/ViewModels/PLEditParser.swift` - PLEDIT.txt parser (working)
- `MacAmpApp/Views/WinampPlaylistWindow.swift:266-299` - Track row (needs fix)

---

**Research Status:** ✅ COMPLETE
**Next:** Create implementation plan
