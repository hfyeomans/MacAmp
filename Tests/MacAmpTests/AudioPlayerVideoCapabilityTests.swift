import Foundation
import Testing
@testable import MacAmp

@MainActor
@Suite("AudioPlayer Video Capability", .tags(.audio))
struct AudioPlayerVideoCapabilityTests {

    @Test("supportsAudioProcessing is true for the default local-audio session")
    func supportsAudioProcessingForLocalAudioReturnsTrue() {
        let audioPlayer = AudioPlayer()
        let streamPlayer = StreamPlayer()
        let coord = PlaybackCoordinator(audioPlayer: audioPlayer, streamPlayer: streamPlayer)

        #expect(coord.supportsAudioProcessing == true)
    }

    @Test("supportsAudioProcessing is true while a video bridge is active")
    func supportsAudioProcessingWithActiveVideoBridge() {
        let audioPlayer = AudioPlayer()
        let streamPlayer = StreamPlayer()
        let coord = PlaybackCoordinator(audioPlayer: audioPlayer, streamPlayer: streamPlayer)

        audioPlayer.currentMediaType = .video
        let ring = LockFreeRingBuffer(capacity: 4096, channelCount: 2)
        let tap = VideoAudioTap(ringBuffer: ring, expectedSampleRate: 48_000)
        audioPlayer._testActivateVideoBridgeAndStartWatchdog(tap: tap, ringBuffer: ring)

        #expect(audioPlayer.isVideoBridgeActive == true)
        #expect(audioPlayer.videoTapFallbackActive == false)
        #expect(coord.supportsAudioProcessing == true)
    }

    @Test("supportsAudioProcessing flips false once tap fallback engages")
    func supportsAudioProcessingWithVideoTapFallback() {
        let audioPlayer = AudioPlayer()
        let streamPlayer = StreamPlayer()
        let coord = PlaybackCoordinator(audioPlayer: audioPlayer, streamPlayer: streamPlayer)

        audioPlayer.currentMediaType = .video
        let ring = LockFreeRingBuffer(capacity: 4096, channelCount: 2)
        let tap = VideoAudioTap(ringBuffer: ring, expectedSampleRate: 48_000)
        audioPlayer._testActivateVideoBridgeAndStartWatchdog(tap: tap, ringBuffer: ring)
        #expect(coord.supportsAudioProcessing == true)

        audioPlayer._testEngageVideoTapFallback()

        #expect(audioPlayer.isVideoBridgeActive == false)
        #expect(audioPlayer.videoTapFallbackActive == true)
        #expect(coord.supportsAudioProcessing == false)
    }

    @Test("supportsAudioProcessing is false during a video session before the bridge activates")
    func supportsAudioProcessingForVideoWithoutBridgeReturnsFalse() {
        let audioPlayer = AudioPlayer()
        let streamPlayer = StreamPlayer()
        let coord = PlaybackCoordinator(audioPlayer: audioPlayer, streamPlayer: streamPlayer)

        audioPlayer.currentMediaType = .video

        #expect(audioPlayer.isVideoBridgeActive == false)
        #expect(coord.supportsAudioProcessing == false)
    }

    @Test("snapshotButterchurnFrame returns nil for a video session without an engine bridge")
    func snapshotButterchurnFrameNilForVideoWithoutBridge() {
        let audioPlayer = AudioPlayer()
        audioPlayer.currentMediaType = .video

        // No bridge activated — even if isEngineRendering were true via some
        // other path, the bridge-aware guard rejects video-without-bridge.
        #expect(audioPlayer.snapshotButterchurnFrame() == nil)
    }

    @Test("snapshotButterchurnFrame passes the guard once a video bridge is active")
    func snapshotButterchurnFrameWorksForVideoBridge() {
        let audioPlayer = AudioPlayer()
        audioPlayer.currentMediaType = .video

        let ring = LockFreeRingBuffer(capacity: 4096, channelCount: 2)
        let tap = VideoAudioTap(ringBuffer: ring, expectedSampleRate: 48_000)
        audioPlayer._testActivateVideoBridgeAndStartWatchdog(tap: tap, ringBuffer: ring)

        // Pre-Phase-6 the guard was `currentMediaType == .audio`; this test
        // would have returned nil. Bridge-aware guard means video sessions
        // get a frame (Milkdrop / Butterchurn drives at 30 FPS off this).
        #expect(audioPlayer.snapshotButterchurnFrame() != nil)
    }

    @Test("Volume slider does not forward to AVPlayer while the engine bridge is active")
    func volumeDoesNotForwardWhileBridgeActive() {
        let audioPlayer = AudioPlayer()
        audioPlayer.currentMediaType = .video
        audioPlayer.videoPlaybackController.volume = 0  // simulate the bridge mute

        let ring = LockFreeRingBuffer(capacity: 4096, channelCount: 2)
        let tap = VideoAudioTap(ringBuffer: ring, expectedSampleRate: 48_000)
        audioPlayer._testActivateVideoBridgeAndStartWatchdog(tap: tap, ringBuffer: ring)

        audioPlayer.volume = 0.42
        // Bridge is the audible path — forwarding to AVPlayer would un-mute
        // and double-stack the audio.
        #expect(audioPlayer.videoPlaybackController.volume == 0)
    }

    @Test("Volume slider forwards to AVPlayer during video sessions without a bridge")
    func volumeForwardsToAVPlayerWhenBridgeInactive() {
        let audioPlayer = AudioPlayer()
        audioPlayer.currentMediaType = .video
        // No bridge ever activated — represents attach-failure / engine-fail
        // / pre-attach windows where AVPlayer plays its own audio direct.
        audioPlayer.videoPlaybackController.volume = 0

        audioPlayer.volume = 0.55
        #expect(audioPlayer.videoPlaybackController.volume == 0.55)
    }
}
