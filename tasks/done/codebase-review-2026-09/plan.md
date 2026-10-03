# Plan — codebase review 2026-09

Scope: recommendations only, no source changes.

1. Create throwaway branch `review/codebase-audit-2026-09` from `feat/avplayer-native-video-dsp`. Done.
2. Mechanical scans (size, lint, singletons, Combine, IUO, force-unwrap, tracked clutter). Done.
3. Read core orchestration files directly. Done.
4. Fan out four read-only area reviews; spot-verify high-impact claims. Done.
5. Synthesize into `review.md` with severity-ordered bugs, YAGNI, duplication clusters, tightening, modernization, structure/naming with target layout, tests, config/hygiene, suggested sequencing. Done.
6. Commit docs-only on the review branch. Do not push.
