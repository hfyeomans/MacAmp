# Depreciated: Internet Streaming Volume Control

> **Purpose:** Documents any depreciated or legacy code discovered during this task. Code marked for removal should be listed here instead of using inline `// Depreciated` comments per project conventions.

---

## Depreciated Code Findings

### 1. Direct AudioPlayer.volume → VideoPlaybackController Propagation (REMOVED)

**File:** `MacAmpApp/Audio/AudioPlayer.swift` (line 61, former didSet)

**Before:**
```swift
var volume: Float = 0.75 {
    didSet {
        playerNode.volume = volume
        videoPlaybackController.volume = volume  // ← REMOVED
        UserDefaults.standard.set(volume, forKey: Keys.volume)
    }
}
```

**After:** Video volume propagation moved to `PlaybackCoordinator.setVolume()` which fans out to all backends uniformly (audio, stream, video). This eliminates AudioPlayer's knowledge of other players.

**Reason:** AudioPlayer should not know about VideoPlaybackController or StreamPlayer. The coordinator pattern centralizes cross-backend propagation.

**Status:** Code removed in commit `463c6a9`. PlaybackCoordinator now handles all cross-backend volume routing.

### 2. Direct AudioPlayer Volume/Balance UI Bindings (REPLACED)

**File:** `MacAmpApp/Views/WinampMainWindow+Helpers.swift` (buildVolumeSlider, buildBalanceSlider)

**Before:**
```swift
func buildVolumeSlider() -> some View {
    @Bindable var player = audioPlayer
    WinampVolumeSlider(volume: $player.volume)  // ← Direct binding
}

func buildBalanceSlider() -> some View {
    @Bindable var player = audioPlayer
    WinampBalanceSlider(balance: $player.balance)  // ← Direct binding
}
```

**After:** Volume and balance sliders use asymmetric `Binding<Float>(get:set:)` that reads from `audioPlayer` but writes through `playbackCoordinator.setVolume()`/`setBalance()` for proper fan-out.

**Reason:** Direct bindings to AudioPlayer bypassed the coordinator, leaving StreamPlayer and VideoPlaybackController unsynchronized during stream playback.

**Status:** Replaced in commit `463c6a9`.

---

## Deferred Items

### Phase 2: Loopback Bridge (Wave 3)

All Phase 2 items (2.0a–2.8b, V2.1–V2.14) are deferred to Wave 3. Phase 2 implements the MTAudioProcessingTap → Ring Buffer → AVAudioSourceNode pipeline to enable EQ, visualization, and balance for internet streams.

**Dependencies:** T4 (lock-free ring buffer, complete) + T5 Phase 1 (complete, this commit).

### Phase 1 Verification Items (Manual Testing Required)

V1.1–V1.11 require manual testing with actual internet radio streams. Cannot be automated. Should be completed during PR review.

### StreamPlayer.balance Not Applied

`StreamPlayer.balance` is a stored property that is NOT applied to AVPlayer (no `.pan` property exists on AVPlayer). This is by design — the value is stored for Phase 2 when the Loopback Bridge routes streams through AVAudioEngine where `playerNode.pan` can apply it.

### AudioPlayer.init() Still Sets videoPlaybackController.volume

`AudioPlayer.init()` at line 173 still directly sets `videoPlaybackController.volume = volume` during engine setup. This is correct for initialization (before PlaybackCoordinator exists) and does not conflict with the coordinator pattern for runtime changes.
