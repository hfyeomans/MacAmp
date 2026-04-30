import AVFoundation
import Foundation
import Testing
@testable import MacAmp

@MainActor
@Suite("Engine Configuration Observer", .tags(.audio))
struct EngineConfigObserverTests {

    @Test("Observer fires onWill once and onDid once for a single notification")
    func observerFiresOnSyntheticNotification() async {
        let engine = AVAudioEngine()
        let observer = AudioEngineConfigurationObserver(engine: engine)
        var willCount = 0
        var didCount = 0
        observer.onWillReconfigure = { willCount += 1 }
        observer.onDidReconfigure = { didCount += 1 }
        observer.start()

        NotificationCenter.default.post(
            name: .AVAudioEngineConfigurationChange,
            object: engine
        )

        // Wait for AsyncSequence delivery + 150 ms debounce window + slack.
        try? await Task.sleep(for: .milliseconds(300))

        #expect(willCount == 1)
        #expect(didCount == 1)
        observer.stop()
    }

    @Test("Observer collapses a burst of notifications into one will/did pair")
    func observerDebouncesBurst() async {
        let engine = AVAudioEngine()
        let observer = AudioEngineConfigurationObserver(engine: engine)
        var willCount = 0
        var didCount = 0
        observer.onWillReconfigure = { willCount += 1 }
        observer.onDidReconfigure = { didCount += 1 }
        observer.start()

        // Three notifications inside the 150 ms debounce window. Each new
        // notification supersedes the in-flight debounce; only the LAST one
        // ultimately fires onDid (after 150 ms of quiet).
        for _ in 0..<3 {
            NotificationCenter.default.post(
                name: .AVAudioEngineConfigurationChange,
                object: engine
            )
            try? await Task.sleep(for: .milliseconds(20))
        }

        // Wait for the final debounce to settle.
        try? await Task.sleep(for: .milliseconds(300))

        #expect(willCount == 1)
        #expect(didCount == 1)
        observer.stop()
    }

    @Test("stop() during a pending burst cancels onDid; nothing fires later")
    func observerStopDuringBurstCancelsDid() async {
        // Documents the contract from commit c454c49: onDid is NOT guaranteed
        // after onWill if stop()/deinit interrupts the debounce window.
        let engine = AVAudioEngine()
        let observer = AudioEngineConfigurationObserver(engine: engine)
        var willCount = 0
        var didCount = 0
        observer.onWillReconfigure = { willCount += 1 }
        observer.onDidReconfigure = { didCount += 1 }
        observer.start()

        NotificationCenter.default.post(
            name: .AVAudioEngineConfigurationChange,
            object: engine
        )

        // Wait long enough for onWill to fire via the AsyncSequence but well
        // under the 150 ms debounce window so onDid is still pending.
        try? await Task.sleep(for: .milliseconds(40))
        #expect(willCount == 1)
        #expect(didCount == 0)

        // Tear down mid-burst — pending debounce task must be cancelled.
        observer.stop()

        // Wait past the debounce window plus slack; onDid must remain 0.
        try? await Task.sleep(for: .milliseconds(300))
        #expect(willCount == 1)
        #expect(didCount == 0)
    }

    @Test("Observer survives multiple start/stop cycles")
    func observerSurvivesStartStopCycles() async {
        let engine = AVAudioEngine()
        let observer = AudioEngineConfigurationObserver(engine: engine)
        var willCount = 0
        var didCount = 0
        observer.onWillReconfigure = { willCount += 1 }
        observer.onDidReconfigure = { didCount += 1 }

        // Cycle 1: start → notification → stop. Should fire one will/did pair.
        observer.start()
        NotificationCenter.default.post(
            name: .AVAudioEngineConfigurationChange,
            object: engine
        )
        try? await Task.sleep(for: .milliseconds(300))
        observer.stop()
        #expect(willCount == 1)
        #expect(didCount == 1)

        // Cycle 2: posting while stopped should be a no-op.
        NotificationCenter.default.post(
            name: .AVAudioEngineConfigurationChange,
            object: engine
        )
        try? await Task.sleep(for: .milliseconds(300))
        #expect(willCount == 1)
        #expect(didCount == 1)

        // Cycle 3: restart and verify the pair fires again.
        observer.start()
        NotificationCenter.default.post(
            name: .AVAudioEngineConfigurationChange,
            object: engine
        )
        try? await Task.sleep(for: .milliseconds(300))
        #expect(willCount == 2)
        #expect(didCount == 2)
        observer.stop()
    }
}
