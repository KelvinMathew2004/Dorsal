import SwiftUI
import Speech
import AVFoundation
import SwiftData

// Stub for Missing ImageCreator
struct ImageCreatorStub {
    static let shared = ImageCreatorStub()
    func generateImage(llmPrompt: ImagePrompt, style: Int = 0) async throws -> (Data?, String?) {
        return (nil, "#000000")
    }
}

// MARK: - Audio Engine Manager (Thread-safe)
final class AudioEngineManager: @unchecked Sendable {
    static let shared = AudioEngineManager()
    private var engine: AVAudioEngine?
    private let lock = NSLock()
    private init() {}
    func createEngine() -> AVAudioEngine {
        lock.lock(); defer { lock.unlock() }
        destroyEngineUnsafe(); let new = AVAudioEngine(); engine = new; return new
    }
    func destroyEngine() {
        lock.lock(); defer { lock.unlock() }
        destroyEngineUnsafe()
    }
    private func destroyEngineUnsafe() {
        if let existing = engine { if existing.isRunning { existing.stop() }; existing.inputNode.removeTap(onBus: 0) }; engine = nil
    }
    func getEngine() -> AVAudioEngine? {
        lock.lock(); defer { lock.unlock() }; return engine
    }
}

@MainActor
class DreamStore: NSObject, ObservableObject {
    @Published var dreams: [Dream] = [] // Legacy support
    
    // Navigation
    @Published var selectedTab: Int = 0
    @Published var navigationPath = NavigationPath()
    
    // Recording
    @Published var currentTranscript: String = ""
    @Published var isRecording = false
    @Published var isProcessing: Bool = false
    
    // Mock
    private var mockTimer: Timer?
    private let useMockMode = true
    private var mockDreamIndex = 0
    
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionTask: SFSpeechRecognitionTask?
    
    override init() {
        super.init()
    }
    
    deinit { AudioEngineManager.shared.destroyEngine() }
    
    // MARK: - Recording Logic
    func startRecording() {
        guard !isRecording else { return }
        if useMockMode { startMockRecording(); return }
    }
    
    func startMockRecording() {
        print("[DreamStore] 🎭 Starting MOCK recording")
        currentTranscript = ""
        isRecording = true
        
        let mockPhrase = "I was swimming deep underwater, but I could breathe perfectly fine. There was a giant ticking clock on the ocean floor."
        
        // Simulate typing effect
        var index = 0
        mockTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                if index < mockPhrase.count {
                    let charIndex = mockPhrase.index(mockPhrase.startIndex, offsetBy: index)
                    self.currentTranscript.append(mockPhrase[charIndex])
                    index += 1
                } else {
                    self.mockTimer?.invalidate()
                    self.mockTimer = nil
                }
            }
        }
    }
    
    func stopRecording(save: Bool, context: ModelContext? = nil) {
        mockTimer?.invalidate()
        mockTimer = nil
        AudioEngineManager.shared.destroyEngine()
        
        withAnimation { isRecording = false }
        
        if save && !currentTranscript.isEmpty {
            Task {
                await MainActor.run { self.isProcessing = true }
                
                // Create and Save to SwiftData
                await createAndSaveDream(context: context)
                
                await MainActor.run {
                    self.isProcessing = false
                    selectedTab = 1 // Switch to Journal Tab
                }
            }
        }
    }
    
    // MARK: - AI GENERATION PIPELINE
    private func createAndSaveDream(context: ModelContext?) async {
        let text = currentTranscript
        
        do {
            // 1. Foundation Models: Deep Analysis
            // Using the updated DreamAnalyzer
            let analysis = try await DreamAnalyzer.shared.analyze(transcript: text)
            
            // 2. Foundation Models: Image Prompt Generation (Optional, can fail safely)
            var imageData: Data? = nil
            var imageHex: String? = nil
            
            if let artPrompt = try? await DreamAnalyzer.shared.generateArtPrompt(transcript: text) {
                let result = try? await ImageCreatorStub.shared.generateImage(llmPrompt: artPrompt)
                imageData = result?.0
                imageHex = result?.1
            }
            
            // 3. Create SwiftData Model
            let newSavedDream = SavedDream(
                title: analysis.title.isEmpty ? "Untitled Dream" : analysis.title,
                rawText: text,
                summary: analysis.summary,
                interpretation: analysis.interpretation,
                actionableAdvice: analysis.actionableAdvice,
                sentiment: analysis.sentiment,
                tone: analysis.tone,
                themes: analysis.themes,
                generatedImageHex: imageHex,
                generatedImageData: imageData
            )
            
            // 4. Save to Context
            if let context = context {
                print("Saving dream to SwiftData...")
                context.insert(newSavedDream)
                try? context.save()
            } else {
                print("Error: No ModelContext provided!")
            }
            
        } catch {
            print("Error generating dream: \(error)")
        }
    }
}
