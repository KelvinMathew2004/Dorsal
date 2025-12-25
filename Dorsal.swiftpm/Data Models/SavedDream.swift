import Foundation
import SwiftData

@Model
final class SavedDream {
    @Attribute(.unique) var id: UUID
    var date: Date
    var rawText: String
    
    // Analysis Data
    var title: String
    var summary: String
    var interpretation: String
    var actionableAdvice: String
    
    // Entities
    var people: [String]
    var places: [String]
    var emotions: [String]
    var symbols: [String]
    
    // Tone & Metrics
    var toneLabel: String
    var toneConfidence: Int
    var voiceFatigue: Int
    var sentimentScore: Int
    
    // Advanced Metrics
    var lucidityScore: Int
    var vividnessScore: Int
    var anxietyLevel: Int
    var coherenceScore: Int
    var isNightmare: Bool
    
    // Image Data
    var imagePrompt: String
    @Attribute(.externalStorage) var generatedImageData: Data?
    
    // Designated Initializer
    init(
        id: UUID = UUID(),
        date: Date = Date(),
        rawText: String,
        title: String,
        summary: String,
        interpretation: String,
        actionableAdvice: String,
        people: [String],
        places: [String],
        emotions: [String],
        symbols: [String],
        toneLabel: String,
        toneConfidence: Int,
        voiceFatigue: Int,
        sentimentScore: Int,
        lucidityScore: Int,
        vividnessScore: Int,
        anxietyLevel: Int,
        coherenceScore: Int,
        isNightmare: Bool,
        imagePrompt: String,
        generatedImageData: Data? = nil
    ) {
        self.id = id
        self.date = date
        self.rawText = rawText
        self.title = title
        self.summary = summary
        self.interpretation = interpretation
        self.actionableAdvice = actionableAdvice
        self.people = people
        self.places = places
        self.emotions = emotions
        self.symbols = symbols
        self.toneLabel = toneLabel
        self.toneConfidence = toneConfidence
        self.voiceFatigue = voiceFatigue
        self.sentimentScore = sentimentScore
        self.lucidityScore = lucidityScore
        self.vividnessScore = vividnessScore
        self.anxietyLevel = anxietyLevel
        self.coherenceScore = coherenceScore
        self.isNightmare = isNightmare
        self.imagePrompt = imagePrompt
        self.generatedImageData = generatedImageData
    }
}

extension SavedDream {
    // FIX: Use convenience init instead of static factory to resolve call site confusion
    convenience init(from dream: Dream) {
        self.init(
            id: dream.id,
            date: dream.date,
            rawText: dream.rawTranscript,
            title: dream.core?.title ?? "Untitled Dream",
            summary: dream.core?.summary ?? "No summary available.",
            interpretation: dream.core?.interpretation ?? "Analysis pending.",
            actionableAdvice: dream.core?.actionableAdvice ?? "",
            people: dream.core?.people ?? [],
            places: dream.core?.places ?? [],
            emotions: dream.core?.emotions ?? [],
            symbols: dream.core?.symbols ?? [],
            toneLabel: dream.core?.tone?.label ?? "Neutral",
            toneConfidence: dream.core?.tone?.confidence ?? 0,
            voiceFatigue: dream.core?.voiceFatigue ?? 0,
            sentimentScore: dream.extras?.sentimentScore ?? 50,
            lucidityScore: dream.extras?.lucidityScore ?? 0,
            vividnessScore: dream.extras?.vividnessScore ?? 0,
            anxietyLevel: dream.extras?.anxietyLevel ?? 0,
            coherenceScore: dream.extras?.coherenceScore ?? 0,
            isNightmare: dream.extras?.isNightmare ?? false,
            imagePrompt: dream.core?.summary ?? "",
            generatedImageData: dream.generatedImageData
        )
    }
}

// SwiftData Model for Weekly Insights
@Model
final class SavedWeeklyInsight {
    @Attribute(.unique) var id: UUID
    var dateGenerated: Date
    var periodOverview: String
    var dominantTheme: String
    var mentalHealthTrend: String
    var strategicAdvice: String
    
    init(periodOverview: String, dominantTheme: String, mentalHealthTrend: String, strategicAdvice: String) {
        self.id = UUID()
        self.dateGenerated = Date()
        self.periodOverview = periodOverview
        self.dominantTheme = dominantTheme
        self.mentalHealthTrend = mentalHealthTrend
        self.strategicAdvice = strategicAdvice
    }
}
