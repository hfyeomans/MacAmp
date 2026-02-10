import Foundation
import Observation

/// Observes AppSettings changes and fires callbacks. Uses recursive
/// `withObservationTracking` with explicit `start()`/`stop()` lifecycle.
@MainActor
final class WindowSettingsObserver {
    private let settings: AppSettings
    private var tasks: [String: Task<Void, Never>] = [:]
    private var handlers: Handlers?

    private struct Handlers {
        let onAlwaysOnTopChanged: @MainActor (Bool) -> Void
        let onDoubleSizeChanged: @MainActor (Bool) -> Void
        let onShowVideoChanged: @MainActor (Bool) -> Void
        let onShowMilkdropChanged: @MainActor (Bool) -> Void
    }

    init(settings: AppSettings) {
        self.settings = settings
    }

    // MARK: - Lifecycle

    func start(
        onAlwaysOnTopChanged: @escaping @MainActor (Bool) -> Void,
        onDoubleSizeChanged: @escaping @MainActor (Bool) -> Void,
        onShowVideoChanged: @escaping @MainActor (Bool) -> Void,
        onShowMilkdropChanged: @escaping @MainActor (Bool) -> Void
    ) {
        handlers = Handlers(
            onAlwaysOnTopChanged: onAlwaysOnTopChanged,
            onDoubleSizeChanged: onDoubleSizeChanged,
            onShowVideoChanged: onShowVideoChanged,
            onShowMilkdropChanged: onShowMilkdropChanged
        )
        observeAlwaysOnTop()
        observeDoubleSize()
        observeShowVideo()
        observeShowMilkdrop()
    }

    func stop() {
        tasks.values.forEach { $0.cancel() }
        tasks.removeAll()
        handlers = nil
    }

    // MARK: - Observers

    private func observeAlwaysOnTop() {
        tasks["alwaysOnTop"]?.cancel()
        tasks["alwaysOnTop"] = Task { @MainActor [weak self] in
            guard let self else { return }
            withObservationTracking {
                _ = self.settings.isAlwaysOnTop
            } onChange: {
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.handlers?.onAlwaysOnTopChanged(self.settings.isAlwaysOnTop)
                    self.observeAlwaysOnTop()
                }
            }
        }
    }

    private func observeDoubleSize() {
        tasks["doubleSize"]?.cancel()
        tasks["doubleSize"] = Task { @MainActor [weak self] in
            guard let self else { return }
            withObservationTracking {
                _ = self.settings.isDoubleSizeMode
            } onChange: {
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.handlers?.onDoubleSizeChanged(self.settings.isDoubleSizeMode)
                    self.observeDoubleSize()
                }
            }
        }
    }

    private func observeShowVideo() {
        tasks["showVideo"]?.cancel()
        tasks["showVideo"] = Task { @MainActor [weak self] in
            guard let self else { return }
            withObservationTracking {
                _ = self.settings.showVideoWindow
            } onChange: {
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.handlers?.onShowVideoChanged(self.settings.showVideoWindow)
                    self.observeShowVideo()
                }
            }
        }
    }

    private func observeShowMilkdrop() {
        tasks["showMilkdrop"]?.cancel()
        tasks["showMilkdrop"] = Task { @MainActor [weak self] in
            guard let self else { return }
            withObservationTracking {
                _ = self.settings.showMilkdropWindow
            } onChange: {
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.handlers?.onShowMilkdropChanged(self.settings.showMilkdropWindow)
                    self.observeShowMilkdrop()
                }
            }
        }
    }
}
