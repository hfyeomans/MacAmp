# Resume Prompt

Updated: 2026-10-02

How to use: paste *"Read `tasks/_context/resume-prompt.md` and follow it."*

## Where things stand

- Current state (release, branches, open PR #91, open issues, test baseline, owner decisions pending): `tasks/_context/state.md`.
- Roadmap and status: `plan.md`; checklist: `todo.md`; deferred items: `deferred.md`; findings and gotchas: `research.md`; folder index: `tasks_index.md`. All in `tasks/_context/`.
- No task is implementing. S3-3 is next.

## Next action

1. Run `git status`. If the 2026-10-02 `_context` rewrite and task-folder moves are still uncommitted, commit them as one docs commit on `main` and push (owner approved 2026-10-02).
2. AT-1 (#86): if its standalone test-only PR is not open or merged yet, do it first (`plan.md`, AT-1).
3. Ask the owner to merge PR #91 (`chore/amp-review-dead-code`) first if possible, so S3-3 branches from the cleaned `main`. Recommended, not required.
4. Open `tasks/hls-streaming-support/` and run pre-flight in order (PF.1, PF.2 and PF.6 are satisfied):
   - PF.3: re-read `StreamDecodePipeline.swift`, `StreamPlayer.swift` and `AudioFileStreamParser.swift` at HEAD and refresh the plan's line anchors.
   - PF.4: cut `feat/hls-streaming-support` from `main`.
   - PF.5: create `MacAmpApp/Audio/HLS/`.
5. Continue with Phase 1 per the task's `todo.md`. Report to the owner before pushing the PR.

## Per-task pickup process

1. Read `_context/state.md` (Decisions in force, Architecture invariants), `research.md`, the task's rows in `plan.md` and `deferred.md`, and `principles.md`. Then read the task folder's six files: `state.md`, `research.md`, `plan.md`, `todo.md`, `placeholder.md`, `depreciated.md` (`plan.md` is created when planning starts).
2. Re-read every "Files Affected" source at HEAD and reconcile drift before Phase 1.
3. Start from a clean `git status`; one task per branch and PR, branched from `main`. Spike branches are throwaway: record findings in the task's `research.md`, then delete the branch.
4. After each phase, regenerate and build/test with TSan, passing the flag on every invocation:
   ```bash
   xcodegen generate
   xcodebuildmcp macos build --json '{"extraArgs":["-enableThreadSanitizer","YES"]}'
   xcodebuildmcp macos test  --json '{"extraArgs":["-enableThreadSanitizer","YES"]}'
   ```
   In the Claude Code sandbox, run tests unsandboxed instead:
   ```bash
   xcodebuild test -scheme MacAmpApp -destination 'platform=macOS' -enableThreadSanitizer YES -derivedDataPath build/DerivedDataDev -IDEPackageSupportDisableManifestSandbox=YES -IDEPackageSupportDisablePluginExecutionSandbox=YES
   ```
   It kills a running MacAmp; relaunch afterwards. Compare against the test baseline in `state.md`.
5. Manual gates: a FAILURE means an ADR amendment plus a targeted retry, never a soft-skip.
6. Run one exhaustive `/codex:review --base main` before the PR. Fix what affects correctness; list the rest one line each. Before another round, tell the owner what it would chase and roughly what it costs.
7. Push, `gh pr create`, and stop. The owner reviews, merges and deletes the branch (GH013 blocks CLI deletion).
8. Close-out after merge:
   - Task `state.md` → MERGED; `git mv tasks/<task> tasks/done/`.
   - `_context/state.md`: add the Shipped row and update current state.
   - `_context/plan.md` and `todo.md`: remove the shipped item and update the next item's status.
   - `_context/deferred.md`: add new deferrals, close resolved ones.
   - `tasks_index.md`: move the row, copy the status words from `plan.md`, and recount `done/`.
   - This file: set the next action.

## Keeping `_context` docs

- Process rules (workflow, verification, comments, deferred items, commits) live in `state.md` (Decisions in force, Process). Do not restate them elsewhere.
- `state.md` is current only, `plan.md` is future only, and `todo.md` derives from `plan.md`. One `Updated` line per file. History lives in git and `tasks/done/`.
- State a fact once, in its home file, and link to it from the others.
