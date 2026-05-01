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
        // bleeding into the host-time stall window (3 s).
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

    @Test("Burst-time fallback is quarantined; gate clears flag before settle ends")
    func watchdogGateQuarantinesBurstFallback() async {
        let player = AudioPlayer()
        let ring = LockFreeRingBuffer(capacity: 4096, channelCount: 2)
        let tap = VideoAudioTap(ringBuffer: ring, expectedSampleRate: 48_000)

        player._testActivateVideoBridgeAndStartWatchdog(tap: tap, ringBuffer: ring)

        // Burst window opens — set fallbackRequested on the C-side flag,
        // exactly what HAL source-pull errors do during route changes.
        player._testSetPendingReconfigureSnapshot(
            PreReconfigureSnapshot(
                wasPlaying: true,
                currentTime: 0,
                wasStreamBridge: false,
                wasVideoBridge: true
            )
        )
        tap._testRequestFallback()

        // Watchdog runs at least one tick; gate should both skip the
        // fallbackRequested check AND clear the flag so it can't carry
        // over into the post-burst window.
        try? await Task.sleep(for: .milliseconds(350))
        #expect(player.videoTapFallbackActive == false)
        #expect(tap.fallbackRequested == false, "Gate must clear stale fallbackRequested raised during burst")

        // End the burst with a short test settle window. Gate is still
        // active; even with a stale flag (none here, since gate cleared
        // it) we must not demote.
        player._testEndVideoReconfigureBurst(settleSeconds: 0.4)
        try? await Task.sleep(for: .milliseconds(300))
        #expect(player.videoTapFallbackActive == false)
        #expect(player.isVideoBridgeActive == true)
    }

    @Test("Fresh fallback after gate clears engages demotion")
    func watchdogResumesAfterSettleWindow() async {
        let player = AudioPlayer()
        let ring = LockFreeRingBuffer(capacity: 4096, channelCount: 2)
        let tap = VideoAudioTap(ringBuffer: ring, expectedSampleRate: 48_000)

        player._testActivateVideoBridgeAndStartWatchdog(tap: tap, ringBuffer: ring)

        // Run a tight burst → settle cycle: open the gate, end the burst
        // with a 200 ms settle window, wait past it. After the gate clears,
        // the watchdog must behave like a fresh session — a new tap
        // failure trips demotion.
        player._testSetPendingReconfigureSnapshot(
            PreReconfigureSnapshot(
                wasPlaying: true,
                currentTime: 0,
                wasStreamBridge: false,
                wasVideoBridge: true
            )
        )
        try? await Task.sleep(for: .milliseconds(50))
        player._testEndVideoReconfigureBurst(settleSeconds: 0.2)
        // 200 ms settle + one watchdog tick + 150 ms slack.
        try? await Task.sleep(for: .milliseconds(600))

        #expect(player.videoTapFallbackActive == false)

        // Genuine post-gate failure — watchdog should now engage normally.
        tap._testRequestFallback()
        try? await Task.sleep(for: .milliseconds(400))

        #expect(player.videoTapFallbackActive == true)
        #expect(player.isVideoBridgeActive == false)
    }

    @Test("Late-gate-edge fallback raised right at deadline expiry is absorbed by clean-up tick")
    func watchdogClearsLateGateEdgeFallback() async {
        let player = AudioPlayer()
        let ring = LockFreeRingBuffer(capacity: 4096, channelCount: 2)
        let tap = VideoAudioTap(ringBuffer: ring, expectedSampleRate: 48_000)

        player._testActivateVideoBridgeAndStartWatchdog(tap: tap, ringBuffer: ring)

        // Open burst so the watchdog observes at least one gated tick
        // (sets wasReconfigureGated = true). 300 ms buys one tick + slack.
        player._testSetPendingReconfigureSnapshot(
            PreReconfigureSnapshot(
                wasPlaying: true,
                currentTime: 0,
                wasStreamBridge: false,
                wasVideoBridge: true
            )
        )
        try? await Task.sleep(for: .milliseconds(300))

        // Compress the settle deadline to ~50 ms, so the very next
        // watchdog tick (~250 ms later) is past the deadline. Then trip
        // fallbackRequested in the boundary window — this simulates HAL
        // emitting one final source-pull error right at the seam.
        player._testEndVideoReconfigureBurst(settleSeconds: 0.05)
        tap._testRequestFallback()

        // Two ticks past the deadline: one to absorb the late-edge flag
        // (the post-gate clean-up branch), one normal check that should
        // see a clean state.
        try? await Task.sleep(for: .milliseconds(600))
        #expect(player.videoTapFallbackActive == false)
        #expect(player.isVideoBridgeActive == true)

        // A FRESH failure after the clean-up tick must still demote.
        tap._testRequestFallback()
        try? await Task.sleep(for: .milliseconds(400))
        #expect(player.videoTapFallbackActive == true)
        #expect(player.isVideoBridgeActive == false)
    }

    @Test("Cancel mid-burst then did-handler arms finite settle and allows fresh fallback")
    func cancelMidBurstThenDidArmsSettleAndAllowsFreshFailure() async {
        let player = AudioPlayer()
        let ring = LockFreeRingBuffer(capacity: 4096, channelCount: 2)
        let tap = VideoAudioTap(ringBuffer: ring, expectedSampleRate: 48_000)

        player._testActivateVideoBridgeAndStartWatchdog(tap: tap, ringBuffer: ring)

        // Burst opens — videoBurstGateOpen flips true via the seam.
        player._testSetPendingReconfigureSnapshot(
            PreReconfigureSnapshot(
                wasPlaying: true,
                currentTime: 0,
                wasStreamBridge: false,
                wasVideoBridge: true
            )
        )

        // User-intent cancel clears snapshot but MUST NOT touch the gate.
        // (Without the orphan-gate fix in handleEngineDidReconfigure, the
        // matching did handler would early-return on the nil snapshot and
        // leave the gate at UInt64.max forever — watchdog forever neutered.)
        player._testCancelPendingReconfigure()

        // Did handler fires through the production path. With the fix the
        // gate-arming runs BEFORE the snapshot guard, so the finite settle
        // window arms even with no resume context. Compress to 200 ms for
        // a time-bounded test.
        player._testHandleEngineDidReconfigure(overrideSettleSeconds: 0.2)

        // Past settle + one watchdog tick + slack.
        try? await Task.sleep(for: .milliseconds(600))
        #expect(player.videoTapFallbackActive == false)

        // Genuine post-gate failure must demote — proves the gate actually
        // cleared rather than orphaning at UInt64.max.
        tap._testRequestFallback()
        try? await Task.sleep(for: .milliseconds(400))

        #expect(player.videoTapFallbackActive == true)
        #expect(player.isVideoBridgeActive == false)
    }

    @Test("User-intent cancel during burst does not reopen watchdog gate")
    func cancelPendingReconfigureDoesNotReopenGate() async {
        let player = AudioPlayer()
        let ring = LockFreeRingBuffer(capacity: 4096, channelCount: 2)
        let tap = VideoAudioTap(ringBuffer: ring, expectedSampleRate: 48_000)

        player._testActivateVideoBridgeAndStartWatchdog(tap: tap, ringBuffer: ring)

        // Burst opens; user-intent path (e.g. user hits pause mid-route-change)
        // calls cancelPendingReconfigure which clears the snapshot. Gate is
        // independent and MUST remain active — HAL is still recovering.
        player._testSetPendingReconfigureSnapshot(
            PreReconfigureSnapshot(
                wasPlaying: true,
                currentTime: 0,
                wasStreamBridge: false,
                wasVideoBridge: true
            )
        )
        tap._testRequestFallback()
        player._testCancelPendingReconfigure()

        // Two watchdog ticks past the cancel.
        try? await Task.sleep(for: .milliseconds(600))

        #expect(player.videoTapFallbackActive == false)
        #expect(player.isVideoBridgeActive == true)
    }

    @Test("armVideoRouteChangeGate uses max() coalescing — never shortens")
    func armVideoRouteChangeGateCoalescesByMax() {
        let player = AudioPlayer()

        #expect(player._testVideoReconfigureGateUntilHost == 0)

        // First arm — gate moves forward.
        player._testArmVideoRouteChangeGate(seconds: 5.0)
        let firstDeadline = player._testVideoReconfigureGateUntilHost
        #expect(firstDeadline > 0)

        // A SHORTER second arm must NOT shorten the deadline. Concurrent
        // signals (HAL listener + engine observer firing for the same
        // route change) would otherwise leave the gate at whichever
        // arrived last instead of whichever extends furthest.
        player._testArmVideoRouteChangeGate(seconds: 1.0)
        let afterShorter = player._testVideoReconfigureGateUntilHost
        #expect(afterShorter == firstDeadline, "Shorter arm must not shorten the deadline (max() coalescing)")

        // A LONGER second arm extends the deadline.
        player._testArmVideoRouteChangeGate(seconds: 10.0)
        let afterLonger = player._testVideoReconfigureGateUntilHost
        #expect(afterLonger > firstDeadline, "Longer arm must extend the deadline")
    }

    @Test("HAL-armed gate deadline survives engine will/did cycle without shortening")
    func halGateSurvivesEngineWillDidCycle() {
        let player = AudioPlayer()

        // HAL listener fires first and arms a long deadline (5 s).
        // Sequence: AirPlay route flip prompts the HAL property listener
        // to arm before the engine eventually catches up.
        player._testArmVideoRouteChangeGate(seconds: 5.0)
        let halDeadline = player._testVideoReconfigureGateUntilHost
        #expect(halDeadline > 0)

        // Engine `will` then fires. With the decoupled state it sets
        // videoBurstGateOpen but MUST NOT touch the deadline (the
        // earlier longer HAL deadline must survive).
        player._testSetPendingReconfigureSnapshot(
            PreReconfigureSnapshot(
                wasPlaying: true,
                currentTime: 0,
                wasStreamBridge: false,
                wasVideoBridge: true
            )
        )
        #expect(player._testVideoReconfigureGateUntilHost == halDeadline,
                "Engine will must not clobber a longer HAL-armed deadline")

        // Engine `did` arms its 2 s settle window via max() coalescing.
        // 5 s > 2 s so the HAL deadline must remain.
        player._testHandleEngineDidReconfigure()
        let afterDid = player._testVideoReconfigureGateUntilHost
        #expect(afterDid >= halDeadline,
                "Engine did must not shorten an earlier longer HAL deadline (max-coalescing)")
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
