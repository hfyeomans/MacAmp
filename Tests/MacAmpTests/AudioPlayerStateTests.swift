import Testing
@testable import MacAmp

@MainActor
@Suite("AudioPlayer State Transitions", .tags(.audio))
struct AudioPlayerStateTests {
    @Test("stop() transitions to .stopped(.manual)")
    func stopTransitionsToManualStopped() {
        let player = AudioPlayer()
        player.stop()
        #expect(player.playbackState == PlaybackState.stopped(.manual))
    }

    @Test("eject() transitions to .stopped(.ejected)")
    func ejectTransitionsToEjectedStopped() {
        let player = AudioPlayer()
        player.eject()
        #expect(player.playbackState == PlaybackState.stopped(.ejected))
    }
}
