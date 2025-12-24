import Foundation

// MARK: - FOUNDATION MODELS API SHIM
// Updated to handle Concurrency/Sendable requirements

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
        // Ensure T is decoded as T.self.
        // Codable includes Decodable, so this should satisfy the requirement.
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
        let mock = try createMock(for: type)
        return GenerationResponse(content: mock)
    }
    
    // Streaming response
    public func streamResponse<T: Codable & Sendable>(to prompt: String, generating type: T.Type) -> AsyncThrowingStream<T, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    try await Task.sleep(nanoseconds: 500_000_000)
                    let mock = try createMock(for: type)
                    continuation.yield(mock)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    private func createMock<T: Codable & Sendable>(for type: T.Type) throws -> T {
        let typeString = String(describing: type)
        
        if typeString.contains("DreamInsight") {
            let json = """
            {
                "title": "The Underwater Clock",
                "summary": "A dream about deep water and time pressure.",
                "interpretation": "This dream symbolizes a fear of running out of time while feeling overwhelmed by emotions (water). The clock represents societal pressure.",
                "actionableAdvice": "Try to schedule 'worry time' so it doesn't bleed into your rest.",
                "sentiment": "Anxiety",
                "emotion": "Anxiety",
                "tone": "Mysterious",
                "themes": ["Time", "Ocean", "Pressure", "Silence"]
            }
            """
            return try JSONDecoder().decode(T.self, from: json.data(using: .utf8)!)
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
        
        throw NSError(domain: "FoundationModels", code: 404, userInfo: [NSLocalizedDescriptionKey: "Mock not found for type \(type)"])
    }
}

public struct GenerationResponse<T: Sendable>: Sendable {
    public let content: T
}

// Ensure Helper Types are Sendable & Codable
public struct ImagePrompt: Codable, Sendable {
    @Guide(description: "A vivid visual description for the image generator.")
    public var visualDescription: String = ""
    
    @Guide(description: "Keywords defining the mood.")
    public var moodKeywords: String = ""
    
    @Guide(description: "Color palette suggestions.")
    public var colorPalette: String = ""
}
