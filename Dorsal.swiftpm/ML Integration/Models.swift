import Foundation

// Legacy struct if needed for filteredDreams logic in DreamStore (can be refactored out later)
struct Dream: Identifiable, Codable {
    var id: UUID
    var date: Date
    var rawTranscript: String
    var smartSummary: String
    var interpretation: String
    var actionableAdvice: String
    var emotion: String
    var tone: String
    var sentimentScore: Double
    var voiceFatigue: Double
    var keyEntities: [String]
    var people: [String]
    var places: [String]
    var emotions: [String]
    var generatedImageHex: String?
    var generatedImageData: Data?
}
