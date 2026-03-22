# Codex Test 1: Duplicate Investigator Smoke Test

## Goal

Verify that a fresh Codex session can discover and use the installed `duplicate-code-investigator`
skill for a real MacAmp duplication-risk question.

## Precondition

- Skill installed at `/Users/hank/.codex/skills/public/duplicate-code-investigator`
- Start a fresh Codex session so the newly installed skill is visible at session startup

## First Test Prompt

```text
Use $duplicate-code-investigator to scan the MacAmp audio pipeline for duplicate execution paths and duplicated initialization risk.

Focus on:
- configureFramer
- activateStreamBridge
- deactivateStreamBridge
- any side effects that can happen from multiple actor, queue, callback, or lifecycle contexts

Do not stop at text duplication. Prioritize behavioral duplication, missing choke points, and competing implementations. Return:
1. confirmed duplicates
2. likely duplicate-path risks
3. false positives or intentional repetition
4. the single safest choke point or ownership recommendation for each real issue

Use `rg` for fast inventory and `ast-grep` for structural matching. Treat `ast-grep` as the primary syntax-aware detector, not a Swift-only special case.
```

## Expected Behavior

The Codex session should:

1. Recognize the installed skill.
2. Use the skill workflow instead of doing a generic review.
3. Investigate duplicate execution paths, not just copied text.
4. Prefer local deterministic scans before broad reasoning.
5. Return ranked findings with evidence.

## Good Signs

- Mentions `duplicate-code-investigator` or clearly follows its workflow
- Searches exact symbols and call sites
- Distinguishes behavioral duplication from structural duplication
- Avoids calling ordinary repeated helper usage a bug without evidence
- Produces a choke-point recommendation instead of only listing matches

## Failure Signs

- Ignores the skill entirely
- Only performs broad prose reasoning with no code evidence
- Treats raw multiple call sites as automatically wrong
- Reports only copy-paste duplication
- Fails to separate confirmed issues from speculative risks

## Follow-Up Prompt If Needed

```text
Re-run this using the duplicate investigator workflow. Treat `ast-grep` and call-site inventory as first-pass evidence, then reason about whether the repeated side effect is intentional or should collapse to one owner.
```
