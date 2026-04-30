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
}
