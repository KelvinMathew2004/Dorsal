import Foundation
import SwiftUI
import FoundationModels
import ImagePlayground
import SwiftData

// MARK: - TIER 1: CORE ANALYSIS
@Generable
struct DreamCoreAnalysis: Codable, Sendable, Hashable {
    @Guide(description: "A concise, engaging title for the dream.")
    var title: String?
    
    @Guide(description: "A 1-2 sentence summary of the dream's narrative flow.")
    var summary: String?
    
    @Guide(description: "The primary emotion felt.")
    var emotion: String?
    
    @Guide(description: "List of people or characters.")
    var people: [String]?
    
    @Guide(description: "List of locations or settings.")
    var places: [String]?
    
    @Guide(description: "List of distinct emotions felt.")
    var emotions: [String]?
    
    @Guide(description: "List of key symbols, objects, or animals.")
    var symbols: [String]?
    
    @Guide(description: "A deep, empathetic psychological interpretation.")
    var interpretation: String?
    
    @Guide(description: "Actionable advice based on the dream's themes.")
    var actionableAdvice: String?
    
    @Guide(description: "Voice fatigue (0-100).", .range(0...100))
    var voiceFatigue: Int?
    
    var tone: ToneAnalysis?
}

// MARK: - TIER 2: EXTRA ANALYSIS
@Generable
struct DreamExtraAnalysis: Codable, Sendable, Hashable {
    @Guide(description: "Sentiment score (0-100).", .range(0...100))
    var sentimentScore: Int?
    
    @Guide(description: "Is this a nightmare?")
    var isNightmare: Bool?
    
    @Guide(description: "Lucidity score (0-100).", .range(0...100))
    var lucidityScore: Int?
    
    @Guide(description: "Vividness score (0-100).", .range(0...100))
    var vividnessScore: Int?
    
    @Guide(description: "Coherence score (0-100).", .range(0...100))
    var coherenceScore: Int?
    
    @Guide(description: "Anxiety level (0-100).", .range(0...100))
    var anxietyLevel: Int?
}

@Generable
struct ToneAnalysis: Codable, Sendable, Hashable {
    var label: String?
    var confidence: Int?
}

@Generable
struct WeeklyInsightResult: Codable, Sendable, Hashable {
    var periodOverview: String?
    var dominantTheme: String?
    var mentalHealthTrend: String?
    var strategicAdvice: String?
}

// MARK: - APP DOMAIN MODEL
struct Dream: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let date: Date
    let rawTranscript: String
    
    var core: DreamCoreAnalysis?
    var extras: DreamExtraAnalysis?
    var generatedImageData: Data?
    
    // Legacy Helpers
    var smartSummary: String { core?.summary ?? "Processing..." }
    var interpretation: String { core?.interpretation ?? "Generating analysis..." }
    var actionableAdvice: String { core?.actionableAdvice ?? "" }
    var tone: String { core?.tone?.label ?? "Neutral" }
    
    var people: [String] { core?.people ?? [] }
    var places: [String] { core?.places ?? [] }
    var emotions: [String] {
        var all = core?.emotions ?? []
        if let primary = core?.emotion, !all.contains(primary) {
            all.insert(primary, at: 0)
        }
        return all
    }
    var keyEntities: [String] { core?.symbols ?? [] }
    
    var analysis: DreamAnalysisResult {
        DreamAnalysisResult(
            title: core?.title ?? "New Dream",
            summary: core?.summary ?? "",
            interpretation: core?.interpretation ?? "",
            actionableAdvice: core?.actionableAdvice ?? "",
            people: core?.people ?? [],
            places: core?.places ?? [],
            emotions: emotions,
            symbols: core?.symbols ?? [],
            tone: core?.tone ?? ToneAnalysis(label: "Neutral", confidence: 0),
            voiceFatigue: core?.voiceFatigue ?? 0,
            sentimentScore: extras?.sentimentScore ?? 50,
            lucidityScore: extras?.lucidityScore ?? 0,
            vividnessScore: extras?.vividnessScore ?? 0,
            anxietyLevel: extras?.anxietyLevel ?? 0,
            coherenceScore: extras?.coherenceScore ?? 0,
            isNightmare: extras?.isNightmare ?? false,
            imagePrompt: core?.summary ?? ""
        )
    }
    
    init(
        id: UUID = UUID(),
        date: Date = Date(),
        rawTranscript: String,
        core: DreamCoreAnalysis? = nil,
        extras: DreamExtraAnalysis? = nil,
        generatedImageData: Data? = nil
    ) {
        self.id = id
        self.date = date
        self.rawTranscript = rawTranscript
        self.core = core
        self.extras = extras
        self.generatedImageData = generatedImageData
    }
    
    // Init from SavedDream (SwiftData)
    init(from saved: SavedDream) {
        self.id = saved.id
        self.date = saved.date
        self.rawTranscript = saved.rawText
        self.generatedImageData = saved.generatedImageData
        
        self.core = DreamCoreAnalysis(
            title: saved.title,
            summary: saved.summary,
            emotion: saved.emotions.first, // Infer primary
            people: saved.people,
            places: saved.places,
            emotions: saved.emotions,
            symbols: saved.symbols,
            interpretation: saved.interpretation,
            actionableAdvice: saved.actionableAdvice,
            voiceFatigue: saved.voiceFatigue,
            tone: ToneAnalysis(label: saved.toneLabel, confidence: saved.toneConfidence)
        )
        
        self.extras = DreamExtraAnalysis(
            sentimentScore: saved.sentimentScore,
            isNightmare: saved.isNightmare,
            lucidityScore: saved.lucidityScore,
            vividnessScore: saved.vividnessScore,
            coherenceScore: saved.coherenceScore,
            anxietyLevel: saved.anxietyLevel
        )
    }
}

// Helper Struct
struct DreamAnalysisResult: Hashable, Codable, Sendable {
    var title: String
    var summary: String
    var interpretation: String
    var actionableAdvice: String
    var people: [String]
    var places: [String]
    var emotions: [String]
    var symbols: [String]
    var tone: ToneAnalysis
    var voiceFatigue: Int
    var sentimentScore: Int
    var lucidityScore: Int
    var vividnessScore: Int
    var anxietyLevel: Int
    var coherenceScore: Int
    var isNightmare: Bool
    var imagePrompt: String
}
