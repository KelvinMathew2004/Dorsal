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
            You MUST respond in U.S. English.
            """)
    }
    
    // Add Pre-warming to load model into memory early
    func prewarm() async {
        session.prewarm()
    }
    
    // MARK: - Streaming Analysis
    
    // Stage 1: Core
    func streamCore(transcript: String) -> AsyncThrowingStream<DreamCoreAnalysis.PartiallyGenerated, Error> {
        let prompt = """
        Analyze this transcript. 
        Transcript: "\(transcript)"
        """
        
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    let stream = session.streamResponse(to: prompt, generating: DreamCoreAnalysis.self)
                    for try await snapshot in stream {
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
        Analyze the remaining metrics based on the transcript: "\(transcript)"
        """
        
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    let stream = session.streamResponse(to: prompt, generating: DreamExtraAnalysis.self)
                    for try await snapshot in stream {
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
            let emo = dream.core?.emotion ?? ""
            return "- \(dream.date.formatted(date: .abbreviated, time: .omitted)): \(dream.core?.summary ?? "") (Emotion: \(emo))"
        }.joined(separator: "\n")
        
        let prompt = "Review these dreams and generate a holistic insight report:\n\(dreamSummaries)"
        
        let response = try await session.respond(to: prompt, generating: WeeklyInsightResult.self)
        return response.content
    }
}
