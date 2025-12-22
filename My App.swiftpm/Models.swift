import Foundation
import SwiftUI
import NaturalLanguage

// MARK: - Data Models
struct Dream: Identifiable, Codable, Hashable {
    let id: UUID
    let date: Date
    let rawTranscript: String
    let smartSummary: String
    let sentimentScore: Double
    let voiceFatigue: Double
    let keyEntities: [String]
    
    // NEW: Specific Categories
    let people: [String]
    let places: [String]
    let emotions: [String]
    
    // Generative Art Parameters
    let artSeed: Int
    let dominantColorHex: String
    
    var sentimentEmoji: String {
        switch sentimentScore {
        case 0.5...: return "✨"
        case 0.1..<0.5: return "😌"
        case -0.1..<0.1: return "😐"
        case -0.5 ..< -0.1: return "😰"
        default: return "😱"
        }
    }
}

struct ChecklistItem: Identifiable, Hashable {
    let id = UUID()
    let question: String
    let keywords: [String]
    var isSatisfied: Bool = false
}

// MARK: - Intelligence Service
class IntelligenceService {
    
    static func generateSmartSummary(from text: String) -> String {
        if text.isEmpty { return "No content recorded." }
        return "You found yourself in a scenario involving \(text.prefix(10))... The atmosphere shifted as you encountered elements that seemed to represent \(extractEntities(text: text, existingTags: []).first ?? "unknown symbols"). The dream suggests a processing of recent emotions."
    }
    
    static func analyzeSentiment(text: String) -> Double {
        let tagger = NLTagger(tagSchemes: [.sentimentScore])
        tagger.string = text
        let (sentiment, _) = tagger.tag(at: text.startIndex, unit: .paragraph, scheme: .sentimentScore)
        return Double(sentiment?.rawValue ?? "0") ?? 0.0
    }
    
    // --- NEW EXTRACTION LOGIC ---
    
    static func extractPeople(from text: String) -> [String] {
        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = text
        var people: Set<String> = []
        let options: NLTagger.Options = [.omitPunctuation, .omitWhitespace, .joinNames]
        
        // 1. CoreML Name Detection
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .nameType, options: options) { tag, range in
            if tag == .personalName {
                people.insert(String(text[range]).capitalized)
            }
            return true
        }
        
        // 2. Fallback Keywords (for "Mom", "Dad", etc which might not be tagged as proper names)
        let familyKeywords = ["mom", "dad", "mother", "father", "brother", "sister", "friend", "grandmother", "grandfather"]
        let words = text.lowercased().components(separatedBy: CharacterSet.punctuationCharacters.union(.whitespaces))
        for word in words {
            if familyKeywords.contains(word) {
                people.insert(word.capitalized)
            }
        }
        
        return Array(people).sorted()
    }
    
    static func extractPlaces(from text: String) -> [String] {
        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = text
        var places: Set<String> = []
        let options: NLTagger.Options = [.omitPunctuation, .omitWhitespace, .joinNames]
        
        // 1. CoreML Place Detection
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .nameType, options: options) { tag, range in
            if tag == .placeName {
                places.insert(String(text[range]).capitalized)
            }
            return true
        }
        
        // 2. Fallback Keywords
        let placeKeywords = ["house", "home", "school", "work", "office", "forest", "beach", "ocean", "space", "room", "kitchen", "basement", "car", "train"]
        let words = text.lowercased().components(separatedBy: CharacterSet.punctuationCharacters.union(.whitespaces))
        for word in words {
            if placeKeywords.contains(word) {
                places.insert(word.capitalized)
            }
        }
        
        return Array(places).sorted()
    }
    
    static func extractEmotions(from text: String) -> [String] {
        // Simple keyword matching against a sentiment dictionary
        // In a real app, you might use a multi-label text classifier
        let emotionMap: [String: [String]] = [
            "Fear": ["scared", "terrified", "afraid", "horror", "nightmare", "panic", "chased"],
            "Joy": ["happy", "excited", "laughing", "smile", "fun", "flying"],
            "Anxiety": ["late", "lost", "stuck", "couldn't move", "frozen", "nervous", "test"],
            "Peace": ["calm", "quiet", "ocean", "gentle", "floating", "safe"],
            "Sadness": ["crying", "missed", "sad", "tears", "lonely"],
            "Confusion": ["weird", "strange", "confused", "didn't make sense", "lost"]
        ]
        
        var detected: Set<String> = []
        let lowerText = text.lowercased()
        
        for (emotion, keywords) in emotionMap {
            for keyword in keywords {
                if lowerText.contains(keyword) {
                    detected.insert(emotion)
                    break 
                }
            }
        }
        
        // Add implicit emotion based on sentiment score if none detected
        if detected.isEmpty {
            let score = analyzeSentiment(text: text)
            if score < -0.6 { detected.insert("Fear") }
            else if score < -0.2 { detected.insert("Anxiety") }
            else if score > 0.5 { detected.insert("Joy") }
            else if score > 0.1 { detected.insert("Peace") }
            else { detected.insert("Neutral") }
        }
        
        return Array(detected).sorted()
    }
    
    static func extractEntities(text: String, existingTags: [String]) -> [String] {
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = text
        var foundTags: Set<String> = []
        let ignoredWords = ["dream", "felt", "like", "went", "saw", "was", "had", "got"]
        
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .lexicalClass, options: [.omitPunctuation, .omitWhitespace]) { tag, range in
            let word = String(text[range]).capitalized
            if let tag = tag, (tag == .noun || tag == .verb), word.count > 3, !ignoredWords.contains(word.lowercased()) {
                if let existing = existingTags.first(where: { $0 == word || $0 == word + "s" || $0 + "s" == word }) {
                    foundTags.insert(existing)
                } else {
                    foundTags.insert(word)
                }
            }
            return true
        }
        return Array(foundTags.prefix(5)).sorted()
    }
}
