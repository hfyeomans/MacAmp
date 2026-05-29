import Foundation

/// Tiny weak-reference wrapper for holding objects in a collection without
/// extending their lifetime. Used by the S3-2 video-tap state fanout registries
/// (`EqualizerController` for EQ, `AudioPlayer` for balance) — the registries
/// observe `VideoTapContext`s whose lifetime is owned by the AVPlayerItem/tap, so
/// the registry must NOT keep them alive.
final class WeakBox<T: AnyObject> {
    weak var value: T?
    init(_ value: T) { self.value = value }
}
