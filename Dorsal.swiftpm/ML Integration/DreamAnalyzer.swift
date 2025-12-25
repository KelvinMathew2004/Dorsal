import Foundation
import Observation
import FoundationModels // Assuming the framework is available

// MARK: - DREAM ANALYZER SERVICE

@MainActor
@Observable
class DreamAnalyzer {
    static let shared = DreamAnalyzer()
    
    private let session: LanguageModelSession
    
    init() {
        self.session = LanguageModelSession(instructions: """
            You are a compassionate, insightful Dream Psychologist and Art Director.
            
            Roles:
            1. Individual Analysis: Interpret specific dreams, identifying emotions and symbols.
            2. Aggregate Analysis: Look at a collection of dreams to identify trends, mental health shifts, and sleep quality patterns over time.
            
            Tone: Safe, non-judgmental, wise, and encouraging.
            """)
    }
    
    // MARK: - Individual Analysis
    func analyze(transcript: String) async throws -> DreamAnalysisResult {
        let prompt = "Analyze this dream transcript: \"\(transcript)\""
        
        // Use standard response to ensure we get the full, type-safe struct.
        // Streaming would require handling Partial/Snapshot types which requires mapping.
        let response = try await session.respond(to: prompt, generating: DreamAnalysisResult.self)
        
        // The response object contains the generated content
        return response.content
    }
    
    // MARK: - Aggregate Analysis
    func analyzeWeeklyTrends(dreams: [Dream]) async throws -> WeeklyInsightResult {
        // Construct a summary prompt to save context window
        let dreamSummaries = dreams.prefix(20).map { dream in
            let emotionsList = dream.analysis.emotions.joined(separator: ", ")
            return "- \(dream.date.formatted(date: .abbreviated, time: .omitted)): \(dream.analysis.summary) (Emotions: \(emotionsList))"
        }.joined(separator: "\n")
        
        let prompt = """
        Review the following dream summaries and generate a holistic insight report:
        
        \(dreamSummaries)
        """
        
        let response = try await session.respond(to: prompt, generating: WeeklyInsightResult.self)
        
        return response.content
    }
}
