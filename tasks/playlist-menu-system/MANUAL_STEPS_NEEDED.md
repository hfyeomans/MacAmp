# Manual Steps Required - ADD Menu Integration

## ⚠️ Action Needed: Add New Files to Xcode Project

The new Swift component files exist but need to be added to the Xcode project target.

### **Files to Add:**

1. `MacAmpApp/Views/Components/SpriteMenuItem.swift`
2. `MacAmpApp/Views/Components/PlaylistMenuButton.swift`

### **How to Add (in Xcode):**

**Option A: Via Xcode UI**
1. Open `MacAmpApp.xcodeproj` in Xcode
2. Right-click on `MacAmpApp/Views/Components` folder
3. Select "Add Files to MacAmpApp..."
4. Select both files:
   - SpriteMenuItem.swift
   - PlaylistMenuButton.swift
5. Ensure "MacAmp" target is checked
6. Click "Add"
7. Build (Cmd+B)

**Option B: Via Command Line** (Simpler)

Since the files are already in the correct directory structure, Xcode should auto-discover them on next project load. Try:

```bash
# Close Xcode if open
# Then reopen the project
open MacAmpApp.xcodeproj
```

### **Verify Files Are Added:**

After adding, verify in Xcode:
- Files appear in the Navigator (left sidebar) under Views/Components
- Files have the "MacAmp" target membership (checkmark in File Inspector)
- Build succeeds without "cannot find" errors

---

## 🧪 Testing the ADD Menu (After Files Added)

### **Step 1: Build and Launch**

```bash
./scripts/quick-install.sh
```

### **Step 2: Open Playlist Window**

In MacAmp:
- Click the "PL" button (playlist button on main window)
- Or use menu: Windows → Playlist

### **Step 3: Test ADD Menu**

**Click the ADD button** (bottom-left corner of playlist window)

**Expected behavior:**
1. ✅ Popup menu appears above the button
2. ✅ Menu shows 3 sprite-based items:
   - ADD URL (top)
   - ADD DIR (middle)
   - ADD FILE (bottom)
3. ✅ Hover over items → sprites change from light to dark grey
4. ✅ Click "ADD FILE" → file picker opens
5. ✅ Click "ADD DIR" → directory picker opens
6. ✅ Click "ADD URL" → info dialog appears (placeholder)
7. ✅ Click outside menu → menu closes

### **Step 4: Verify Sprites**

**While menu is open:**
- Menu items should show sprite graphics (not text)
- Hovering should swap sprites (lighter → darker grey)
- Each item should be 22×18 pixels
- Menu should look like original Winamp

### **Step 5: Test Actions**

**ADD FILE:**
- Should open file picker
- Select MP3 file(s)
- Files should be added to playlist

**ADD DIR:**
- Should open directory picker
- Select folder with music
- All audio files in folder should be added

**ADD URL:**
- Should show "not yet implemented" dialog
- (We'll implement URL input later)

---

## 🐛 Troubleshooting

### **Menu Doesn't Appear:**
- Check console for errors
- Verify SkinManager in environment
- Check button position is correct

### **Sprites Don't Show:**
- Verify sprite names match SkinSprites.swift
- Check skin is loaded properly
- Verify SimpleSpriteImage works

### **Hover Doesn't Change Sprites:**
- Verify NSTrackingArea is working
- Check mouseEntered/Exited fire
- May need to adjust tracking area setup

---

## 📝 Current Implementation Status

**Implemented:**
- ✅ SpriteMenuItem with hover detection
- ✅ PlaylistMenuButton with NSMenu
- ✅ ADD menu actions (URL placeholder, Dir fully functional, File reuses existing)
- ✅ Sprite definitions (32 sprites all correct)

**Not Yet Implemented:**
- ⏳ REM menu integration
- ⏳ SEL menu integration
- ⏳ MISC menu integration
- ⏳ LIST menu integration
- ⏳ Multi-track selection state
- ⏳ M3U export functionality
- ⏳ URL input dialog

**Blocked On:**
- ⚠️ Need to add new Swift files to Xcode project target

---

## ✅ Next Steps After Files Added

1. Build succeeds
2. Test ADD menu functionality
3. Fix any issues found
4. Commit ADD menu POC
5. Continue with remaining menus (REM, SEL, MISC, LIST)
