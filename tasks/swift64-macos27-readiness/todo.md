# TODO: Swift 6.4 / macOS 27 Readiness (S4-1)

> **Status:** 📋 QUEUED — nothing started. Scaffolded 2026-09-05.
> **Gate:** Phase 2 must not begin before `plan.md` scores ≥ 9/10 with Codex Oracle.

---

## Phase 0 — Research (no code; may run opportunistically before the Structure Sprint)

- [ ] 0.1 Read the 8 relevant files in `/Applications/Xcode.app/Contents/PlugIns/IDEIntelligenceChat.framework/Versions/A/Resources/AdditionalDocumentation/` (list in `research.md`); record the macOS-26-generation caveat against every claim taken from them
- [ ] 0.2 `agy -p` deep research per the prompt outline in `research.md` § 3 — Swift 6.2 → 6.4 deltas, macOS 26 → 27 API deltas, primary sources only
- [ ] 0.3 WebSearch point-lookups for anything `agy -p` left ambiguous (swift.org release notes, Swift Evolution proposal status)
- [ ] 0.4 Answer research question (a): what flips at `SWIFT_VERSION` 6.4 — concurrency defaults, stdlib additions (`InlineArray`/`Span`), deprecations, strict-concurrency diagnostics
- [ ] 0.5 Assess (a) against the ADR-3a `@unchecked Sendable` containment: header contract, `RenderThreadSafe` marker protocol, Gate 3a/3b/3c tests — do any become redundant, insufficient, or uncompilable?
- [ ] 0.6 Assess (a) against `Synchronization.Atomic` / `Mutex` usage in `MacAmpApp/Audio/VideoDSP/`
- [ ] 0.7 Answer research question (b): SwiftUI additions on macOS 26/27 worth adopting, filtered by the 1:1 pixel-faithful skin constraint
- [ ] 0.8 Answer research question (c): macOS 27 AppKit (Liquid Glass), toolbars, WebKit-in-SwiftUI (Butterchurn), AVFoundation / `MTAudioProcessingTap`, AVAudioEngine — additions AND deprecations
- [ ] 0.9 Answer research question (d): deployment target 15 → 26 or 27 — what it unlocks, what it breaks for skins + windowing, user-reach cost
- [ ] 0.10 Build the per-subsystem impact matrix (Audio, Audio/Streaming, Audio/VideoDSP, Skins, Windows/Windowing, Milkdrop/WebKit, Views, Tests)
- [ ] 0.11 Baseline check: build + full TSan test suite on the current pins under Xcode 27, so any post-bump delta is attributable
- [ ] 0.12 Record every open question for the user in `research.md`

## Phase 1 — Plan + Oracle gate

- [ ] 1.1 Write `plan.md`: adopt / defer decision per inventory item, with rationale
- [ ] 1.2 Write **ADR-1: deployment target** (stay 15.0 vs raise to 26/27) — reach cost, APIs unlocked, `if #available` fallbacks needed either way, kill switch
- [ ] 1.3 Write the language-mode ADR: `SWIFT_VERSION` + swift-tools-version, together or staged; rollback path
- [ ] 1.4 Write the ADR-3a-containment-under-6.4 ADR (or record that no change is needed)
- [ ] 1.5 Sequence the work into phases with a kill switch per phase
- [ ] 1.6 Fix the cosmetic `project.yml` `xcodeVersion: 26.0` drift as part of the plan's scope
- [ ] 1.7 Codex Oracle plan review (`gpt-5.5`, `reasoningEffort: xhigh`) — iterate to ≥ 9/10
- [ ] 1.8 User sign-off on the deployment-target ADR before any code

## Phase 2 — Implementation (PLACEHOLDER — do not start before plan Oracle ≥ 9)

- [ ] 2.1 **DO NOT START BEFORE PLAN ORACLE ≥ 9.** Phase items are written only once Phase 1 lands; the shape depends entirely on the ADR-1 outcome.

---

## Notes

- Predecessors: S3-2 PR #C → S3-3 → S3-4 → Post-S3 Structure Sprint. Only Phase 0 may run ahead of them.
- Ordering vs S4-2 `github-issues-triage` is an assumption pending user confirmation (see `_context/state.md` D-S4).
