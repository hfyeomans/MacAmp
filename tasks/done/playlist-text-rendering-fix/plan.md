# Playlist Text Rendering Fix - Implementation Plan

**Objective:** Replace TEXT.BMP bitmap fonts with real text for playlist track listings
**Scope:** Fix track rendering to match Winamp behavior
**Time:** 30-60 minutes

---

## 🎯 Goal

Replace bitmap font rendering with native SwiftUI Text components styled by PLEDIT.txt colors.

---

## 📐 Implementation Steps

### **Step 1: Replace PlaylistBitmapText with Text** (15 min)

**File:** `MacAmpApp/Views/WinampPlaylistWindow.swift` (lines 266-299)

**Current (WRONG):**
```swift
PlaylistBitmapText(
    "\(track.title) - \(track.artist)",
    color: textColor,
    spacing: 1,
    fallbackSize: 9
)
```

**New (CORRECT):**
```swift
Text("\(track.title) - \(track.artist)")
    .font(.system(size: 9))  // Or .custom(playlistStyle.font, size: 9)
    .foregroundColor(textColor)
    .lineLimit(1)
    .truncationMode(.tail)
```

### **Step 2: Apply PLEDIT.txt Font** (10 min)

**Option A: Use playlistStyle.font if available**
```swift
.font(.custom(playlistStyle.font, size: 9))
```

**Option B: Fallback to system font (simpler)**
```swift
.font(.system(size: 9, design: .monospaced))
```

**Recommendation:** Start with Option B (system font), add custom font support later if needed.

### **Step 3: Update Text Colors** (5 min)

**Already working!** The `trackTextColor()` method correctly returns PLEDIT.txt colors:

```swift
private func trackTextColor(track: Track) -> Color {
    if let currentTrack = audioPlayer.currentTrack, currentTrack.url == track.url {
        return playlistStyle.currentTextColor  // White for current track
    }
    return playlistStyle.normalTextColor  // Green for normal tracks
}
```

### **Step 4: Update Background Colors** (5 min)

**Already working!** The `trackBackground()` method correctly applies selected background:

```swift
private func trackBackground(track: Track, index: Int) -> Color {
    if let currentTrack = audioPlayer.currentTrack, currentTrack.url == track.url {
        return playlistStyle.selectedBackgroundColor
    }
    if selectedTrackIndex == index {
        return playlistStyle.selectedBackgroundColor.opacity(0.6)
    }
    return Color.clear
}
```

### **Step 5: Test** (10 min)

- [ ] Track text renders correctly
- [ ] Current track shows in white
- [ ] Normal tracks show in green
- [ ] Selected tracks show blue background
- [ ] Unicode characters display properly
- [ ] Long titles truncate
- [ ] Test with different skins

---

## 📝 Code Changes

### **Before:**

```swift
HStack(spacing: 2) {
    PlaylistBitmapText("\(index + 1).", color: textColor, ...)
        .frame(width: 18, alignment: .trailing)

    PlaylistBitmapText("\(track.title) - \(track.artist)", color: textColor, ...)
        .frame(maxWidth: .infinity, alignment: .leading)

    PlaylistBitmapText(formatDuration(track.duration), color: textColor, ...)
        .frame(width: 38, alignment: .trailing)
}
```

### **After:**

```swift
HStack(spacing: 2) {
    Text("\(index + 1).")
        .font(.system(size: 9, design: .monospaced))
        .foregroundColor(textColor)
        .frame(width: 18, alignment: .trailing)

    Text("\(track.title) - \(track.artist)")
        .font(.system(size: 9))
        .foregroundColor(textColor)
        .lineLimit(1)
        .frame(maxWidth: .infinity, alignment: .leading)

    Text(formatDuration(track.duration))
        .font(.system(size: 9, design: .monospaced))
        .foregroundColor(textColor)
        .frame(width: 38, alignment: .trailing)
}
```

---

## ✅ Benefits

**After Fix:**
- ✅ Unicode support (accented characters, emoji, etc.)
- ✅ Faster rendering (native text vs sprite lookup)
- ✅ Matches Winamp behavior
- ✅ Better text quality (anti-aliased)
- ✅ Simpler code (no character-by-character sprite positioning)
- ✅ Uses PLEDIT.txt colors correctly

---

## 🎨 TEXT.BMP Correct Usage

**Keep PlaylistBitmapText For:**
- Main window time display ✅
- Playlist info bar time displays (PlaylistTimeText) ✅
- Visualizer text (if any) ✅
- Shade mode displays ✅

**Remove PlaylistBitmapText From:**
- Playlist track listings ❌

---

## 🧪 Testing Plan

### **Visual Verification:**
1. Track text looks clean (not pixelated bitmap)
2. Colors match PLEDIT.txt (green normal, white current)
3. Selected tracks show blue background
4. Long titles truncate with ellipsis

### **Functional Testing:**
1. Unicode artist names display correctly
2. Track info from metadata (title, artist from ID3 tags)
3. Different skins apply different colors
4. Performance is good (no lag with large playlists)

### **Edge Cases:**
1. Missing track metadata (fallback to filename)
2. Very long track titles (truncation works)
3. Special characters in titles
4. Empty playlist

---

## 📦 Files to Modify

**Primary:**
- `MacAmpApp/Views/WinampPlaylistWindow.swift` (lines 266-299)

**Verify Unchanged:**
- `MacAmpApp/Views/Components/PlaylistBitmapText.swift` (still valid for main window)
- `MacAmpApp/Views/Components/PlaylistTimeText.swift` (correct usage)

---

**Status:** Ready for implementation
**Priority:** P2 (Should fix before 1.0 release)
**Time:** 30-60 minutes
