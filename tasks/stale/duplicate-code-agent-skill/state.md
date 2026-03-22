# State: Duplicate Code Agent Skill

## Status

Research and prototype design complete. Codex-first skill is installed, validated, and now documented as v1.

## Branch / Worktree

- Branch: `feature/duplicate-code-agent-skill`
- Worktree: `.claude/worktrees/duplicate-code-agent-skill`

## Current Focus

Freeze the Codex-first version cleanly, document how humans should use it, and document how other agents should call Codex later without changing live agent instruction files yet.

## Decisions So Far

1. Treat this as a separate task with isolated branch/worktree context.
2. Treat duplicate code broadly:
   - structural duplication
   - behavioral duplication
   - duplicated orchestration / repeated side effects
3. Design around a specialized sub-agent rather than a static checklist only.
4. Build on tools already present in the environment:
   - `rg`
   - `ast-grep`
   - `semgrep`
5. Keep the design portable across harnesses by separating shared workflow from harness-specific invocation mechanics.
6. Use `agents/openai.yaml` only for Codex UI metadata and implicit invocation policy; keep actual sub-agent creation in the skill instructions.
7. Treat `ast-grep` as the primary structural detector and `gemini` as a second-pass synthesizer for broad scopes.

## Evidence Captured

- `configureFramer()` duplicate-call incident from the unified audio pipeline.
- Previous repo-wide duplication analysis showing existing structural duplication patterns.
- Helper script prototype confirms a clean first-pass call-site inventory for `configureFramer` and `deactivateStreamBridge`.
- Codex skill scaffold validates successfully with `quick_validate.py`.
- Manual zip artifact created at `tasks/duplicate-code-agent-skill/dist/duplicate-code-investigator.zip`.
- Official Claude packager script is present but blocked locally by missing Python `yaml` dependency.
- Experimental Codex install created at `/Users/hank/.codex/skills/public/duplicate-code-investigator`.
- Installed Codex copy validates successfully with `quick_validate.py`.
- Installed Codex copy updated to a modular, language-agnostic version with `patterns-general.md` and `patterns-swift.md`.
- Repo `AGENTS.md` now includes a duplicate-work planning/review trigger.
- `/review` should treat AGENTS as a likely influence, not a guaranteed hard trigger, until verified in a fresh Codex session.
- Fresh Codex smoke test produced useful categorized findings and appears to have followed the duplicate-investigator workflow.
- Historical PR57 review against merge commit `cf71762`, using a temp worktree plus `--add-dir` for newer task docs, produced the strongest validation so far with ranked findings around stale ownership, missing choke points, and async handoff risk.
- `~/.claude/CLAUDE.md` is the correct style source for later Codex/Oracle integration guidance, not the repo-root `CLAUDE.md`.
- v1 usage guidance is now captured in `duplicate-code-investigator-v1.md`.
- later agent-doc updates are now scoped through `codex-invocation-guidance.md` instead of changing live instruction files immediately.
- packaging and transport guidance is now captured in `packaging-and-transport.md`, including the recommendation to move the canonical source into a standalone repo under `~/dev/src/`.
- the current `dist/duplicate-code-investigator.zip` artifact is stale relative to the installed Codex skill and must be regenerated before transport.
- the release artifact has now been regenerated from the installed Codex skill and verified to include the modular reference files.
- current zip checksum:
  `3c84bf871dd8ecf07482a6200b4e565bf9b1aafc15211efd3d2a2a07b6e43012`
- standalone packaging repo created at `/Users/hank/dev/src/duplicate-code-investigator-skill`.
- standalone repo now contains the canonical portable core under `/Users/hank/dev/src/duplicate-code-investigator-skill/core/duplicate-code-investigator`.
- standalone repo initialized as its own git repository on `main`.
- standalone repo initial release commit:
  `30c51ae` — `chore: initialize duplicate-code-investigator-skill v1.0.0`
- full Codex invocation guidance is now mirrored into the standalone repo at `/Users/hank/dev/src/duplicate-code-investigator-skill/docs/CODEX-INVOCATION-GUIDANCE.md`.
- standalone repo second commit:
  `8023f31` — `docs: add codex invocation guidance`
- standalone repo built release artifacts:
  - `duplicate-code-investigator-codex-v1.0.0.zip`
  - `duplicate-code-investigator-portable-v1.0.0.tar.gz`
- standalone repo manifest checksum entries:
  - codex zip: `be8219631214380b7784a8c417b22a8c0ae98fa1bbd0fe5016d90ab46df38bff`
  - portable tar.gz: `d344ca6b0c8ffce5b5937d78d7ef428528e24bd9fd8cd2b475bd7dcefef47277`

## Codex CLI Review Patterns

- `codex --no-alt-screen "<prompt>"`:
  best interactive mode when full scrollback matters and the review needs custom instructions.
- `codex exec "<prompt>" | tee /tmp/output.txt`:
  best non-interactive mode when full output capture matters more than TUI ergonomics.
- `codex review --base <rev>` or `codex review --commit <sha>`:
  best for native patch review, but current local CLI version rejects combining `--base` or `--commit` with a custom prompt despite the help text implying otherwise.
- Temp worktree review pattern:
  `git worktree add /tmp/<name> <sha>` then run `codex --no-alt-screen` or `codex exec` inside that worktree to review a historical branch/PR snapshot with custom instructions.
- Historical snapshot + current docs pattern:
  from the historical worktree, run `codex exec --add-dir /Users/hank/dev/src/MacAmp "<prompt>"` so Codex reviews the old code snapshot while still being able to read newer task docs or reference files from the current repo checkout.
- Prompting rule:
  if the review needs duplicate-investigator behavior plus custom scope/focus, prefer interactive `codex` or `codex exec` over `codex review` until the parser mismatch is fixed.
- Output capture rule:
  use `tee` with `codex exec` or `codex review` for durable logs; use `--no-alt-screen` with interactive `codex` to preserve terminal scrollback.

### Working Examples

- Interactive review with full scrollback:
  ```bash
  codex --no-alt-screen "Use \$duplicate-code-investigator to review the changes from <base> to HEAD. Findings first. Do not modify code."
  ```
- Non-interactive review with durable output:
  ```bash
  codex exec "Use \$duplicate-code-investigator to review the changes from <base> to HEAD. Findings first. Do not modify code." | tee /tmp/codex-review.txt
  ```
- Historical PR snapshot review:
  ```bash
  git worktree add /tmp/macamp-pr57-review cf71762
  cd /tmp/macamp-pr57-review
  codex --no-alt-screen "Use \$duplicate-code-investigator to review the changes from aad01ea3f02528c3522a669cf60dec2d14f6a42a to HEAD. Findings first. Do not modify code."
  ```
- Historical snapshot plus current repo docs:
  ```bash
  cd /tmp/macamp-pr57-review
  codex exec \
    --add-dir /Users/hank/dev/src/MacAmp \
    "Use \$duplicate-code-investigator to review the changes from aad01ea3f02528c3522a669cf60dec2d14f6a42a to HEAD.

  Compare against:
  - /Users/hank/dev/src/MacAmp/tasks/audio-pipeline-duplicate-investigation/research.md
  - /Users/hank/dev/src/MacAmp/tasks/audio-pipeline-duplicate-investigation/state.md
  - /Users/hank/dev/src/MacAmp/tasks/audio-pipeline-duplicate-investigation/plan.md
  - tasks/unified-audio-pipeline/lessons-learned.md

  Findings first. Use rg and ast-grep style evidence where helpful. Do not modify code." \
    | tee /tmp/codex-exec-pr57-review-2.txt
  ```
- Native patch review without extra instructions:
  ```bash
  codex review --base origin/main
  ```
- Current local parser caveat:
  `codex review --base <rev> "<prompt>"` and `codex review --commit <sha> "<prompt>"` currently fail in this CLI version even though help text suggests they should work.

### Follow-On Topic

- After this skill stabilizes, investigate how other agents should call Codex more effectively:
  - when to use `codex review`
  - when to use interactive `codex`
  - when to use `codex exec`
  - how to pass historical snapshots, prompts, and extra directories cleanly
  - how to preserve full output for later comparison

## Open Threads

1. When to apply the new Codex invocation guidance into `~/.claude/CLAUDE.md`, repo-level agent docs, and other harness instruction files.
2. Whether to add CI or PR-review automation later for structural duplicate sweeps.
3. Whether to publish a Claude/Gemini packaging pass from the same frozen core contract.
