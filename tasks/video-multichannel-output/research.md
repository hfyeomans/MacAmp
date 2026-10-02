# Research: Video Multichannel Output (S4-4, #88)

Updated: 2026-10-02

Seeded from the S3-2 Phase 8 investigation (the 5.1 balance bug) and a macOS 27 SDK header pass; deferred from S3-2 by the owner. Mirrors issue #88.

## Summary

Video playback downmixes every source to stereo before the EQ/balance tap, so 5.1 and other multichannel or spatial content never reaches a multichannel or spatial output as multichannel. Goal: play 2-channel, 5.1 and other layouts the way Apple Music and TV can, while MacAmp's balance slider still controls the left vs right speakers.

## Current behavior (on `main` since PR #89)

- The video tap is created with `MTAudioProcessingTapCreateWithPreferredFormat` (macOS 27), pinned to 2-channel Float32 non-interleaved at the source sample rate (`VideoTap.preferredProcessingFormat`). The pin stops the tap's format from following the output device, which fixed audible pumping on AirPlay 2.
- Stereo was chosen deliberately (matching Winamp and Webamp) because the tap's balance treats channels 0/1 as L/R. With the source's 6 channels pinned (`C L R Ls Rs LFE`), balance hit Center and Left instead of Left and Right (S3-2 gate 8.13).
- Webamp does the same: `StereoBalanceNode` up- or down-mixes any source to stereo before balance.

## Findings (macOS 27 SDK headers; verified unless marked)

- The per-track `MTAudioProcessingTap` runs before AVPlayer's downmix and spatializer. There is no public post-downmix hook for AVPlayer; Pre/PostEffects only order the tap against the audio-mix volume ramp (QA1783).
- Preferred formats with more than 2 channels require an `AudioChannelLayout`.
- `AVPlayerItem.allowedAudioSpatializationFormats` defaults to mono, stereo and multichannel for video.
- `AVPlayerItemSampleBufferOutput` (macOS 27) is HLS-only.
- System balance (`kAudioHardwareServiceDeviceProperty_VirtualMainBalance`) is device-level and system-wide, so MacAmp must not change it.
- No API exposes AVPlayer's downmix matrix.
- *Inferred:* a PCM tap cannot carry Dolby Atmos objects or passthrough.

## Recommended design

Keep the source channels (pin the source layout) and apply balance by speaker side from the channel layout:

- L/Ls/Lrs get the left gain; R/Rs/Rrs get the right gain.
- Fold Center (and LFE, if Apple's downmix includes it) into the near side: `C' = g_far·C`, and the near-side front gets `+= (1−g_far)·k·C`, with k about 0.707 (−3 dB).
- With an ITU-style downmix, the far speaker is silent at full balance on stereo devices. Multichannel and spatial outputs keep every channel, with the image shifted toward the near side.
- Size: about 40-60 LOC in the tap plus a layout-to-role mapping computed on the main actor. No route detection and no item rebuild.

### Rejected

- **Pin 2 channels only on stereo devices.** AirPods report 2 channels, so they would lose spatial audio. Every route change would also need an item rebuild, because a live `audioMix` change is ignored (ADR-7).
- **`AVSampleBufferAudioRenderer` rebuild.** Too large, and it gains nothing.
- **Core Audio process tap.** Breaks A/V sync.

### Limitation

With AirPods spatial audio on, the far ear is never fully silent, whatever the in-app design.

## Experiments before implementation

1. Measure Apple's C and LFE downmix coefficients: play C-only, LFE-only and Rs-only 5.1 test tones to a 2-channel device through a pass-through tap, and capture via a loopback device.
2. Log the negotiated tap channel count per route: display speakers, AirPods, AirPlay 2 (Sonos/HomePod) and HDMI 5.1.
3. Check whether attaching a tap changes the Spatial Audio / Dolby Atmos indicator (5.1 AAC and E-AC-3 JOC on AirPods).
4. Check whether `allowedAudioSpatializationFormats` can change on a playing item.

### Passthrough check (before pinning more than 2 channels)

The macOS 27 SDK declares `AVEncoderContentSourceKey` and `AVAudioContentSource_Passthrough` (`AVFAudio/AVAudioSettings.h:44,110`) and describes them as encoder content-source settings. An older deep-research claim that passthrough routes could hand a tap encoded, non-PCM frames (`tasks/_context/depreciated/deep-research-avplayer-bridge.md:124-131`) is unverified. Confirm what the tap receives on an HDMI or other encoded route.

### Resources

- `clapperboard-videos/` at the repo root: five short tracked clips, including `5_mp4_480_surround.mp4`.
- Prior art: `tasks/stale/video-audio-tap-phase2-rereview/` reviewed the paused video-audio-engine-routing converter downmix (input/output channel layouts, `kAudioConverterPropertyPerformDownmix`, the AAC layout-tag fallback).

## Acceptance

- 5.1 reaches multichannel and spatial outputs as multichannel.
- On stereo speakers, full left or right balance silences the far speaker.
- Stereo and mono behavior is unchanged.
- The AirPlay 2 pumping fix still holds (source-rate pinned format).
- No render-budget or deadline-risk regressions.
