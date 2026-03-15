# State

- Status: completed
- Current step: findings synthesized for review output
- Notes:
  - Review covered `git diff`, `git diff --stat`, live repository inventory checks, and targeted Swift 6.2/concurrency validation.
  - Confirmed the generated Xcode project exposes `MacAmpApp` as the scheme; the edited `MacAmp` commands are not repository-accurate.
  - Confirmed top-level codebase stats in `docs/MACAMP_ARCHITECTURE_GUIDE.md` (`111` Swift files, `18,475` LoC under `MacAmpApp/`) are correct.
  - Confirmed several documentation metrics remain stale:
    - Active docs excluding `archive/`, `context/`, `sessions/`: `18` files / `19,495` lines
    - Markdown files in `docs/archive/`: `26`
    - `docs/README.md` inventory counts and many per-doc line totals do not match the filesystem
  - Confirmed superseded-pattern cleanup is incomplete in edited docs:
    - `docs/IMPLEMENTATION_PATTERNS.md` still presents `nonisolated(unsafe)` as a live pattern
    - `docs/MACAMP_ARCHITECTURE_GUIDE.md` still documents `Task.detached` as current behavior
    - `docs/README.md` still indexes `nonisolated(unsafe) deinit`
  - Confirmed the new Swift 6.2 architecture section is partially accurate but not fully repo-accurate:
    - omits `StreamDecodePipeline.isolated deinit`
    - `Package.swift` snippet does not match the current manifest
