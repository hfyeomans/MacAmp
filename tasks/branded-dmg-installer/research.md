# Research: Branded DMG Installer

> **Description:** Document findings on DMG branding tools, techniques, and best practices.
> **Purpose:** Inform the design and implementation of a professional DMG installer.

---

## Tools

### create-dmg (Recommended)
- `brew install create-dmg`
- Handles background image, icon positioning, volume icon, window size
- Command-line driven, scriptable for CI/CD
- https://github.com/create-dmg/create-dmg

### node-appdmg (Alternative)
- JSON config file driven
- More flexible layout options
- Requires Node.js
- https://github.com/LinusU/node-appdmg

### Manual (hdiutil + AppleScript)
- Most control but most complex
- Use `hdiutil` to create read-write DMG, mount, apply AppleScript for layout, convert to read-only

## Background Image Best Practices

- **Size:** Match window size (e.g., 600x400 for standard, 660x400 for wider)
- **Format:** PNG with transparency support
- **Retina:** Consider @2x version (1200x800) for high-DPI displays
- **Design:** Dark theme works well for media apps; include app icon, name, and clear install instructions
- **Arrow:** Visual arrow from app icon position to Applications icon position

## Notarization Requirement

The DMG must be notarized separately from the app inside it. Apple's notarization service checks the DMG container independently. The app's own notarization ticket is embedded in the app, but the DMG needs its own.

Process: build DMG → submit to notarytool → wait for Accepted → staple ticket to DMG.

## Reference: Audacity DMG

- Window size: ~600x400
- Background: Logo + "INSTALLATION" banner + instruction text
- App icon: left-center (~175, 275)
- Applications shortcut: right-center (~425, 275)
- Arrow graphic pointing right from app to Applications
