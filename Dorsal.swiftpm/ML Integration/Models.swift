import Foundation
import SwiftUI
import NaturalLanguage

// MARK: - Image Creator API (Simulated)
enum ImageStyle: String, Codable {
    case animation, illustration, sketch, photo
}

@MainActor // <--- FIX: Ensures thread safety for the singleton
class ImageCreator {
    static let shared = ImageCreator()
    
    func generateImage(prompt: String, style: ImageStyle = .illustration) async throws -> String {
        // Simulates async generation
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        let hash = prompt.hashValue
        return String(format: "#%06X", abs(hash) % 0xFFFFFF)
    }
}

// MARK: - Data Models
struct Dream: Identifiable, Codable, Hashable {
    let id: UUID
    let date: Date
    let rawTranscript: String
    let smartSummary: String
    let sentimentScore: Double
    let voiceFatigue: Double
    let keyEntities: [String]
    let people: [String]
    let places: [String]
    let emotions: [String]
    
    var generatedImageHex: String?
    
    var isPositive: Bool {
        return sentimentScore >= 0.1
    }
    
    var sentimentSymbol: String {
        switch sentimentScore {
        case 0.5...: return "sparkles"
        case 0.1..<0.5: return "leaf.fill"
        case -0.1..<0.1: return "minus"
        case -0.5 ..< -0.1: return "cloud.rain.fill"
        default: return "bolt.fill"
        }
    }
    
    var sentimentColor: Color {
        switch sentimentScore {
        case 0.5...: return .yellow
        case 0.1..<0.5: return .green
        case -0.1..<0.1: return .gray
        case -0.5 ..< -0.1: return .blue
        default: return .red
        }
    }
}

struct ChecklistItem: Identifiable, Hashable {
    let id = UUID()
    let question: String
    let keywords: [String]
    var isSatisfied: Bool = false
    var triggerKeywords: [String] = []
}

// MARK: - Intelligence Service
class IntelligenceService {
    
    static func generateSmartSummary(from text: String, entities: [String], emotions: [String]) -> String {
        if text.isEmpty { return "No recording available to analyze." }
        if text.count < 15 { return "The recording was too brief for a detailed analysis." }
        
        var summary = ""
        
        // Narrative Construction
        if let firstEntity = entities.first {
            summary += "Your dream centered on concepts resembling \(firstEntity). "
        } else {
            summary += "You described a series of abstract events. "
        }
        
        // Contextual analysis
        if !emotions.isEmpty {
            let uniqueEmotions = Array(Set(emotions)).prefix(3).joined(separator: ", ")
            summary += "The emotional tone shifted between \(uniqueEmotions), suggesting you may be processing these specific feelings from your waking life. "
        }
        
        // Symbolic analysis
        if entities.count > 1 {
            let symbols = entities.dropFirst().prefix(2).joined(separator: " and ")
            summary += "The presence of \(symbols) is notable and could represent underlying subconscious focus."
        }
        
        return summary
    }
    
    static func analyzeSentiment(text: String) -> Double {
        let tagger = NLTagger(tagSchemes: [.sentimentScore])
        tagger.string = text
        let (sentiment, _) = tagger.tag(at: text.startIndex, unit: .paragraph, scheme: .sentimentScore)
        return Double(sentiment?.rawValue ?? "0") ?? 0.0
    }
    
    static func extractPeople(from text: String) -> [String] {
        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = text
        var people: Set<String> = []
        let options: NLTagger.Options = [.omitPunctuation, .omitWhitespace, .joinNames]
        
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .nameType, options: options) { tag, range in
            if tag == .personalName { people.insert(String(text[range]).capitalized) }
            return true
        }
        
        let blocklist = ["I", "Me", "My", "Someone", "Nobody", "Anyone", "Everyone"]
        
        let familyKeywords = ["mom", "dad", "mother", "father", "brother", "sister", "friend", "grandmother", "grandfather"]
        let words = text.lowercased().components(separatedBy: CharacterSet.punctuationCharacters.union(.whitespaces))
        for word in words {
            if familyKeywords.contains(word) { people.insert(word.capitalized) }
        }
        
        return Array(people).filter { !blocklist.contains($0) }.sorted()
    }
    
    static func extractPlaces(from text: String) -> [String] {
        let placeKeywords = ["house", "home", "school", "work", "office", "forest", "beach", "ocean", "space", "room", "kitchen", "basement", "car", "train", "gym", "mall"]
        var places: Set<String> = []
        let words = text.lowercased().components(separatedBy: CharacterSet.punctuationCharacters.union(.whitespaces))
        for word in words {
            if placeKeywords.contains(word) { places.insert(word.capitalized) }
        }
        return Array(places).sorted()
    }
    
    static func extractEmotions(from text: String) -> [String] {
        let emotionMap: [String: [String]] = [
            "Fear": ["scared", "terrified", "afraid", "horror", "nightmare", "panic", "chased"],
            "Joy": ["happy", "excited", "laughing", "smile", "fun", "flying", "good"],
            "Anxiety": ["late", "lost", "stuck", "couldn't move", "frozen", "nervous", "test", "stress"],
            "Peace": ["calm", "quiet", "ocean", "gentle", "floating", "safe", "ok", "fine", "peace"],
            "Sadness": ["crying", "missed", "sad", "tears", "lonely"],
            "Confusion": ["weird", "strange", "confused", "didn't make sense", "lost", "foggy"]
        ]
        
        var detected: Set<String> = []
        let lowerText = text.lowercased()
        for (emotion, keywords) in emotionMap {
            for keyword in keywords {
                if lowerText.contains(keyword) { detected.insert(emotion); break }
            }
        }
        if detected.isEmpty {
            let score = analyzeSentiment(text: text)
            if score < -0.5 { detected.insert("Fear") }
            else if score < -0.1 { detected.insert("Anxiety") }
            else if score > 0.5 { detected.insert("Joy") }
            else if score >= 0.1 { detected.insert("Peace") }
            else { detected.insert("Neutral") }
        }
        return Array(detected).sorted()
    }
    
    static func extractEntities(text: String, existingTags: [String]) -> [String] {
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = text
        var foundTags: Set<String> = []
        
        let blocklist = [
            "dream", "felt", "like", "went", "saw", "was", "had", "got", "look", "said",
            "anything", "something", "everything", "nothing", "yeah", "okay", "thing",
            "stuff", "really", "kind", "sort", "maybe", "lot"
        ]
        
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .lexicalClass, options: [.omitPunctuation, .omitWhitespace]) { tag, range in
            let word = String(text[range]).capitalized
            
            if let tag = tag, (tag == .noun), word.count > 3, !blocklist.contains(word.lowercased()) {
                if let existing = existingTags.first(where: { $0.lowercased() == word.lowercased() || $0.lowercased() == word.lowercased() + "s" || $0.lowercased() + "s" == word.lowercased() }) {
                    foundTags.insert(existing)
                } else {
                    foundTags.insert(word)
                }
            }
            return true
        }
        return Array(foundTags.prefix(6)).sorted()
    }
}
