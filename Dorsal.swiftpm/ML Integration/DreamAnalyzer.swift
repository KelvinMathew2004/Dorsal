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
        // Passed string directly to avoid closure Sendability issues
        self.session = LanguageModelSession(instructions: """
            You are an expert dream interpreter with deep knowledge of Jungian archetypes.
            Analyze the user's dream description and provide a structured interpretation.
            """)
    }
    
    func analyze(transcript: String) async throws -> DreamInsight {
        isAnalyzing = true
        defer { isAnalyzing = false }
        
        let prompt = "Analyze this dream: \"\(transcript)\""
        
        // Await the actor call. Since DreamInsight is Sendable (Codable struct), this is safe.
        let stream = await session.streamResponse(to: prompt, generating: DreamInsight.self)
        
        var finalResult: DreamInsight?
        
        for try await partial in stream {
            self.currentAnalysis = partial
            finalResult = partial
        }
        
        guard let result = finalResult else {
            throw NSError(domain: "DreamAnalyzer", code: 500, userInfo: [NSLocalizedDescriptionKey: "No analysis generated"])
        }
        
        return result
    }
    
    func generateArtPrompt(transcript: String) async throws -> ImagePrompt {
        let prompt = "Create a creative image prompt based on this dream: \"\(transcript)\""
        let response = try await session.respond(to: prompt, generating: ImagePrompt.self)
        return response.content
    }
    
    func generateInsights(recentDreams: [Dream]) async throws -> [TherapeuticInsight] {
        return []
    }
}

// Ensure this is Sendable
struct TherapeuticInsight: Identifiable, Codable, Sendable {
    var id = UUID()
    var title: String
    var description: String
}
