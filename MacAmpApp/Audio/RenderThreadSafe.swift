import AudioToolbox
import Foundation
import Synchronization

/// Marker protocol for types safe to store as fields of an `@unchecked Sendable`
/// audio-mechanism class accessed from an Apple render thread (`MTAudioProcessingTap`,
/// `AVAudioSourceNode` tap closure, etc.).
///
/// Conformance is opt-in via extension. Each conforming type must:
///   - Be `Sendable` (or equivalent at the FFI boundary)
///   - Provide its own thread-safety story (atomics, mutex, immutability)
///   - Not capture or invoke `@MainActor`-isolated state on the render thread
///
/// **Conformance centralization rule.** All `RenderThreadSafe` conformance
/// extensions MUST live in this file. PRs adding conformances elsewhere require
/// explicit reviewer justification and an ADR amendment. This rule reduces the
/// audit surface to a single reviewable file.
///
/// **Stdlib primitive value types are deliberately not conformed.** Per the
/// `VideoTapContext` header contract, primitive cross-thread state must be
/// `Atomic`-wrapped; mutability is enforced by the source-level guard
/// (`VideoTapSendableContractTests.allStoredVarsAreAtomicOrMutex`), not by
/// `Mirror` reflection.
///
/// **Marked `~Copyable`** so that `Synchronization.Atomic<T>` and
/// `Synchronization.Mutex<T>` (themselves `~Copyable`) can conform.
/// Copyable types remain free to conform — `~Copyable` is a generalization,
/// not a restriction.
internal protocol RenderThreadSafe: ~Copyable {}

extension Atomic: RenderThreadSafe {}
extension Mutex: RenderThreadSafe {}

extension Optional: RenderThreadSafe where Wrapped: RenderThreadSafe {}

extension UnsafePointer: RenderThreadSafe {}
extension UnsafeMutablePointer: RenderThreadSafe {}
extension UnsafeRawPointer: RenderThreadSafe {}
extension UnsafeMutableRawPointer: RenderThreadSafe {}

extension AudioStreamBasicDescription: RenderThreadSafe {}

extension VisualizerFeed: RenderThreadSafe {}
extension VisualizerScratchBuffers: RenderThreadSafe {}
