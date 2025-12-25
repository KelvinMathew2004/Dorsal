import Foundation
import SwiftData

@Model
final class SavedDream {
    var id: UUID
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
    
    // Metrics
    var toneLabel: String
    var toneConfidence: Int
    var voiceFatigue: Int
    var sentimentScore: Int
    
    // Advanced Metrics (New)
    var lucidityScore: Int
    var vividnessScore: Int
    var anxietyLevel: Int
    var coherenceScore: Int
    var isNightmare: Bool
    
    // Image Data
    var imagePrompt: String
    @Attribute(.externalStorage) var generatedImageData: Data?
    
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
    convenience init(from dream: Dream) {
        self.init(
            id: dream.id,
            date: dream.date,
            rawText: dream.rawTranscript,
            title: dream.analysis.title,
            summary: dream.analysis.summary,
            interpretation: dream.analysis.interpretation,
            actionableAdvice: dream.analysis.actionableAdvice,
            people: dream.analysis.people,
            places: dream.analysis.places,
            emotions: dream.analysis.emotions,
            symbols: dream.analysis.symbols,
            toneLabel: dream.analysis.tone.label,
            toneConfidence: dream.analysis.tone.confidence,
            voiceFatigue: dream.analysis.voiceFatigue,
            sentimentScore: dream.analysis.sentimentScore,
            lucidityScore: dream.analysis.lucidityScore,
            vividnessScore: dream.analysis.vividnessScore,
            anxietyLevel: dream.analysis.anxietyLevel,
            coherenceScore: dream.analysis.coherenceScore,
            isNightmare: dream.analysis.isNightmare,
            imagePrompt: dream.analysis.imagePrompt,
            generatedImageData: dream.generatedImageData
        )
    }
}
