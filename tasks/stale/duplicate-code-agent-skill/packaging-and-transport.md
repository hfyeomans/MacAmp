# Packaging And Transport Plan

## Recommendation

Yes, this should move into its own standalone folder outside MacAmp.

Recommended home:

- `~/dev/src/duplicate-code-investigator-skill`

Reason:

- the core skill is no longer MacAmp-only
- transport and installation should not depend on a single product repo
- Codex, Claude, and Gemini packaging can share one canonical source
- versioning and release artifacts become much cleaner

## Canonical Distribution Model

Use a two-layer distribution model:

1. one canonical source repo for the portable core
2. harness-specific install and packaging adapters

That gives us:

- one source of truth for `SKILL.md`, references, and scripts
- reproducible packaging for Codex
- adapter docs or install helpers for Claude and Gemini
- clean version tags and zip/tarball releases

## Important Current State

The installed Codex skill is the freshest artifact:

- `/Users/hank/.codex/skills/public/duplicate-code-investigator/`

The current zip artifact is stale relative to the installed skill.

Evidence:

- installed skill includes:
  - `references/patterns-general.md`
  - `references/patterns-swift.md`
  - `references/example-macamp-bridge-ownership.md`
- current zip does not include those files

Implication:

- do not treat the current zip as the transport artifact
- regenerate packaging from the installed skill or from a refreshed canonical source tree first

## Recommended Standalone Repo Layout

```text
duplicate-code-investigator-skill/
├── core/
│   └── duplicate-code-investigator/
│       ├── SKILL.md
│       ├── agents/
│       │   └── openai.yaml
│       ├── references/
│       │   ├── investigation-workflow.md
│       │   ├── invocation-model.md
│       │   ├── patterns-general.md
│       │   ├── patterns-swift.md
│       │   ├── harness-codex.md
│       │   ├── harness-claude.md
│       │   ├── harness-gemini.md
│       │   └── example-macamp-bridge-ownership.md
│       └── scripts/
│           └── inventory_duplicate_paths.sh
├── packaging/
│   ├── codex/
│   │   ├── install.sh
│   │   ├── install-link.sh
│   │   └── package.sh
│   ├── claude/
│   │   ├── install.sh
│   │   └── snippets/
│   └── gemini/
│       ├── install.sh
│       └── snippets/
├── docs/
│   ├── INSTALL-CODEX.md
│   ├── INSTALL-CLAUDE.md
│   ├── INSTALL-GEMINI.md
│   ├── CLAUDE-INTEGRATION.md
│   └── GEMINI-INTEGRATION.md
├── dist/
│   ├── duplicate-code-investigator-codex-v1.zip
│   ├── duplicate-code-investigator-portable-v1.tar.gz
│   └── manifest.json
└── tests/
    ├── smoke/
    └── prompts/
```

## What Each Layer Does

### `core/`

Portable source of truth.

Contains:

- the skill text
- reusable references
- reusable scripts
- Codex metadata

### `packaging/codex/`

Codex-specific packaging and install.

Should provide:

- copy install into `~/.codex/skills/public/duplicate-code-investigator`
- symlink install for local development
- zip packaging from `core/duplicate-code-investigator/`

### `packaging/claude/`

Claude adapter packaging.

For now, treat this as:

- install snippets
- recommended agent text
- hook guidance
- later, a true installer if you standardize the target path and format

### `packaging/gemini/`

Gemini adapter packaging.

For now, treat this as:

- project-skill or extension snippets
- command examples
- later, a true installer if you standardize the target path and format

## Release Artifacts

Produce these from the standalone repo:

### 1. Codex zip

For transport into another Codex environment.

Contents:

- just the Codex-ready skill folder

Target use:

- unzip and copy into `~/.codex/skills/public/`

### 2. Portable tarball

For transporting the full source package with adapters and docs.

Contents:

- `core/`
- `packaging/`
- `docs/`
- `tests/`

Target use:

- install or adapt into Codex, Claude, or Gemini environments

### 3. Manifest

Include:

- version
- git commit
- build timestamp
- source of truth path
- included files
- checksums for release artifacts

## Installation Modes

### Mode A: local dev symlink

Best for active iteration.

Codex example:

- symlink `core/duplicate-code-investigator/` into `~/.codex/skills/public/duplicate-code-investigator`

Benefits:

- edit once, test immediately
- no repeated copy step

### Mode B: copy install

Best for normal use.

Codex example:

- copy packaged skill into `~/.codex/skills/public/duplicate-code-investigator`

Benefits:

- stable runtime artifact
- no accidental coupling to the source repo

### Mode C: release artifact install

Best for shipping to other machines or other agents/users.

Benefits:

- versioned
- reproducible
- auditable

## Codex Installer Requirements

The Codex installer should:

1. validate source files exist
2. remove or replace an existing install safely
3. copy or link into `~/.codex/skills/public/duplicate-code-investigator`
4. print the installed path
5. remind the user that a fresh Codex session is required

Optional:

- run `quick_validate.py` if available in the local Codex install

## Claude And Gemini Packaging Recommendation

Do not over-promise a one-command universal installer yet.

Instead:

- package the portable core now
- add adapter snippets and installation docs
- turn those into real installers after you settle the exact Claude and Gemini local conventions

That keeps the repo honest and still transportable.

## Suggested Versioning

Use semantic tags:

- `v1.0.0` for the current frozen Codex-first version
- `v1.1.0` for packaging improvements or extra references
- `v2.0.0` only if the core contract changes materially

## Suggested Immediate Next Steps

1. Create the standalone repo folder at `~/dev/src/duplicate-code-investigator-skill`
2. Copy the installed Codex skill into `core/duplicate-code-investigator/`
3. Regenerate the release zip from that canonical source
4. Add `install.sh`, `install-link.sh`, and `package.sh` for Codex
5. Add the current invocation guidance as adapter docs for later Claude/Gemini wiring

## Recommendation On Whether To Create The Folder Now

Yes.

This is the right time because:

- the core is stable enough to freeze as v1
- the packaging work is now orthogonal to MacAmp itself
- future Claude/Gemini work should build from a neutral source repo, not from a product worktree

## Implementation Constraint

Creating `~/dev/src/duplicate-code-investigator-skill` is outside the current writable repo sandbox.

So the next move is straightforward:

- if you want me to create that standalone folder and scaffold the packaging repo now, I need approval to write outside `/Users/hank/dev/src/MacAmp`
