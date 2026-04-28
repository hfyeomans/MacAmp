# Plan: Branded DMG Installer

> **Description:** Implementation plan for creating a professional branded DMG installer.
> **Purpose:** Step-by-step guide for designing, building, and notarizing a branded DMG.

---

## Steps

### 1. Design Background Image

Create a PNG background image (~600x400px) with:
- MacAmp logo/icon prominently displayed
- "INSTALLATION" or "Install MacAmp" banner
- "Drag MacAmp.app to the Applications shortcut" instruction text
- Arrow graphic pointing from app icon position to Applications position
- Dark theme matching MacAmp/Winamp aesthetic

Tool: Figma, Photoshop, or similar. Export as PNG.

### 2. Install create-dmg

```bash
brew install create-dmg
```

### 3. Build the DMG

```bash
create-dmg \
  --volname "MacAmp" \
  --volicon "MacAmpApp/Assets.xcassets/AppIcon.appiconset/icon_512x512.png" \
  --background "assets/dmg-background.png" \
  --window-pos 200 120 \
  --window-size 600 400 \
  --icon-size 100 \
  --icon "MacAmp.app" 175 275 \
  --hide-extension "MacAmp.app" \
  --app-drop-link 425 275 \
  "dist/MacAmp-VERSION.dmg" \
  "dist/"
```

Icon positions (175, 275) and (425, 275) should align with the arrow in the background image. Adjust coordinates after testing with the actual background.

### 4. Notarize the DMG

```bash
xcrun notarytool submit dist/MacAmp-VERSION.dmg \
  --keychain-profile "notarytool-password" --wait
xcrun stapler staple dist/MacAmp-VERSION.dmg
```

### 5. Verify

```bash
hdiutil attach dist/MacAmp-VERSION.dmg -readonly
# Visually verify: background, icon positions, drag-to-install layout
spctl -a -vv /Volumes/MacAmp/MacAmp.app
# Should show: accepted, source=Notarized Developer ID
hdiutil detach /Volumes/MacAmp
```

### 6. Update Release Script

Add the branded DMG step to the release process in `docs/RELEASE_BUILD_GUIDE.md` and `BUILDING_RETRO_MACOS_APPS_SKILL.md`.

## Success Criteria

- DMG opens with branded background showing MacAmp logo
- App icon and Applications shortcut positioned over the arrow graphic
- Drag-to-install workflow works
- DMG notarized and stapled
- Gatekeeper accepts both DMG and contained app
