@preconcurrency import AVFoundation
import Foundation
import Testing
@testable import MacAmp

/// Lifecycle / race tests for the Phase 2 video-tap wiring. Targets the
/// failure modes Oracle flagged in the Phase 2 review (2026-05-02): the
/// `audioMix`-during-playback violation of ADR-7 and the stale-attach
/// race when a second video load supersedes the first before the
/// asset's audio tracks have finished loading. Both are exercised by
/// going through `VideoTap.buildAudioMix` + `AVPlayerItem` /
/// `AVPlayer` lifetimes the same way `AudioPlayer.startVideoLoad`
/// does in production.
@MainActor
@Suite("VideoTap lifecycle", .tags(.audio, .concurrency))
struct VideoTapLifecycleTests {
    /// Build → drop → verify the `VideoTapContext` is released by
    /// `tapFinalize`. Establishes that the `Unmanaged.passRetained`
    /// inside `VideoTap.buildAudioMix` is always balanced by AVPlayer's
    /// teardown chain when the surrounding `AVPlayer` is dropped.
    @Test("Single attach lifecycle: Context released after AVPlayer drop")
    func singleAttachLifecycle() async throws {
        let url = try Self.clipURL("1_mp4_441_stereo.mp4")
        let asset = AVURLAsset(url: url)
        let tracks = try await asset.loadTracks(withMediaType: .audio)
        let audioTrack = try #require(tracks.first)

        weak var weakContext: VideoTapContext?

        try {
            let context = VideoTapContext(feed: VisualizerFeed())
            weakContext = context
            let mix = try VideoTap.buildAudioMix(audioTrack: audioTrack, context: context)
            let item = AVPlayerItem(asset: asset)
            item.audioMix = mix
            let player = AVPlayer(playerItem: item)
            _ = player  // strong refs alive only inside this scope
        }()

        try await Self.waitUntilNil(weakContext)
        #expect(weakContext == nil, "VideoTapContext should be released after the surrounding AVPlayer is dropped")
    }

    /// Build two contexts back-to-back without any awaits between them
    /// — simulates the rapid-skip scenario where `startVideoLoad` is
    /// called for video1 then video2 before the first one has finished
    /// loading. Both contexts must be released after both AVPlayers drop.
    @Test("Rapid double-build: both contexts released after AVPlayers drop")
    func rapidDoubleBuildLifecycle() async throws {
        let url = try Self.clipURL("1_mp4_441_stereo.mp4")
        let asset = AVURLAsset(url: url)
        let tracks = try await asset.loadTracks(withMediaType: .audio)
        let audioTrack = try #require(tracks.first)

        weak var weakA: VideoTapContext?
        weak var weakB: VideoTapContext?

        try {
            let contextA = VideoTapContext(feed: VisualizerFeed())
            weakA = contextA
            let mixA = try VideoTap.buildAudioMix(audioTrack: audioTrack, context: contextA)
            let itemA = AVPlayerItem(asset: asset)
            itemA.audioMix = mixA
            let playerA = AVPlayer(playerItem: itemA)

            let contextB = VideoTapContext(feed: VisualizerFeed())
            weakB = contextB
            let mixB = try VideoTap.buildAudioMix(audioTrack: audioTrack, context: contextB)
            let itemB = AVPlayerItem(asset: asset)
            itemB.audioMix = mixB
            let playerB = AVPlayer(playerItem: itemB)

            _ = (playerA, playerB)
        }()

        try await Self.waitUntilNil(weakA)
        try await Self.waitUntilNil(weakB)
        #expect(weakA == nil, "First Context should be released after its AVPlayer is dropped")
        #expect(weakB == nil, "Second Context should be released after its AVPlayer is dropped")
    }

    /// Stale-load short-circuit. When `isStillRelevant` returns false
    /// after `audioMixBuilder` resolves, `loadVideo` MUST bail without
    /// constructing an `AVPlayer` or installing observers. This is the
    /// load-bearing race-prevention seam — production uses it via the
    /// `videoLoadGeneration` counter to invalidate superseded loads
    /// before they can overwrite the active player.
    @Test("loadVideo bails when isStillRelevant returns false after audioMixBuilder")
    func loadVideoBailsWhenStaleAfterAudioMixBuilder() async throws {
        let url = try Self.clipURL("3_mov_480_stereo.mov")
        let controller = VideoPlaybackController()

        await controller.loadVideo(
            url: url,
            autoPlay: false,
            audioMixBuilder: { _ in nil },  // succeeds; not the failure under test
            isStillRelevant: { false }
        )

        #expect(controller.player == nil, "Stale loadVideo must not construct an AVPlayer")
        #expect(controller.isPlaying == false, "Stale loadVideo must not flip isPlaying")
        #expect(controller.metadataString == "", "Stale loadVideo must not kick off metadata loading")
    }

    /// When `audioMixBuilder` returns a real mix (with a Context
    /// retained inside it via `passRetained`) but `isStillRelevant`
    /// then returns false, the built mix is dropped on the floor by
    /// `loadVideo`. The Context's +1 retain MUST still be balanced by
    /// the AVMutableAudioMix → MTAudioProcessingTap deinit chain so
    /// `tapFinalize` fires and releases the Context. This closes the
    /// retain/release lifecycle gap the prior weak-context lifecycle
    /// tests don't exercise.
    @Test("Stale loadVideo drops the built audioMix without leaking the Context")
    func staleLoadVideoDropsBuiltMixWithoutLeak() async throws {
        let url = try Self.clipURL("4_m4v_441_stereo.m4v")
        let asset = AVURLAsset(url: url)
        let tracks = try await asset.loadTracks(withMediaType: .audio)
        let audioTrack = try #require(tracks.first)
        let controller = VideoPlaybackController()

        weak var weakContext: VideoTapContext?
        // Hoisted out of the closure so we can assert the build path
        // actually fired — `try?` would let the test pass silently if
        // `buildAudioMix` ever started failing.
        let mixBuilt = ConfirmFlag()

        await controller.loadVideo(
            url: url,
            autoPlay: false,
            audioMixBuilder: { _ in
                let context = VideoTapContext(feed: VisualizerFeed())
                weakContext = context
                let mix: AVMutableAudioMix
                do {
                    mix = try VideoTap.buildAudioMix(audioTrack: audioTrack, context: context)
                } catch {
                    Issue.record("buildAudioMix unexpectedly threw: \(error)")
                    return nil
                }
                mixBuilt.set()
                return mix
            },
            isStillRelevant: { false }  // mix built, then load aborts
        )

        #expect(mixBuilt.value, "audioMixBuilder must have produced a real mix to exercise the dropped-mix path")
        #expect(controller.player == nil, "Stale loadVideo must not construct an AVPlayer")
        try await Self.waitUntilNil(weakContext)
        #expect(weakContext == nil, "Built audioMix must drop its Context retain when loadVideo aborts")
    }

    /// Positive companion to the stale-load test: when
    /// `isStillRelevant` returns true the player IS constructed.
    /// Guards against a regression where the short-circuit accidentally
    /// triggers in the happy path.
    @Test("loadVideo constructs AVPlayer when isStillRelevant returns true")
    func loadVideoConstructsPlayerWhenRelevant() async throws {
        let url = try Self.clipURL("3_mov_480_stereo.mov")
        let controller = VideoPlaybackController()

        await controller.loadVideo(
            url: url,
            autoPlay: false,
            audioMixBuilder: { _ in nil },
            isStillRelevant: { true }
        )

        #expect(controller.player != nil, "Non-stale loadVideo must construct an AVPlayer")
    }

    /// Detach (set `audioMix = nil`) while the surrounding `AVPlayer`
    /// stays alive. The Context should still be released — the tap +
    /// Context retain is held by the audioMix, not by the player itself.
    @Test("Detach during AVPlayer lifetime releases Context")
    func detachDuringPlayerLifetime() async throws {
        let url = try Self.clipURL("2_mp4_480_stereo.mp4")
        let asset = AVURLAsset(url: url)
        let tracks = try await asset.loadTracks(withMediaType: .audio)
        let audioTrack = try #require(tracks.first)

        weak var weakContext: VideoTapContext?
        let player: AVPlayer

        do {
            let context = VideoTapContext(feed: VisualizerFeed())
            weakContext = context
            let mix = try VideoTap.buildAudioMix(audioTrack: audioTrack, context: context)
            let item = AVPlayerItem(asset: asset)
            item.audioMix = mix
            let livePlayer = AVPlayer(playerItem: item)
            VideoTap.detach(from: item)  // drops audioMix from item
            player = livePlayer
        }

        try await Self.waitUntilNil(weakContext)
        #expect(weakContext == nil, "Context should be released after detach even while AVPlayer is alive")
        _ = player  // keep player alive past the wait so the test exercises detach-not-player-drop
    }

    // MARK: - Phase 7 — stress, failure-injection, and replacement lifecycle

    /// 10 build/attach/replace cycles in quick succession — every Context must be
    /// released. Stresses the `passRetained`↔`tapFinalize` balance under rapid churn
    /// (the production rapid-skip path). (todo 7.2)
    @Test("Ten rapid build/attach cycles: all Contexts released")
    func tenRapidCyclesNoLeak() async throws {
        let url = try Self.clipURL("1_mp4_441_stereo.mp4")
        let asset = AVURLAsset(url: url)
        let audioTrack = try #require(try await asset.loadTracks(withMediaType: .audio).first)

        var weakRefs: [() -> Bool] = []  // each returns true while its Context is alive
        try {
            for _ in 0..<10 {
                let context = VideoTapContext(feed: VisualizerFeed())
                weak var weakContext: VideoTapContext? = context
                weakRefs.append { weakContext != nil }
                let mix = try VideoTap.buildAudioMix(audioTrack: audioTrack, context: context)
                let item = AVPlayerItem(asset: asset)
                item.audioMix = mix
                _ = AVPlayer(playerItem: item)  // dropped at end of each iteration
            }
        }()

        // Allow the teardown chain (tapFinalize) to drain.
        for _ in 0..<50 where weakRefs.contains(where: { $0() }) {
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        #expect(weakRefs.allSatisfy { $0() == false }, "all 10 Contexts must be released after their players drop")
    }

    /// Injected `MTAudioProcessingTapCreate` failure (ADR-10): `buildAudioMix` must
    /// release the `passRetained` Context and throw — NOT leak. (todo 7.3)
    @Test("Tap-create failure releases the Context (no leak)")
    func tapCreateFailureReleasesContext() async throws {
        let url = try Self.clipURL("1_mp4_441_stereo.mp4")
        let asset = AVURLAsset(url: url)
        let audioTrack = try #require(try await asset.loadTracks(withMediaType: .audio).first)

        weak var weakContext: VideoTapContext?
        do {
            let context = VideoTapContext(feed: VisualizerFeed())
            weakContext = context
            VideoTap._testForceTapCreateFailure = true
            defer { VideoTap._testForceTapCreateFailure = false }  // reset BEFORE any await
            do {
                _ = try VideoTap.buildAudioMix(audioTrack: audioTrack, context: context)
                Issue.record("buildAudioMix should have thrown on forced tap-create failure")
            } catch VideoTapError.createFailed {
                // expected
            }
        }  // context dropped + flag reset here, before the await below

        try await Self.waitUntilNil(weakContext)
        #expect(weakContext == nil, "forced create failure must release the retained Context (ADR-10), not leak it")
    }

    /// Pause + resume must NOT release the Context — the tap stays installed on the
    /// item's audioMix across a transport pause/resume cycle. (todo 7.5)
    @Test("Pause/resume preserves the Context (not released across the cycle)")
    func pauseResumePreservesContext() async throws {
        let url = try Self.clipURL("1_mp4_441_stereo.mp4")
        let controller = VideoPlaybackController()
        weak var weakContext: VideoTapContext?

        await controller.loadVideo(
            url: url,
            autoPlay: false,
            audioMixBuilder: { asset in
                guard let track = try? await asset.loadTracks(withMediaType: .audio).first else { return nil }
                let context = VideoTapContext(feed: VisualizerFeed())
                weakContext = context
                return try? VideoTap.buildAudioMix(audioTrack: track, context: context)
            },
            isStillRelevant: { true }
        )

        #expect(controller.player != nil, "loadVideo must construct the player")
        #expect(weakContext != nil, "Context is alive while held by the item's audioMix")

        controller.play()
        controller.pause()
        controller.play()  // resume

        // The Context must survive the whole pause/resume cycle (still held by the tap).
        #expect(weakContext != nil, "pause/resume must not release the Context")
        #expect(controller.player?.currentItem?.audioMix != nil, "audioMix (with the tap) must remain installed")
    }

    /// Attach + immediate drop with NO playback (no `tapProcess` ever runs): the
    /// `tapFinalize` chain must still release the Context. (todo 7.4)
    @Test("Attach then immediate drop (no playback) still finalizes")
    func attachThenImmediateDropFinalizes() async throws {
        let url = try Self.clipURL("4_m4v_441_stereo.m4v")
        let asset = AVURLAsset(url: url)
        let audioTrack = try #require(try await asset.loadTracks(withMediaType: .audio).first)

        weak var weakContext: VideoTapContext?
        try {
            let context = VideoTapContext(feed: VisualizerFeed())
            weakContext = context
            let mix = try VideoTap.buildAudioMix(audioTrack: audioTrack, context: context)
            let item = AVPlayerItem(asset: asset)
            item.audioMix = mix
            _ = AVPlayer(playerItem: item)  // never played; dropped immediately
        }()

        try await Self.waitUntilNil(weakContext)
        #expect(weakContext == nil, "Context must finalize even if tapProcess never ran")
    }

    /// `replaceCurrentItem(with: nil)` then drop — the outgoing item's tap must
    /// finalize and release the Context. NOTE: this exercises the RELEASE path (no
    /// playback / no active `tapProcess`); active-render replacement UAF is a TSan/ASan
    /// manual concern, not proven here. (todo 7.7)
    @Test("replaceCurrentItem(nil) releases the outgoing Context")
    func replaceCurrentItemWithNilReleasesContext() async throws {
        let url = try Self.clipURL("2_mp4_480_stereo.mp4")
        let asset = AVURLAsset(url: url)
        let audioTrack = try #require(try await asset.loadTracks(withMediaType: .audio).first)

        weak var weakContext: VideoTapContext?
        try {
            let context = VideoTapContext(feed: VisualizerFeed())
            weakContext = context
            let mix = try VideoTap.buildAudioMix(audioTrack: audioTrack, context: context)
            let item = AVPlayerItem(asset: asset)
            item.audioMix = mix
            let player = AVPlayer(playerItem: item)
            player.replaceCurrentItem(with: nil)  // drop the tapped item
        }()

        try await Self.waitUntilNil(weakContext)
        #expect(weakContext == nil, "replaceCurrentItem(nil) must finalize the outgoing tap's Context")
    }

    // MARK: - Helpers

    private static func clipURL(_ filename: String) throws -> URL {
        let projectRoot: URL
        if let env = ProcessInfo.processInfo.environment["SRCROOT"] {
            projectRoot = URL(fileURLWithPath: env)
        } else {
            projectRoot = URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()  // Tests/MacAmpTests/
                .deletingLastPathComponent()  // Tests/
                .deletingLastPathComponent()  // project root
        }
        let url = projectRoot.appendingPathComponent("clapperboard-videos/\(filename)")
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw VideoTapLifecycleTestError.missingFixture(url.path)
        }
        return url
    }

    /// Poll a weak reference until it goes nil or the deadline expires.
    /// `tapFinalize` may fire on a background queue, so a fixed sleep
    /// would be flaky.
    private static func waitUntilNil<T: AnyObject>(
        _ ref: @autoclosure () -> T?,
        timeoutMs: UInt64 = 5_000,
        pollMs: UInt64 = 50
    ) async throws {
        let pollNs = pollMs * 1_000_000
        let maxIterations = timeoutMs / pollMs
        for _ in 0..<maxIterations {
            if ref() == nil { return }
            try await Task.sleep(nanoseconds: pollNs)
        }
    }
}

private enum VideoTapLifecycleTestError: Error {
    case missingFixture(String)
}

/// Tiny ref-typed boolean so closures can flip a flag without dealing
/// with `inout` capture or actor isolation.
private final class ConfirmFlag {
    private(set) var value = false
    func set() { value = true }
}
