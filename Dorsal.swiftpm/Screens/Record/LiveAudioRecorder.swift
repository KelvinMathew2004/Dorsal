import SwiftUI
import AVFoundation
import Speech

// MARK: - Buffer Converter Helper
// Helper class moved to file scope to ensure visibility of Sendable conformance.
// Marked @unchecked Sendable because it is used within a synchronous block
// where we know it won't be accessed from multiple threads simultaneously.
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

// Mark as @unchecked Sendable because we manage thread safety manually for the Engine
// and AVAudioEngine itself isn't fully Sendable-compliant in older OS versions.
class LiveAudioRecorder: NSObject, ObservableObject, @unchecked Sendable {
    @Published var isRecording = false
    @Published var isPaused = false
    @Published var duration: TimeInterval = 0
    @Published var audioLevel: Float = 0
    @Published var liveTranscript: String = ""
    
    // Core Audio Engine
    private let audioEngine = AVAudioEngine()
    private var audioFile: AVAudioFile?
    private var recordingURL: URL?
    
    // New iOS 26+ Speech Components
    private var analyzer: SpeechAnalyzer?
    private var transcriber: DictationTranscriber?
    private var inputContinuation: AsyncStream<AnalyzerInput>.Continuation?
    private var analysisTask: Task<Void, Never>?
    private let bufferConverter = BufferConverter()
    
    // Time Tracking
    private var startTime: Date?
    private var accumulatedTime: TimeInterval = 0
    private var timer: Timer?
    
    // Internal queue to serialize audio engine operations
    private let queue = DispatchQueue(label: "com.dorsal.audioQueue", qos: .userInitiated)
    
    // Throttle visualizer updates
    private var lastUpdateTime: TimeInterval = 0
    
    override init() {
        super.init()
        setupInterruptionObserver()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        Task { [weak self] in
            await self?.analyzer?.cancelAndFinishNow()
        }
    }
    
    // MARK: - Interruption Handling
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
                // We leave it in .paused state for safety, user can manually resume.
            }
            
        @unknown default:
            break
        }
    }
    
    // MARK: - Public API
    
    func startRecording(keywords: [String] = [], completion: @escaping @Sendable (Bool) -> Void) {
        // 1. Check Microphone Permission
        if AVAudioApplication.shared.recordPermission != .granted {
            print("Microphone not authorized in Recorder")
            completion(false)
            return
        }
        
        // 2. Check Speech Recognition Permission
        // Crucial check to ensure we have permission before starting the analyzer
        if SFSpeechRecognizer.authorizationStatus() != .authorized {
            print("Speech Recognition not authorized in Recorder")
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
        // Stop Engine
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        let inputNode = audioEngine.inputNode
        inputNode.removeTap(onBus: 0)
        
        // Stop Analysis Stream
        inputContinuation?.finish()
        inputContinuation = nil
        
        // Wait for analyzer to finish (best effort)
        let _ = Task { [weak self] in
            try? await self?.analyzer?.finalizeAndFinishThroughEndOfInput()
            self?.analysisTask?.cancel()
            self?.analysisTask = nil
            self?.analyzer = nil
            self?.transcriber = nil
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
    
    // MARK: - Asset Management
    
    private func ensureAssetsInstalled(for transcriber: DictationTranscriber) async throws {
        // Check if the locale is already installed
        if await DictationTranscriber.installedLocales.contains(where: { $0.identifier == "en-US" }) {
            return
        }
        
        // Download if needed
        if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
            print("Downloading speech assets for en-US...")
            try await request.downloadAndInstall()
            print("Assets installed.")
        }
    }
    
    // MARK: - Internal Logic
    
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
        
        // cleanup previous state
        analysisTask?.cancel()
        analyzer = nil
        transcriber = nil
        
        DispatchQueue.main.async {
            self.liveTranscript = ""
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
        
        // Setup Audio File for backup
        do {
            audioFile = try AVAudioFile(forWriting: url, settings: recordingFormat.settings)
        } catch {
            print("Audio File Error: \(error)")
            DispatchQueue.main.async { completion(false) }
            return
        }
        
        // --- NEW SPEECH ANALYZER SETUP ---
        do {
            // 1. Create Dictation Transcriber
            // Use .progressiveLongDictation for continuous speech with partial results
            let newTranscriber = DictationTranscriber(locale: Locale(identifier: "en-US"), preset: .progressiveLongDictation)
            self.transcriber = newTranscriber
            
            // 2. Ensure Assets (Models) are present
            try await ensureAssetsInstalled(for: newTranscriber)
            
            // 3. Configure Keyword Biasing (Checklist Optimization)
            let context = AnalysisContext()
            // Provide context to bias the recognizer towards our checklist keywords
            if !keywords.isEmpty {
                context.contextualStrings = [.general: keywords]
            }
            
            // 4. Create Analyzer with Context
            let newAnalyzer = SpeechAnalyzer(modules: [newTranscriber])
            try await newAnalyzer.setContext(context)
            self.analyzer = newAnalyzer
            
            // 5. Prepare Input Stream
            let (stream, continuation) = AsyncStream<AnalyzerInput>.makeStream()
            self.inputContinuation = continuation
            
            // 6. Determine best format for analyzer
            let analyzerFormat = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [newTranscriber]) ?? recordingFormat
            
            // 7. Start Analysis Task loop
            self.analysisTask = Task {
                do {
                    // Start the analyzer processing the stream
                    try await newAnalyzer.start(inputSequence: stream)
                    
                    // Consume results
                    for try await result in newTranscriber.results {
                        // FIX: DictationTranscriber.Result accesses text directly via .text property,
                        // which is an AttributedString. We extract the string from it.
                        let text = String(result.text.characters)
                        DispatchQueue.main.async {
                            self.liveTranscript = text
                        }
                    }
                } catch {
                    print("Speech Analysis Error: \(error)")
                }
            }
            
            // 8. Install Tap
            inputNode.removeTap(onBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, time in
                self?.handleAudioBuffer(buffer: buffer, targetFormat: analyzerFormat)
            }
            
            // 9. Start Engine
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
        
        // 1. Write to local file for backup/playback
        try? audioFile?.write(from: buffer)
        
        // 2. Feed to Speech Analyzer
        do {
            let convertedBuffer = try bufferConverter.convertBuffer(buffer, to: targetFormat)
            inputContinuation?.yield(AnalyzerInput(buffer: convertedBuffer))
        } catch {
            print("Buffer conversion error: \(error)")
        }
        
        // 3. Throttled visualizer update
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
            
            DispatchQueue.main.async {
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
