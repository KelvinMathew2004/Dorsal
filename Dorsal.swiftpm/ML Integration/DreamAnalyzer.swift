import Foundation
import Observation
import FoundationModels
import SoundAnalysis
import CoreML
import AVFoundation

@Generable
struct RepairVoiceFatigue: Codable, Sendable {
    @Guide(description: "Voice fatigue score (0-100) based on tone.", .range(0...100))
    var voiceFatigue: Int
}

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
    
    func prewarmModel() {
        session.prewarm()
    }
    
    // MARK: - Streaming Analysis
    
    func streamCore(transcript: String, userName: String) -> AsyncThrowingStream<DreamCoreAnalysis.PartiallyGenerated, Error> {
        let prompt = "Analyze this transcript of a dream. Transcript: \"\(transcript)\""
        
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
    
    // MARK: - CUSTOM COREML FATIGUE MODEL (Window Averaging)
    
    func analyzeVocalFatigue(audioURL: URL) async throws -> Int {
        // Create the delegate helper which is NOT on the MainActor
        let delegate = FatigueDelegate()
        
        return try await withCheckedThrowingContinuation { continuation in
            delegate.continuation = continuation
            
            do {
                // MANUAL LOADING: Load the compiled .mlmodelc directly from the bundle
                guard let modelURL = Bundle.main.url(forResource: "VocalFatigueModel", withExtension: "mlmodelc") else {
                    throw NSError(domain: "DreamAnalyzer", code: 404, userInfo: [NSLocalizedDescriptionKey: "VocalFatigueModel.mlmodelc not found in bundle. Make sure it is added to your project resources."])
                }
                
                let config = MLModelConfiguration()
                let model = try MLModel(contentsOf: modelURL, configuration: config)
                
                let request = try SNClassifySoundRequest(mlModel: model)
                // request.overlapFactor defaults to 0.5, meaning windows overlap by 50%
                // This is good for smoothing out the average.
                
                let analyzer = try SNAudioFileAnalyzer(url: audioURL)
                
                try analyzer.add(request, withObserver: delegate)
                
                // Run analysis.
                try analyzer.analyze()
                
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    // MARK: - FALLBACK: TEXT-BASED FATIGUE
    // This is the replacement function you requested
    func estimateFallbackFatigue(transcript: String) async -> Int {
        do {
            let res = try await session.respond(
                to: "Estimate a voice fatigue score (0-100) based purely on the exhaustion level described in this text: \"\(transcript)\"",
                generating: RepairVoiceFatigue.self
            )
            return res.content.voiceFatigue
        } catch {
            print("Fallback fatigue estimation failed: \(error)")
            return 0 // Default to 0 if even the LLM fails
        }
    }
    
    // MARK: - Internal Helper Class (Non-Isolated)
    // Handles accumulation and averaging of scores
    private class FatigueDelegate: NSObject, SNResultsObserving {
        var continuation: CheckedContinuation<Int, Error>?
        var scores: [Double] = [] // Store confidence scores for every window
        
        func request(_ request: SNRequest, didProduce result: SNResult) {
            guard let result = result as? SNClassificationResult else { return }
            
            // Logic to extract "Fatigued" confidence from this specific window
            // Note: Labels are Case Sensitive based on your training data
            let fatiguedClass = result.classifications.first(where: { $0.identifier.lowercased() == "fatigued" })
            let healthyClass = result.classifications.first(where: { $0.identifier.lowercased() == "healthy" })
            
            var windowScore: Double = 0.0
            
            if let fScore = fatiguedClass?.confidence {
                // If "Fatigued" label exists, use its confidence directly
                windowScore = fScore
            } else if let hScore = healthyClass?.confidence {
                // If only "Healthy" exists, Fatigue is the inverse
                windowScore = 1.0 - hScore
            } else if let top = result.classifications.first {
                // Fallback: Check top classification
                if top.identifier.lowercased().contains("fatigue") {
                    windowScore = top.confidence
                } else {
                    windowScore = 1.0 - top.confidence
                }
            }
            
            // Add this window's score to our collection
            scores.append(windowScore)
        }
        
        func request(_ request: SNRequest, didFailWithError error: Error) {
            continuation?.resume(throwing: error)
            continuation = nil
        }
        
        func requestDidComplete(_ request: SNRequest) {
            // Once the entire file is processed, calculate the average
            if let cont = continuation {
                if scores.isEmpty {
                    cont.resume(returning: 0)
                } else {
                    let total = scores.reduce(0, +)
                    let average = total / Double(scores.count)
                    
                    // Return the averaged percentage
                    cont.resume(returning: Int(average * 100))
                }
                continuation = nil // Ensure we only resume once
            }
        }
    }
    
    // MARK: - Extras & Legacy
    
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
        
        let prompt = "Review these dream summaries and generate a holistic insight report:\n\(dreamSummaries)"
        
        var response = try await session.respond(
            to: prompt,
            generating: WeeklyInsightResult.self,
            options: GenerationOptions(temperature: 0.5)
        ).content
        
        response = await ensureWeeklyInsights(current: response, context: dreamSummaries)
        
        return response
    }
        
    func DreamQuestion(transcript: String, analysis: String, question: String) async throws -> String {
        let prompt = """
        Use the provided transcript and analysis context to answer the user's question in short paragraphs and concise pointers.
        
        Transcript:
        "\(transcript)"
        
        Analysis Context:
        "\(analysis)"
        
        User Question:
        "\(question)"
        """
        
        let response = try await session.respond(to: prompt)
        return response.content
    }
    
    func DreamsQuestion(summaries: String, analysis: String, question: String) async throws -> String {
        let prompt = """
        Answer the User Question by synthesizing this information. Connect the specific dream events (from the summaries) to the broader trends (from the analysis) where relevant. Keep the response concise (under 150 words) unless the question requires deep detail.
        
        ---
        Weekly Dream Summaries:
        \(summaries)
        
        Weekly Analysis (Context):
        \(analysis)
        ---
        
        User Question:
        "\(question)"
        """
        
        let response = try await session.respond(to: prompt)
        return response.content
    }
    
    // MARK: - Trend Analysis & Coaching
    
    func GenerateCoachingTip(metric: String, description: String, statsContext: String, trendStatus: String) async throws -> String {
        let prompt = """
        You are a sleep coach analyzing the user's "\(metric)" trend.
        
        About this metric:
        \(description)
        
        Data Context (Timeframe & Data Points):
        \(statsContext)
        
        Current Trend Status: \(trendStatus)
        
        Task:
        Based strictly on the provided data points and trend status, provide a single, short (1-2 sentences) insight or tip.
        - If the data/status is concerning (e.g. High Anxiety, Nightmares), offer a calming, actionable tip to improve.
        - If the data/status is positive, offer reinforcement to maintain it.
        - Reference the specific data trend (e.g., "Since your anxiety spiked on Tuesday...") if relevant.
        """
        let response = try await session.respond(to: prompt)
        return response.content
    }
    
    func TrendQuestion(metric: String, statsContext: String, trendStatus: String, question: String) async throws -> String {
        let prompt = """
        Context:
        Metric: \(metric)
        Data Points:
        \(statsContext)
        Current Status: \(trendStatus)
        
        User Question:
        "\(question)"
        
        Answer concisely (max 100 words) using the provided data context.
        """
        let response = try await session.respond(to: prompt)
        return response.content
    }
}
