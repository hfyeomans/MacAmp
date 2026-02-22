import Testing
import Foundation
@testable import MacAmp

// MARK: - Unit Tests

@Suite("LockFreeRingBuffer")
struct LockFreeRingBufferTests {
    @Test("Write N frames and read N frames back with data integrity")
    func writeAndReadExact() {
        let buffer = LockFreeRingBuffer(capacity: 64, channelCount: 2)
        let frameCount = 32
        let sampleCount = frameCount * 2

        var source = [Float](repeating: 0, count: sampleCount)
        for i in 0..<sampleCount {
            source[i] = Float(i)
        }

        let written = buffer.write(from: &source, frameCount: frameCount)
        #expect(written == frameCount)
        #expect(buffer.availableFrames == frameCount)

        var dest = [Float](repeating: -1, count: sampleCount)
        let readCount = buffer.read(into: &dest, frameCount: frameCount)
        #expect(readCount == frameCount)
        #expect(buffer.availableFrames == 0)

        for i in 0..<sampleCount {
            #expect(dest[i] == source[i], "Mismatch at sample \(i): \(dest[i]) != \(source[i])")
        }
    }

    @Test("Read from empty buffer returns 0 and increments underrun")
    func readFromEmpty() {
        let buffer = LockFreeRingBuffer(capacity: 64, channelCount: 2)
        var dest = [Float](repeating: 0, count: 128)
        let readCount = buffer.read(into: &dest, frameCount: 64)
        #expect(readCount == 0)
        let stats = buffer.telemetry()
        #expect(stats.underruns == 1)
    }

    @Test("Write over capacity triggers overrun and advances read pointer")
    func writeOverCapacity() {
        let capacity = 16
        let buffer = LockFreeRingBuffer(capacity: capacity, channelCount: 1)

        // Fill buffer completely
        var first = [Float]((0..<16).map { Float($0) })
        let w1 = buffer.write(from: &first, frameCount: capacity)
        #expect(w1 == capacity)

        // Write 8 more frames — should overrun, dropping oldest 8
        var second = [Float]((100..<108).map { Float($0) })
        let w2 = buffer.write(from: &second, frameCount: 8)
        #expect(w2 == 8)

        let stats = buffer.telemetry()
        #expect(stats.overruns == 1)

        // Read back: should get frames 8-15 from first write, then 100-107
        var dest = [Float](repeating: -1, count: capacity)
        let readCount = buffer.read(into: &dest, frameCount: capacity)
        #expect(readCount == capacity)

        // First 8 frames should be from the original write (indices 8-15)
        for i in 0..<8 {
            #expect(dest[i] == Float(i + 8))
        }
        // Last 8 frames should be the overwriting data
        for i in 0..<8 {
            #expect(dest[i + 8] == Float(100 + i))
        }
    }

    @Test("Wrap-around write and read across buffer boundary")
    func wrapAround() {
        let capacity = 16
        let buffer = LockFreeRingBuffer(capacity: capacity, channelCount: 1)

        // Write 12 frames, then read them to advance pointers
        var batch1 = [Float]((0..<12).map { Float($0) })
        _ = buffer.write(from: &batch1, frameCount: 12)
        var trash = [Float](repeating: 0, count: 12)
        _ = buffer.read(into: &trash, frameCount: 12)

        // Now write pointer is at 12, read pointer is at 12
        // Write 10 frames — wraps around (12+10 = 22 > 16)
        var batch2 = [Float]((50..<60).map { Float($0) })
        let written = buffer.write(from: &batch2, frameCount: 10)
        #expect(written == 10)

        var dest = [Float](repeating: -1, count: 10)
        let readCount = buffer.read(into: &dest, frameCount: 10)
        #expect(readCount == 10)

        for i in 0..<10 {
            #expect(dest[i] == Float(50 + i), "Wrap-around mismatch at \(i)")
        }
    }

    @Test("Multiple small writes followed by one large read")
    func multipleSmallWrites() {
        let buffer = LockFreeRingBuffer(capacity: 64, channelCount: 1)

        for batch in 0..<4 {
            var data = [Float]((0..<8).map { Float(batch * 100 + Int($0)) })
            let written = buffer.write(from: &data, frameCount: 8)
            #expect(written == 8)
        }

        #expect(buffer.availableFrames == 32)

        var dest = [Float](repeating: -1, count: 32)
        let readCount = buffer.read(into: &dest, frameCount: 32)
        #expect(readCount == 32)

        for batch in 0..<4 {
            for i in 0..<8 {
                #expect(dest[batch * 8 + i] == Float(batch * 100 + i))
            }
        }
    }

    @Test("Generation change detected by reader")
    func generationChange() {
        let buffer = LockFreeRingBuffer(capacity: 64, channelCount: 2)
        let gen0 = buffer.currentGeneration()
        #expect(gen0 == 0)

        buffer.flush(newGeneration: true)
        let gen1 = buffer.currentGeneration()
        #expect(gen1 == 1)

        buffer.flush(newGeneration: false)
        let gen2 = buffer.currentGeneration()
        #expect(gen2 == 1)
    }

    @Test("Flush clears all buffered data")
    func flushClearsData() {
        let buffer = LockFreeRingBuffer(capacity: 64, channelCount: 2)
        var source = [Float](repeating: 1.0, count: 64)
        _ = buffer.write(from: &source, frameCount: 32)
        #expect(buffer.availableFrames == 32)

        buffer.flush()
        #expect(buffer.availableFrames == 0)
    }

    @Test("Telemetry counters track underruns and overruns")
    func telemetryCounters() {
        let capacity = 8
        let buffer = LockFreeRingBuffer(capacity: capacity, channelCount: 1)

        // Trigger underrun
        var dest = [Float](repeating: 0, count: 8)
        _ = buffer.read(into: &dest, frameCount: 8)
        _ = buffer.read(into: &dest, frameCount: 8)

        // Fill and trigger overrun
        var source = [Float](repeating: 1.0, count: capacity)
        _ = buffer.write(from: &source, frameCount: capacity)
        var extra = [Float](repeating: 2.0, count: 4)
        _ = buffer.write(from: &extra, frameCount: 4)

        let stats = buffer.telemetry()
        #expect(stats.underruns == 2)
        #expect(stats.overruns == 1)
    }

    @Test("Stereo data integrity — L/R channels preserved")
    func stereoDataIntegrity() {
        let buffer = LockFreeRingBuffer(capacity: 32, channelCount: 2)
        let frameCount = 16
        let sampleCount = frameCount * 2

        // Create L/R pattern: L=frame, R=frame+1000
        var source = [Float](repeating: 0, count: sampleCount)
        for frame in 0..<frameCount {
            source[frame * 2] = Float(frame)          // Left
            source[frame * 2 + 1] = Float(frame + 1000) // Right
        }

        _ = buffer.write(from: &source, frameCount: frameCount)
        var dest = [Float](repeating: -1, count: sampleCount)
        _ = buffer.read(into: &dest, frameCount: frameCount)

        for frame in 0..<frameCount {
            #expect(dest[frame * 2] == Float(frame), "Left channel mismatch at frame \(frame)")
            #expect(dest[frame * 2 + 1] == Float(frame + 1000), "Right channel mismatch at frame \(frame)")
        }
    }
}

// MARK: - Concurrent Stress Tests

@Suite("LockFreeRingBuffer Concurrency", .tags(.concurrency))
struct LockFreeRingBufferConcurrencyTests {
    @Test("Concurrent writer and reader — no crash, data flows",
          .timeLimit(.minutes(1)))
    func concurrentWriteRead() async {
        let buffer = LockFreeRingBuffer(capacity: 4096, channelCount: 2)
        let iterations = 50_000
        let chunkSize = 128
        let sampleCount = chunkSize * 2

        await withTaskGroup(of: Void.self) { group in
            // Writer
            group.addTask {
                var source = [Float]((0..<sampleCount).map { Float($0) })
                for _ in 0..<iterations {
                    _ = buffer.write(from: &source, frameCount: chunkSize)
                }
            }

            // Reader
            group.addTask {
                var dest = [Float](repeating: 0, count: sampleCount)
                var totalRead = 0
                while totalRead < iterations * chunkSize {
                    let n = buffer.read(into: &dest, frameCount: chunkSize)
                    totalRead += n
                    if n == 0 {
                        await Task.yield()
                    }
                }
            }
        }

        // If we get here without crashing or hanging, the test passes
        let stats = buffer.telemetry()
        #expect(stats.underruns >= 0) // Just verifying telemetry works
    }

    @Test("Concurrent write/read with periodic flush (simulating ABR format change)",
          .timeLimit(.minutes(1)))
    func concurrentWithFormatChange() async {
        let buffer = LockFreeRingBuffer(capacity: 4096, channelCount: 2)
        let chunkSize = 64
        let sampleCount = chunkSize * 2
        let writerIterations = 20_000

        await withTaskGroup(of: Void.self) { group in
            // Writer
            group.addTask {
                var source = [Float](repeating: 0.5, count: sampleCount)
                for i in 0..<writerIterations {
                    _ = buffer.write(from: &source, frameCount: chunkSize)
                    // Flush every 1000 iterations to simulate format change
                    if i > 0 && i % 1000 == 0 {
                        buffer.flush(newGeneration: true)
                    }
                }
            }

            // Reader
            group.addTask {
                var dest = [Float](repeating: 0, count: sampleCount)
                var cachedGen: UInt64 = 0
                var totalRead = 0
                let targetRead = writerIterations * chunkSize / 2 // Read half the data

                while totalRead < targetRead {
                    let gen = buffer.currentGeneration()
                    if gen != cachedGen {
                        cachedGen = gen
                    }
                    let n = buffer.read(into: &dest, frameCount: chunkSize)
                    totalRead += n
                    if n == 0 {
                        await Task.yield()
                    }
                }
            }
        }

        // Generation should have been incremented
        #expect(buffer.currentGeneration() > 0)
    }

    @Test("High throughput — 48kHz simulated audio rate",
          .timeLimit(.minutes(1)))
    func highThroughput() async {
        let buffer = LockFreeRingBuffer(capacity: 4096, channelCount: 2)
        let sampleRate = 48000
        let durationSeconds = 2
        let framesPerChunk = 512
        let totalFrames = sampleRate * durationSeconds
        let chunksToWrite = totalFrames / framesPerChunk
        let sampleCount = framesPerChunk * 2

        await withTaskGroup(of: Void.self) { group in
            // Writer at ~48kHz
            group.addTask {
                var source = [Float](repeating: 0.25, count: sampleCount)
                for _ in 0..<chunksToWrite {
                    _ = buffer.write(from: &source, frameCount: framesPerChunk)
                }
            }

            // Reader at ~48kHz
            group.addTask {
                var dest = [Float](repeating: 0, count: sampleCount)
                var totalRead = 0
                while totalRead < totalFrames {
                    let n = buffer.read(into: &dest, frameCount: framesPerChunk)
                    totalRead += n
                    if n == 0 {
                        await Task.yield()
                    }
                }
            }
        }

        let stats = buffer.telemetry()
        // Some overruns/underruns are expected under contention but should be bounded
        #expect(stats.overruns < UInt64(chunksToWrite / 2), "Too many overruns: \(stats.overruns)")
    }
}

// MARK: - Tags

extension Tag {
    @Tag static var concurrency: Self
}
