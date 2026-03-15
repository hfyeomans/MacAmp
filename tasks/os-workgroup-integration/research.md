# Research: os_workgroup Integration

> **Purpose:** Research Apple os_workgroup API usage for real-time audio threads on Apple Silicon, preventing audio glitches under CPU pressure.

**Status:** Pending research/planning.

---

## Context

The AVAudioSourceNode render block runs on the audio IO thread. Under CPU pressure, Apple Silicon can deprioritize threads not in a workgroup. os_workgroup tells the system this thread is real-time audio, preventing audio glitches under load.

---
