# Todo

- [ ] Create a new worktree from `main`
- [ ] Create implementation branch `fix/xcode-butterchurn-webcontent` in that worktree
- [ ] Inspect `MacAmpApp/MacAmp.entitlements` for invalid or ineffective keys
- [ ] Inspect `project.yml` signing/runtime settings and update there if needed
- [ ] Regenerate the Xcode project with XcodeGen if `project.yml` changes
- [ ] Rebuild the macOS app from the worktree
- [ ] Verify `codesign -dvvv --entitlements :-` no longer reports an invalid entitlements blob
- [ ] Review `ButterchurnWebView.swift` and gate `developerExtrasEnabled` if appropriate
- [ ] Review `ButterchurnWebView.swift` and gate `isInspectable` if appropriate
- [ ] Do not move Butterchurn files unless directly required by the fix; defer broad consolidation to `milkdrop-feature-consolidation`
- [ ] Run from Xcode and confirm Butterchurn renders
- [ ] Launch outside Xcode and confirm Butterchurn still renders
- [ ] Verify `Contents/Resources/Butterchurn/` is still present in the built app
- [ ] Open a focused PR against `main`
