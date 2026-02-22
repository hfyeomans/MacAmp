import SwiftUI

/// Consolidates interaction state previously scattered as @State vars across
/// WinampMainWindow and its extension. Owned by root view, passed to children.
@MainActor
@Observable
final class WinampMainWindowInteractionState {
    // MARK: - Scrubbing (position slider drag)

    var isScrubbing: Bool = false
    var wasPlayingPreScrub: Bool = false
    var scrubbingProgress: Double = 0.0

    // MARK: - Track info scrolling

    var scrollOffset: CGFloat = 0
    var scrollTimer: Timer?

    // MARK: - Pause blinking

    var pauseBlinkVisible: Bool = true
    var isViewVisible: Bool = false

    // MARK: - Scrolling Animation

    /// Closure that returns the current display title. Set by the view layer so the timer
    /// always reads the live value instead of a stale capture.
    var displayTitleProvider: () -> String = { "MacAmp" }

    func startScrolling() {
        guard scrollTimer == nil else { return }
        guard isViewVisible else { return }

        scrollTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let trackText = self.displayTitleProvider()
                let textWidth = CGFloat(trackText.count * 5)
                let displayWidth = WinampMainWindowLayout.trackInfo.width

                if textWidth > displayWidth {
                    self.scrollOffset -= 5

                    if abs(self.scrollOffset) >= textWidth + 20 {
                        self.scrollOffset = displayWidth
                    }
                }
            }
        }
        if let timer = scrollTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    private var scrollRestartTask: Task<Void, Never>?

    func resetScrolling() {
        scrollTimer?.invalidate()
        scrollTimer = nil
        scrollOffset = 0
        scrollRestartTask?.cancel()

        scrollRestartTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            guard let self, self.isViewVisible else { return }
            self.startScrolling()
        }
    }

    // MARK: - Position Slider Scrubbing

    func handlePositionDrag(_ value: DragGesture.Value, in geometry: GeometryProxy, audioPlayer: AudioPlayer) {
        if !isScrubbing {
            isScrubbing = true
            wasPlayingPreScrub = audioPlayer.isPlaying
            if wasPlayingPreScrub {
                audioPlayer.pause()
            }
        }

        let width = geometry.size.width
        let x = min(max(0, value.location.x), width)
        let progress = Double(x / width)

        scrubbingProgress = progress
    }

    func handlePositionDragEnd(_ value: DragGesture.Value, in geometry: GeometryProxy, audioPlayer: AudioPlayer) {
        let width = geometry.size.width
        let x = min(max(0, value.location.x), width)
        let progress = Double(x / width)

        scrubbingProgress = progress
        audioPlayer.seekToPercent(progress, resume: wasPlayingPreScrub)

        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(0.3))
            guard !Task.isCancelled else { return }
            self?.isScrubbing = false
        }
    }

    // MARK: - Time Helpers

    func timeDigits(from seconds: Double) -> [Int] {
        let totalSeconds = max(0, Int(seconds))
        let minutes = totalSeconds / 60
        let secs = totalSeconds % 60

        return [
            minutes / 10,
            minutes % 10,
            secs / 10,
            secs % 10
        ]
    }

    // MARK: - Lifecycle

    func cleanup() {
        scrollTimer?.invalidate()
        scrollTimer = nil
        scrollRestartTask?.cancel()
        scrollRestartTask = nil
    }
}
