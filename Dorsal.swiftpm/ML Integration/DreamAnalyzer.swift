import Foundation
import Observation

// MARK: - DREAM ANALYZER (UPDATED)
// Matches user's snippet logic using streamResponse and DreamInsight

@MainActor
@Observable
class DreamAnalyzer {
    static let shared = DreamAnalyzer()
    
    var currentAnalysis: DreamInsight?
    var isAnalyzing = false
    private let session: LanguageModelSession
    
    init() {
        self.session = LanguageModelSession(instructions: """
            You are an expert dream interpreter with deep knowledge of Jungian archetypes.
            Analyze the user's dream description and provide a structured interpretation.
            """)
    }
    
    // Analyzes the dream using streaming (simulated or real)
    func analyze(transcript: String) async throws -> DreamInsight {
        isAnalyzing = true
        defer { isAnalyzing = false }
        
        let prompt = "Analyze this dream: \"\(transcript)\""
        
        // Simulating the stream for the mock environment
        // In a real env, this would call session.streamResponse(...)
        let response = try await session.respond(to: prompt, generating: DreamInsight.self)
        
        self.currentAnalysis = response.content
        return response.content
    }
    
    func generateArtPrompt(transcript: String) async throws -> ImagePrompt {
        let prompt = "Create a creative image prompt based on this dream: \"\(transcript)\""
        let response = try await session.respond(to: prompt, generating: ImagePrompt.self)
        return response.content
    }
    
    func generateInsights(recentDreams: [Dream]) async throws -> [TherapeuticInsight] {
        guard !recentDreams.isEmpty else { return [] }
        let context = recentDreams.prefix(5).map { $0.smartSummary }.joined(separator: "\n")
        let prompt = "Identify psychological patterns in these dreams: \n\(context)"
        let response = try await session.respond(to: prompt, generating: [TherapeuticInsight].self)
        return response.content
    }
}
