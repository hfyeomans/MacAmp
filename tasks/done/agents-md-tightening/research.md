# Research: AGENTS.md Consolidation

## Scope
- User-level file: `/Users/hank/.codex/AGENTS.md`
- Project-level file: `/Users/hank/dev/src/MacAmp/AGENTS.md`

## Findings
- User-level file contains global operating constraints:
  - Skill-first workflow trigger
  - TypeScript/JavaScript standards
  - Multi-step task context workflow
- Project-level file duplicates most of the same global content, then adds MacAmp-specific rules.
- Project-level file is overly long due to tutorial-style command examples and repeated sections (TS rules and task workflow appear twice).
- High-signal project-specific triggers are mixed with low-signal examples, which increases prompt noise.

## High-Signal Triggers To Preserve
1. Skill-first workflow (must check available skills before ad-hoc approach).
2. MacAmp is Swift/macOS-first.
3. Tool routing:
   - files: `fd`
   - text: `rg`
   - structural code search: `sg` (mandatory for syntax-aware matching)
   - JSON: `jq`
   - YAML/XML: `yq`
4. Task artifact workflow in `tasks/<task-id>/` (`research.md`, `plan.md`, `state.md` at minimum).
5. Placeholder policy:
   - no in-code TODOs in production
   - track placeholders in task `placeholder.md`
6. Legacy/deprecated policy:
   - remove dead/legacy code; track findings in task `deprecated.md`
7. XcodeGen workflow:
   - `project.yml` + `Package.swift` are source of truth
   - run `xcodegen generate` after file tree changes
   - do not hand-edit `.pbxproj`
8. Use `xcodebuildmcp` skill/tools for Apple platform build/test/run/debug flows.
9. PR review comment resolution trigger: `scripts/resolve-pr-comments.sh`.
10. Gemini CLI trigger for large cross-file analysis.

## Consolidation Strategy
- Keep global behavior short; do not restate user-level instructions verbatim.
- Keep project file focused on MacAmp-specific deltas and concise command references.
- Remove tutorial-heavy example blocks that do not change behavior.
