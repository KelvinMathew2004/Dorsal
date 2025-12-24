import Foundation

// MARK: - FOUNDATION MODELS API SHIM
// Updated to handle Concurrency/Sendable requirements as requested.

@attached(member, names: arbitrary)
public macro Generable() = #externalMacro(module: "FoundationModelsMacros", type: "GenerableMacro")

@propertyWrapper
public struct Guide<T: Codable & Sendable>: Codable, Sendable {
    public var wrappedValue: T
    public var description: String
    public var constraints: [Constraint] = []
    
    public enum Constraint: Codable, Sendable {
        case range(ClosedRange<Int>)
        case possibleValues([String])
    }

    public init(wrappedValue: T, description: String, _ constraints: Constraint...) {
        self.wrappedValue = wrappedValue
        self.description = description
        self.constraints = constraints
    }
    
    // Support for string initialization
    public init(description: String, _ constraints: Constraint...) where T: ExpressibleByStringLiteral {
        self.wrappedValue = "" as! T
        self.description = description
        self.constraints = constraints
    }
    
    // Support for array initialization
    public init(description: String, _ constraints: Constraint...) where T: ExpressibleByArrayLiteral {
        self.wrappedValue = [] as! T
        self.description = description
        self.constraints = constraints
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.wrappedValue = try container.decode(T.self)
        self.description = ""
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(wrappedValue)
    }
}

public actor LanguageModelSession {
    private let instructions: String
    
    public init(instructions: String) {
        self.instructions = instructions
    }
    
    // Non-streaming response
    public func respond<T: Codable & Sendable>(to prompt: String, generating type: T.Type) async throws -> GenerationResponse<T> {
        let mock = try createMock(for: type, prompt: prompt)
        return GenerationResponse(content: mock)
    }
    
    // Streaming response
    public func streamResponse<T: Codable & Sendable>(to prompt: String, generating type: T.Type) -> AsyncThrowingStream<T, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    try await Task.sleep(nanoseconds: 500_000_000)
                    let mock = try createMock(for: type, prompt: prompt)
                    continuation.yield(mock)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    private func createMock<T: Codable & Sendable>(for type: T.Type, prompt: String = "") throws -> T {
        let typeString = String(describing: type)
        let lowerPrompt = prompt.lowercased()
        
        if typeString.contains("DreamInsight") {
            // Dynamic Mock Data based on keywords in the prompt
            if lowerPrompt.contains("swimming") || lowerPrompt.contains("underwater") {
                let json = """
                {
                    "summary": "A vivid dream about swimming deep underwater without gear, feeling a heavy anchor or clock.",
                    "interpretation": "Water often represents the subconscious. The ability to breathe suggests comfort with deep emotions, but the heavy object implies a burden or deadline you feel dragging you down.",
                    "actionableAdvice": "Consider what 'weight' you are carrying in waking life. Is there a deadline or emotional burden you can release?",
                    "emotion": "Reflective",
                    "tone": "Calm"
                }
                """
                return try JSONDecoder().decode(T.self, from: json.data(using: .utf8)!)
            } else if lowerPrompt.contains("school") || lowerPrompt.contains("presentation") {
                let json = """
                {
                    "summary": "Being back in a school setting to give a presentation, but encountering obstacles like wet notes and loose teeth.",
                    "interpretation": "A classic anxiety dream. School settings often represent social performance. Loose teeth typically symbolize a fear of powerlessness or losing face in public.",
                    "actionableAdvice": "Practice self-compassion. Remind yourself of your competence and that one mistake does not define you.",
                    "emotion": "Anxious",
                    "tone": "Tense"
                }
                """
                return try JSONDecoder().decode(T.self, from: json.data(using: .utf8)!)
            } else if lowerPrompt.contains("forest") || lowerPrompt.contains("chase") {
                 let json = """
                {
                    "summary": "Running through a dark forest with glass trees while being chased.",
                    "interpretation": "The forest represents the unknown. Glass trees suggest fragility—perhaps a situation in your life feels dangerous and easily broken. Being chased indicates avoidance of a confronting issue.",
                    "actionableAdvice": "Identify what you are running from. Facing the fear directly often diminishes its power.",
                    "emotion": "Fear",
                    "tone": "Urgent"
                }
                """
                return try JSONDecoder().decode(T.self, from: json.data(using: .utf8)!)
            } else {
                // Generic fallback
                let json = """
                {
                    "summary": "A complex dream sequence with varied imagery.",
                    "interpretation": "Your mind is processing recent events. The imagery suggests a mix of curiosity and uncertainty about the future.",
                    "actionableAdvice": "Keep a dream journal to spot recurring patterns over time.",
                    "emotion": "Neutral",
                    "tone": "Observational"
                }
                """
                return try JSONDecoder().decode(T.self, from: json.data(using: .utf8)!)
            }
        }
        else if typeString.contains("ImagePrompt") {
             let json = """
            {
                "visualDescription": "Surreal digital art of a grandfather clock sinking in a deep blue ocean, cinematic lighting, bubbles rising",
                "moodKeywords": "Mysterious, Deep, Blue",
                "colorPalette": "Dark Blue, Gold, Black"
            }
            """
            return try JSONDecoder().decode(T.self, from: json.data(using: .utf8)!)
        }
        else if typeString.contains("DreamEntities") {
             let json = """
            {
                "people": ["Mom", "Sarah"],
                "places": ["School", "Ocean"],
                "emotions": ["Fear", "Calm"],
                "keyEntities": ["Clock", "Anchor"]
            }
            """
            return try JSONDecoder().decode(T.self, from: json.data(using: .utf8)!)
        }
        else if typeString.contains("TherapeuticInsight") {
             let json = """
            [
                {
                    "title": "Recurring Water Theme",
                    "observation": "You dream of water often.",
                    "suggestion": "Consider what water means to you."
                }
            ]
            """
            // Note: If T is [TherapeuticInsight], we need to handle array decoding
            return try JSONDecoder().decode(T.self, from: json.data(using: .utf8)!)
        }
        
        throw NSError(domain: "FoundationModels", code: 404, userInfo: [NSLocalizedDescriptionKey: "Mock not found for type \(type)"])
    }
}

public struct GenerationResponse<T: Sendable>: Sendable {
    public let content: T
}
