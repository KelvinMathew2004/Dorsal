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
    
    func streamCore(transcript: String, userName: String) -> AsyncThrowingStream<DreamCoreAnalysis.PartiallyGenerated, Error> {
        let prompt = "Analyze this transcript of \(userName)'s dream. Transcript: \"\(transcript)\""
        
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
        
    func ensureCoreFields(current: DreamCoreAnalysis, transcript: String) async -> DreamCoreAnalysis {
        var updated = current
        
        do {
            if updated.title == nil {
                let res = try await session.respond(to: "Generate a short title (4 words max) for: \"\(transcript)\"", generating: RepairTitle.self)
                updated.title = res.content.title
            }
            if updated.summary == nil {
                let res = try await session.respond(to: "Summarize this dream in 1-2 sentences: \"\(transcript)\"", generating: RepairSummary.self)
                updated.summary = res.content.summary
            }
            if updated.interpretation == nil {
                let res = try await session.respond(to: "Provide a psychological interpretation for: \"\(transcript)\"", generating: RepairInterpretation.self)
                updated.interpretation = res.content.interpretation
            }
            if updated.actionableAdvice == nil {
                let res = try await session.respond(to: "Provide actionable advice for: \"\(transcript)\"", generating: RepairAdvice.self)
                updated.actionableAdvice = res.content.actionableAdvice
            }
            
            if updated.tone == nil {
                let res = try await session.respond(to: "Determine the tone of this dream: \"\(transcript)\"", generating: RepairTone.self)
                updated.tone = res.content.tone
            }
            if updated.voiceFatigue == nil {
                let res = try await session.respond(to: "Estimate voice fatigue (0-100) for: \"\(transcript)\"", generating: RepairVoiceFatigue.self)
                updated.voiceFatigue = res.content.voiceFatigue
            }
            
        } catch {
            print("Repair Core Error: \(error)")
        }
        return updated
    }
    
    func ensureExtraFields(current: DreamExtraAnalysis, transcript: String) async -> DreamExtraAnalysis {
        var updated = current
        
        do {
            if updated.sentimentScore == nil {
                let res = try await session.respond(to: "Determine sentiment score (0-100) for: \"\(transcript)\"", generating: RepairSentiment.self)
                updated.sentimentScore = res.content.sentimentScore
            }
            if updated.anxietyLevel == nil {
                let res = try await session.respond(to: "Determine anxiety level (0-100) for: \"\(transcript)\"", generating: RepairAnxiety.self)
                updated.anxietyLevel = res.content.anxietyLevel
            }
            if updated.isNightmare == nil {
                let res = try await session.respond(to: "Is this a nightmare? \"\(transcript)\"", generating: RepairNightmare.self)
                updated.isNightmare = res.content.isNightmare
            }
            if updated.lucidityScore == nil {
                let res = try await session.respond(to: "Determine lucidity score (0-100) for: \"\(transcript)\"", generating: RepairLucidity.self)
                updated.lucidityScore = res.content.lucidityScore
            }
            if updated.vividnessScore == nil {
                let res = try await session.respond(to: "Determine vividness score (0-100) for: \"\(transcript)\"", generating: RepairVividness.self)
                updated.vividnessScore = res.content.vividnessScore
            }
            if updated.coherenceScore == nil {
                let res = try await session.respond(to: "Determine coherence score (0-100) for: \"\(transcript)\"", generating: RepairCoherence.self)
                updated.coherenceScore = res.content.coherenceScore
            }
        } catch {
            print("Repair Extras Error: \(error)")
        }
        return updated
    }

    func ensureWeeklyInsights(current: WeeklyInsightResult, context: String) async -> WeeklyInsightResult {
        var updated = current
        do {
            if updated.periodOverview == nil {
                let res = try await session.respond(to: "Generate a period overview for these dreams:\n\(context)", generating: RepairPeriodOverview.self)
                updated.periodOverview = res.content.periodOverview
            }
            if updated.dominantTheme == nil {
                let res = try await session.respond(to: "Identify the dominant theme for these dreams:\n\(context)", generating: RepairDominantTheme.self)
                updated.dominantTheme = res.content.dominantTheme
            }
            if updated.mentalHealthTrend == nil {
                let res = try await session.respond(to: "Analyze the mental health trend for these dreams:\n\(context)", generating: RepairMentalHealthTrend.self)
                updated.mentalHealthTrend = res.content.mentalHealthTrend
            }
            if updated.strategicAdvice == nil {
                let res = try await session.respond(to: "Provide strategic advice based on these dreams:\n\(context)", generating: RepairStrategicAdvice.self)
                updated.strategicAdvice = res.content.strategicAdvice
            }
        } catch {
            print("Repair Insights Error: \(error)")
        }
        return updated
    }
    
    // MARK: - Weekly Insights
    
    func analyzeWeeklyTrends(dreams: [Dream], userName: String) async throws -> WeeklyInsightResult {
        let validDreams = dreams.filter {
            if let summary = $0.core?.summary, !summary.isEmpty {
                return true
            }
            return false
        }
        
        let dreamSummaries = validDreams.prefix(20).map { dream in
            let summary = dream.core?.summary ?? "No summary available"
            let emo = dream.core?.emotion ?? "Unknown"
            return "- \(dream.date.formatted(date: .abbreviated, time: .omitted)): \(summary) (Emotion: \(emo))"
        }.joined(separator: "\n")
        
        let prompt = "Review these dream summaries for \(userName) and generate a holistic insight report:\n\(dreamSummaries)"
        
        var response = try await session.respond(
            to: prompt,
            generating: WeeklyInsightResult.self,
            options: GenerationOptions(temperature: 0.5)
        ).content
        
        response = await ensureWeeklyInsights(current: response, context: dreamSummaries)
        
        return response
    }
}
