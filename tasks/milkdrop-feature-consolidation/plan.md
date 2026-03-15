# Plan: Milkdrop Feature Consolidation

> **Description:** Implementation plan for consolidating Milkdrop / Butterchurn code and resources under `Features/Milkdrop/`.
> **Purpose:** Make the feature self-contained and navigable without mixing feature consolidation into the urgent Xcode runtime fix.

---

## Objective

Move Milkdrop / Butterchurn feature files and resources into a single feature-owned area while keeping behavior unchanged.

## Proposed Target Layout

```text
MacAmpApp/Features/Milkdrop/
  MilkdropWindow.swift
  MilkdropWindowController.swift
  MilkdropWindowSizeState.swift
  ButterchurnBridge.swift
  ButterchurnPresetManager.swift
  ButterchurnWebView.swift
  Chrome/
  Resources/Butterchurn/
```

## Candidate Migrations

- `Models/MilkdropWindowSizeState.swift`
- `ViewModels/ButterchurnBridge.swift`
- `ViewModels/ButterchurnPresetManager.swift`
- `Views/WinampMilkdropWindow.swift`
- `Views/Windows/ButterchurnWebView.swift`
- `Views/Windows/MilkdropWindowChromeView.swift`
- `Windows/WinampMilkdropWindowController.swift`
- repo-root `Butterchurn/`

## Constraints

- Do not combine this task with the urgent Xcode Butterchurn runtime fix unless file moves are directly required there.
- Do not mix generic windowing code into this feature folder.
- Keep resource bundling correct for both Xcode Debug and packaged builds.

## Verification

- Butterchurn resources still bundle correctly
- Milkdrop window still renders and loads Butterchurn assets
- Xcode build and packaged build both resolve resources from the new location
- No feature behavior regressions are introduced by the move
