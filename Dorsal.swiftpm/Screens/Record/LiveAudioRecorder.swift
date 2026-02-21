import SwiftUI
@preconcurrency import AVFoundation
import Speech
import UIKit

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
    
    private var audioEngine = AVAudioEngine()
    private var audioFile: AVAudioFile?
    private var recordingURL: URL?
    
    private var analyzer: SpeechAnalyzer?
    private var currentAnalyzerFormat: AVAudioFormat?
    private var inputContinuation: AsyncStream<AnalyzerInput>.Continuation?
    private var analysisTask: Task<Void, Never>?
    private var demoTask: Task<Void, Never>?
    private var demoPlayer: AVAudioPlayer?
    private var isDemoRecording = false
    var onDemoFinished: (@Sendable () -> Void)?
    private let demoPlaybackVolume: Float = 0.05
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
            
            await prepareAnalyzer()
            
        } catch {
            print("LiveAudioRecorder: Background asset check failed (non-fatal): \(error)")
        }
    }
    
    private func getSelectedModule() async -> any SpeechModule {
        let isHQInstalled = await SpeechTranscriber.installedLocales.contains { $0.identifier == targetLocale.identifier }
        
        if isHQInstalled {
            print("🔊 Using High-Quality SpeechTranscriber")
            return SpeechTranscriber(locale: targetLocale, preset: .progressiveTranscription)
        } else {
            print("⚠️ Using Fallback DictationTranscriber")
            return DictationTranscriber(locale: targetLocale, preset: .progressiveLongDictation)
        }
    }
    
    private func prepareAnalyzer() async {
        let selectedModule = await getSelectedModule()
        guard let format = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [selectedModule]) else {
            print("LiveAudioRecorder: Skipping preheat; no best available format determined without engine.")
            return
        }
        
        let options = SpeechAnalyzer.Options(priority: .userInitiated, modelRetention: .processLifetime)
        let newAnalyzer = SpeechAnalyzer(modules: [selectedModule], options: options)
        
        do {
            print("LiveAudioRecorder: Preheating analyzer initially...")
            try await newAnalyzer.prepareToAnalyze(in: format)
            
            self.analyzer = newAnalyzer
            self.currentAnalyzerFormat = format
        } catch {
            print("LiveAudioRecorder: Failed to preheat analyzer: \(error)")
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
    
    func startDemoRecording(resourceName: String, keywords: [String] = [], completion: @escaping @Sendable (Bool) -> Void) {
        guard let demoURL = demoAudioURL(resourceName: resourceName) else {
            print("Demo audio not found: \(resourceName)")
            completion(false)
            return
        }

        isDemoRecording = true
        queue.async { [weak self] in
            Task { [weak self] in
                await self?.setupAndStartDemo(demoURL: demoURL, keywords: keywords, completion: completion)
            }
        }
    }

    private func demoAudioURL(resourceName: String) -> URL? {
        let extensions = ["m4a", "mp3", "wav", "caf", "aac"]
        for ext in extensions {
            if let url = Bundle.main.url(forResource: resourceName, withExtension: ext) {
                return url
            }
        }
        if let url = Bundle.main.url(forResource: resourceName, withExtension: nil) {
            return url
        }
        if let dataAsset = NSDataAsset(name: resourceName) {
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("\(resourceName).demo")
            do {
                try dataAsset.data.write(to: tempURL, options: .atomic)
                return tempURL
            } catch {
                print("Failed to write demo asset: \(error)")
            }
        }
        return nil
    }

    func startRecording(keywords: [String] = [], completion: @escaping @Sendable (Bool) -> Void) {
        if AVAudioApplication.shared.recordPermission != .granted {
            print("Microphone not authorized in Recorder")
            completion(false)
            return
        }

        isDemoRecording = false
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
        demoTask?.cancel()
        demoTask = nil
        demoPlayer?.stop()
        demoPlayer = nil

        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.reset() // Clear any stale hardware states
        let inputNode = audioEngine.inputNode
        inputNode.removeTap(onBus: 0)
        
        inputContinuation?.finish()
        inputContinuation = nil
        
        let _ = Task { [weak self] in
            if let analyzer = self?.analyzer {
                do {
                    try await analyzer.finalizeAndFinishThroughEndOfInput()
                } catch {
                    // Ignore - Expected if task was cancelled or finished
                }
            }
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
            self.isDemoRecording = false
        }
        
        return recordingURL
    }
    
    private func setupAndStartDemo(demoURL: URL, keywords: [String], completion: @escaping @Sendable (Bool) -> Void) async {
        analysisTask?.cancel()
        demoTask?.cancel()

        DispatchQueue.main.async {
            self.liveTranscript = ""
            self.finalizedText = ""
            self.duration = 0
            self.accumulatedTime = 0
            self.audioLevel = 0
        }

        recordingURL = demoURL
        audioFile = nil

        do {
            let session = AVAudioSession.sharedInstance()
            try? session.setCategory(.playback, options: [.duckOthers])
            try? session.setActive(true)

            let demoFile = try AVAudioFile(forReading: demoURL)
            let fileFormat = demoFile.processingFormat
            
            // Speed up demo playback seamlessly
            let playbackRate: Float = 1.5

            let player = try AVAudioPlayer(contentsOf: demoURL)
            player.volume = demoPlaybackVolume
            player.enableRate = true
            player.rate = playbackRate
            player.prepareToPlay()
            player.play()
            self.demoPlayer = player

            if self.analyzer == nil {
                print("LiveAudioRecorder: Analyzer was not preheated or missing. Creating now...")
                let selectedModule = await getSelectedModule()
                let format = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [selectedModule]) ?? fileFormat
                self.currentAnalyzerFormat = format

                let options = SpeechAnalyzer.Options(priority: .userInitiated, modelRetention: .processLifetime)
                let newAnalyzer = SpeechAnalyzer(modules: [selectedModule], options: options)

                try? await newAnalyzer.prepareToAnalyze(in: format)

                self.analyzer = newAnalyzer
            }

            guard let analyzer = self.analyzer, let analyzerFormat = self.currentAnalyzerFormat else {
                print("Error: Analyzer failed to initialize.")
                DispatchQueue.main.async { completion(false) }
                return
            }

            let context = AnalysisContext()
            if !keywords.isEmpty {
                context.contextualStrings = [.general: keywords]
            }
            try await analyzer.setContext(context)
            
            // Set up stream identically to live mic recording to preserve "live typing" effect
            let (stream, continuation) = AsyncStream<AnalyzerInput>.makeStream()
            self.inputContinuation = continuation

            self.analysisTask = Task {
                do {
                    try await analyzer.start(inputSequence: stream)
                    
                    let modules = await analyzer.modules
                    if let module = modules.first {
                        if let dt = module as? DictationTranscriber {
                            for try await result in dt.results {
                                let text = String(result.text.characters)
                                await MainActor.run { self.liveTranscript = text }
                            }
                        } else if let st = module as? SpeechTranscriber {
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

            demoTask = Task { [weak self] in
                guard let self = self else { return }
                let bufferSize: AVAudioFrameCount = 1024

                do {
                    let totalFrames = demoFile.length
                    var framesRead: AVAudioFramePosition = 0

                    while framesRead < totalFrames {
                        if Task.isCancelled { break }
                        if await MainActor.run(resultType: Bool.self, body: { self.isPaused }) {
                            try await Task.sleep(nanoseconds: 100_000_000)
                            continue
                        }
                        guard let buffer = AVAudioPCMBuffer(pcmFormat: fileFormat, frameCapacity: bufferSize) else { break }
                        try demoFile.read(into: buffer, frameCount: bufferSize)
                        if buffer.frameLength == 0 { break }

                        framesRead += AVAudioFramePosition(buffer.frameLength)
                        self.handleDemoBuffer(buffer: buffer, targetFormat: analyzerFormat)

                        // Adjust buffer feeding sleep matching the speed up rate
                        let seconds = Double(buffer.frameLength) / fileFormat.sampleRate
                        try await Task.sleep(nanoseconds: UInt64((seconds / Double(playbackRate)) * 1_000_000_000))
                    }

                    if Task.isCancelled { return }
                    try await Task.sleep(nanoseconds: 500_000_000)
                    if !Task.isCancelled {
                        await MainActor.run { self.onDemoFinished?() }
                    }
                } catch {
                    print("Demo playback failed: \(error)")
                    if !Task.isCancelled {
                        await MainActor.run { self.onDemoFinished?() }
                    }
                }
            }

            DispatchQueue.main.async {
                self.isRecording = true
                self.isPaused = false
                self.startTime = Date()
                self.startTimer()
                completion(true)
            }

        } catch {
            print("Demo setup error: \(error)")
            DispatchQueue.main.async { completion(false) }
        }
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
        
        // Re-instantiate engine to completely flush cached hardware formats
        // from the demo playback session and force reading the new mic category.
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine = AVAudioEngine()
        
        analysisTask?.cancel()
        
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
            if self.analyzer == nil {
                print("LiveAudioRecorder: Analyzer was not preheated or missing. Creating now...")
                let selectedModule = await getSelectedModule()
                let format = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [selectedModule]) ?? recordingFormat
                self.currentAnalyzerFormat = format
                
                let options = SpeechAnalyzer.Options(priority: .userInitiated, modelRetention: .processLifetime)
                let newAnalyzer = SpeechAnalyzer(modules: [selectedModule], options: options)
                
                try? await newAnalyzer.prepareToAnalyze(in: format)
                
                self.analyzer = newAnalyzer
            }
            
            guard let analyzer = self.analyzer, let analyzerFormat = self.currentAnalyzerFormat else {
                print("Error: Analyzer failed to initialize.")
                DispatchQueue.main.async { completion(false) }
                return
            }
            
            let context = AnalysisContext()
            if !keywords.isEmpty {
                context.contextualStrings = [.general: keywords]
            }
            try await analyzer.setContext(context)
            
            let (stream, continuation) = AsyncStream<AnalyzerInput>.makeStream()
            self.inputContinuation = continuation
            
            self.analysisTask = Task {
                do {
                    try await analyzer.start(inputSequence: stream)
                    
                    let modules = await analyzer.modules
                    if let module = modules.first {
                        if let dt = module as? DictationTranscriber {
                            for try await result in dt.results {
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
                        } else if let st = module as? SpeechTranscriber {
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
                    
                } catch is CancellationError {
                    // Ignore expected cancellation
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
    
    private func handleDemoBuffer(buffer: AVAudioPCMBuffer, targetFormat: AVAudioFormat) {
        do {
            let convertedBuffer = try bufferConverter.convertBuffer(buffer, to: targetFormat)
            inputContinuation?.yield(AnalyzerInput(buffer: convertedBuffer))
        } catch {
            print("Demo buffer conversion error: \(error)")
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
            let scaled = normalized * demoPlaybackVolume

            Task { @MainActor in
                self.audioLevel = scaled
            }
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
