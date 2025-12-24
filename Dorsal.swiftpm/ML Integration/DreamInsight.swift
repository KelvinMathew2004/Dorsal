import Foundation

// Ensure the struct is Sendable
struct DreamInsight: Codable, Sendable {
    
    @Guide(description: "A short, creative title for the dream.")
    var title: String = ""
    
    @Guide(description: "A concise summary of the dream's events.")
    var summary: String = ""
    
    @Guide(description: "A detailed psychological interpretation of the dream's symbols and narrative.")
    var interpretation: String = ""
    
    @Guide(description: "Practical advice based on the dream's meaning.")
    var actionableAdvice: String = ""
    
    @Guide(description: "The overall tone of the dream description.")
    var tone: String = ""
    
    @Guide(description: "The primary emotion associated with this dream.", .possibleValues(["Joy", "Fear", "Confusion", "Excitement", "Peace", "Anxiety", "Curiosity"]))
    var sentiment: String = ""
    
    var emotion: String { sentiment }
    
    @Guide(description: "A list of 3-5 key themes or symbols identified in the dream (e.g., 'Flying', 'Water', 'Childhood').")
    var themes: [String] = []
}
