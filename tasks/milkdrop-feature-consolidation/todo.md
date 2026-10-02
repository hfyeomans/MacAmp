# Todo: Milkdrop Feature Consolidation

Updated: 2026-10-02

Derived from `plan.md`.

## Decide (after SS-0)

- [ ] Naming: keep the `Winamp` prefix or rename to `MilkdropWindow`/`MilkdropWindowController`
- [ ] Chrome file location: flat or `Chrome/`
- [ ] Whether `Butterchurn/test.html` keeps shipping
- [ ] Confirm the source-to-target table in `plan.md` against SS-0's `mapping.md` at post-S3 HEAD

## Execute

- [ ] Move the 7 Swift files into `Features/Milkdrop/` (pure-move commit)
- [ ] Move `Butterchurn/` to `MacAmpApp/Features/Milkdrop/Resources/Butterchurn/`; update `project.yml:25`; exclude it from the `MacAmpApp` source entry
- [ ] `xcodegen generate`; confirm a single `Butterchurn` folder reference
- [ ] TSan build and test
- [ ] Verify Butterchurn loads in a Debug run and in a packaged Release build
- [ ] One `/codex:review --base main`, then open the PR
