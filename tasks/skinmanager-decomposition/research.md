# Research: SkinManager Decomposition

> **Description:** Research task for decomposing `SkinManager.swift` into clearer ownership boundaries that match the approved Swift project structure.
> **Purpose:** Define a safe post-S2 / pre-S3 plan for reducing `SkinManager.swift` without mixing skin behavior changes into the structure-policy task itself.

---

## Goal

Create a decomposition plan for `MacAmpApp/ViewModels/SkinManager.swift` that aligns skin workflows with the target ownership model.

## Current Context

- `SkinManager.swift` is currently `783` lines.
- The file mixes:
  - default-skin payload and fallback caching
  - skin discovery and selection
  - import validation and replacement prompts
  - skin loading and application
- The file still lives under `ViewModels/`, which does not match the approved feature/subsystem ownership model.

## Initial Scope

In scope:
- responsibility mapping inside `SkinManager.swift`
- separation of feature-owned skin flows from reusable skin infrastructure
- identifying extraction seams that reduce file size without changing behavior

Out of scope:
- redesigning the skin format
- changing sprite fallback behavior
- broad repo-wide folder moves outside the agreed skin ownership boundaries

## Target Alignment

- Feature-owned UI and workflow pieces should move toward `Features/Skins/`
- Reusable skin loading/parsing helpers should remain in a shared skin subsystem only if they are truly generic

## Status

Planned. Post-S2 / pre-S3 architecture follow-on.
