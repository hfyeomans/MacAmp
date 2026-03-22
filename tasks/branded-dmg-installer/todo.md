# Todo: Branded DMG Installer

> **Description:** Track actionable work items for creating a branded DMG installer.
> **Purpose:** Each item is a discrete, verifiable unit of work.

---

- [ ] Design background image (MacAmp branding, arrow, install instructions)
- [ ] Store background image in `assets/dmg-background.png` (or similar)
- [ ] Install `create-dmg` via Homebrew
- [ ] Build DMG with `create-dmg` using background and icon positioning
- [ ] Test: open DMG and verify visual layout (background, icon positions, arrow alignment)
- [ ] Adjust icon coordinates if needed to align with background design
- [ ] Notarize DMG (`xcrun notarytool submit`)
- [ ] Staple notarization ticket (`xcrun stapler staple`)
- [ ] Verify Gatekeeper acceptance (`spctl -a -vv`)
- [ ] Update `docs/RELEASE_BUILD_GUIDE.md` with branded DMG step
- [ ] Upload to GitHub release (replace plain DMG)
