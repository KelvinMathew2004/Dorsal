import SwiftUI
import Combine
@preconcurrency import AVFoundation
import Speech
import UIKit

nonisolated private final class ConversionState: @unchecked Sendable {
    var isProcessed = false
}

nonisolated private class BufferConverter {
    enum Error: Swift.Error {
        case failedToCreateConverter
        case failedToCreateConversionBuffer
        case conversionFailed(NSError?)
    }

    private var converter: AVAudioConverter?

    func convertBuffer(_ buffer: AVAudioPCMBuffer, to format: AVAudioFormat) throws -> AVAudioPCMBuffer {
        let inputFormat = buffer.format
        guard inputFormat != format else {
            // The audio engine reuses its tap buffers. The asynchronous analyzer needs ownership.
            guard let copy = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: buffer.frameLength) else {
                throw Error.failedToCreateConversionBuffer
            }
            copy.frameLength = buffer.frameLength
            let source = UnsafeMutableAudioBufferListPointer(buffer.mutableAudioBufferList)
            let destination = UnsafeMutableAudioBufferListPointer(copy.mutableAudioBufferList)
            for index in source.indices {
                if let input = source[index].mData, let output = destination[index].mData {
                    memcpy(output, input, Int(source[index].mDataByteSize))
                }
            }
            return copy
        }
        
        if converter == nil || converter?.outputFormat != format || converter?.inputFormat != inputFormat {
            converter = AVAudioConverter(from: inputFormat, to: format)
            converter?.primeMethod = .none
        }
        
        guard let converter = converter else {
            throw Error.failedToCreateConverter
        }
        
        let sampleRateRatio = converter.outputFormat.sampleRate / converter.inputFormat.sampleRate
        let scaledInputFrameLength = Double(buffer.frameLength) * sampleRateRatio
        let frameCapacity = AVAudioFrameCount(scaledInputFrameLength.rounded(.up))
        
        guard let conversionBuffer = AVAudioPCMBuffer(pcmFormat: converter.outputFormat, frameCapacity: frameCapacity) else {
            throw Error.failedToCreateConversionBuffer
        }
        
        var nsError: NSError?
        let state = ConversionState()
        
        let status = converter.convert(to: conversionBuffer, error: &nsError) { packetCount, inputStatusPointer in
            defer { state.isProcessed = true }
            inputStatusPointer.pointee = state.isProcessed ? .noDataNow : .haveData
            return state.isProcessed ? nil : buffer
        }
        
        guard status != .error else {
            throw Error.conversionFailed(nsError)
        }
        
        return conversionBuffer
    }
}

// The tap runs off the main actor. Locking makes closing the file/stream wait for
// the last buffer without touching UI or recorder state on the realtime callback.
nonisolated final class AudioCaptureSink: @unchecked Sendable {
    private let lock = NSLock()
    private var file: AVAudioFile?
    private var continuation: AsyncStream<AnalyzerInput>.Continuation?
    private let format: AVAudioFormat?
    private let converter = BufferConverter()
    private var closed = false
    private var reportedWriteError = false
    private var reportedConversionError = false
    private var lastMeterTime: TimeInterval = 0
    let onFailure: @Sendable (Bool) -> Void
    let onLevel: @Sendable (Float) -> Void

    init(file: AVAudioFile, format: AVAudioFormat?, continuation: AsyncStream<AnalyzerInput>.Continuation?,
         onFailure: @escaping @Sendable (Bool) -> Void, onLevel: @escaping @Sendable (Float) -> Void) {
        self.file = file
        self.format = format
        self.continuation = continuation
        self.onFailure = onFailure
        self.onLevel = onLevel
    }

    func consume(_ buffer: AVAudioPCMBuffer) {
        lock.lock()
        defer { lock.unlock() }
        guard !closed else { return }
        do { try file?.write(from: buffer) }
        catch {
            if !reportedWriteError { reportedWriteError = true; onFailure(true) }
        }
        if let format, let continuation {
            do { continuation.yield(AnalyzerInput(buffer: try converter.convertBuffer(buffer, to: format))) }
            catch {
                if !reportedConversionError { reportedConversionError = true; onFailure(false) }
            }
        }
        let now = Date.timeIntervalSinceReferenceDate
        guard now - lastMeterTime > 0.03, buffer.frameLength > 0,
              let samples = buffer.floatChannelData?[0] else { return }
        lastMeterTime = now
        var sum: Float = 0
        for index in stride(from: 0, to: Int(buffer.frameLength) * buffer.stride, by: buffer.stride) {
            sum += samples[index] * samples[index]
        }
        onLevel(min(sqrt(sum / Float(buffer.frameLength)) * 10, 1))
    }

    func finish() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        closed = true
        file = nil
        continuation?.finish()
        continuation = nil
        return reportedWriteError
    }
}

@MainActor
final class LiveAudioRecorder: NSObject, ObservableObject {
    struct RecordingResult {
        let url: URL
        let transcript: String
        let transcriptionMessage: String?
        let audioWriteFailed: Bool
    }

    enum RecordingError: LocalizedError {
        case microphoneDenied, invalidInput, speechUnavailable, noSpeech
        var errorDescription: String? {
            switch self {
            case .microphoneDenied: return "Allow microphone access in Settings to record a dream."
            case .invalidInput: return "The microphone isn’t available. Check your audio connection and try again."
            case .speechUnavailable: return "Transcription isn’t available yet. Your audio is kept on this device; retry transcription later."
            case .noSpeech: return "No speech was recognized. Your audio is kept on this device; you can play it or retry transcription."
            }
        }
    }

    @Published private(set) var isRecording = false
    @Published private(set) var isPaused = false
    @Published private(set) var audioLevel: Float = 0
    @Published private(set) var liveTranscript = ""
    @Published private(set) var transcriptionMessage: String?
    @Published var recordingError: String?

    private let audioEngine = AVAudioEngine()
    private var sink: AudioCaptureSink?
    private var recordingURL: URL?
    private var analyzer: SpeechAnalyzer?
    private var resultsTask: Task<Void, Never>?
    private var preparationTask: Task<Void, Never>?
    private var accumulator = TranscriptAccumulator()
    private var hasTap = false
    private var isStarting = false
    private var isStopping = false
    private let locale = Locale(identifier: "en_US")

    init(prepareModels: Bool = true) {
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(handleInterruption),
                                               name: AVAudioSession.interruptionNotification, object: nil)
        if prepareModels { preparationTask = Task { [weak self] in await self?.checkAndPrepareModels() } }
    }

    // Downloads may finish at any time, but never replace an analyzer in use.
    func checkAndPrepareModels() async {
        do {
            guard let module = await supportedModule() else { return }
            if let request = try await AssetInventory.assetInstallationRequest(supporting: [module]) {
                try await request.downloadAndInstall()
            }
        } catch {
            // Optional preparation: a later recording or explicit retry checks again.
            print("Speech asset preparation deferred: \(error)")
        }
    }

    private func supportedModule() async -> (any SpeechModule)? {
        if SpeechTranscriber.isAvailable,
           let supported = await SpeechTranscriber.supportedLocale(equivalentTo: locale) {
            return SpeechTranscriber(locale: supported, preset: .progressiveTranscription)
        }
        if let supported = await DictationTranscriber.supportedLocale(equivalentTo: locale) {
            return DictationTranscriber(locale: supported, preset: .progressiveLongDictation)
        }
        return nil
    }

    private func installedModule() async -> (any SpeechModule)? {
        if let preferred = await supportedModule(), await AssetInventory.status(forModules: [preferred]) == .installed {
            return preferred
        }
        if let supported = await DictationTranscriber.supportedLocale(equivalentTo: locale) {
            let fallback = DictationTranscriber(locale: supported, preset: .progressiveLongDictation)
            if await AssetInventory.status(forModules: [fallback]) == .installed { return fallback }
        }
        return nil
    }

    func startRecording(keywords: [String] = []) async throws {
        guard !isRecording, !isStarting, !isStopping else { return }
        isStarting = true
        defer { isStarting = false }
        guard AVAudioApplication.shared.recordPermission == .granted else { throw RecordingError.microphoneDenied }
        transcriptionMessage = nil
        recordingError = nil
        accumulator = TranscriptAccumulator()
        liveTranscript = ""
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .measurement,
                                    options: [.duckOthers, .defaultToSpeaker, .allowBluetoothHFP])
            try session.setActive(true)
            let format = audioEngine.inputNode.outputFormat(forBus: 0)
            guard format.sampleRate > 0, format.channelCount > 0 else { throw RecordingError.invalidInput }
            let url = try RecordingFiles.makeURL()
            recordingURL = url
            // CAF matches the PCM format supplied by the engine; an .m4a extension does not.
            let file = try AVAudioFile(forWriting: url, settings: format.settings)
            var continuation: AsyncStream<AnalyzerInput>.Continuation?
            var analyzerFormat: AVAudioFormat?
            if let module = await installedModule(),
               let speechFormat = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [module], considering: format) {
                let speechAnalyzer = SpeechAnalyzer(modules: [module])
                do {
                    let context = AnalysisContext()
                    context.contextualStrings = [.general: keywords]
                    try await speechAnalyzer.setContext(context)
                    let (stream, input) = AsyncStream<AnalyzerInput>.makeStream()
                    // start() performs required setup; optional prewarming isn't a readiness gate.
                    try await speechAnalyzer.start(inputSequence: stream)
                    analyzer = speechAnalyzer
                    continuation = input
                    analyzerFormat = speechFormat
                    resultsTask = Task { [weak self] in
                        do {
                            try await Self.consumeResults(module) { text, isFinal in
                                self?.accumulator.append(text, isFinal: isFinal)
                                self?.liveTranscript = self?.accumulator.text ?? ""
                            }
                        } catch {
                            guard !Task.isCancelled else { return }
                            self?.transcriptionMessage = RecordingError.speechUnavailable.localizedDescription
                        }
                    }
                } catch {
                    await speechAnalyzer.cancelAndFinishNow()
                    transcriptionMessage = RecordingError.speechUnavailable.localizedDescription
                }
            } else {
                transcriptionMessage = RecordingError.speechUnavailable.localizedDescription
            }
            let capture = AudioCaptureSink(file: file, format: analyzerFormat, continuation: continuation,
                onFailure: { [weak self] isWriteFailure in
                    Task { @MainActor [weak self] in
                        if isWriteFailure {
                            self?.recordingError = "Audio couldn’t be fully written. Stop recording and check the available storage on your device."
                        } else {
                            self?.transcriptionMessage = "Live transcription was interrupted. Your audio is kept; retry transcription after recording."
                        }
                    }
                }, onLevel: { [weak self] level in
                    Task { @MainActor [weak self] in
                        guard self?.isRecording == true, self?.isPaused == false else { return }
                        self?.audioLevel = level
                    }
                })
            sink = capture
            audioEngine.inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
                capture.consume(buffer)
            }
            hasTap = true
            audioEngine.prepare()
            try audioEngine.start()
            isRecording = true
            isPaused = false
        } catch {
            stopCapture()
            await analyzer?.cancelAndFinishNow()
            resultsTask?.cancel()
            await resultsTask?.value
            resultsTask = nil
            analyzer = nil
            if let recordingURL { try? FileManager.default.removeItem(at: recordingURL) }
            recordingURL = nil
            try? session.setActive(false, options: .notifyOthersOnDeactivation)
            throw error
        }
    }

    func pauseRecording() {
        guard isRecording, !isPaused, !isStopping else { return }
        audioEngine.pause()
        isPaused = true
        audioLevel = 0
    }

    func resumeRecording() {
        guard isRecording, isPaused, !isStopping else { return }
        do {
            try AVAudioSession.sharedInstance().setActive(true)
            try audioEngine.start()
            isPaused = false
        } catch {
            recordingError = "Recording couldn’t resume. You can retry, or stop to keep what you’ve recorded."
        }
    }

    @discardableResult
    private func stopCapture() -> Bool {
        audioEngine.stop()
        if hasTap { audioEngine.inputNode.removeTap(onBus: 0); hasTap = false }
        let writeFailed = sink?.finish() ?? false
        sink = nil
        audioEngine.reset()
        audioLevel = 0
        return writeFailed
    }

    func stopRecording(discard: Bool = false) async -> RecordingResult? {
        guard isRecording, !isStopping else { return nil }
        isStopping = true
        defer { isStopping = false }
        let writeFailed = stopCapture()
        isRecording = false
        isPaused = false
        // Release the microphone before waiting for any final speech results.
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        if let analyzer {
            if discard {
                await analyzer.cancelAndFinishNow()
                resultsTask?.cancel()
            } else {
                do { try await analyzer.finalizeAndFinishThroughEndOfInput() }
                catch { transcriptionMessage = RecordingError.speechUnavailable.localizedDescription }
            }
        }
        // Finalize ends result production; await the consumer to drain queued final passages.
        await resultsTask?.value
        resultsTask = nil
        analyzer = nil
        guard let url = recordingURL else { return nil }
        recordingURL = nil
        if discard {
            try? FileManager.default.removeItem(at: url)
            return nil
        }
        let transcript = accumulator.text.trimmingCharacters(in: .whitespacesAndNewlines)
        return RecordingResult(url: url, transcript: transcript,
                               transcriptionMessage: transcriptionMessage ?? (transcript.isEmpty ? RecordingError.noSpeech.localizedDescription : nil),
                               audioWriteFailed: writeFailed)
    }

    func transcribeFile(at url: URL) async throws -> String {
        let installed = await installedModule()
        let candidate = installed != nil ? installed : await supportedModule()
        guard let module = candidate else {
            throw RecordingError.speechUnavailable
        }
        if let request = try await AssetInventory.assetInstallationRequest(supporting: [module]) {
            try await request.downloadAndInstall()
        }
        try Task.checkCancellation()
        let speechAnalyzer = SpeechAnalyzer(modules: [module])
        let consumer = Task {
            var transcript = TranscriptAccumulator()
            try await Self.consumeResults(module) { text, isFinal in transcript.append(text, isFinal: isFinal) }
            return transcript.text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        do {
            let file = try AVAudioFile(forReading: url)
            try await speechAnalyzer.start(inputAudioFile: file, finishAfterFile: true)
            let text = try await consumer.value
            guard !text.isEmpty else { throw RecordingError.noSpeech }
            return text
        } catch {
            await speechAnalyzer.cancelAndFinishNow()
            consumer.cancel()
            _ = try? await consumer.value
            throw error
        }
    }


    private static func consumeResults(_ module: any SpeechModule,
                                       update: (String, Bool) -> Void) async throws {
        if let transcriber = module as? SpeechTranscriber {
            for try await result in transcriber.results { update(String(result.text.characters), result.isFinal) }
        } else if let transcriber = module as? DictationTranscriber {
            for try await result in transcriber.results { update(String(result.text.characters), result.isFinal) }
        }
    }

    @objc private func handleInterruption(_ notification: Notification) {
        guard let raw = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }
        if type == .began { pauseRecording() }
        else if let rawOptions = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt,
                AVAudioSession.InterruptionOptions(rawValue: rawOptions).contains(.shouldResume) { resumeRecording() }
    }
}
