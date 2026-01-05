import SwiftUI
import AVFoundation
import Speech

// Mark as @unchecked Sendable because we manage thread safety manually for the Engine
// and AVAudioEngine itself isn't fully Sendable-compliant in older OS versions.
class LiveAudioRecorder: NSObject, ObservableObject, @unchecked Sendable {
    @Published var isRecording = false
    @Published var duration: TimeInterval = 0
    @Published var audioLevel: Float = 0
    @Published var liveTranscript: String = ""
    
    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    
    private var audioFile: AVAudioFile?
    private var recordingURL: URL?
    private var startTime: Date?
    private var timer: Timer?
    
    // Internal queue to serialize audio engine operations
    private let queue = DispatchQueue(label: "com.dorsal.audioQueue", qos: .userInitiated)
    
    // Throttle visualizer updates to prevent main thread flooding (60fps is ~16ms)
    private var lastUpdateTime: TimeInterval = 0
    
    override init() {
        super.init()
    }
    
    // MARK: - Public API
    
    func startRecording(completion: @escaping @Sendable (Bool) -> Void) {
        // Permission check (Safety)
        if AVAudioApplication.shared.recordPermission != .granted {
            print("Microphone not authorized in Recorder")
            completion(false)
            return
        }
        
        // Run setup on our internal serial queue
        queue.async { [weak self] in
            self?.setupAndStartEngine(completion: completion)
        }
    }
    
    func stopRecording() -> URL? {
        // Stop logic needs to happen essentially synchronously to return the URL,
        // but stopping the engine should be careful.
        
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        
        // Remove tap safely
        let inputNode = audioEngine.inputNode
        inputNode.removeTap(onBus: 0)
        
        // End Speech Request
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        
        recognitionRequest = nil
        recognitionTask = nil
        audioFile = nil
        
        // Update State on Main Thread
        DispatchQueue.main.async {
            self.isRecording = false
            self.timer?.invalidate()
            self.audioLevel = 0 // Reset visualizer
        }
        
        return recordingURL
    }
    
    // MARK: - Internal Logic (Running on 'queue')
    
    private func setupAndStartEngine(completion: @escaping @Sendable (Bool) -> Void) {
        // 1. Setup Audio Session FIRST
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers, .defaultToSpeaker, .allowBluetoothHFP])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("Audio Session Error: \(error)")
            DispatchQueue.main.async { completion(false) }
            return
        }
        
        // 2. Cleanup
        recognitionTask?.cancel()
        recognitionTask = nil
        
        DispatchQueue.main.async {
            self.liveTranscript = ""
            self.duration = 0
            self.audioLevel = 0
        }
        
        // 3. Setup File
        let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = docDir.appendingPathComponent("live_recording.m4a")
        recordingURL = url
        
        // 4. Access Input Node
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        // Check if format is valid
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
        
        // 5. Setup Speech Recognition
        setupSpeechRecognition()
        
        // 6. Install Tap
        inputNode.removeTap(onBus: 0)
        // Buffer size 1024 gives frequent updates (~23ms at 44.1kHz)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, time in
            self?.handleAudioBuffer(buffer: buffer, time: time)
        }
        
        // 7. Start Engine
        do {
            audioEngine.prepare()
            try audioEngine.start()
            
            DispatchQueue.main.async {
                self.isRecording = true
                self.startTime = Date()
                self.startTimer()
                completion(true)
            }
        } catch {
            print("Engine Start Error: \(error)")
            DispatchQueue.main.async { completion(false) }
        }
    }
    
    private func setupSpeechRecognition() {
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        let canDoSpeech = (SFSpeechRecognizer.authorizationStatus() == .authorized) && (speechRecognizer?.isAvailable == true)
        
        if canDoSpeech {
            recognitionRequest?.shouldReportPartialResults = true
            
            // We need to weak capture self to avoid cycles, but explicit self capture in closure
            // is required.
            recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest!) { [weak self] result, error in
                guard let self = self else { return }
                
                if let result = result {
                    // FIX: Extract the string here (on the background thread)
                    // The result object itself is NOT Sendable, so we cannot pass it to Main Actor.
                    let transcript = result.bestTranscription.formattedString
                    
                    // Update transcript on Main Thread using the safe String value
                    DispatchQueue.main.async {
                        self.liveTranscript = transcript
                    }
                }
            }
        }
    }
    
    private func handleAudioBuffer(buffer: AVAudioPCMBuffer, time: AVAudioTime) {
        // A. Append to Speech Request
        recognitionRequest?.append(buffer)
        
        // B. Write to File
        do {
            try audioFile?.write(from: buffer)
        } catch {
            print("Error writing to file: \(error)")
        }
        
        // C. Calculate Audio Level (Visualizer)
        // Only update every ~30ms to save Main Thread bandwidth (approx 30fps)
        let now = Date().timeIntervalSince1970
        if now - lastUpdateTime < 0.03 { return }
        lastUpdateTime = now
        
        let channelData = buffer.floatChannelData?[0]
        let frameLength = Int(buffer.frameLength)
        let bufferStride = buffer.stride
        
        if let data = channelData {
            var sum: Float = 0
            // Calculate RMS (Root Mean Square) for better volume perception
            for i in stride(from: 0, to: frameLength * bufferStride, by: bufferStride) {
                let sample = data[i]
                sum += sample * sample
            }
            let rms = sqrt(sum / Float(frameLength))
            
            // Boost the signal significantly. Raw mic input is often very low (0.01 - 0.1).
            // Multiply by 10 or 20 to make it visible in the UI.
            // Then clamp to 0...1
            let normalized = min(max(rms * 10.0, 0), 1.0)
            
            // Update UI on Main Thread
            DispatchQueue.main.async {
                self.audioLevel = normalized
            }
        }
    }
    
    private func startTimer() {
        DispatchQueue.main.async {
            self.timer?.invalidate()
            self.timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                guard let self = self, let start = self.startTime else { return }
                self.duration = Date().timeIntervalSince(start)
            }
        }
    }
}
