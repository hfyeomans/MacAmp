import Foundation
import AudioToolbox

/// Orchestrates the full stream decode chain:
/// `URLSession → ICYFramer → AudioFileStreamParser → AudioConverterDecoder → LockFreeRingBuffer`
///
/// **Architecture:**
/// - `@MainActor` class for lifecycle/state management (matches PlaybackCoordinator pattern)
/// - `DecodeContext` (@unchecked Sendable, queue-confined) owns all decode-queue state
/// - NSObject delegate proxy forwards URLSession bytes to decode queue
/// - Callbacks to StreamPlayer are `@MainActor @Sendable`
///
/// **Threading:**
/// ```
/// Main Thread (@MainActor)     Decode Queue (serial)     Audio IO Thread (RT)
/// ├─ start()/stop()/pause()    ├─ ICYFramer              ├─ AVAudioSourceNode
/// ├─ state callbacks           ├─ AudioFileStreamParser   │  render block
/// └─ UI updates                ├─ AudioConverterDecoder   │  ringBuffer.read()
///                              └─ ringBuffer.write()  ──►│
/// ```
///
/// **Layer:** Mechanism (orchestrator, owns decode chain lifecycle)
@MainActor
final class StreamDecodePipeline {

    // MARK: - Stream State

    enum StreamState: Sendable {
        case idle
        case connecting
        case buffering
        case playing
        case paused
        case error(String)
    }

    private(set) var state: StreamState = .idle

    // MARK: - Callbacks (to StreamPlayer)

    var onStateChange: (@MainActor @Sendable (StreamState) -> Void)?
    var onFormatReady: (@MainActor @Sendable (Float64) -> Void)?
    var onMetadata: (@MainActor @Sendable (ICYFramer.ICYMetadata) -> Void)?

    // MARK: - Ring Buffer (shared with AudioPlayer's AVAudioSourceNode)

    private(set) var ringBuffer: LockFreeRingBuffer?

    // MARK: - Decode Context (queue-confined, NOT @MainActor)

    private let decodeQueue = DispatchQueue(label: "com.macamp.stream.decode", qos: .userInitiated)
    private var decodeContext: DecodeContext?

    // MARK: - URLSession

    private var urlSession: URLSession?
    private var dataTask: URLSessionDataTask?
    private var delegateProxy: SessionDelegateProxy?

    // MARK: - Generation Token

    /// Incremented on each start() AND stop(). All callbacks check generation
    /// to reject stale data from previous streams.
    private var generation: UInt64 = 0

    // MARK: - Prebuffer Tracking

    private var formatReadyFired: Bool = false

    // MARK: - Lifecycle

    func start(url: URL, ringBuffer: LockFreeRingBuffer) {
        // Teardown previous (also advances generation)
        stopInternal()

        generation &+= 1
        let currentGeneration = generation

        self.ringBuffer = ringBuffer
        ringBuffer.flush()
        formatReadyFired = false

        // Create decode context
        let formatHint = Self.formatHint(for: url)
        let context = DecodeContext(
            decodeQueue: decodeQueue,
            ringBuffer: ringBuffer,
            formatHint: formatHint,
            generation: currentGeneration,
            onFormatReady: { [weak self] sampleRate, gen in
                Task { @MainActor [weak self] in
                    guard let self, gen == self.generation, !self.formatReadyFired else { return }
                    self.formatReadyFired = true
                    self.setState(.playing)
                    self.onFormatReady?(sampleRate)
                    AppLog.info(.audio, "StreamDecodePipeline: Format ready — \(sampleRate)Hz")
                }
            },
            onMetadata: { [weak self] metadata, gen in
                Task { @MainActor [weak self] in
                    guard let self, gen == self.generation else { return }
                    self.onMetadata?(metadata)
                }
            }
        )
        decodeContext = context

        // Create URLSession with delegate proxy
        // Proxy callbacks are set once before URLSession starts, then immutable.
        let proxy = SessionDelegateProxy(
            onResponse: { [weak self] response in
                Task { @MainActor [weak self] in
                    self?.handleHTTPResponse(response, generation: currentGeneration)
                }
            },
            onData: { [weak context] data in
                // Direct dispatch to decode queue — no MainActor hop needed.
                // This avoids the race where data arrives before response handler
                // configures the framer (configureFramer also dispatches to decode queue,
                // so ordering is preserved by the serial queue).
                context?.handleIncomingData(data)
            },
            onComplete: { [weak self] error in
                Task { @MainActor [weak self] in
                    self?.handleStreamComplete(error: error, generation: currentGeneration)
                }
            }
        )
        delegateProxy = proxy

        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = 30
        sessionConfig.timeoutIntervalForResource = 0
        let operationQueue = OperationQueue()
        operationQueue.maxConcurrentOperationCount = 1
        operationQueue.qualityOfService = .userInitiated
        urlSession = URLSession(configuration: sessionConfig, delegate: proxy, delegateQueue: operationQueue)

        var request = URLRequest(url: url)
        request.setValue("1", forHTTPHeaderField: "Icy-MetaData")
        request.setValue("*/*", forHTTPHeaderField: "Accept")

        dataTask = urlSession?.dataTask(with: request)
        setState(.connecting)
        dataTask?.resume()

        AppLog.info(.audio, "StreamDecodePipeline: Starting — \(url.absoluteString)")
    }

    func pause() {
        guard case .playing = state else { return }
        dataTask?.suspend()
        setState(.paused)
    }

    func resume() {
        guard case .paused = state else { return }
        dataTask?.resume()
        setState(.playing)
    }

    func stop() {
        stopInternal()
        setState(.idle)
    }

    isolated deinit {
        dataTask?.cancel()
        urlSession?.invalidateAndCancel()
        decodeContext?.shutdown()
    }

    // MARK: - Internal

    private func stopInternal() {
        // Advance generation FIRST — stale callbacks will be rejected
        generation &+= 1

        dataTask?.cancel()
        dataTask = nil
        urlSession?.invalidateAndCancel()
        urlSession = nil
        delegateProxy = nil
        decodeContext?.shutdown()
        decodeContext = nil
        ringBuffer = nil
        formatReadyFired = false
    }

    private func setState(_ newState: StreamState) {
        state = newState
        onStateChange?(newState)
    }

    // MARK: - HTTP Response (MainActor)

    private func handleHTTPResponse(_ response: URLResponse, generation: UInt64) {
        guard generation == self.generation else { return }

        guard let httpResponse = response as? HTTPURLResponse else {
            stopInternal()
            setState(.error("Invalid HTTP response"))
            return
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            stopInternal()
            setState(.error("HTTP \(httpResponse.statusCode)"))
            return
        }

        // Extract ICY metaint — case-insensitive header lookup
        let headers = httpResponse.allHeaderFields
        let metaInt: Int
        if let metaIntValue = Self.extractICYMetaInt(from: headers) {
            metaInt = metaIntValue
            AppLog.debug(.audio, "StreamDecodePipeline: ICY metaint = \(metaInt)")
        } else {
            metaInt = 0
        }

        // configureFramer dispatches to decode queue — ordering is preserved
        // because data delivery also dispatches to the same serial queue.
        decodeContext?.configureFramer(metaInterval: metaInt)
        setState(.buffering)
    }

    /// Case-insensitive lookup for icy-metaint header.
    private static func extractICYMetaInt(from headers: [AnyHashable: Any]) -> Int? {
        for (key, value) in headers {
            if let keyStr = key as? String,
               keyStr.caseInsensitiveCompare("icy-metaint") == .orderedSame,
               let valueStr = value as? String,
               let parsed = Int(valueStr) {
                return parsed
            }
        }
        return nil
    }

    // MARK: - Stream Completion (MainActor)

    private func handleStreamComplete(error: Error?, generation: UInt64) {
        guard generation == self.generation else { return }

        // Teardown on error/completion (not just state change)
        let wasError: Bool
        if let error {
            if (error as NSError).code == NSURLErrorCancelled {
                wasError = false  // Normal cancellation from stop()
            } else {
                wasError = true
                AppLog.error(.audio, "StreamDecodePipeline: \(error.localizedDescription)")
            }
        } else {
            wasError = false
        }

        stopInternal()

        if wasError {
            setState(.error("Stream error: \(error!.localizedDescription)"))
        } else if (error as? NSError)?.code != NSURLErrorCancelled {
            // Natural stream end (server closed connection)
            setState(.idle)
            AppLog.info(.audio, "StreamDecodePipeline: Stream ended")
        }
        // If cancelled, stopInternal already set idle via generation advance
    }

    // MARK: - Format Hint

    private static func formatHint(for url: URL) -> AudioFileTypeID {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "mp3": return kAudioFileMP3Type
        case "aac", "aacp": return kAudioFileAAC_ADTSType
        default: break
        }
        let path = url.path.lowercased()
        if path.contains("mp3") || path.contains("mpeg") { return kAudioFileMP3Type }
        if path.contains("aac") { return kAudioFileAAC_ADTSType }
        return 0
    }

    static func formatHint(forContentType contentType: String?) -> AudioFileTypeID {
        guard let ct = contentType?.lowercased() else { return 0 }
        if ct.contains("mpeg") || ct.contains("mp3") { return kAudioFileMP3Type }
        if ct.contains("aac") || ct.contains("aacp") { return kAudioFileAAC_ADTSType }
        return 0
    }
}

// MARK: - DecodeContext (queue-confined, NOT @MainActor)

/// Owns all decode-queue-confined state. Accessed ONLY from the decode serial queue.
/// Separated from the @MainActor pipeline to avoid isolation conflicts.
///
/// @unchecked Sendable: All mutable state is confined to the decode serial queue.
/// Debug assertions (dispatchPrecondition) verify confinement on internal methods.
/// This is the same pattern as VisualizerScratchBuffers in VisualizerPipeline.swift.
private final class DecodeContext: @unchecked Sendable {
    private let decodeQueue: DispatchQueue
    private let ringBuffer: LockFreeRingBuffer
    private let generation: UInt64

    private var framer = ICYFramer()
    private var parser: AudioFileStreamParser?
    private var decoder: AudioConverterDecoder?
    private var magicCookie: Data?
    private var prebufferedFrames: Int = 0
    private var formatReadyFired: Bool = false
    private var detectedSampleRate: Float64 = 0
    private var isShutdown: Bool = false

    private static let prebufferThreshold: Int = 2048

    private let onFormatReady: @Sendable (Float64, UInt64) -> Void
    private let onMetadata: @Sendable (ICYFramer.ICYMetadata, UInt64) -> Void

    init(
        decodeQueue: DispatchQueue,
        ringBuffer: LockFreeRingBuffer,
        formatHint: AudioFileTypeID,
        generation: UInt64,
        onFormatReady: @escaping @Sendable (Float64, UInt64) -> Void,
        onMetadata: @escaping @Sendable (ICYFramer.ICYMetadata, UInt64) -> Void
    ) {
        self.decodeQueue = decodeQueue
        self.ringBuffer = ringBuffer
        self.generation = generation
        self.onFormatReady = onFormatReady
        self.onMetadata = onMetadata

        decodeQueue.async { [self] in
            let parser = AudioFileStreamParser(formatHint: formatHint)
            parser.confinementQueue = decodeQueue

            parser.onFormatAvailable = { [weak self] asbd in
                self?.handleFormatAvailable(asbd)
            }
            parser.onMagicCookie = { [weak self] cookie in
                self?.magicCookie = cookie
            }
            parser.onPackets = { [weak self] data, descriptions in
                self?.handlePackets(data: data, descriptions: descriptions)
            }

            self.parser = parser
        }
    }

    /// Configure the ICY framer with metaint value.
    /// Dispatched to decode queue — preserves ordering with data delivery.
    func configureFramer(metaInterval: Int) {
        decodeQueue.async { [self] in
            guard !isShutdown else { return }
            framer.configure(metaInterval: metaInterval)
        }
    }

    /// Process incoming HTTP data. Dispatched to decode queue.
    func handleIncomingData(_ data: Data) {
        decodeQueue.async { [self] in
            guard !isShutdown else { return }
            let chunks = framer.consume(data)

            for chunk in chunks {
                switch chunk {
                case .audio(let audioData):
                    parser?.parse(audioData)
                case .metadata(let metadata):
                    onMetadata(metadata, generation)
                }
            }
        }
    }

    /// Shutdown the decode chain. C API ordering: converter before parser.
    /// After shutdown, all subsequent decode-queue work is rejected via isShutdown flag.
    func shutdown() {
        decodeQueue.async { [self] in
            guard !isShutdown else { return }
            isShutdown = true
            decoder?.dispose()
            decoder = nil
            parser?.close()
            parser = nil
        }
    }

    // MARK: - Internal (decode queue only)

    private func handleFormatAvailable(_ asbd: AudioStreamBasicDescription) {
        dispatchPrecondition(condition: .onQueue(decodeQueue))
        guard !isShutdown, decoder == nil else { return }

        detectedSampleRate = asbd.mSampleRate
        let newDecoder = AudioConverterDecoder(inputFormat: asbd, magicCookie: magicCookie)
        newDecoder.confinementQueue = decodeQueue
        decoder = newDecoder

        AppLog.info(.audio, "DecodeContext: Decoder created — \(asbd.mSampleRate)Hz")
    }

    private func handlePackets(data: Data, descriptions: [AudioStreamPacketDescription]) {
        dispatchPrecondition(condition: .onQueue(decodeQueue))
        guard !isShutdown, let decoder else { return }

        decoder.enqueue(data: data, descriptions: descriptions)

        while decoder.hasQueuedPackets {
            guard !isShutdown else { break }  // Check between decode iterations
            guard let (pcmBuffer, frameCount) = decoder.decode() else { break }

            let framesWritten = ringBuffer.write(from: pcmBuffer, frameCount: frameCount)
            prebufferedFrames += framesWritten

            if !formatReadyFired && prebufferedFrames >= Self.prebufferThreshold {
                formatReadyFired = true
                onFormatReady(detectedSampleRate, generation)
            }
        }
    }
}

// MARK: - URLSession Delegate Proxy

/// Lightweight NSObject that forwards URLSession delegate callbacks.
/// Required because URLSessionDataDelegate needs NSObject conformance.
///
/// @unchecked Sendable: Callback closures are set once in init (immutable after construction),
/// then only read from the URLSession delegate queue. No concurrent mutation.
private final class SessionDelegateProxy: NSObject, URLSessionDataDelegate, @unchecked Sendable {

    private let onResponse: @Sendable (URLResponse) -> Void
    private let onData: @Sendable (Data) -> Void
    private let onComplete: @Sendable (Error?) -> Void

    init(
        onResponse: @escaping @Sendable (URLResponse) -> Void,
        onData: @escaping @Sendable (Data) -> Void,
        onComplete: @escaping @Sendable (Error?) -> Void
    ) {
        self.onResponse = onResponse
        self.onData = onData
        self.onComplete = onComplete
    }

    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping @Sendable (URLSession.ResponseDisposition) -> Void
    ) {
        onResponse(response)
        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        onData(data)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        onComplete(error)
    }
}
