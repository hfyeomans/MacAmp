import AVFoundation
import Foundation
import Testing
@testable import MacAmp

@MainActor
@Suite("Video Tap Fallback", .tags(.audio))
struct VideoTapFallbackTests {

    @Test("engageVideoTapFallback flips the flag and restores AVPlayer volume")
    func engageRestoresAVPlayerVolume() {
        let player = AudioPlayer()
        player.volume = 0.3
        // Simulate the bridge-active mute on the controller side. While
        // the real bridge runs, AVPlayer.volume is 0 because the engine
        // is the audible path; fallback must restore the user's slider.
        player.videoPlaybackController.volume = 0

        #expect(player.videoTapFallbackActive == false)
        player._testEngageVideoTapFallback()
        #expect(player.videoTapFallbackActive == true)
        #expect(player.videoPlaybackController.volume == 0.3)
    }

    @Test("engageVideoTapFallback is idempotent")
    func engageIsIdempotent() {
        let player = AudioPlayer()
        player.volume = 0.4
        player.videoPlaybackController.volume = 0

        player._testEngageVideoTapFallback()
        #expect(player.videoTapFallbackActive == true)
        #expect(player.videoPlaybackController.volume == 0.4)

        // The idempotency guard short-circuits before the volume restore
        // runs again, so an external re-mute survives a second engage.
        player.videoPlaybackController.volume = 0.0
        player._testEngageVideoTapFallback()
        #expect(player.videoPlaybackController.volume == 0.0)
        #expect(player.videoTapFallbackActive == true)
    }

    @Test("Watchdog engages fallback when tap.fallbackRequested is set")
    func watchdogEngagesOnFallbackRequested() async {
        let player = AudioPlayer()
        let ring = LockFreeRingBuffer(capacity: 4096, channelCount: 2)
        let tap = VideoAudioTap(ringBuffer: ring, expectedSampleRate: 48_000)

        player._testActivateVideoBridgeAndStartWatchdog(tap: tap, ringBuffer: ring)
        #expect(player.videoTapFallbackActive == false)
        #expect(player.isVideoBridgeActive == true)

        // Trip the immediate-trigger path. The watchdog ticks every 250 ms;
        // 600 ms gives two ticks of margin against scheduler jitter without
        // bleeding into the host-time stall window (1 s).
        tap._testRequestFallback()
        try? await Task.sleep(for: .milliseconds(600))

        #expect(player.videoTapFallbackActive == true)
        #expect(player.isVideoBridgeActive == false)
    }

    @Test("Watchdog gate holds fallback during engine reconfigure burst")
    func watchdogGateHoldsDuringReconfigure() async {
        let player = AudioPlayer()
        let ring = LockFreeRingBuffer(capacity: 4096, channelCount: 2)
        let tap = VideoAudioTap(ringBuffer: ring, expectedSampleRate: 48_000)

        player._testActivateVideoBridgeAndStartWatchdog(tap: tap, ringBuffer: ring)
        #expect(player.videoTapFallbackActive == false)
        #expect(player.isVideoBridgeActive == true)

        // Simulate the route-change reconfigure window. While the snapshot
        // is non-nil, HAL has halted the AVPlayer audio render thread —
        // tap.fallbackRequested may briefly trip on source-pull errors
        // and lastCallbackHostTime will go stale. The watchdog must NOT
        // demote in this window; doing so leaves Milkdrop / EQ / balance
        // dimmed until the user stops + replays.
        player._testSetPendingReconfigureSnapshot(
            PreReconfigureSnapshot(
                wasPlaying: true,
                currentTime: 0,
                wasStreamBridge: false,
                wasVideoBridge: true
            )
        )
        tap._testRequestFallback()

        // Two watchdog ticks plus margin (250 ms × 2 + 100 ms slack).
        try? await Task.sleep(for: .milliseconds(600))

        #expect(player.videoTapFallbackActive == false)
        #expect(player.isVideoBridgeActive == true)
    }

    @Test("playTrack resets videoTapFallbackActive for the next session")
    func playTrackResetsFallbackFlag() {
        let player = AudioPlayer()
        player._testEngageVideoTapFallback()
        #expect(player.videoTapFallbackActive == true)

        // Use a non-stream file URL that doesn't exist — `playTrack` will
        // bail out at `engine.loadFile`, but the per-track reset of
        // `videoTapFallbackActive` runs BEFORE the load attempt.
        let track = Track(
            url: URL(fileURLWithPath: "/tmp/macamp-vtf-tests/nonexistent.mp3"),
            title: "Test",
            artist: "Test",
            duration: 0
        )
        player.playTrack(track: track)
        #expect(player.videoTapFallbackActive == false)
    }
}
