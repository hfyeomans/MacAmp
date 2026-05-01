# EQ Numerical Match Research: BiquadCascade vs AVAudioUnitEQ

> **Scope:** What BiquadCascade must implement to produce subjectively identical EQ to AVAudioUnitEQ.
> **Sources:** Apple SDK headers (authoritative), RBJ Audio EQ Cookbook, psychoacoustic literature.
> **Word limit:** ~600 words.

---

## Biquad design conclusion

**Apple uses a Butterworth-analog-prototype parametric EQ, parameterised by octave bandwidth — not Q.**

This is stated verbatim in Apple's own SDK header (`AudioUnitParameters.h`, `kAUNBandEQFilterType_Parametric`):

> "Parametric filter based on Butterworth analog prototype. Uses parameterisation where the bandwidth is specified as the relationship of the upper bandedge frequency to the lower bandedge frequency in octaves, where the upper and lower bandedge frequencies are the respective frequencies above and below the center frequency at which the gain is equal to half the peak gain."

The "half the peak gain" bandedge definition means the bandwidth is measured at the −(gain/2) dB points (not the conventional −3 dB points). This is the same parameterisation used in the Robert Bristow-Johnson (RBJ) Audio EQ Cookbook's peaking-EQ formula — the `α = sin(ω₀) · sinh((ln 2)/2 · BW · ω₀/sin(ω₀))` path (where `BW` is bandwidth in octaves). The design is **constant-bandwidth-in-octaves (≈ constant-Q)**: the octave-width is fixed; the absolute Hz span grows with frequency.

**Confidence: HIGH.** The SDK header is the primary Apple source; the Butterworth analog prototype with octave bandwidth is a well-established technique and aligns exactly with the RBJ cookbook's octave-BW peaking-EQ variant.

---

## Per-band parameters table

MacAmp's `EqualizerController.swift` (`configureEQ()`) sets the exact parameters passed to `AVAudioUnitEQ`. These are the values BiquadCascade must replicate:

| Band | Frequency (Hz) | Type | Bandwidth (octaves) | Gain range (dB) |
|------|---------------|------|---------------------|-----------------|
| 0 | 70 | Low shelf | n/a | −96 → +24 |
| 1 | 180 | Parametric | 1.0 | −96 → +24 |
| 2 | 320 | Parametric | 1.0 | −96 → +24 |
| 3 | 600 | Parametric | 1.0 | −96 → +24 |
| 4 | 1000 | Parametric | 1.0 | −96 → +24 |
| 5 | 3000 | Parametric | 1.0 | −96 → +24 |
| 6 | 6000 | Parametric | 1.0 | −96 → +24 |
| 7 | 12000 | Parametric | 1.0 | −96 → +24 |
| 8 | 14000 | Parametric | 1.0 | −96 → +24 |
| 9 | 16000 | High shelf | n/a | −96 → +24 |

These are Winamp's actual internal processing frequencies (not the classic skin label values 60/170/310). The global gain (preamp) range is also −96 → +24 dB per the SDK.

**Confidence: HIGH** (read directly from production EqualizerController source + SDK header gain range).

---

## Tolerance target

**≤ 1 dB worst-case magnitude error across 20 Hz – 20 kHz per band.**

The 1 dB figure is the established psychoacoustic JND for tonal/loudness changes (Weber's law applied to intensity; widely cited in Zwicker & Fastl "Psychoacoustics: Facts and Models"). For EQ matching between two implementations, a ≤ 1 dB worst-case deviation across the audible band is considered subjectively transparent — errors below this threshold are imperceptible in normal listening. The practical industry target for cloning/approximating parametric EQ curves (e.g. DAW plugin emulations of hardware) uses ≤ 0.5 dB as a conservative margin to stay well below the JND; ≤ 1 dB is the outer acceptance boundary. Use **≤ 0.5 dB** as the spike's pass criterion (leaves headroom below the JND), with ≤ 1 dB as the hard reject boundary.

---

## Implementation hints for BiquadCascade

1. **Peaking (parametric) bands — use the RBJ octave-BW formula:**
   - `ω₀ = 2π · f / sampleRate`
   - `α = sin(ω₀) · sinh((ln 2 / 2) · BW · ω₀ / sin(ω₀))`  where `BW = 1.0` octave
   - `A = 10^(dBgain / 40)` (linear amplitude at half-peak-gain bandedge)
   - Coefficients: `b0 = 1 + α·A`, `b1 = -2·cos(ω₀)`, `b2 = 1 - α·A`, `a0 = 1 + α/A`, `a1 = -2·cos(ω₀)`, `a2 = 1 - α/A`; normalise by `a0`.

2. **Shelf bands (bands 0 and 9) — use RBJ low/high shelf formulas** with the same `A` derivation. The SDK header shows these as `kAUNBandEQFilterType_LowShelf` / `HighShelf` (no bandwidth parameter; frequency is the shelf midpoint at half-gain).

3. **Gain shape:** The RBJ peaking formula is inherently symmetric — boost and cut use identical coefficient paths with `A` vs `1/A`. AVAudioUnitEQ's Butterworth-prototype derivation follows the same symmetry. No separate boost/cut code paths needed.

4. **Sample rate independence:** Compute coefficients fresh on `tapPrepare` (where `AudioStreamBasicDescription` gives you the asset's native sample rate). Recompute whenever gain parameters change via atomic update from the main thread. No lookup tables — the formula is cheap.

5. **Verification method during spike:** Render a 0 dBFS sine sweep (20 Hz – 20 kHz, logarithmic) through both `AVAudioUnitEQ` (engine path, offline render) and `BiquadCascade` (same sweep, same gain settings). Measure magnitude error per frequency bin. Pass if worst-case deviation ≤ 0.5 dB.

---

**Confidence on numerical-match feasibility: HIGH** — the Apple SDK header confirms the Butterworth/octave-BW parameterisation that maps directly to the RBJ cookbook formula, which is well-understood and straightforward to implement precisely.
