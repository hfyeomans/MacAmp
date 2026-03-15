# Research: Milkdrop Feature Consolidation

> **Description:** Research task for consolidating Milkdrop / Butterchurn feature files and resources under a dedicated `Features/Milkdrop/` ownership boundary.
> **Purpose:** Define a safe post-S1 move plan that improves ownership without interfering with the current Xcode runtime fix.

---

## Goal

Create a source-to-target migration map for Milkdrop / Butterchurn code and resources.

## Initial Context

- `swift-project-structure-research` identified Milkdrop / Butterchurn as a highly scattered feature.
- Current files are split across:
  - `Models/`
  - `ViewModels/`
  - `Views/`
  - `Views/Windows/`
  - `Windows/`
  - repo-root `Butterchurn/` resources
- `xcode-butterchurn-webcontent-diagnosis` should stay focused on the runtime fix first.

## Initial Scope

In scope:
- feature-local Swift files for Milkdrop / Butterchurn
- feature-owned raw resources
- feature-local state types and bridges

Out of scope:
- fixing the Xcode runtime bug unless the move is directly required
- generic window infrastructure
- unrelated visualizer pipeline changes

## Status

Planned. Post-S1 follow-on.
