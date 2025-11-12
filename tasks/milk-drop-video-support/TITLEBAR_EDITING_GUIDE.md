# Milkdrop Titlebar Manual Editing Guide

## File: MacAmpApp/Views/WinampMilkdropWindow.swift

### Letter Positioning (Lines 221-235)

**MILKDROP text X position**: Line 235
```swift
.position(x: 256, y: 10)  // ← Change x: 256 to move letters left/right
```

- Increase X to move letters RIGHT
- Decrease X to move letters LEFT
- Current: X=256 (center of 512px window)

**Letter Y position**: Line 235
```swift
.position(x: 256, y: 10)  // ← Change y: 10 to move letters up/down
```

- Increase Y to move letters DOWN
- Decrease Y to move letters UP  
- Current: Y=10 (middle of 20px titlebar)

### Titlebar Tile Positions

**Left fill tiles** (Lines 195-198):
```swift
ForEach(0..<8, id: \.self) { i in
    SimpleSpriteImage("GEN_TOP_CENTER_FILL\(suffix)", width: 25, height: 20)
        .position(x: 50 + 12.5 + CGFloat(i) * 25, y: 10)
        //        ^^^ Start  ^^^^ Half-tile  ^^^^^^^^ Increment
}
```

**To add more left tiles**: Change `0..<8` to `0..<12` (line 195)
**To move left tiles**: Change `x: 50` starting position

**Right fill tiles** (Lines 203-206):
```swift
ForEach(0..<7, id: \.self) { i in
    SimpleSpriteImage("GEN_TOP_CENTER_FILL\(suffix)", width: 25, height: 20)
        .position(x: 280 + 12.5 + CGFloat(i) * 25, y: 10)
        //        ^^^ Start position (after letters)
}
```

**To add more right tiles**: Change `0..<7` to `0..<10` (line 203)
**To move right tiles closer to letters**: Change `x: 280` starting position

### Tile Layout Calculation

Window width: **512px**

Current layout:
```
[Left corner] [Left end] [8 left tiles] [MILKDROP] [7 right tiles] [Right end] [Right corner]
   25px         25px      8×25=200px      49px       7×25=175px      25px         25px
```

Total: 25+25+200+49+175+25+25 = 524px (overlapping by 12px - intentional for seamless look)

### Quick Fixes

**If tiles don't fill width**:
- Line 195: Increase left tiles `0..<15`
- Line 203: Increase right tiles `0..<15`

**If tiles overlap letters**:
- Line 197: Increase start X `x: 60 + ...` (move left tiles further left)
- Line 205: Increase start X `x: 300 + ...` (move right tiles further right)

**If letters too high/low**:
- Line 235: Adjust Y value (current: 10)

### Two-Piece Letter System

Each letter renders as VStack (lines 244-248):
```swift
VStack(spacing: 0) {
    SimpleSpriteImage("\(prefix)\(letter)_TOP", width: width, height: 4)    // Top 4px
    SimpleSpriteImage("\(prefix)\(letter)_BOTTOM", width: width, height: 3) // Bottom 3px
}
// Total: 7px tall complete letter
```

Letters used: M, I, L, K, D, R, O, P (8 letters)
Each has: _TOP and _BOTTOM sprites
Each has: SELECTED and normal states
Total: 32 letter sprites (8×2×2)
