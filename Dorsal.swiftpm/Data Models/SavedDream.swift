import Foundation
import SwiftData

@Model
final class SavedDream {
    var id: UUID
    var date: Date
    var title: String
    var rawText: String
    var summary: String
    var interpretation: String
    var actionableAdvice: String
    var sentiment: String
    var tone: String
    var themes: [String]
    var generatedImageHex: String?
    @Attribute(.externalStorage) var generatedImageData: Data?
    
    init(
        id: UUID = UUID(),
        date: Date = Date(),
        title: String,
        rawText: String,
        summary: String,
        interpretation: String,
        actionableAdvice: String,
        sentiment: String,
        tone: String,
        themes: [String],
        generatedImageHex: String? = nil,
        generatedImageData: Data? = nil
    ) {
        self.id = id
        self.date = date
        self.title = title
        self.rawText = rawText
        self.summary = summary
        self.interpretation = interpretation
        self.actionableAdvice = actionableAdvice
        self.sentiment = sentiment
        self.tone = tone
        self.themes = themes
        self.generatedImageHex = generatedImageHex
        self.generatedImageData = generatedImageData
    }
}
