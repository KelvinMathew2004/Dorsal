import Foundation
import NaturalLanguage

// MARK: - Data Model
struct Dream: Identifiable, Hashable {
    let id = UUID()
    let date: Date
    let rawTranscript: String
    let smartSummary: String
    let sentimentScore: Double // -1.0 to 1.0
    let voiceFatigue: Double   // 0.0 to 1.0
    let keyEntities: [String]
    
    // Computed helper for UI
    var sentimentEmoji: String {
        switch sentimentScore {
        case 0.5...: return "✨" // Positive
        case 0.1..<0.5: return "😌" // Mildly Positive
        case -0.1..<0.1: return "😐" // Neutral
        case -0.5 ..< -0.1: return "😰" // Anxious
        default: return "😱" // Nightmare
        }
    }
}

// MARK: - Intelligence Service
// Simulated "Apple Intelligence" Service
// In a real iOS 18 app, this would wrap WritingTools and on-device LLMs.
class IntelligenceService {
    
    // 1. NLTagger for Sentiment (Real On-Device ML)
    static func analyzeSentiment(text: String) -> Double {
        let tagger = NLTagger(tagSchemes: [.sentimentScore])
        tagger.string = text
        let (sentiment, _) = tagger.tag(at: text.startIndex, unit: .paragraph, scheme: .sentimentScore)
        return Double(sentiment?.rawValue ?? "0") ?? 0.0
    }
    
    // 2. NLTagger for Entity Extraction (Real On-Device ML)
    static func extractEntities(text: String) -> [String] {
        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = text
        var entities: [String] = []
        
        // Custom logic to simulate keyword extraction for "Dream Objects"
        let words = text.components(separatedBy: " ")
        for word in words {
            // Simple filter for demo purposes
            if word.count > 5 { entities.append(word.capitalized) }
        }
        return Array(entities.prefix(3)) // Return top 3 tags
    }
    
    // 3. Simulated LLM Summarization
    static func generateSmartSummary(from text: String) -> String {
        if text.isEmpty { return "No content to summarize." }
        // Simulated AI response
        return "✨ AI Summary: The dreamer experienced a sequence involving \(text.prefix(20))... The narrative suggests a focus on subconscious processing of daily events."
    }
}
