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
    
    func prewarm() async {
        session.prewarm()
    }
    
    // MARK: - Streaming Analysis
    
    func streamCore(transcript: String) -> AsyncThrowingStream<DreamCoreAnalysis.PartiallyGenerated, Error> {
        let prompt = "Analyze this transcript. Transcript: \"\(transcript)\""
        
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    let stream = session.streamResponse(
                        to: prompt,
                        generating: DreamCoreAnalysis.self,
                        options: GenerationOptions(temperature: 0.5)
                    )
                    
                    for try await snapshot in stream {
                        continuation.yield(snapshot.content)
                    }
                    continuation.finish()
                } catch let error as LanguageModelSession.GenerationError {
                    switch error {
                    case .guardrailViolation:
                        continuation.finish(throwing: DreamError.safetyViolation)
                        
                    case .refusal(let refusal, _):
                        Task {
                            do {
                                let reason = try await self.extractRefusalReason(from: refusal)
                                continuation.finish(throwing: DreamError.refusal(reason))
                            } catch {
                                continuation.finish(throwing: DreamError.refusal("Policy restriction"))
                            }
                        }
                        
                    case .exceededContextWindowSize:
                        continuation.finish(throwing: DreamError.tooLong)
                        
                    case .assetsUnavailable:
                        continuation.finish(throwing: DreamError.modelDownloading)
                        
                    case .unsupportedLanguageOrLocale:
                        continuation.finish(throwing: DreamError.unsupportedLanguage)
                        
                    case .decodingFailure:
                        continuation.finish(throwing: DreamError.formatError)
                        
                    case .rateLimited, .concurrentRequests:
                        continuation.finish(throwing: DreamError.systemBusy)
                        
                    case .unsupportedGuide:
                        continuation.finish(throwing: DreamError.internalError)
                        
                    @unknown default:
                        continuation.finish(throwing: error)
                    }
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    private nonisolated func extractRefusalReason(from refusal: LanguageModelSession.GenerationError.Refusal) async throws -> String {
        let response = try await refusal.explanation
        return response.content
    }
    
    func streamExtras(transcript: String) -> AsyncThrowingStream<DreamExtraAnalysis.PartiallyGenerated, Error> {
        let prompt = """
        Analyze the remaining metrics based on the transcript: "\(transcript)"
        """
        
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    let stream = session.streamResponse(
                        to: prompt,
                        generating: DreamExtraAnalysis.self,
                        options: GenerationOptions(temperature: 0.5)
                    )
                    
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
        
        let response = try await session.respond(
            to: prompt,
            generating: WeeklyInsightResult.self,
            options: GenerationOptions(temperature: 0.5)
        )
        return response.content
    }
}
