# Claude Adapter

## Purpose

Adapt the same workflow to Claude's specialized-agent and sub-agent model.

## Recommended Pattern

Create a dedicated duplicate investigator agent first, before broad implementation work.

That agent should own:

- duplicate-path analysis
- competing-implementation discovery
- call-site inventory
- evidence gathering

If the repo slice is large, split work into:

- execution-path agent
- structural-duplication agent

## Prompt Shape

Use instructions equivalent to the Codex adapter:

- prioritize duplicated side effects over copied text
- inventory suspicious symbols and lifecycle hooks
- identify missing choke points
- distinguish confirmed duplicates from intentional repetition

## Packaging Note

This file is a workflow adapter, not a claim that Claude uses Codex metadata files.

The portable part is:

- the trigger conditions
- the investigation workflow
- the evidence rules
- the sub-agent role definition
