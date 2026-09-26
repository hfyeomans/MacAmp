# TODO: Video Multichannel Output (#88)

- [ ] Experiment 1: measure Apple's C/LFE downmix coefficients (C-only / LFE-only / Rs-only 5.1 tones → 2-ch device, loopback capture)
- [ ] Experiment 2: negotiated tap channel count per route (display speakers, AirPods, AirPlay 2, HDMI 5.1)
- [ ] Experiment 3: does a tap change the Spatial Audio / Dolby Atmos indicator (5.1 AAC, E-AC-3 JOC on AirPods)
- [ ] Experiment 4: can `allowedAudioSpatializationFormats` change on a playing item
- [ ] `plan.md` (recommended design: pin source layout + layout-side balance with centre fold)
- [ ] Implement + unit tests (layout → role mapping, fold math)
- [ ] Ear checks: 5.1 on stereo speakers (far speaker silent at full balance), 5.1/spatial output, stereo + mono unchanged, AirPlay 2 no pumping
