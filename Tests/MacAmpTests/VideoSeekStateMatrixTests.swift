@preconcurrency import AVFoundation
import Foundation
import Testing
@testable import MacAmp

/// Seek-state matrix for `VideoPlaybackController.seek(to:resume:)`.
/// The seek completion's transport-state assignment was tightened
/// during Phase 2 Oracle review (rounds 4 + 5) to (a) distinguish
/// implicit `resume: nil` from explicit `resume: false`, (b) preserve
/// loaded-but-idle state across nil-resume seeks, and (c) honour pause
/// issued during seek. This test pins down the contract so the
/// behaviour does not regress.
@MainActor
@Suite("VideoPlaybackController seek state matrix", .tags(.audio, .concurrency))
struct VideoSeekStateMatrixTests {
    @Test("resume=nil + currently playing → still playing after seek")
    func nilResumeWhilePlaying() async throws {
        let controller = try await Self.preparedController(autoPlay: true)
        try await Self.seekAndWait(controller, time: 0.5, resume: nil)
        #expect(controller.isPlaying == true)
        #expect(controller.isPaused == false)
    }

    @Test("resume=nil + currently paused → still paused after seek")
    func nilResumeWhilePaused() async throws {
        let controller = try await Self.preparedController(autoPlay: true)
        controller.pause()
        try await Self.seekAndWait(controller, time: 0.5, resume: nil)
        #expect(controller.isPlaying == false)
        #expect(controller.isPaused == true)
    }

    @Test("resume=nil + loaded-but-idle → stays loaded-but-idle")
    func nilResumeWhileLoadedIdle() async throws {
        // loadVideo(autoPlay: false) → isPlaying=false AND isPaused=false.
        // The seek completion must NOT convert this into a "paused" state.
        let controller = try await Self.preparedController(autoPlay: false)
        #expect(controller.isPlaying == false)
        #expect(controller.isPaused == false)
        try await Self.seekAndWait(controller, time: 0.5, resume: nil)
        #expect(controller.isPlaying == false)
        #expect(controller.isPaused == false, "Loaded-but-idle must not be promoted to paused by a seek")
    }

    @Test("resume=true → playing after seek (overrides current state)")
    func explicitResumeTrue() async throws {
        let controller = try await Self.preparedController(autoPlay: false)
        try await Self.seekAndWait(controller, time: 0.5, resume: true)
        #expect(controller.isPlaying == true)
        #expect(controller.isPaused == false)
    }

    @Test("resume=false → paused after seek (overrides current state)")
    func explicitResumeFalse() async throws {
        let controller = try await Self.preparedController(autoPlay: true)
        try await Self.seekAndWait(controller, time: 0.5, resume: false)
        #expect(controller.isPlaying == false)
        #expect(controller.isPaused == true)
    }

    // MARK: - Helpers

    private static func preparedController(autoPlay: Bool) async throws -> VideoPlaybackController {
        let url = try fixtureURL("2_mp4_480_stereo.mp4")
        let controller = VideoPlaybackController()
        await controller.loadVideo(url: url, autoPlay: autoPlay)
        // Wait briefly for AVPlayerItem to become readyToPlay so seek
        // doesn't bail with "no current item duration."
        try await waitUntil({ controller.player?.currentItem?.status == .readyToPlay })
        return controller
    }

    /// Issue a seek and wait for completion via a continuation.
    private static func seekAndWait(
        _ controller: VideoPlaybackController,
        time: Double,
        resume: Bool?
    ) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let resumeOnce = ContinuationGuard(continuation)
            controller.seek(to: time, resume: resume) { _ in
                resumeOnce.fire()
            }
            // Failsafe: if completion never fires (shouldn't happen for
            // the fixture clips), time out so the test doesn't hang.
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                resumeOnce.fireWithError(SeekTestError.completionTimeout)
            }
        }
    }

    private static func waitUntil(
        _ condition: @MainActor () -> Bool,
        timeoutMs: UInt64 = 5_000,
        pollMs: UInt64 = 50
    ) async throws {
        let pollNs = pollMs * 1_000_000
        let maxIterations = timeoutMs / pollMs
        for _ in 0..<maxIterations {
            if condition() { return }
            try await Task.sleep(nanoseconds: pollNs)
        }
        throw SeekTestError.timeout
    }

    private static func fixtureURL(_ filename: String) throws -> URL {
        let projectRoot: URL
        if let env = ProcessInfo.processInfo.environment["SRCROOT"] {
            projectRoot = URL(fileURLWithPath: env)
        } else {
            projectRoot = URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
        }
        let url = projectRoot.appendingPathComponent("clapperboard-videos/\(filename)")
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw SeekTestError.missingFixture(url.path)
        }
        return url
    }
}

private enum SeekTestError: Error {
    case missingFixture(String)
    case timeout
    case completionTimeout
}

/// Wraps a checked continuation so `seek` completion + the failsafe
/// timeout can race without double-resuming.
private final class ContinuationGuard: @unchecked Sendable {
    private let continuation: CheckedContinuation<Void, Error>
    private let lock = NSLock()
    private var fired = false

    init(_ continuation: CheckedContinuation<Void, Error>) {
        self.continuation = continuation
    }

    func fire() {
        lock.lock()
        let shouldFire = !fired
        fired = true
        lock.unlock()
        if shouldFire { continuation.resume() }
    }

    func fireWithError(_ error: Error) {
        lock.lock()
        let shouldFire = !fired
        fired = true
        lock.unlock()
        if shouldFire { continuation.resume(throwing: error) }
    }
}
