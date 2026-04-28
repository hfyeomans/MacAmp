import Foundation
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

    // MARK: - Phase 4 Characterization Tests (seek state machine behavior)

    @Test("stop() resets currentTime and playbackProgress to zero")
    func stopResetsTimeAndProgress() {
        let player = AudioPlayer()
        player.stop()
        #expect(player.currentTime == 0)
        #expect(player.playbackProgress == 0)
    }

    @Test("stop() clears currentTrack and resets title")
    func stopClearsTrackState() {
        let player = AudioPlayer()
        player.stop()
        #expect(player.currentTrack == nil)
        #expect(player.currentTitle == "No Track Loaded")
        #expect(player.currentTrackURL == nil)
        #expect(player.currentDuration == 0.0)
    }

    @Test("stop() resets audio properties to defaults")
    func stopResetsAudioProperties() {
        let player = AudioPlayer()
        player.stop()
        #expect(player.bitrate == 0)
        #expect(player.sampleRate == 0)
        #expect(player.channelCount == 2)
    }

    @Test("stop() sets isPlaying false and isPaused false")
    func stopSetsDerivedStateFalse() {
        let player = AudioPlayer()
        player.stop()
        #expect(player.isPlaying == false)
        #expect(player.isPaused == false)
    }

    @Test("eject() clears playlist")
    func ejectClearsPlaylist() {
        let player = AudioPlayer()
        player.eject()
        #expect(player.playlist.isEmpty)
        #expect(player.currentTrack == nil)
    }

    @Test("eject() resets all playback state")
    func ejectResetsAllState() {
        let player = AudioPlayer()
        player.eject()
        #expect(player.currentTime == 0.0)
        #expect(player.playbackProgress == 0.0)
        #expect(player.currentDuration == 0.0)
        #expect(player.currentTitle == "No Track Loaded")
        #expect(player.currentTrackURL == nil)
        #expect(player.bitrate == 0)
        #expect(player.sampleRate == 0)
        #expect(player.channelCount == 2)
    }

    @Test("initial state is .idle with no track")
    func initialStateIsIdle() {
        let player = AudioPlayer()
        #expect(player.playbackState == .idle)
        #expect(player.isPlaying == false)
        #expect(player.isPaused == false)
        #expect(player.currentTrack == nil)
        #expect(player.currentTime == 0)
        #expect(player.playbackProgress == 0)
    }

    @Test("play() without loaded track stays idle")
    func playWithoutTrackStaysIdle() {
        let player = AudioPlayer()
        player.play()
        // No file loaded, so play should not transition to playing
        #expect(player.isPlaying == false)
    }

    @Test("pause() without playing has no effect")
    func pauseWithoutPlayingNoEffect() {
        let player = AudioPlayer()
        player.pause()
        // playerNode not playing, should be a no-op
        #expect(player.isPaused == false)
        #expect(player.playbackState == .idle)
    }

    @Test("volume persists via UserDefaults on commit")
    func volumePersistence() {
        let savedVolume = UserDefaults.standard.float(forKey: "volume")
        defer { UserDefaults.standard.set(savedVolume, forKey: "volume") }

        let player = AudioPlayer()
        player.volume = 0.42
        player.commitVolumeToDefaults()
        #expect(UserDefaults.standard.float(forKey: "volume") == 0.42)
    }

    @Test("balance persists via UserDefaults on commit")
    func balancePersistence() {
        let savedBalance = UserDefaults.standard.float(forKey: "balance")
        defer { UserDefaults.standard.set(savedBalance, forKey: "balance") }

        let player = AudioPlayer()
        player.balance = -0.5
        player.commitBalanceToDefaults()
        #expect(UserDefaults.standard.float(forKey: "balance") == -0.5)
    }

    // Locks in the Phase 1B contract that persistence is gesture-end-driven —
    // setter alone must NOT write UserDefaults. Guards against the per-tick
    // persistence pattern silently regressing.
    @Test("volume setter without commit does not persist")
    func volumeNoPersistenceWithoutCommit() {
        let savedVolume = UserDefaults.standard.float(forKey: "volume")
        defer { UserDefaults.standard.set(savedVolume, forKey: "volume") }

        UserDefaults.standard.set(Float(0.123), forKey: "volume")
        let player = AudioPlayer()  // init reads UserDefaults → player.volume == 0.123
        player.volume = 0.789       // setter triggers didSet but should NOT write UserDefaults
        #expect(UserDefaults.standard.float(forKey: "volume") == 0.123)
    }

    @Test("balance setter without commit does not persist")
    func balanceNoPersistenceWithoutCommit() {
        let savedBalance = UserDefaults.standard.float(forKey: "balance")
        defer { UserDefaults.standard.set(savedBalance, forKey: "balance") }

        UserDefaults.standard.set(Float(0.321), forKey: "balance")
        let player = AudioPlayer()
        player.balance = -0.789
        #expect(UserDefaults.standard.float(forKey: "balance") == 0.321)
    }

    @Test("isBridgeActive is initially false")
    func bridgeInitiallyInactive() {
        let player = AudioPlayer()
        #expect(player.isBridgeActive == false)
    }

    @Test("isEngineRendering is false when idle")
    func engineNotRenderingWhenIdle() {
        let player = AudioPlayer()
        #expect(player.isEngineRendering == false)
    }
}
