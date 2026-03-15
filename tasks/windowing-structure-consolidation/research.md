# Research: Windowing Structure Consolidation

> **Description:** Research task for consolidating MacAmp’s generic window-management infrastructure under a dedicated `Windowing/` ownership boundary.
> **Purpose:** Map the current scattered windowing files to a focused subsystem and define a safe post-S1 consolidation scope.

---

## Goal

Create a source-to-target migration map for generic window infrastructure without mixing that work into active Sprint S1 tasks.

## Initial Context

- `swift-project-structure-research` identified generic windowing infrastructure as one of the cleanest high-value consolidation targets.
- Current window-related code is spread across:
  - `MacAmpApp/Windows/`
  - `MacAmpApp/Utilities/Window*`
  - `MacAmpApp/ViewModels/WindowCoordinator*`
  - some `Models/*Window*` value/state types

## Initial Scope

In scope:
- generic window mechanics
- docking geometry/types
- frame persistence/store
- visibility/registry/coordinator infrastructure
- dependency analysis for `WindowCoordinator`, `WindowRegistry`, and adjacent helpers before any move is proposed

Out of scope:
- feature-specific window views
- feature-specific chrome
- runtime behavior changes unrelated to ownership cleanup

## Dependency Analysis Requirement

- Before implementation, map which `WindowCoordinator` and `WindowRegistry` responsibilities are truly generic versus feature-coupled.
- Identify whether a safe move requires:
  - leaving some types in their current feature area
  - extracting a protocol/adapter seam first
  - splitting generic and feature-specific responsibilities into separate files
- Reject any move plan that would introduce circular dependencies or force a broad behavior refactor under the guise of structure cleanup.

## Status

Planned. Post-S1 follow-on.
