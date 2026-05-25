import Foundation
import SwiftData

@Model
final class SavedDream {
    var id: UUID = UUID()
    var date: Date = Date()
    var rawText: String = ""
    
    // Analysis Data
    var title: String = ""
    var summary: String = ""
    var interpretation: String = ""
    var actionableAdvice: String = ""
    
    // Entities
    var people: [String] = []
    var places: [String] = []
    var emotions: [String] = []
    var symbols: [String] = []
    
    // Tone & Metrics
    var toneLabel: String = ""
    var toneConfidence: Int = 0
    var voiceFatigue: Int = 0
    var sentimentScore: Int = 0
    
    // Advanced Metrics
    var lucidityScore: Int = 0
    var vividnessScore: Int = 0
    var anxietyLevel: Int = 0
    var coherenceScore: Int = 0
    var isNightmare: Bool = false
    
    // Image Data
    var imagePrompt: String = ""
    @Attribute(.externalStorage) var generatedImageData: Data? = nil
    
    var isBookmarked: Bool = false
    
    // Designated Initializer
    init(
        id: UUID = UUID(),
        date: Date = Date(),
        rawText: String = "",
        title: String = "",
        summary: String = "",
        interpretation: String = "",
        actionableAdvice: String = "",
        people: [String] = [],
        places: [String] = [],
        emotions: [String] = [],
        symbols: [String] = [],
        toneLabel: String = "",
        toneConfidence: Int = 0,
        voiceFatigue: Int = 0,
        sentimentScore: Int = 0,
        lucidityScore: Int = 0,
        vividnessScore: Int = 0,
        anxietyLevel: Int = 0,
        coherenceScore: Int = 0,
        isNightmare: Bool = false,
        imagePrompt: String = "",
        generatedImageData: Data? = nil,
        isBookmarked: Bool = false
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
        self.isBookmarked = isBookmarked
    }
}

// SwiftData Model for Weekly Insights
@Model
final class SavedWeeklyInsight {
    var id: UUID = UUID()
    var dateGenerated: Date = Date()
    var periodOverview: String = ""
    var dominantTheme: String = ""
    var mentalHealthTrend: String = ""
    var strategicAdvice: String = ""
    
    init(
        periodOverview: String = "",
        dominantTheme: String = "",
        mentalHealthTrend: String = "",
        strategicAdvice: String = ""
    ) {
        self.id = UUID()
        self.dateGenerated = Date()
        self.periodOverview = periodOverview
        self.dominantTheme = dominantTheme
        self.mentalHealthTrend = mentalHealthTrend
        self.strategicAdvice = strategicAdvice
    }
}
