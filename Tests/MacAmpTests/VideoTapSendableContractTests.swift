#if DEBUG
import Foundation
import Testing
@testable import MacAmp

/// ADR-3a Gate 3 contract tests for `VideoTapContext`. The class is
/// declared `@unchecked Sendable` to silence Swift 6 concurrency checking
/// at the C-callback FFI boundary; these tests enforce that every stored
/// field carries its own thread-safety story.
@MainActor
@Suite("VideoTapContext @unchecked Sendable contract", .tags(.audio, .concurrency))
struct VideoTapContextSendableContractTests {
    /// Test 3a — Mirror reflection over every stored field. Catches type
    /// violations on Copyable fields: a non-`Sendable` reference, a
    /// `@MainActor` closure, an unaudited type. The conformance lives in
    /// `RenderThreadSafe.swift` so all conforming types are visible from a
    /// single audit file.
    ///
    /// **Coverage gap (documented):** `Mirror` cannot reflect `~Copyable`
    /// stored fields because `Mirror.Child.value: Any` requires Copyable
    /// — `Synchronization.Atomic<T>` and `Synchronization.Mutex<T>`
    /// (themselves `~Copyable`) appear as `Void` placeholder values and
    /// are skipped here. Atomic/Mutex are safe by construction (the
    /// stdlib wrappers carry their own thread-safety contract); the
    /// remaining gap — a future `let foo: SomeNonCopyableType` that is
    /// not actually atomic — is gated by the file header contract block
    /// (Gate 1) and code review only.
    @Test("All stored fields conform to RenderThreadSafe")
    func allStoredFieldsConformToRenderThreadSafe() {
        let context = VideoTapContext._makeForContractTest()
        let mirror = Mirror(reflecting: context)
        var violations: [String] = []
        for child in mirror.children {
            let label = child.label ?? "<unlabelled>"
            // ~Copyable fields (Atomic, Mutex) reflect as Void — skip them.
            if type(of: child.value) == Void.self { continue }
            if !(child.value is RenderThreadSafe) {
                violations.append("\(label): \(type(of: child.value))")
            }
        }
        #expect(violations.isEmpty, """
            VideoTapContext stored properties violate the @unchecked Sendable + render-thread \
            contract documented in VideoTapContext.swift's header. Each violation must either:
              (1) Wrap the value in Atomic<T> / Mutex<T>, OR
              (2) Conform via `extension <TypeName>: RenderThreadSafe {}` in
                  RenderThreadSafe.swift after auditing the storage.
            See plan.md ADR-3a.

            Violations:
            \(violations.joined(separator: "\n"))
            """)
    }

    /// Test 3b — Source-level regex on `VideoTapContext.swift`. Catches
    /// the `var foo: Bool` mutability-violation case that Mirror cannot
    /// distinguish from `let foo: Bool` (both reflect the same way). Per
    /// the header contract, every stored `var` must be `Atomic<...>` or
    /// `Mutex<...>`; primitive `var` fields are forbidden.
    @Test("All stored vars are Atomic<...> or Mutex<...>")
    func allStoredVarsAreAtomicOrMutex() throws {
        let url = try Self.videoTapContextSourceURL()
        let source = try String(contentsOf: url, encoding: .utf8)

        // Match `var name: Type` storage declarations (storage, not computed).
        // Computed `var` properties have `{ get }` / `{ get set }` and are
        // excluded by requiring a type body that does NOT contain `{` — the
        // pattern terminates at `=`, end-of-line, or just before `{`.
        let pattern = #/^[ \t]*(?:private|internal|fileprivate|public|nonisolated\(unsafe\))?\s*var\s+(\w+)\s*:\s*([^={\n]+?)(?:\s*=|\s*$)/#.anchorsMatchLineEndings()

        var violations: [String] = []
        for match in source.matches(of: pattern) {
            let name = String(match.output.1)
            let type = String(match.output.2).trimmingCharacters(in: .whitespacesAndNewlines)
            let isAtomic = type.hasPrefix("Atomic<")
            let isMutex = type.hasPrefix("Mutex<")
            if !isAtomic && !isMutex {
                violations.append("var \(name): \(type)")
            }
        }
        #expect(violations.isEmpty, """
            VideoTapContext has stored `var` fields that are NOT Atomic<T> or Mutex<T>.
            Per the header contract (ADR-3a Gate 1), all mutable cross-thread fields must
            wrap their value in Synchronization.Atomic or Synchronization.Mutex. Constants
            must use `let`.

            Violations:
            \(violations.joined(separator: "\n"))
            """)
    }

    /// Test 3c — render-confinement of `BiquadCascade`. The Context's `cascade`
    /// is a non-`Sendable` class mutated ONLY by the render thread (`tapProcess`);
    /// main must never touch it — that confinement is what keeps the
    /// `@unchecked Sendable` containment valid (the `RenderThreadSafe` conformance
    /// is by-confinement, not compiler-enforced). Enforce that `.cascade` member
    /// access appears only in the declaration/init (`VideoTapContext.swift`) and
    /// the render path (`VideoTap.swift`).
    @Test("BiquadCascade is render-confined: `.cascade` referenced only in allowed files")
    func cascadeIsRenderConfined() throws {
        let audioDir = try Self.projectRoot().appendingPathComponent("MacAmpApp/Audio")
        let allowed: Set<String> = ["VideoTapContext.swift", "VideoTap.swift"]
        let pattern = #/\.cascade\b/#
        var offenders: [String] = []
        if let enumerator = FileManager.default.enumerator(at: audioDir, includingPropertiesForKeys: nil) {
            for case let url as URL in enumerator where url.pathExtension == "swift" {
                if allowed.contains(url.lastPathComponent) { continue }
                let source = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
                if source.firstMatch(of: pattern) != nil {
                    offenders.append(url.lastPathComponent)
                }
            }
        }
        #expect(offenders.isEmpty, """
            `.cascade` is accessed outside the allowed files \(allowed.sorted()). The Context's
            BiquadCascade is render-thread-confined (non-Sendable, mutated only in tapProcess);
            touching it from any other context (e.g. the Phase 5 fanout) breaks the
            @unchecked Sendable containment. Phase 5 must write coefficients via
            `installCoefficients` (the Mutex), never via `.cascade`.
            Offending files: \(offenders.joined(separator: ", "))
            """)
    }

    /// Resolve the project root from `SRCROOT` (set by xcodebuild) or from
    /// `#filePath` (works under SPM `swift test`).
    private static func projectRoot() throws -> URL {
        if let env = ProcessInfo.processInfo.environment["SRCROOT"] {
            return URL(fileURLWithPath: env)
        }
        return URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // Tests/MacAmpTests/
            .deletingLastPathComponent()  // Tests/
            .deletingLastPathComponent()  // project root
    }

    private static func videoTapContextSourceURL() throws -> URL {
        try projectRoot().appendingPathComponent("MacAmpApp/Audio/VideoDSP/VideoTapContext.swift")
    }
}
#endif
