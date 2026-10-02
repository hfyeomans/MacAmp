# Todo: Video Multichannel Output (S4-4, #88)

Updated: 2026-10-02

Design, experiments and acceptance live in `research.md`.

## Phase 0: Experiments

- [ ] 0.1 Experiment 1: measure Apple's C/LFE downmix coefficients (C-only, LFE-only and Rs-only 5.1 tones to a 2-channel device, loopback capture)
- [ ] 0.2 Experiment 2: log the negotiated tap channel count per route (display speakers, AirPods, AirPlay 2, HDMI 5.1)
- [ ] 0.3 Experiment 3: check whether a tap changes the Spatial Audio / Dolby Atmos indicator (5.1 AAC, E-AC-3 JOC on AirPods)
- [ ] 0.4 Experiment 4: check whether `allowedAudioSpatializationFormats` can change on a playing item
- [ ] 0.5 Passthrough check on an encoded route before pinning more than 2 channels
- [ ] 0.6 Record the results in `research.md`

## Phase 1: Plan

- [ ] 1.1 Write `plan.md` (recommended design: pin the source layout; layout-side balance with a centre fold), adjusted by the experiment results
- [ ] 1.2 Owner sign-off

## Phase 2: Implementation

- [ ] 2.1 Implement in the tap, with unit tests for the layout-to-role mapping and the fold math
- [ ] 2.2 `xcodegen generate`, then `xcodebuildmcp macos build` and `test` with `--json '{"extraArgs":["-enableThreadSanitizer","YES"]}'`
- [ ] 2.3 Ear checks: 5.1 on stereo speakers (far speaker silent at full balance), 5.1/spatial output, stereo and mono unchanged, AirPlay 2 without pumping

## Phase 3: Close-out

- [ ] 3.1 One exhaustive `/codex:review --base main`; PR closing #88; the owner merges
- [ ] 3.2 Update `docs/VIDEO_WINDOW.md` (remove #88 from Planned; describe multichannel output) and the `_context` files
- [ ] 3.3 `git mv tasks/video-multichannel-output tasks/done/`
