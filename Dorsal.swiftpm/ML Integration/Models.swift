import Foundation
import SwiftUI
import FoundationModels
import ImagePlayground
import SwiftData

// MARK: - ERRORS
enum DreamError: Error, LocalizedError {
    case safetyViolation
    case refusal(String)
    case tooLong
    case modelDownloading
    case unsupportedLanguage
    case formatError
    case systemBusy
    case internalError
    
    // Image Generation Errors
    case imageNotSupported
    case imageUnavailable
    case imageInputInvalid
    case backgroundExecutionForbidden
    case imageGenerationFailed
    case personIdentityRequired

    var errorDescription: String? {
        switch self {
        case .safetyViolation: return "Content flagged by safety filters."
        case .refusal(let r): return "Model refused: \(r)"
        case .tooLong: return "The dream is too long for the model to process."
        case .modelDownloading: return "Apple Intelligence is still downloading assets."
        case .unsupportedLanguage: return "This language is not supported for on-device AI."
        case .formatError: return "Failed to process the model output."
        case .systemBusy: return "System is busy with other AI tasks. Try again in a moment."
        case .internalError: return "Internal Foundation Model error."
            
        case .imageNotSupported: return "Image creation is not supported on this device."
        case .imageUnavailable: return "Image creation services are currently unavailable."
        case .imageInputInvalid: return "The input provided for image generation was invalid."
        case .backgroundExecutionForbidden: return "Image generation stopped because the app was in the background."
        case .imageGenerationFailed: return "Failed to generate visual representation."
        case .personIdentityRequired: return "Prompt contains a specific person that requires identity verification."
        }
    }
}

// MARK: - TIER 1: CORE ANALYSIS
@Generable
struct DreamCoreAnalysis: Codable, Sendable, Hashable {
    @Guide(description: "A short title of 4 words or fewer.")
    var title: String?
    
    @Guide(description: "A 1-2 sentence summary of the dream's narrative flow.")
    var summary: String?

    @Guide(description: "List of people or characters. Use single-word base nouns only. No descriptors or modifiers.")
    var people: [String]?

    @Guide(description: "List of locations or settings. You MUST use single-word base location nouns only. No descriptors or modifiers.")
    var places: [String]?
    
    @Guide(description: "The primary emotion felt.")
    var emotion: String?

    @Guide(description: "List of distinct emotions felt. Emotions only.")
    var emotions: [String]?

    @Guide(description: "List of symbols. Single-word object, animal, or phenomenon nouns only. Do NOT include people, places, emotions.")
    var symbols: [String]?
    
    @Guide(description: "A deep, empathetic psychological interpretation.")
    var interpretation: String?
    
    @Guide(description: "Actionable advice based on the dream's themes.")
    var actionableAdvice: String?
    
    @Guide(description: "Voice fatigue (0-100).", .range(0...100))
    var voiceFatigue: Int?
    
    var tone: ToneAnalysis?
}

// MARK: - TIER 2: EXTRA ANALYSIS
@Generable
struct DreamExtraAnalysis: Codable, Sendable, Hashable {
    @Guide(description: "Sentiment score (0-100).", .range(0...100))
    var sentimentScore: Int?
    
    @Guide(description: "Is this a nightmare?")
    var isNightmare: Bool?
    
    @Guide(description: "Lucidity score (0-100).", .range(0...100))
    var lucidityScore: Int?
    
    @Guide(description: "Vividness score (0-100).", .range(0...100))
    var vividnessScore: Int?
    
    @Guide(description: "Coherence score (0-100).", .range(0...100))
    var coherenceScore: Int?
    
    @Guide(description: "Anxiety level (0-100).", .range(0...100))
    var anxietyLevel: Int?
}

@Generable
struct ToneAnalysis: Codable, Sendable, Hashable {
    @Guide(description: "Tone label. Single word.")
    var label: String?
    
    @Guide(description: "Confidence score for tone detection.", .range(0...100))
    var confidence: Int?
}

@Generable
struct WeeklyInsightResult: Codable, Sendable, Hashable {
    @Guide(description: "High-level overview of all dreams.")
    var periodOverview: String?
    
    @Guide(description: "Dominant theme. 1–3 words.")
    var dominantTheme: String?
    
    @Guide(description: "One short sentence describing the overall mental health trend.")
    var mentalHealthTrend: String?
    var strategicAdvice: String?
}

// MARK: - REPAIR WRAPPERS (Single Field Generation)
@Generable
struct RepairTitle: Codable, Sendable {
    @Guide(description: "A short title of 4 words or fewer.")
    var title: String
}

@Generable
struct RepairSummary: Codable, Sendable {
    @Guide(description: "A 1-2 sentence summary of the dream's narrative flow.")
    var summary: String
}

@Generable
struct RepairVoiceFatigue: Codable, Sendable {
    @Guide(description: "Voice fatigue (0-100).", .range(0...100))
    var voiceFatigue: Int
}

@Generable
struct RepairTone: Codable, Sendable {
    var tone: ToneAnalysis
}

@Generable
struct RepairInterpretation: Codable, Sendable {
    @Guide(description: "A deep, empathetic psychological interpretation.")
    var interpretation: String
}

@Generable
struct RepairAdvice: Codable, Sendable {
    @Guide(description: "Actionable advice based on the dream's themes.")
    var actionableAdvice: String
}

@Generable
struct RepairSentiment: Codable, Sendable {
    @Guide(description: "Sentiment score (0-100).", .range(0...100))
    var sentimentScore: Int
}

@Generable
struct RepairNightmare: Codable, Sendable {
    @Guide(description: "Is this a nightmare?")
    var isNightmare: Bool
}

@Generable
struct RepairLucidity: Codable, Sendable {
    @Guide(description: "Lucidity score (0-100).", .range(0...100))
    var lucidityScore: Int
}

@Generable
struct RepairVividness: Codable, Sendable {
    @Guide(description: "Vividness score (0-100).", .range(0...100))
    var vividnessScore: Int
}

@Generable
struct RepairCoherence: Codable, Sendable {
    @Guide(description: "Coherence score (0-100).", .range(0...100))
    var coherenceScore: Int
}

@Generable
struct RepairAnxiety: Codable, Sendable {
    @Guide(description: "Anxiety level (0-100).", .range(0...100))
    var anxietyLevel: Int
}

// Weekly Insight Repairs
@Generable
struct RepairPeriodOverview: Codable, Sendable {
    var periodOverview: String
}

@Generable
struct RepairDominantTheme: Codable, Sendable {
    var dominantTheme: String
}

@Generable
struct RepairMentalHealthTrend: Codable, Sendable {
    var mentalHealthTrend: String
}

@Generable
struct RepairStrategicAdvice: Codable, Sendable {
    var strategicAdvice: String
}


// MARK: - APP DOMAIN MODEL
struct Dream: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let date: Date
    let rawTranscript: String
    
    var core: DreamCoreAnalysis?
    var extras: DreamExtraAnalysis?
    var generatedImageData: Data?
    
    var analysisError: String?
    
    // Legacy Helpers
    var smartSummary: String { core?.summary ?? "Processing..." }
    var interpretation: String { core?.interpretation ?? "Generating analysis..." }
    var actionableAdvice: String { core?.actionableAdvice ?? "" }
    var tone: String { core?.tone?.label ?? "Neutral" }
    
    var people: [String] { core?.people ?? [] }
    var places: [String] { core?.places ?? [] }
    var emotions: [String] {
        var all = core?.emotions ?? []
        if let primary = core?.emotion, !all.contains(primary) {
            all.insert(primary, at: 0)
        }
        return all
    }
    var keyEntities: [String] { core?.symbols ?? [] }
    
    var analysis: DreamAnalysisResult {
        DreamAnalysisResult(
            title: core?.title ?? "New Dream",
            summary: core?.summary ?? "",
            interpretation: core?.interpretation ?? "",
            actionableAdvice: core?.actionableAdvice ?? "",
            people: core?.people ?? [],
            places: core?.places ?? [],
            emotions: emotions,
            symbols: core?.symbols ?? [],
            tone: core?.tone ?? ToneAnalysis(label: "Neutral", confidence: 0),
            voiceFatigue: core?.voiceFatigue ?? 0,
            sentimentScore: extras?.sentimentScore ?? 50,
            lucidityScore: extras?.lucidityScore ?? 0,
            vividnessScore: extras?.vividnessScore ?? 0,
            anxietyLevel: extras?.anxietyLevel ?? 0,
            coherenceScore: extras?.coherenceScore ?? 0,
            isNightmare: extras?.isNightmare ?? false,
            imagePrompt: core?.summary ?? ""
        )
    }
    
    init(
        id: UUID = UUID(),
        date: Date = Date(),
        rawTranscript: String,
        core: DreamCoreAnalysis? = nil,
        extras: DreamExtraAnalysis? = nil,
        generatedImageData: Data? = nil,
        analysisError: String? = nil
    ) {
        self.id = id
        self.date = date
        self.rawTranscript = rawTranscript
        self.core = core
        self.extras = extras
        self.generatedImageData = generatedImageData
        self.analysisError = analysisError
    }
    
    // Init from SavedDream (SwiftData)
    init(from saved: SavedDream) {
        self.id = saved.id
        self.date = saved.date
        self.rawTranscript = saved.rawText
        self.generatedImageData = saved.generatedImageData
        
        // Reconstruct Core Analysis from flat properties
        self.core = DreamCoreAnalysis(
            title: saved.title,
            summary: saved.summary,
            people: saved.people,
            places: saved.places,
            emotion: saved.emotions.first,
            emotions: saved.emotions,
            symbols: saved.symbols,
            interpretation: saved.interpretation,
            actionableAdvice: saved.actionableAdvice,
            voiceFatigue: saved.voiceFatigue,
            tone: ToneAnalysis(label: saved.toneLabel, confidence: saved.toneConfidence)
        )
        
        // Reconstruct Extra Analysis from flat properties
        self.extras = DreamExtraAnalysis(
            sentimentScore: saved.sentimentScore,
            isNightmare: saved.isNightmare,
            lucidityScore: saved.lucidityScore,
            vividnessScore: saved.vividnessScore,
            coherenceScore: saved.coherenceScore,
            anxietyLevel: saved.anxietyLevel
        )
        self.analysisError = nil
    }
}

// Helper Struct
struct DreamAnalysisResult: Hashable, Codable, Sendable {
    var title: String
    var summary: String
    var interpretation: String
    var actionableAdvice: String
    var people: [String]
    var places: [String]
    var emotions: [String]
    var symbols: [String]
    var tone: ToneAnalysis
    var voiceFatigue: Int
    var sentimentScore: Int
    var lucidityScore: Int
    var vividnessScore: Int
    var anxietyLevel: Int
    var coherenceScore: Int
    var isNightmare: Bool
    var imagePrompt: String
}
