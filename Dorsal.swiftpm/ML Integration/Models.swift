import Foundation
import SwiftUI
import FoundationModels
import ImagePlayground

// MARK: - GENERABLE MODELS (FOUNDATION FRAMEWORK)

@Generable
struct DreamAnalysisResult: Codable, Sendable, Hashable { // Added Hashable
    
    @Guide(description: "A concise, engaging title for the dream (3-6 words).")
    var title: String = ""
    
    @Guide(description: "A 1-2 sentence summary of the dream's narrative flow.")
    var summary: String = ""
    
    @Guide(description: "A deep, empathetic psychological interpretation acting as a friendly therapist.")
    var interpretation: String = ""
    
    @Guide(description: "Actionable advice based on the dream's themes.")
    var actionableAdvice: String = ""
    
    // Entities
    @Guide(description: "List of people or characters identified.")
    var people: [String] = []
    
    @Guide(description: "List of specific locations or settings.")
    var places: [String] = []
    
    @Guide(description: "List of distinct emotions felt.")
    var emotions: [String] = []
    
    @Guide(description: "List of key objects, animals, or symbols.")
    var symbols: [String] = []
    
    // MARK: - Advanced Metrics (Mental Health & Sleep)
    
    @Guide(description: "Analysis of the speaker's tone.")
    var tone: ToneAnalysis = ToneAnalysis()
    
    @Guide(description: "Voice fatigue level based on speech patterns (0=Fresh, 100=Exhausted).", .range(0...100))
    var voiceFatigue: Int = 0
    
    @Guide(description: "Overall sentiment (0=Negative, 100=Positive).", .range(0...100))
    var sentimentScore: Int = 50
    
    @Guide(description: "Lucidity score: likelihood the dreamer knew they were dreaming.", .range(0...100))
    var lucidityScore: Int = 0
    
    @Guide(description: "Vividness score: how sensory-rich and clear the memory is.", .range(0...100))
    var vividnessScore: Int = 0
    
    @Guide(description: "Anxiety level detected in the narrative.", .range(0...100))
    var anxietyLevel: Int = 0
    
    @Guide(description: "Narrative coherence: how structured the memory is (Memory Health).", .range(0...100))
    var coherenceScore: Int = 50
    
    @Guide(description: "Is this dream considered a nightmare?")
    var isNightmare: Bool = false
    
    @Guide(description: "Detailed art prompt for the dream.")
    var imagePrompt: String = ""
}

// MARK: - NEW: WEEKLY INSIGHTS MODEL

@Generable
struct WeeklyInsightResult: Codable, Sendable, Hashable { // Added Hashable
    
    @Guide(description: "A holistic summary of the user's dreaming patterns over the selected period.")
    var periodOverview: String = ""
    
    @Guide(description: "The most dominant recurring theme or symbol found across multiple dreams.")
    var dominantTheme: String = ""
    
    @Guide(description: "Analysis of the user's mental health trend based on dream content (e.g., 'Increasing Anxiety', 'Finding Peace').")
    var mentalHealthTrend: String = ""
    
    @Guide(description: "An observation about the user's sleep quality trend inferred from fatigue and vividness scores.")
    var sleepQualityObservation: String = ""
    
    @Guide(description: "Strategic, therapeutic advice for the upcoming week based on these aggregated insights.")
    var strategicAdvice: String = ""
    
    @Guide(description: "Three keywords that define this period.")
    var keywords: [String] = []
}

@Generable
struct ToneAnalysis: Codable, Sendable, Hashable { // Added Hashable
    @Guide(description: "The dominant tone label.")
    var label: String = ""
    
    @Guide(description: "Confidence percentage.", .range(0...100))
    var confidence: Int = 0
}

@Generable
struct ImagePrompt: Codable, Sendable {
    @Guide(description: "A detailed visual description of the scene to be generated.")
    var visualDescription: String = ""
    
    @Guide(description: "Mood keywords to influence the atmosphere (e.g. 'Mysterious', 'Joyful').")
    var moodKeywords: String = ""
    
    @Guide(description: "The artistic style or color palette (e.g. 'Dreamlike', 'Cyberpunk', 'Watercolor').")
    var colorPalette: String = ""
}


// MARK: - APP DOMAIN MODELS

struct Dream: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let date: Date
    let rawTranscript: String
    
    // Analysis
    var analysis: DreamAnalysisResult
    
    // Generated Asset
    var generatedImageData: Data?
    
    // Computed Helpers for Charts & Legacy View Compatibility
    var sentimentScore: Double { Double(analysis.sentimentScore) }
    var anxietyScore: Double { Double(analysis.anxietyLevel) }
    var fatigueScore: Double { Double(analysis.voiceFatigue) }
    
    // Legacy properties to fix HistoryView/DetailView errors
    var smartSummary: String { analysis.summary }
    var interpretation: String { analysis.interpretation }
    var actionableAdvice: String { analysis.actionableAdvice }
    var emotion: String { analysis.emotions.joined(separator: ", ") }
    var tone: String { analysis.tone.label }
    var keyEntities: [String] { analysis.symbols } // Mapping symbols to old "keyEntities"
    var people: [String] { analysis.people }
    var places: [String] { analysis.places }
    var emotions: [String] { analysis.emotions }
    var voiceFatigue: Double { Double(analysis.voiceFatigue) / 100.0 } // Normalize for legacy views if they expect 0.0-1.0
    var generatedImageHex: String? { nil } // Deprecated
    
    init(
        id: UUID = UUID(),
        date: Date = Date(),
        rawTranscript: String,
        analysis: DreamAnalysisResult,
        generatedImageData: Data? = nil
    ) {
        self.id = id
        self.date = date
        self.rawTranscript = rawTranscript
        self.analysis = analysis
        self.generatedImageData = generatedImageData
    }
}
