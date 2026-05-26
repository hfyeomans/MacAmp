# Review f41418a Video Regressions State

## Status

- Review complete.

## Decisions

- Treat this as a code-review task; do not edit production code.
- Use duplicate-path review heuristics for bridge setup/teardown and volume routing.
- Recommend removing the unconditional volume restore from generic bridge teardown; restore direct AVPlayer volume only in the actual fallback/no-bridge continuation path.

## Blockers

- None.
