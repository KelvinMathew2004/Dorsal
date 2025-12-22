import SwiftUI
import Speech
import NaturalLanguage
import AVFoundation

// MARK: - View Model
@MainActor
class DreamStore: ObservableObject {
    @Published var dreams: [Dream] = []
    @Published var currentTranscript: String = ""
    @Published var isRecording = false
    @Published var audioPower: Float = 0.0
    
    // Mock Data Generator
    init() {
        seedMockData()
    }
    
    func seedMockData() {
        let mock1 = Dream(date: Date().addingTimeInterval(-86400), rawTranscript: "I was flying over a purple ocean and the clouds were made of cotton candy.", smartSummary: "A lucid flying dream featuring surreal landscapes and positive emotional resonance.", sentimentScore: 0.8, voiceFatigue: 0.2, keyEntities: ["Ocean", "Flying", "Clouds"])
        let mock2 = Dream(date: Date().addingTimeInterval(-172800), rawTranscript: "I missed my math test and couldn't find the classroom door.", smartSummary: "A classic anxiety dream centered on academic performance and feelings of being lost.", sentimentScore: -0.6, voiceFatigue: 0.7, keyEntities: ["Test", "Classroom", "Lost"])
        let mock3 = Dream(date: Date().addingTimeInterval(-259200), rawTranscript: "I was just walking through a forest.", smartSummary: "A peaceful, grounded dream involving nature.", sentimentScore: 0.1, voiceFatigue: 0.1, keyEntities: ["Forest", "Walking"])
        
        dreams = [mock1, mock2, mock3]
    }
    
    // Simulation of Recording logic
    func toggleRecording() {
        isRecording.toggle()
        if isRecording {
            simulateLiveTranscribing()
        } else {
            saveDream()
        }
    }
    
    private func simulateLiveTranscribing() {
        // Simulates words appearing in real-time
        let phrases = ["I saw a giant...", "Clock melting...", "In the sky...", "It felt real."]
        var index = 0
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            if !self.isRecording { timer.invalidate(); return }
            self.audioPower = Float.random(in: 0.1...1.0)
            if index < phrases.count {
                self.currentTranscript += phrases[index] + " "
                index += 1
            }
        }
    }
    
    private func saveDream() {
        let sentiment = IntelligenceService.analyzeSentiment(text: currentTranscript)
        let entities = IntelligenceService.extractEntities(text: currentTranscript)
        let summary = IntelligenceService.generateSmartSummary(from: currentTranscript)
        
        let newDream = Dream(
            date: Date(),
            rawTranscript: currentTranscript,
            smartSummary: summary,
            sentimentScore: sentiment,
            voiceFatigue: Double.random(in: 0.1...0.9), // Simulated
            keyEntities: entities
        )
        
        withAnimation {
            dreams.insert(newDream, at: 0)
            currentTranscript = "" // Reset
            audioPower = 0.0
        }
    }
}
