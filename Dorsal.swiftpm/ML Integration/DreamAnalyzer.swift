import Foundation
import Observation
import FoundationModels

@MainActor
@Observable
class DreamAnalyzer {
    static let shared = DreamAnalyzer()
    private let session: LanguageModelSession
    
    init() {
        self.session = LanguageModelSession(instructions: """
            You are a compassionate, insightful Dream Psychologist.
            Analyze dreams with empathy. Identify key symbols, emotions, and themes.
            """)
    }
    
    // MARK: - Streaming Analysis
    
    // Stage 1: Core
    func streamCore(transcript: String) -> AsyncThrowingStream<DreamCoreAnalysis.PartiallyGenerated, Error> {
        let prompt = """
        Analyze this transcript. 
        Provide a concise title, summary, primary emotion, people, places, emotions, symbols, interpretation, advice, fatigue, and tone.
        Transcript: "\(transcript)"
        """
        
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    let stream = session.streamResponse(to: prompt, generating: DreamCoreAnalysis.self)
                    for try await snapshot in stream {
                        // Fix: Check if content exists directly without optional binding if it's already non-optional
                        // However, API usually returns optional content in snapshot.
                        // If compiler complains "Initializer for conditional binding must have Optional type",
                        // it means snapshot.content is NON-OPTIONAL.
                        // So we just yield it directly.
                        continuation.yield(snapshot.content)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    // Stage 2: Extras
    func streamExtras(transcript: String) -> AsyncThrowingStream<DreamExtraAnalysis.PartiallyGenerated, Error> {
        let prompt = """
        Analyze the remaining metrics: Sentiment, Nightmare status, Lucidity, Vividness, Coherence, and Anxiety.
        Transcript: "\(transcript)"
        """
        
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    let stream = session.streamResponse(to: prompt, generating: DreamExtraAnalysis.self)
                    for try await snapshot in stream {
                        // Same fix: Yield directly if non-optional
                        continuation.yield(snapshot.content)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    // Weekly Insights
    func analyzeWeeklyTrends(dreams: [Dream]) async throws -> WeeklyInsightResult {
        let dreamSummaries = dreams.prefix(20).map { dream in
            let emo = dream.core?.primaryEmotion ?? ""
            return "- \(dream.date.formatted(date: .abbreviated, time: .omitted)): \(dream.core?.summary ?? "") (Emotion: \(emo))"
        }.joined(separator: "\n")
        
        let prompt = "Review these dreams and generate a holistic insight report:\n\(dreamSummaries)"
        
        let response = try await session.respond(to: prompt, generating: WeeklyInsightResult.self)
        return response.content
    }
}
