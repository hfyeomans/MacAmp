# Plan: SkinManager Decomposition

> **Description:** Implementation plan for reducing `SkinManager.swift` and aligning its responsibilities with the approved Swift project structure.
> **Purpose:** Keep the decomposition bounded, behavior-preserving, and consistent with the target `Features/Skins` ownership model.

---

## Objective

Decompose `MacAmpApp/ViewModels/SkinManager.swift` into smaller, clearer units while preserving skin loading, switching, import, and fallback behavior.

## Candidate Extraction Boundaries

- default-skin payload and fallback sprite cache handling
- skin discovery and metadata refresh
- import validation, replacement prompts, and notifications
- skin loading / payload application

## Constraints

- Preserve current skin behavior and fallback semantics.
- Do not turn this into a full skin-system rewrite.
- Keep feature-owned workflow code separate from truly reusable skin infrastructure.
- Do not use this task to reintroduce a generic dumping-ground utility layer.

## Verification

- Skin discovery still lists bundled and imported skins correctly
- Switching skins still updates the active skin correctly
- Skin import and replacement prompts still work
- Default Winamp fallback behavior still works when sprites are missing
- Project builds after any file moves and XcodeGen regeneration if needed
