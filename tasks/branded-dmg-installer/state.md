# State: Branded DMG Installer

> **Description:** Create a professional branded DMG installer with MacAmp logo, background image, and drag-to-install layout.
> **Purpose:** Replace the plain DMG with a polished installer experience matching professional macOS apps (e.g., Audacity).

## Status

📋 PLANNED

**Sprint:** Not assigned (standalone release tooling task)
**Created:** 2026-03-22
**Last Updated:** 2026-03-22

## Context

The current DMG is a plain volume with just the app and an Applications symlink. Professional macOS apps use branded DMG installers with custom background images, positioned icons, and drag-to-install instructions.

Reference: Audacity's DMG installer with logo, "INSTALLATION" banner, "Drag to Applications" instruction text, and positioned app + Applications icons.

## Size

Small-Medium

## Priority

Low — cosmetic/polish. Current plain DMG works fine functionally.

## Notes

- The DMG must be notarized separately from the app (Apple requires container notarization)
- Tool: `create-dmg` (brew install) handles background, icon positioning, and volume icon
- Background image needs to be designed with MacAmp branding
- The app inside the DMG is already signed and notarized — only the DMG container needs re-notarization
