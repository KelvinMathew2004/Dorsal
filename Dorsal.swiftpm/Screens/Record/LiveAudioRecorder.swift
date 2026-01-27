import SwiftUI
import AVFoundation
import Speech

private final class ConversionState: @unchecked Sendable {
    var isProcessed = false
}

private class BufferConverter {
    enum Error: Swift.Error {
        case failedToCreateConverter
        case failedToCreateConversionBuffer
        case conversionFailed(NSError?)
    }

    private var converter: AVAudioConverter?

    func convertBuffer(_ buffer: AVAudioPCMBuffer, to format: AVAudioFormat) throws -> AVAudioPCMBuffer {
        let inputFormat = buffer.format
        guard inputFormat != format else {
            return buffer
        }
        
        if converter == nil || converter?.outputFormat != format {
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

class LiveAudioRecorder: NSObject, ObservableObject, @unchecked Sendable {
    enum TranscriptionError: Error {
        case localeNotSupported
        case failedToSetupRecognitionStream
    }

    @Published var isRecording = false
    @Published var isPaused = false
    @Published var duration: TimeInterval = 0
    @Published var audioLevel: Float = 0
    @Published var liveTranscript: String = ""
    private var finalizedText: String = ""
    
    private let audioEngine = AVAudioEngine()
    private var audioFile: AVAudioFile?
    private var recordingURL: URL?
    
    private var analyzer: SpeechAnalyzer?
    private var inputContinuation: AsyncStream<AnalyzerInput>.Continuation?
    private var analysisTask: Task<Void, Never>?
    private let bufferConverter = BufferConverter()
    
    private var startTime: Date?
    private var accumulatedTime: TimeInterval = 0
    private var timer: Timer?
    
    private let queue = DispatchQueue(label: "com.dorsal.audioQueue", qos: .userInitiated)
    
    private var lastUpdateTime: TimeInterval = 0
    
    private let targetLocale = Locale(identifier: "en_US")
    
    override init() {
        super.init()
        setupInterruptionObserver()
        Task {
            await checkAndPrepareModels()
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        Task { [weak self] in
            await self?.analyzer?.cancelAndFinishNow()
        }
    }
    
    // MARK: - Model Preparation (Background Only)
    
    func checkAndPrepareModels() async {
        let transcriber = SpeechTranscriber(locale: targetLocale, preset: .progressiveTranscription)
        
        do {
            if await installed(locale: targetLocale) {
            } else {
                print("LiveAudioRecorder: Starting background download for SpeechTranscriber assets...")
                try await downloadIfNeeded(for: transcriber)
            }
        } catch {
            print("LiveAudioRecorder: Background asset check failed (non-fatal): \(error)")
        }
    }
    
    func supported(locale: Locale) async -> Bool {
        let supported = await SpeechTranscriber.supportedLocales
        return supported.map { $0.identifier(.bcp47) }.contains(locale.identifier(.bcp47))
    }

    func installed(locale: Locale) async -> Bool {
        let installed = await Set(SpeechTranscriber.installedLocales)
        return installed.map { $0.identifier(.bcp47) }.contains(locale.identifier(.bcp47))
    }

    func downloadIfNeeded(for module: SpeechTranscriber) async throws {
        if let downloader = try await AssetInventory.assetInstallationRequest(supporting: [module]) {
            try await downloader.downloadAndInstall()
            print("LiveAudioRecorder: Speech assets installed successfully.")
        }
    }
    
    // MARK: - Audio Handling
    
    private func setupInterruptionObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption),
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance()
        )
    }
    
    @objc private func handleInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        switch type {
        case .began:
            print("Audio Session Interruption Began")
            self.pauseRecording()
            
        case .ended:
            guard let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt else { return }
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            
            if options.contains(.shouldResume) {
            }
            
        @unknown default:
            break
        }
    }
    
    func startRecording(keywords: [String] = [], completion: @escaping @Sendable (Bool) -> Void) {
        if AVAudioApplication.shared.recordPermission != .granted {
            print("Microphone not authorized in Recorder")
            completion(false)
            return
        }
        
        queue.async { [weak self] in
            Task {
                await self?.setupAndStartEngine(keywords: keywords, completion: completion)
            }
        }
    }
    
    func pauseRecording() {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            if self.audioEngine.isRunning {
                self.audioEngine.pause()
            }
            
            DispatchQueue.main.async {
                if self.isRecording && !self.isPaused {
                    self.isPaused = true
                    self.timer?.invalidate()
                    
                    if let start = self.startTime {
                        self.accumulatedTime += Date().timeIntervalSince(start)
                    }
                    self.startTime = nil
                    self.audioLevel = 0
                }
            }
        }
    }
    
    func resumeRecording() {
        guard isRecording && isPaused else { return }
        
        queue.async { [weak self] in
            guard let self = self else { return }
            do {
                try self.audioEngine.start()
                
                DispatchQueue.main.async {
                    self.isPaused = false
                    self.startTime = Date()
                    self.startTimer()
                }
            } catch {
                print("Error resuming engine: \(error)")
            }
        }
    }
    
    func stopRecording() -> URL? {
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        let inputNode = audioEngine.inputNode
        inputNode.removeTap(onBus: 0)
        
        inputContinuation?.finish()
        inputContinuation = nil
        
        let _ = Task { [weak self] in
            try? await self?.analyzer?.finalizeAndFinishThroughEndOfInput()
            self?.analysisTask?.cancel()
            self?.analysisTask = nil
            self?.analyzer = nil
        }
        
        audioFile = nil
        
        DispatchQueue.main.async {
            self.isRecording = false
            self.isPaused = false
            self.timer?.invalidate()
            self.audioLevel = 0
            self.duration = 0
            self.accumulatedTime = 0
        }
        
        return recordingURL
    }
    
    private func setupAndStartEngine(keywords: [String], completion: @escaping @Sendable (Bool) -> Void) async {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers, .defaultToSpeaker, .allowBluetoothHFP])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("Audio Session Error: \(error)")
            DispatchQueue.main.async { completion(false) }
            return
        }
        
        analysisTask?.cancel()
        analyzer = nil
        
        DispatchQueue.main.async {
            self.liveTranscript = ""
            self.finalizedText = ""
            self.duration = 0
            self.accumulatedTime = 0
            self.audioLevel = 0
        }
        
        let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = docDir.appendingPathComponent("live_recording.m4a")
        recordingURL = url
        
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        if recordingFormat.sampleRate == 0 || recordingFormat.channelCount == 0 {
             print("Error: Invalid Input Format. AudioSession might not be ready.")
             DispatchQueue.main.async { completion(false) }
             return
        }
        
        do {
            audioFile = try AVAudioFile(forWriting: url, settings: recordingFormat.settings)
        } catch {
            print("Audio File Error: \(error)")
            DispatchQueue.main.async { completion(false) }
            return
        }
        
        do {
            var selectedModule: any SpeechModule
            var isUsingDictation = false
            
            let isHQInstalled = await SpeechTranscriber.installedLocales.contains { $0.identifier == targetLocale.identifier }
            
            if isHQInstalled {
                print("Starting engine with HQ SpeechTranscriber")
                selectedModule = SpeechTranscriber(locale: targetLocale, preset: .progressiveTranscription)
            } else {
                print("HQ assets missing (or not supported), falling back to DictationTranscriber")
                selectedModule = DictationTranscriber(locale: targetLocale, preset: .progressiveLongDictation)
                isUsingDictation = true
            }
            
            let context = AnalysisContext()
            if !keywords.isEmpty {
                context.contextualStrings = [.general: keywords]
            }
            
            let options = SpeechAnalyzer.Options(priority: .userInitiated, modelRetention: .processLifetime)
            
            let newAnalyzer = SpeechAnalyzer(modules: [selectedModule], options: options)
            try await newAnalyzer.setContext(context)
            
            print("Preheating analyzer...")
            try await newAnalyzer.prepareToAnalyze(in: recordingFormat)
            
            self.analyzer = newAnalyzer
            
            let (stream, continuation) = AsyncStream<AnalyzerInput>.makeStream()
            self.inputContinuation = continuation
            
            let analyzerFormat = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [selectedModule]) ?? recordingFormat
            
            self.analysisTask = Task {
                do {
                    try await newAnalyzer.start(inputSequence: stream)
                    
                    if isUsingDictation {
                        if let dt = selectedModule as? DictationTranscriber {
                            for try await result in dt.results {
                                let text = String(result.text.characters)
                                await MainActor.run { self.liveTranscript = text }
                            }
                        }
                    } else {
                        if let st = selectedModule as? SpeechTranscriber {
                            for try await result in st.results {
                                let text = String(result.text.characters)
                                let isFinal = result.isFinal
                                
                                await MainActor.run {
                                    if isFinal {
                                        self.finalizedText += (self.finalizedText.isEmpty ? "" : " ") + text
                                        self.liveTranscript = self.finalizedText
                                    } else {
                                        self.liveTranscript = (self.finalizedText.isEmpty ? "" : self.finalizedText + " ") + text
                                    }
                                }
                            }
                        }
                    }
                    
                } catch {
                    print("Speech Analysis Error: \(error)")
                }
            }
            
            inputNode.removeTap(onBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, time in
                self?.handleAudioBuffer(buffer: buffer, targetFormat: analyzerFormat)
            }
            
            audioEngine.prepare()
            try audioEngine.start()
            
            DispatchQueue.main.async {
                self.isRecording = true
                self.isPaused = false
                self.startTime = Date()
                self.startTimer()
                completion(true)
            }
            
        } catch {
            print("Engine/Analyzer Start Error: \(error)")
            DispatchQueue.main.async { completion(false) }
        }
    }
    
    private func handleAudioBuffer(buffer: AVAudioPCMBuffer, targetFormat: AVAudioFormat) {
        if !audioEngine.isRunning { return }
        
        try? audioFile?.write(from: buffer)
        
        do {
            let convertedBuffer = try bufferConverter.convertBuffer(buffer, to: targetFormat)
            inputContinuation?.yield(AnalyzerInput(buffer: convertedBuffer))
        } catch {
            print("Buffer conversion error: \(error)")
        }
        
        let now = Date().timeIntervalSince1970
        if now - lastUpdateTime < 0.03 { return }
        lastUpdateTime = now
        
        let channelData = buffer.floatChannelData?[0]
        let frameLength = Int(buffer.frameLength)
        let bufferStride = buffer.stride
        
        if let data = channelData {
            var sum: Float = 0
            for i in stride(from: 0, to: frameLength * bufferStride, by: bufferStride) {
                let sample = data[i]
                sum += sample * sample
            }
            let rms = sqrt(sum / Float(frameLength))
            let normalized = min(max(rms * 10.0, 0), 1.0)
            
            Task { @MainActor in
                self.audioLevel = normalized
            }
        }
    }
    
    private func startTimer() {
        DispatchQueue.main.async {
            self.timer?.invalidate()
            self.timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                if self.isPaused { return }
                
                if let start = self.startTime {
                    self.duration = self.accumulatedTime + Date().timeIntervalSince(start)
                } else {
                    self.duration = self.accumulatedTime
                }
            }
        }
    }
}
