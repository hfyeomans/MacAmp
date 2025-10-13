# Test Skin Download Guide

**Source:** https://skins.webamp.org/

---

## 🎯 Recommended Test Skins

### Download these 10 diverse skins for comprehensive testing:

1. **Bento** - Modern minimalist design
   - URL: Search "Bento" on skins.webamp.org
   - Era: 2000s modern
   - Complexity: Medium

2. **MMD3** - Classic popular skin
   - Search: "MMD3"
   - Era: 1990s classic
   - Complexity: High

3. **Nucleo NLog v102** - Complex modern skin
   - Search: "Nucleo NLog"
   - Era: 2000s
   - Complexity: High

4. **Vizor** - Unique design
   - Search: "Vizor"
   - Era: 2000s
   - Complexity: Medium

5. **XMMS Turquoise** - Cross-platform variant
   - Search: "XMMS Turquoise"
   - Era: 2000s
   - Complexity: Low

6. **Skinner** - Vintage classic
   - Search: "Skinner"
   - Era: 1990s
   - Complexity: Medium

7. **Midnight** - Dark theme
   - Search: "Midnight"
   - Era: 2000s
   - Complexity: Medium

8. **Energy Amplifier** - Most downloaded classic
   - Search: "Energy Amplifier"
   - Era: 1990s
   - Popularity: #1 most downloaded

9. **Sony wx-5500mdx** - Hardware replica
   - Search: "Sony wx-5500mdx"
   - Era: 1990s
   - Popularity: #2 most downloaded

10. **Any modern 2020s skin** - Recent design
    - Browse recent uploads
    - Look for upload date 2020+
    - Test modern design patterns

---

## 📥 Download Process

### Via skins.webamp.org:

1. Go to https://skins.webamp.org/
2. Search for skin name in search box
3. Click on skin to preview
4. Look for download link (usually .wsz file)
5. Save to: `/Users/hank/dev/src/MacAmp/tasks/phase4-semantic-migration/test-skins/`

### Expected Structure:
```
test-skins/
├── bento.wsz
├── mmd3.wsz
├── nucleo-nlog-v102.wsz
├── vizor.wsz
├── xmms-turquoise.wsz
├── skinner.wsz
├── midnight.wsz
├── energy-amplifier.wsz
├── sony-wx-5500mdx.wsz
└── modern-skin-2024.wsz
```

---

## 🔍 What to Check for Each Skin

### 1. Sprite Sheet Presence:
```bash
unzip -l skinname.wsz | grep -i ".bmp"
```

**Expected Files:**
- MAIN.bmp (or main.bmp)
- CBUTTONS.bmp (or cbuttons.bmp)
- NUMBERS.bmp OR NUMS_EX.bmp
- SHUFREP.bmp
- TITLEBAR.bmp
- VOLUME.bmp
- BALANCE.bmp
- EQMAIN.bmp

### 2. Extract for Analysis:
```bash
unzip skinname.wsz -d test-skins/skinname-extracted/
```

### 3. Test in MacAmp:
- Open MacAmp
- Skins → Import
- Select downloaded .wsz
- Test ALL buttons:
  - Transport: Previous, Play, Pause, Stop, Next, Eject
  - Window: Minimize, Shade, Close
  - Features: EQ, Playlist, Shuffle, Repeat
  - Sliders: Volume, Balance, Position
  - Equalizer: All sliders, On/Auto, Presets

### 4. Monitor Console:
- Look for "missing sprite" or "sprite not found" errors
- Note which sprites fail (if any)
- Document sprite name being requested

---

## 📊 Results Template

### For Each Skin Create:

**File:** `test-skins/skinname-results.md`

```markdown
# Test Results: [Skin Name]

**Downloaded From:** skins.webamp.org
**File Size:** [size]
**Era:** [1990s/2000s/2010s/2020s]

## Sprite Sheets Present:
- [ ] MAIN.bmp
- [ ] CBUTTONS.bmp
- [ ] NUMBERS.bmp
- [ ] NUMS_EX.bmp
- [ ] SHUFREP.bmp
- [ ] Others: ___

## Button Functionality:
### Transport Buttons:
- [ ] Previous works
- [ ] Play works
- [ ] Pause works
- [ ] Stop works
- [ ] Next works
- [ ] Eject works

### Window Buttons:
- [ ] Minimize works
- [ ] Shade works
- [ ] Close works

### Feature Buttons:
- [ ] EQ works
- [ ] Playlist works
- [ ] Shuffle works
- [ ] Repeat works

### Sliders:
- [ ] Volume slider renders correctly
- [ ] Balance slider renders correctly
- [ ] Position slider renders correctly
- [ ] EQ sliders render correctly

### Indicators:
- [ ] Playing indicator shows
- [ ] Paused indicator shows
- [ ] Stopped indicator shows
- [ ] Mono/Stereo indicators work

## Console Errors:
```
[Paste any sprite errors here]
```

## Sprite Name Variants Found:
```
[List any non-standard sprite names]
```

## Overall Assessment:
- ✅ Fully functional
- ⚠️ Partial issues
- ❌ Major problems

## Notes:
[Any observations]
```

---

## 🎯 Success Metrics

**Phase 4 NOT Needed IF:**
- 10/10 skins work perfectly
- No sprite resolution errors
- All sprite names match expected patterns
- Only NUMS_EX variants found (already handled)

**Phase 4 IS Needed IF:**
- <7/10 skins work
- Multiple sprite name variants discovered
- Console shows missing sprite errors
- Non-digit sprite variations found

---

**Status:** Ready for download and testing
**Location:** tasks/phase4-semantic-migration/test-skins/
**Next:** Download skins and begin testing
