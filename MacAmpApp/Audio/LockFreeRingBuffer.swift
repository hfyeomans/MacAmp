import Atomics
import CoreAudio

/// Lock-free single-producer single-consumer ring buffer for real-time audio.
///
/// Writer: MTAudioProcessingTap thread. Reader: AVAudioSourceNode render thread.
/// Both threads are real-time — zero allocations, zero locks, zero ARC on the hot path.
///
/// Storage is a flat interleaved float buffer: `[L0, R0, L1, R1, ...]`.
/// Pre-allocated once in `init`, never reallocated.
final class LockFreeRingBuffer: @unchecked Sendable {
    let capacity: Int
    let channelCount: Int
    private let storage: UnsafeMutablePointer<Float>
    private let sampleCount: Int

    private let writeHead = ManagedAtomic<UInt64>(0)
    private let readHead = ManagedAtomic<UInt64>(0)
    private let generation = ManagedAtomic<UInt64>(0)

    private let underrunCount = ManagedAtomic<UInt64>(0)
    private let overrunCount = ManagedAtomic<UInt64>(0)

    init(capacity: Int = 4096, channelCount: Int = 2) {
        precondition(capacity > 0, "Capacity must be positive")
        precondition(channelCount > 0, "Channel count must be positive")
        self.capacity = capacity
        self.channelCount = channelCount
        self.sampleCount = capacity * channelCount
        self.storage = .allocate(capacity: sampleCount)
        storage.initialize(repeating: 0, count: sampleCount)
    }

    deinit {
        storage.deallocate()
    }

    // MARK: - Write (Producer Thread)

    /// Write interleaved frames into the ring buffer.
    /// Called from the producer (tap) thread. Returns the number of frames actually written.
    @inline(__always)
    func write(from source: UnsafePointer<Float>, frameCount: Int) -> Int {
        let wh = writeHead.load(ordering: .relaxed)
        let rh = readHead.load(ordering: .acquiring)

        let available = capacity - Int(wh &- rh)
        let framesToWrite: Int

        if frameCount <= available {
            framesToWrite = frameCount
        } else {
            // Overrun: advance read head to make room
            let deficit = UInt64(frameCount - available)
            readHead.wrappingIncrementThenLoad(by: deficit, ordering: .relaxed)
            overrunCount.wrappingIncrementThenLoad(by: 1, ordering: .relaxed)
            framesToWrite = frameCount
        }

        let startIndex = Int(wh % UInt64(capacity))
        let samplesToWrite = framesToWrite * channelCount
        let startSample = startIndex * channelCount

        let firstChunk = min(samplesToWrite, sampleCount - startSample)
        let secondChunk = samplesToWrite - firstChunk

        memcpy(storage + startSample, source, firstChunk * MemoryLayout<Float>.size)
        if secondChunk > 0 {
            memcpy(storage, source + firstChunk, secondChunk * MemoryLayout<Float>.size)
        }

        writeHead.store(wh &+ UInt64(framesToWrite), ordering: .releasing)
        return framesToWrite
    }

    /// Write from an AudioBufferList (interleaved format).
    func write(_ bufferList: UnsafePointer<AudioBufferList>, frameCount: UInt32) -> UInt32 {
        let ablPointer = UnsafeMutableAudioBufferListPointer(
            UnsafeMutablePointer(mutating: bufferList)
        )
        guard let firstBuffer = ablPointer.first,
              let data = firstBuffer.mData else {
            return 0
        }
        let floatPtr = data.assumingMemoryBound(to: Float.self)
        return UInt32(write(from: floatPtr, frameCount: Int(frameCount)))
    }

    // MARK: - Read (Consumer Thread)

    /// Read interleaved frames from the ring buffer into a destination.
    /// Returns the number of frames actually read. Caller fills remaining with silence.
    @inline(__always)
    func read(into destination: UnsafeMutablePointer<Float>, frameCount: Int) -> Int {
        let rh = readHead.load(ordering: .relaxed)
        let wh = writeHead.load(ordering: .acquiring)

        let available = Int(wh &- rh)
        if available == 0 {
            underrunCount.wrappingIncrementThenLoad(by: 1, ordering: .relaxed)
            return 0
        }

        let framesToRead = min(frameCount, available)
        let startIndex = Int(rh % UInt64(capacity))
        let samplesToRead = framesToRead * channelCount
        let startSample = startIndex * channelCount

        let firstChunk = min(samplesToRead, sampleCount - startSample)
        let secondChunk = samplesToRead - firstChunk

        memcpy(destination, storage + startSample, firstChunk * MemoryLayout<Float>.size)
        if secondChunk > 0 {
            memcpy(destination + firstChunk, storage + startSample + firstChunk, secondChunk * MemoryLayout<Float>.size)
        }

        readHead.store(rh &+ UInt64(framesToRead), ordering: .releasing)
        return framesToRead
    }

    /// Read into an AudioBufferList (interleaved format).
    func read(into bufferList: UnsafeMutablePointer<AudioBufferList>, frameCount: UInt32) -> UInt32 {
        let ablPointer = UnsafeMutableAudioBufferListPointer(bufferList)
        guard let firstBuffer = ablPointer.first,
              let data = firstBuffer.mData else {
            return 0
        }
        let floatPtr = data.assumingMemoryBound(to: Float.self)
        return UInt32(read(into: floatPtr, frameCount: Int(frameCount)))
    }

    // MARK: - Generation (Format Changes)

    /// Flush all buffered data, optionally incrementing the generation counter.
    /// Called from setup callbacks (NOT real-time).
    func flush(newGeneration: Bool = true) {
        writeHead.store(0, ordering: .relaxed)
        readHead.store(0, ordering: .relaxed)
        if newGeneration {
            generation.wrappingIncrementThenLoad(by: 1, ordering: .releasing)
        }
    }

    /// Current generation. Reader checks this to detect format changes.
    func currentGeneration() -> UInt64 {
        generation.load(ordering: .acquiring)
    }

    // MARK: - Telemetry

    /// Number of frames currently available for reading.
    var availableFrames: Int {
        let wh = writeHead.load(ordering: .relaxed)
        let rh = readHead.load(ordering: .relaxed)
        return Int(wh &- rh)
    }

    /// Read telemetry counters (safe to call from any thread).
    func telemetry() -> (underruns: UInt64, overruns: UInt64) {
        (
            underruns: underrunCount.load(ordering: .relaxed),
            overruns: overrunCount.load(ordering: .relaxed)
        )
    }
}
