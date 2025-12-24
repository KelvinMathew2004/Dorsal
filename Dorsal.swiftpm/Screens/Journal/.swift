import Foundation

// MARK: - DREAM ANALYZER (FOUNDATION MODELS INTEGRATION)
@MainActor
class DreamAnalyzer {
    static let shared = DreamAnalyzer()
    
    private let session: LanguageModelSession
    
    init() {
        // Initialize Session with System Instructions as per the article
        self.session = LanguageModelSession {
            """
            You are an expert dream psychologist and art director.
            Your goal is to analyze dream transcripts to provide deep, meaningful interpretations.
            You also generate specific artistic prompts for image generation.
            """
        }
    }
    
    // 1. Structured Analysis using Guided Generation
    func analyze(transcript: String) async throws -> DreamAnalysis {
        let prompt = "Analyze the following dream transcript: \"\(transcript)\""
        
        let response = try await session.respond(to: prompt, generating: DreamAnalysis.self)
        return response.content
    }
    
    // 2. Image Prompt Generation
    func generateArtPrompt(transcript: String) async throws -> ImagePrompt {
        let prompt = "Create a vivid, short art prompt for an illustration based on this dream: \"\(transcript)\""
        
        let response = try await session.respond(to: prompt, generating: ImagePrompt.self)
        return response.content
    }
    
    // 3. Batch Insights Generation
    func generateInsights(recentDreams: [Dream]) async throws -> [TherapeuticInsight] {
        guard !recentDreams.isEmpty else { return [] }
        
        // Provide context from recent dreams
        let context = recentDreams.prefix(5).map { $0.smartSummary }.joined(separator: "\n")
        let prompt = "Based on these recent dreams, identify key psychological patterns: \n\(context)"
        
        // Request structured array response
        let response = try await session.respond(to: prompt, generating: [TherapeuticInsight].self)
        return response.content
    }
}
