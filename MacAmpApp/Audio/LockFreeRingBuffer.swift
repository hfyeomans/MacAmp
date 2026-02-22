import Atomics
import CoreAudio

/// Lock-free single-producer single-consumer ring buffer for real-time audio.
///
/// Writer: MTAudioProcessingTap thread. Reader: AVAudioSourceNode render thread.
/// Both threads are real-time — zero allocations, zero locks, zero ARC on the hot path.
///
/// Storage is a flat interleaved float buffer: `[L0, R0, L1, R1, ...]`.
/// Pre-allocated once in `init`, never reallocated.
///
/// **Known race (accepted):** During an overrun, the producer advances `readHead`
/// then writes to storage regions the consumer may be reading. This is a deliberate
/// trade-off for real-time audio: a brief glitch (garbled samples) is preferable to
/// blocking either thread. TSan may flag this; it is safe because both accesses are
/// plain `memcpy` on `Float` values and the worst outcome is a few corrupted samples.
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
        let (product, overflow) = capacity.multipliedReportingOverflow(by: channelCount)
        precondition(!overflow, "capacity * channelCount overflows Int")
        self.capacity = capacity
        self.channelCount = channelCount
        self.sampleCount = product
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
        guard frameCount > 0 else { return 0 }

        // The backing store can hold at most `capacity` frames in one write cycle.
        // If caller submits more, keep the newest tail to match drop-oldest behavior.
        let boundedFrameCount = min(frameCount, capacity)
        let droppedPrefixFrames = frameCount - boundedFrameCount
        let droppedPrefixSamples = droppedPrefixFrames * channelCount
        let boundedSource = source + droppedPrefixSamples

        let wh = writeHead.load(ordering: .relaxed)
        let rh = readHead.load(ordering: .acquiring)

        let usedDistance = wh &- rh
        let usedFrames = usedDistance > UInt64(capacity) ? capacity : Int(usedDistance)
        let available = capacity - usedFrames
        let framesToWrite: Int

        if boundedFrameCount <= available {
            framesToWrite = boundedFrameCount
        } else {
            // Overrun: advance read head to make room.
            // NOTE: This creates a benign race with the consumer's memcpy (see class doc).
            let deficit = UInt64(boundedFrameCount - available)
            // .relaxed is safe here: the writeHead.store(.releasing) below provides
            // the necessary fence. The consumer acquires writeHead before reading data,
            // so it will see the updated readHead by the time it observes new frames.
            _ = readHead.wrappingIncrementThenLoad(by: deficit, ordering: .relaxed)
            overrunCount.wrappingIncrementThenLoad(by: 1, ordering: .relaxed)
            framesToWrite = boundedFrameCount
        }

        let startIndex = Int(wh % UInt64(capacity))
        let samplesToWrite = framesToWrite * channelCount
        let startSample = startIndex * channelCount

        let firstChunk = min(samplesToWrite, sampleCount - startSample)
        let secondChunk = samplesToWrite - firstChunk

        memcpy(storage + startSample, boundedSource, firstChunk * MemoryLayout<Float>.size)
        if secondChunk > 0 {
            memcpy(storage, boundedSource + firstChunk, secondChunk * MemoryLayout<Float>.size)
        }

        writeHead.store(wh &+ UInt64(framesToWrite), ordering: .releasing)
        return framesToWrite
    }

    /// Write from an AudioBufferList (interleaved format).
    func write(_ bufferList: UnsafePointer<AudioBufferList>, frameCount: UInt32) -> UInt32 {
        let ablPointer = UnsafeMutableAudioBufferListPointer(
            UnsafeMutablePointer(mutating: bufferList)
        )
        precondition(ablPointer.count == 1, "Expected single interleaved AudioBufferList")
        guard let firstBuffer = ablPointer.first,
              let data = firstBuffer.mData else {
            return 0
        }
        precondition(firstBuffer.mNumberChannels == UInt32(channelCount), "Channel count mismatch")
        let requiredBytes = UInt64(frameCount) * UInt64(channelCount) * UInt64(MemoryLayout<Float>.size)
        precondition(UInt64(firstBuffer.mDataByteSize) >= requiredBytes, "AudioBufferList buffer too small")
        let floatPtr = data.assumingMemoryBound(to: Float.self)
        return UInt32(write(from: floatPtr, frameCount: Int(frameCount)))
    }

    // MARK: - Read (Consumer Thread)

    /// Read interleaved frames from the ring buffer into a destination.
    /// Returns the number of frames actually read. Caller fills remaining with silence.
    @inline(__always)
    func read(into destination: UnsafeMutablePointer<Float>, frameCount: Int) -> Int {
        guard frameCount > 0 else { return 0 }

        let rh = readHead.load(ordering: .relaxed)
        let wh = writeHead.load(ordering: .acquiring)

        let availableDistance = wh &- rh
        if availableDistance == 0 || availableDistance > UInt64(capacity) {
            underrunCount.wrappingIncrementThenLoad(by: 1, ordering: .relaxed)
            return 0
        }

        let available = Int(availableDistance)
        let framesToRead = min(frameCount, available)
        let startIndex = Int(rh % UInt64(capacity))
        let samplesToRead = framesToRead * channelCount
        let startSample = startIndex * channelCount

        let firstChunk = min(samplesToRead, sampleCount - startSample)
        let secondChunk = samplesToRead - firstChunk

        memcpy(destination, storage + startSample, firstChunk * MemoryLayout<Float>.size)
        if secondChunk > 0 {
            memcpy(destination + firstChunk, storage, secondChunk * MemoryLayout<Float>.size)
        }

        _ = readHead.wrappingIncrementThenLoad(by: UInt64(framesToRead), ordering: .releasing)
        return framesToRead
    }

    /// Read into an AudioBufferList (interleaved format).
    func read(into bufferList: UnsafeMutablePointer<AudioBufferList>, frameCount: UInt32) -> UInt32 {
        let ablPointer = UnsafeMutableAudioBufferListPointer(bufferList)
        precondition(ablPointer.count == 1, "Expected single interleaved AudioBufferList")
        guard let firstBuffer = ablPointer.first,
              let data = firstBuffer.mData else {
            return 0
        }
        precondition(firstBuffer.mNumberChannels == UInt32(channelCount), "Channel count mismatch")
        let requiredBytes = UInt64(frameCount) * UInt64(channelCount) * UInt64(MemoryLayout<Float>.size)
        precondition(UInt64(firstBuffer.mDataByteSize) >= requiredBytes, "AudioBufferList buffer too small")
        let floatPtr = data.assumingMemoryBound(to: Float.self)
        return UInt32(read(into: floatPtr, frameCount: Int(frameCount)))
    }

    // MARK: - Generation (Format Changes)

    /// Flush all buffered data, optionally incrementing the generation counter.
    /// Called from setup callbacks (NOT real-time).
    /// Caller must ensure the producer is quiesced before calling; concurrent writes
    /// during flush may cause readHead to appear to move backward.
    func flush(newGeneration: Bool = true) {
        // Preserve monotonic head counters: an empty buffer is represented by
        // readHead == writeHead, not by resetting either counter to zero.
        // This avoids transient wh<rh observations across threads.
        let wh = writeHead.load(ordering: .acquiring)
        readHead.store(wh, ordering: .releasing)
        if newGeneration {
            generation.wrappingIncrementThenLoad(by: 1, ordering: .releasing)
        }
    }

    /// Current generation. Reader checks this to detect format changes.
    func currentGeneration() -> UInt64 {
        generation.load(ordering: .acquiring)
    }

    // MARK: - Telemetry

    /// Approximate number of frames currently available for reading.
    ///
    /// Uses relaxed loads for both head pointers — suitable for telemetry, logging,
    /// and UI display, but NOT for synchronization decisions. The producer and
    /// consumer should use their own acquire/release loads on the hot path.
    var availableFrames: Int {
        let wh = writeHead.load(ordering: .relaxed)
        let rh = readHead.load(ordering: .relaxed)
        let distance = wh &- rh
        if distance > UInt64(capacity) {
            return 0
        }
        return Int(distance)
    }

    /// Read telemetry counters (safe to call from any thread).
    func telemetry() -> (underruns: UInt64, overruns: UInt64) {
        (
            underruns: underrunCount.load(ordering: .relaxed),
            overruns: overrunCount.load(ordering: .relaxed)
        )
    }
}
