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
        // BUG FIX: Only analyze the actual transcript part of the prompt, ignoring the "Context -" section.
        // This prevents the mock from "finding" people/places just because they were listed in the context.
        let analysisText = prompt.components(separatedBy: "Context -").first?.lowercased() ?? prompt.lowercased()
        
        if typeString.contains("DreamInsight") {
            // Dynamic Insight Generation
            var summary = "A detailed dream analysis."
            var interpretation = "This dream reflects deep subconscious processing."
            var advice = "Reflect on these symbols in your waking life."
            var emotion = "Neutral"
            var tone = "Observational"
            
            if analysisText.contains("swimming") {
                summary = "Swimming deep underwater, observing clocks and anchors without fear."
                interpretation = "The ocean represents the unconscious mind. Swimming comfortably suggests you are exploring deep emotions. The anchor and clock represent time and grounding forces."
                advice = "Don't let time pressure stop you from exploring your feelings."
                emotion = "Peaceful"
                tone = "Dreamy"
            } else if analysisText.contains("teeth") {
                summary = "A public speaking event where teeth fall out and crumble."
                interpretation = "Teeth falling out is a universal archetype for loss of power or fear of embarrassment. It suggests anxiety about communication or self-image."
                advice = "Focus on your message, not your fear of judgement."
                emotion = "Embarrassed"
                tone = "Anxious"
            } else if analysisText.contains("chasing") || analysisText.contains("chase") {
                summary = "Being chased through a glass forest."
                interpretation = "Being chased usually indicates you are avoiding a difficult situation. The glass forest suggests the environment feels fragile or dangerous."
                advice = "Turn around and face what is chasing you."
                emotion = "Terrified"
                tone = "Urgent"
            } else if analysisText.contains("flying") {
                summary = "Flying high above a futuristic city."
                interpretation = "Flying dreams often symbolize freedom and a higher perspective. You may be rising above a problem."
                advice = "Enjoy this new perspective and apply it to your work."
                emotion = "Liberated"
                tone = "Exhilarated"
            } else if analysisText.contains("bear") {
                summary = "Talking to a bear in the kitchen."
                interpretation = "The bear represents primal instincts integrated into domestic life. Its calm demeanor suggests you are at peace with your inner nature."
                advice = "Listen to your intuition, it is trying to speak."
                emotion = "Curious"
                tone = "Surreal"
            } else if analysisText.contains("mall") {
                summary = "Wandering through an empty mall with faceless mannequins."
                interpretation = "Empty public spaces often reflect feelings of isolation or lack of direction. Faceless figures suggest a disconnect from social identity."
                advice = "Reconnect with what feels authentic to you, not just what is expected."
                emotion = "Lonely"
                tone = "Eerie"
            }
            
            let json = """
            {
                "summary": "\(summary)",
                "interpretation": "\(interpretation)",
                "actionableAdvice": "\(advice)",
                "emotion": "\(emotion)",
                "tone": "\(tone)"
            }
            """
            return try JSONDecoder().decode(T.self, from: json.data(using: .utf8)!)
        }
        else if typeString.contains("ImagePrompt") {
            // Dynamic Image Prompt Generation based on keywords
            var visual = "Abstract dreamscape with floating geometric shapes in a neon fog"
            var mood = "Surreal, Hazy"
            var palette = "Purple, Pink, Grey"
            
            if analysisText.contains("underwater") || analysisText.contains("ocean") {
                visual = "A vast underwater abyss with a faint light from the surface, a grandfather clock sinking into the deep blue void, cinematic lighting, professional animation style"
                mood = "Mysterious, Heavy, Deep, Blue"
                palette = "Deep Blue, Black, faint White"
            } else if analysisText.contains("forest") {
                visual = "A dark forest made entirely of transparent glass trees shattering into sparkling dust, moonlight refracting through shards, high contrast, crisp lines"
                mood = "Fragile, Sharp, Bright"
                palette = "Crystal White, Silver, Green"
            } else if analysisText.contains("city") || analysisText.contains("flying") {
                visual = "Futuristic city skyline viewed from above, clouds drifting between skyscrapers, golden hour lighting, clean vector art style"
                mood = "Free, Expansive, Golden"
                palette = "Gold, Blue, White"
            } else if analysisText.contains("bear") {
                visual = "A cozy kitchen scene with a large, friendly brown bear sitting at a small table holding a coffee cup, warm lighting, storybook illustration style"
                mood = "Warm, Whimsical, Cozy"
                palette = "Brown, Orange, Cream"
            } else if analysisText.contains("mall") {
                visual = "Endless empty shopping mall corridor, pristine white tiles, rows of faceless mannequins standing still, vaporwave aesthetic"
                mood = "Eerie, Sterile, Lonely"
                palette = "White, Pastel Pink, Teal"
            }
            
             let json = """
            {
                "visualDescription": "\(visual)",
                "moodKeywords": "\(mood)",
                "colorPalette": "\(palette)"
            }
            """
            return try JSONDecoder().decode(T.self, from: json.data(using: .utf8)!)
        }
        else if typeString.contains("DreamEntities") {
            // "SMART" MOCK EXTRACTOR
            
            let ontology: [String: String] = [
                // People
                "sarah": "people", "mom": "people", "dad": "people", "brother": "people",
                "sister": "people", "boss": "people", "bear": "people", "mannequins": "people", "mannequin": "people",
                
                // Places
                "underwater": "places", "ocean": "places", "school": "places", "office": "places",
                "forest": "places", "home": "places", "city": "places", "sky": "places",
                "mall": "places", "hotel": "places", "kitchen": "places", "field": "places",
                "apartment": "places", "ballroom": "places", "roof": "places",
                
                // Emotions
                "scared": "emotions", "terrified": "emotions", "happy": "emotions",
                "peaceful": "emotions", "lonely": "emotions", "embarrassed": "emotions",
                "helpless": "emotions", "normal": "emotions", "free": "emotions",
                
                // Symbols (Key Entities)
                "anchor": "keyEntities", "clock": "keyEntities", "notes": "keyEntities",
                "teeth": "keyEntities", "seashell": "keyEntities", "glass": "keyEntities",
                "trees": "keyEntities", "wind": "keyEntities", "apple": "keyEntities",
                "dust": "keyEntities", "legs": "keyEntities", "coffee": "keyEntities",
                "tornado": "keyEntities", "door": "keyEntities", "wall": "keyEntities",
                "chandeliers": "keyEntities"
            ]
            
            var people: [String] = []
            var places: [String] = []
            var emotions: [String] = []
            var keys: [String] = []
            
            // Scan ONLY the analysisText (cleaned prompt) for entities
            for (key, category) in ontology {
                if analysisText.contains(key) {
                    let capitalized = key.capitalized
                    switch category {
                    case "people": people.append(capitalized)
                    case "places": places.append(capitalized)
                    case "emotions": emotions.append(capitalized)
                    case "keyEntities": keys.append(capitalized)
                    default: break
                    }
                }
            }
            
            let peopleJson = people.map { "\"\($0)\"" }.joined(separator: ",")
            let placesJson = places.map { "\"\($0)\"" }.joined(separator: ",")
            let emotionsJson = emotions.map { "\"\($0)\"" }.joined(separator: ",")
            let keysJson = keys.map { "\"\($0)\"" }.joined(separator: ",")
            
            let json = """
            {
                "people": [\(peopleJson)],
                "places": [\(placesJson)],
                "emotions": [\(emotionsJson)],
                "keyEntities": [\(keysJson)]
            }
            """
            return try JSONDecoder().decode(T.self, from: json.data(using: .utf8)!)
        }
        else if typeString.contains("TherapeuticInsight") {
             let json = """
            [
                {
                    "title": "Recurring Theme",
                    "observation": "You frequently dream about water or being chased.",
                    "suggestion": "This often relates to avoiding a difficult emotion."
                }
            ]
            """
            return try JSONDecoder().decode(T.self, from: json.data(using: .utf8)!)
        }
        
        throw NSError(domain: "FoundationModels", code: 404, userInfo: [NSLocalizedDescriptionKey: "Mock not found for type \(type)"])
    }
}

public struct GenerationResponse<T: Sendable>: Sendable {
    public let content: T
}
