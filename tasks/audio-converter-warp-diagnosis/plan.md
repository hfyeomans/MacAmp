# Plan — Fastest Path To Root Cause

## Goal
Identify first deterministic fault point in chain:
`URL bytes -> ICY-framed audio bytes -> parser packets -> converter output PCM`.

## Recommended Execution Order

1. Add low-overhead packet/frame accounting instrumentation (Option D).
- Count bytes/packets entering parser, packets handed to converter, frames produced.
- Log whether packet descriptions are present and valid for every parser callback.
- Log `icy-metaint` extracted value and metadata chunk counts.

2. Add a toggle to dump decoder PCM to raw file for a short capture (Option A).
- Confirms corruption before/after converter.
- Enables waveform/spectrum inspection in Audacity.

3. If accounting or PCM capture points to converter input semantics, diff against SFBAudioEngine callback behavior (Option B).
- Focus only on callback packet provisioning and descriptor handling.

4. Use simplification (Option C) only after instrumentation proves a converter-input boundary issue.
- Simplifying too early risks masking the fault without locating it.

## Success Criteria
- Can answer exactly where corruption first appears.
- Can quantify frame production vs consumption mismatch with counters.
- Can tie under-run timing to a specific packet/frame loss mechanism.
