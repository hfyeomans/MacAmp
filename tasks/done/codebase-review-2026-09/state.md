# State — codebase review 2026-09

> **Closed 2026-10-02.** Archived from the local branch `review/codebase-audit-2026-09` (`4c3702d`). Its summary reached the owner as the "amp review"; every finding was checked against `main` and fixed, slotted or rejected in `tasks/_context/research.md` (Amp code review).

Status: complete (review delivered).

- Branch: `review/codebase-audit-2026-09` (throwaway). Source branch `feat/avplayer-native-video-dsp` untouched.
- Deliverable: `tasks/codebase-review-2026-09/review.md`.
- No source files modified. No push.

Decisions:
- `DockingController` recommended for removal rather than repair (vestigial single-container model).
- `Package.swift` flagged as invalid/stale; decision on split-vs-delete left to owner.
- `SimpleSpriteImage.legacy` explicitly NOT recommended for removal yet (81 call sites).

Open questions for owner:
- Is `BUILDING_RETRO_MACOS_APPS_SKILL.md` maintained documentation (docs link to it) or removable?
- Should `Package.swift` remain a source of truth (requires splitting the ObjC shim into a Clang target)?
