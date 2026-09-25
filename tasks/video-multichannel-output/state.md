# Task State: Video Multichannel Output

> **Purpose:** Play 5.1 and other multichannel/spatial video audio as multichannel (like Apple Music/TV) while MacAmp's balance still controls the left vs right speakers.
> **Created:** 2026-09-25
> **Issue:** [#88](https://github.com/hfyeomans/MacAmp/issues/88)
> **Status:** 📋 **QUEUED** — deferred from S3-2 by the owner on 2026-09-25; S3-2 ships a stereo downmix for fidelity. Research findings seeded in `research.md`; experiments not started.

---

## Predecessors

| Predecessor | Why | Status |
|-------------|-----|--------|
| S3-2 `avplayer-native-video-dsp` → PR #C merged | Introduces the preferred-format tap (ADR-12) this task extends | 🔧 in progress |
| D-TARGET27 / PR #87 merged | `MTAudioProcessingTapCreateWithPreferredFormat` is macOS 27 | ✅ merged 2026-09-25 (`c79c2ca`) |

## Starting point

- `VideoTap.preferredProcessingFormat` pins **2 ch** at the source rate: mono is upmixed and multichannel downmixed by the system before the tap.
- This task changes the pin to the source layout and makes balance layout-aware (see the recommended design in `research.md`).

## Next step

Run experiments 1–4 in `research.md`, then write `plan.md`.
