import SwiftUI
import AVFoundation
import SoundAnalysis
import CoreML
import Combine

// MARK: - Main App Entry Point
@main
struct VocalFatigueApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

// MARK: - View Model
class FatigueAnalyzer: NSObject, ObservableObject, AVAudioRecorderDelegate {
    @Published var isRecording = false
    @Published var fatigueScore: Double = 0.0
    @Published var statusMessage = "Initializing..."
    @Published var showScore = false
    
    private var audioRecorder: AVAudioRecorder?
    private var soundClassifier: MLModel?
    private var frameScores: [Double] = []
    
    override init() {
        super.init()
        initializeModel()
    }
    
    private func initializeModel() {
        // 1. Check if the compiled .mlmodelc already exists (Xcode usually creates this)
        if let compiledUrl = Bundle.main.url(forResource: "VocalFatigueModel", withExtension: "mlmodelc") {
            print("Found pre-compiled model.")
            
            // PRINT THE PATH SO YOU CAN FIND IT
            print("\n---------------------------------------------------")
            print("📂 EXISTING MODEL FOUND!")
            print("👇 COPY THIS PATH to find your file:")
            print("📂 \(compiledUrl.path)")
            print("---------------------------------------------------\n")
            
            loadModel(from: compiledUrl)
            return
        }
        
        // 2. If not found, try to compile the .mlmodel file at runtime
        print("Compiled .mlmodelc not found. Attempting to compile source .mlmodel...")
        
        guard let sourceUrl = Bundle.main.url(forResource: "VocalFatigueModel", withExtension: "mlmodel") else {
            print("Error: Could not find VocalFatigueModel.mlmodel in the bundle.")
            self.statusMessage = "Model file missing"
            return
        }
        
        // Compiling can be slow, so we do it in the background
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let tempCompiledUrl = try MLModel.compileModel(at: sourceUrl)
                
                // IMPORTANT: Print the location so you can find the file!
                print("\n---------------------------------------------------")
                print("🎉 SUCCESS! Model Compiled Successfully.")
                print("👇 COPY THIS PATH to find your file:")
                print("📂 \(tempCompiledUrl.path)")
                print("---------------------------------------------------\n")
                
                DispatchQueue.main.async {
                    self.loadModel(from: tempCompiledUrl)
                }
            } catch {
                print("Compilation Error: \(error)")
                DispatchQueue.main.async {
                    self.statusMessage = "Failed to compile model"
                }
            }
        }
    }
    
    private func loadModel(from url: URL) {
        do {
            self.soundClassifier = try MLModel(contentsOf: url)
            self.statusMessage = "Ready to analyze"
        } catch {
            print("Model Init Error: \(error)")
            self.statusMessage = "Failed to load model"
        }
    }
    
    // Path to save the temporary recording
    private var audioFileURL: URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0].appendingPathComponent("recording.wav")
    }
    
    // Start Recording
    func startRecording() {
        guard soundClassifier != nil else {
            statusMessage = "Model not ready"
            return
        }
        
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 16000,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsFloatKey: false,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            
            audioRecorder = try AVAudioRecorder(url: audioFileURL, settings: settings)
            audioRecorder?.delegate = self
            
            if audioRecorder?.record() == true {
                isRecording = true
                showScore = false
                statusMessage = "Recording..."
                frameScores.removeAll()
            } else {
                statusMessage = "Could not start recording"
            }
            
        } catch {
            statusMessage = "Failed to start recording: \(error.localizedDescription)"
        }
    }
    
    // Stop Recording & Trigger Analysis
    func stopRecording() {
        audioRecorder?.stop()
        isRecording = false
        statusMessage = "Analyzing..."
        
        // Slight delay to ensure file is closed properly
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.analyzeAudio()
        }
    }
    
    // Analyze the recorded file
    private func analyzeAudio() {
        guard let classifier = soundClassifier else {
            statusMessage = "Model not loaded"
            return
        }
        
        frameScores.removeAll()
        
        do {
            let request = try SNClassifySoundRequest(mlModel: classifier)
            let analyzer = try SNAudioFileAnalyzer(url: audioFileURL)
            
            try analyzer.add(request, withObserver: self)
            try analyzer.analyze()
            
        } catch {
            print("Analysis Error: \(error)")
            statusMessage = "Could not analyze audio"
        }
    }
}

// MARK: - Sound Analysis Observer
extension FatigueAnalyzer: SNResultsObserving {
    func request(_ request: SNRequest, didProduce result: SNResult) {
        guard let result = result as? SNClassificationResult else { return }
        guard let topClassification = result.classifications.first else { return }
        
        // Match labels
        let fatiguedClass = result.classifications.first(where: {
            $0.identifier.lowercased().contains("fatigue")
        })
        let healthyClass = result.classifications.first(where: {
            $0.identifier.lowercased().contains("health")
        })
        
        var calculatedScore: Double = 0.0
        
        if let fScore = fatiguedClass?.confidence {
            calculatedScore = fScore
        } else if let hScore = healthyClass?.confidence {
            calculatedScore = 1.0 - hScore
        } else {
            if topClassification.identifier.lowercased().contains("fatigue") {
                calculatedScore = topClassification.confidence
            } else {
                calculatedScore = 1.0 - topClassification.confidence
            }
        }
        
        DispatchQueue.main.async {
            self.frameScores.append(calculatedScore)
        }
    }
    
    func request(_ request: SNRequest, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.statusMessage = "Analysis Failed: \(error.localizedDescription)"
        }
    }
    
    func requestDidComplete(_ request: SNRequest) {
        DispatchQueue.main.async {
            // Average the scores to get a percentage
            if !self.frameScores.isEmpty {
                let total = self.frameScores.reduce(0, +)
                self.fatigueScore = total / Double(self.frameScores.count)
            } else {
                self.fatigueScore = 0.0
            }
            
            self.statusMessage = "Analysis Complete"
            self.showScore = true
        }
    }
}

// MARK: - UI
struct ContentView: View {
    @StateObject private var analyzer = FatigueAnalyzer()
    
    var body: some View {
        ZStack {
            Color(UIColor.systemGroupedBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 40) {
                
                // Title
                VStack(spacing: 8) {
                    Text("Vocal Health")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.gray)
                    Text("Fatigue Analyzer")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                }
                .padding(.top, 50)
                
                // Score Indicator
                ZStack {
                    Circle()
                        .stroke(lineWidth: 20)
                        .opacity(0.3)
                        .foregroundColor(.gray)
                    
                    Circle()
                        .trim(from: 0.0, to: analyzer.showScore ? CGFloat(analyzer.fatigueScore) : 0.0)
                        .stroke(style: StrokeStyle(lineWidth: 20, lineCap: .round, lineJoin: .round))
                        .foregroundColor(scoreColor)
                        .rotationEffect(Angle(degrees: 270.0))
                        .animation(.easeOut(duration: 1.0), value: analyzer.showScore)
                        .animation(.easeOut(duration: 1.0), value: analyzer.fatigueScore)

                    VStack {
                        if analyzer.showScore {
                            Text("\(Int(analyzer.fatigueScore * 100))%")
                                .font(.system(size: 50, weight: .bold))
                            Text("Fatigue Level")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Image(systemName: "waveform")
                                .font(.system(size: 50))
                                .foregroundColor(.blue)
                        }
                    }
                }
                .frame(width: 200, height: 200)
                .padding()
                
                // Status Text
                Text(analyzer.statusMessage)
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.white))
                
                Spacer()
                
                // Record Button
                Button(action: {
                    if analyzer.isRecording {
                        analyzer.stopRecording()
                    } else {
                        analyzer.startRecording()
                    }
                }) {
                    ZStack {
                        Circle()
                            .fill(analyzer.isRecording ? Color.red : Color.blue)
                            .frame(width: 80, height: 80)
                            .shadow(radius: 10)
                        
                        if analyzer.isRecording {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.white)
                                .frame(width: 30, height: 30)
                        } else {
                            Circle()
                                .stroke(Color.white, lineWidth: 4)
                                .frame(width: 70, height: 70)
                                .opacity(0.5)
                            Image(systemName: "mic.fill")
                                .font(.title)
                                .foregroundColor(.white)
                        }
                    }
                }
                .padding(.bottom, 50)
            }
            .padding()
        }
        .onAppear {
            requestMicrophoneAccess()
        }
    }
    
    var scoreColor: Color {
        if analyzer.fatigueScore < 0.4 { return .green }
        if analyzer.fatigueScore < 0.7 { return .orange }
        return .red
    }
    
    func requestMicrophoneAccess() {
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            if !granted {
                print("Microphone access denied")
            }
        }
    }
}
