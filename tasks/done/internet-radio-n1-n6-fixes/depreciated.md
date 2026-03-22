# Depreciated: Internet Radio N1-N6 Fixes

> **Purpose:** Documents any depreciated or legacy code discovered during this task. Code marked for removal should be listed here instead of using inline `// Depreciated` comments per project conventions.

---

## Depreciated Code Findings

_None yet. Will be populated during implementation if legacy patterns are discovered._

## Expected Deprecations

The following patterns will be replaced during implementation:

### N2: Imperative isPlaying/isPaused Flags (PlaybackCoordinator)
- **Pattern:** Stored `var isPlaying: Bool` / `var isPaused: Bool` with imperative assignments scattered across ~12-15 locations
- **Replaced by:** Computed properties that derive state from the active audio source
- **Rationale:** Imperative flags desync from StreamPlayer's KVO-driven state changes. Computed derivation eliminates the root cause.
- **Status:** Pending implementation

### N3: externalPlaybackHandler Naming
- **Pattern:** Property named `externalPlaybackHandler` that implies playback initiation
- **Replaced by:** `onTrackMetadataUpdate` -- accurately describes the callback's behavior
- **Rationale:** Handler only fires on metadata refresh for placeholder tracks, never initiates playback
- **Status:** Pending implementation
