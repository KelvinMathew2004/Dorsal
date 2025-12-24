import Foundation
import SwiftUI
import NaturalLanguage
import UIKit

// MARK: - SHARED DATA MODELS

// 1. Dream Model
struct Dream: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let date: Date
    let rawTranscript: String
    
    // AI Analysis Fields
    let smartSummary: String
    let interpretation: String
    let actionableAdvice: String
    let emotion: String
    let tone: String
    
    // Metrics
    let sentimentScore: Double
    let voiceFatigue: Double
    
    // Context (Extracted via Foundation Model)
    let keyEntities: [String]
    let people: [String]
    let places: [String]
    let emotions: [String]
    
    // Generated Content
    var generatedImageHex: String?
    var generatedImageData: Data?
    
    var isPositive: Bool {
        return sentimentScore >= 0.1
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Dream, rhs: Dream) -> Bool {
        lhs.id == rhs.id
    }
}

// 2. Dream Insight
struct DreamInsight: Codable, Sendable {
    @Guide(description: "The primary emotion felt during the dream.")
    var emotion: String = ""
    
    @Guide(description: "The speaking tone of the transcript.")
    var tone: String = ""
    
    @Guide(description: "A concise summary of the dream narrative.")
    var summary: String = ""
    
    @Guide(description: "A psychological interpretation of the dream's meaning.")
    var interpretation: String = ""
    
    @Guide(description: "Actionable therapeutic advice for the user.")
    var actionableAdvice: String = ""
    
    init(emotion: String, tone: String, summary: String, interpretation: String, actionableAdvice: String) {
        self.emotion = emotion; self.tone = tone; self.summary = summary; self.interpretation = interpretation; self.actionableAdvice = actionableAdvice
    }
    
    init() {}
}

// 3. Entity Extraction (Generable)
struct DreamEntities: Codable, Sendable {
    @Guide(description: "List of people identified in the dream.")
    var people: [String] = []
    
    @Guide(description: "List of places identified.")
    var places: [String] = []
    
    @Guide(description: "List of distinct emotions felt or described.")
    var emotions: [String] = []
    
    @Guide(description: "List of significant symbols or objects.")
    var keyEntities: [String] = []
    
    init(people: [String] = [], places: [String] = [], emotions: [String] = [], keyEntities: [String] = []) {
        self.people = people
        self.places = places
        self.emotions = emotions
        self.keyEntities = keyEntities
    }
}

// 4. Therapeutic Insight
struct TherapeuticInsight: Identifiable, Codable, Sendable {
    var id: UUID = UUID()
    
    @Guide(description: "Title of the psychological pattern.")
    var title: String = ""
    
    @Guide(description: "Observation of the user's recent dream themes.")
    var observation: String = ""
    
    @Guide(description: "Suggestion for the user.")
    var suggestion: String = ""
    
    init(title: String, observation: String, suggestion: String) {
        self.title = title
        self.observation = observation
        self.suggestion = suggestion
    }
    
    init() {}
}

// 5. Image Prompt
public struct ImagePrompt: Codable, Sendable {
    @Guide(description: "A vivid visual description for the image generator.")
    public var visualDescription: String = ""
    
    @Guide(description: "Keywords defining the mood.")
    public var moodKeywords: String = ""
    
    @Guide(description: "Color palette suggestions.")
    public var colorPalette: String = ""
    
    public init(visualDescription: String = "", moodKeywords: String = "", colorPalette: String = "") {
        self.visualDescription = visualDescription
        self.moodKeywords = moodKeywords
        self.colorPalette = colorPalette
    }
}

// 6. Checklist Item
struct ChecklistItem: Identifiable, Hashable, Sendable {
    let id = UUID()
    let question: String
    let keywords: [String]
    var isSatisfied: Bool = false
    var triggerKeywords: [String] = []
}

// 7. Image Creator Support
enum ImageStyle: String, Codable {
    case animation, illustration, sketch, photo
}

@MainActor
class ImageCreator {
    static let shared = ImageCreator()
    
    func generateImage(llmPrompt: ImagePrompt, style: ImageStyle = .illustration) async throws -> (Data?, String) {
        try? await Task.sleep(nanoseconds: 500_000_000)
        let hash = abs(llmPrompt.visualDescription.hashValue)
        let hex = String(format: "#%06X", hash % 0xFFFFFF)
        
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 1024, height: 1024))
        let image = renderer.image { context in
            let ctx = context.cgContext
            let colorHash = abs(llmPrompt.colorPalette.hashValue)
            let r = CGFloat((colorHash >> 16) & 0xFF) / 255.0
            let g = CGFloat((colorHash >> 8) & 0xFF) / 255.0
            let b = CGFloat(colorHash & 0xFF) / 255.0
            let color = UIColor(red: r, green: g, blue: b, alpha: 1.0)
            color.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 1024, height: 1024))
            
            ctx.setBlendMode(.overlay)
            UIColor.white.withAlphaComponent(0.2).setFill()
            ctx.fillEllipse(in: CGRect(x: 200, y: 200, width: 600, height: 600))
        }
        
        return (image.jpegData(compressionQuality: 0.8), hex)
    }
}
