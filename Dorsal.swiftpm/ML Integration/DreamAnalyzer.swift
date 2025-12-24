import Foundation
import Observation

@MainActor
@Observable
class DreamAnalyzer {
    static let shared = DreamAnalyzer()
    
    var currentAnalysis: DreamInsight?
    var isAnalyzing = false
    private let session: LanguageModelSession
    
    init() {
        self.session = LanguageModelSession(instructions: """
            You are an expert dream interpreter and data extractor.
            Your goal is to analyze dream transcripts to provide deep interpretation and extract structured data (people, places, emotions, symbols).
            """)
    }
    
    // 1. Analyze Meaning
    func analyze(transcript: String) async throws -> DreamInsight {
        isAnalyzing = true
        defer { isAnalyzing = false }
        
        let prompt = "Analyze this dream: \"\(transcript)\""
        
        // Using streamResponse from Guide.swift
        let stream = await session.streamResponse(to: prompt, generating: DreamInsight.self)
        
        var finalResult: DreamInsight?
        for try await partial in stream {
            self.currentAnalysis = partial
            finalResult = partial
        }
        
        return finalResult ?? DreamInsight()
    }
    
    // 2. Extract Entities
    func extractEntities(transcript: String, existingPeople: [String], existingPlaces: [String]) async throws -> DreamEntities {
        let prompt = """
        Extract people, places, emotions, and key symbols from: "\(transcript)"
        Context - Known People: \(existingPeople.joined(separator: ", "))
        Context - Known Places: \(existingPlaces.joined(separator: ", "))
        """
        
        let response = try await session.respond(to: prompt, generating: DreamEntities.self)
        return response.content
    }
    
    // 3. Art Prompt
    func generateArtPrompt(transcript: String) async throws -> ImagePrompt {
        let prompt = "Create a creative image prompt based on this dream: \"\(transcript)\""
        let response = try await session.respond(to: prompt, generating: ImagePrompt.self)
        return response.content
    }
    
    // 4. Insights
    func generateInsights(recentDreams: [Dream]) async throws -> [TherapeuticInsight] {
        guard !recentDreams.isEmpty else { return [] }
        let context = recentDreams.prefix(5).map { $0.smartSummary }.joined(separator: "\n")
        let prompt = "Identify psychological patterns in these dreams: \n\(context)"
        let response = try await session.respond(to: prompt, generating: [TherapeuticInsight].self)
        return response.content
    }
}
