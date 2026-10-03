# State: GitHub Issues Triage (S4-2)

Updated: 2026-10-02

**Status:** QUEUED. Research not started.

## Purpose

Triage and fix the user-filed issues on `hfyeomans/MacAmp` plus internal item P-6, landing the fixes in the post-Structure-Sprint layout.

## Gating

Hard-gated behind the Structure Sprint and S4-1 `swift64-macos27-readiness` (D-S4, `tasks/_context/state.md`).

## Open issues

#47, #79 and #84 are in scope here. #86 was fixed separately in #92. #88 is S4-4 `video-multichannel-output`. The full open-issue table is in `tasks/_context/state.md`.

## Scope

Order: #47, then P-6, then #79, then #84. One branch and one PR per item. Repro leads and hypotheses live in `research.md`.

| Item | Reporter, filed | Problem | Size | Likely area |
|------|-----------------|---------|------|-------------|
| #47 | @hfyeomans, 2026-02-10 | Cmd+Shift+1-3 is bound to both skin switching and the window toggles | Small | `AppCommands`, `SkinsCommands` |
| P-6 | internal, 2026-05-28 | After a video, loading an audio track does not auto-play (needs Next) | Small | `AudioPlayer`, `PlaybackCoordinator`, `VideoPlaybackController` |
| #79 | @MatteAce, 2026-04-11 | Dropping files on the window, Dock icon or app icon does nothing; Finder double-click and "Open With" fail; Cmd+O hides video files | Medium | Document types, drop handling, `AppCommands` |
| #84 | @morozov, 2026-05-16 | "Nucleo NLog v2G rendering defects": the Nucleo NLog v102 skin renders with defects the default skin does not show | Medium | `Skins/`, `SpriteResolver` |
| `timeControlStatus` residual | internal (S3-2 route gates) | An external pause of the video `AVPlayer` is not mirrored in the UI; goes next to P-6 | Small | `VideoPlaybackController` |
| RemoteLayerTreeDisplayLinkClient warnings | internal | Watch item: in scope only if the "stuck 0.50s" warnings recur with no debugger attached | Unknown | Main-thread UI performance |

## Owner decisions affecting this task

None open. #86 was fixed separately in #92, and there is no plan-level Oracle gate (owner, 2026-10-02).

## Next step

Phase 0 triage (`todo.md`) once the Structure Sprint and S4-1 have merged. Use `./scripts/resolve-pr-comments.sh <PR#>` for reviewer threads on each PR.
