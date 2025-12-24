import Foundation

// Service to handle basic text processing and entity extraction
// This replaces the missing file dependency in DreamStore.swift
struct IntelligenceService {
    
    static func extractEntities(text: String, existingTags: [String]) -> [String] {
        var entities: Set<String> = []
        let lowerText = text.lowercased()
        
        // 1. Check for existing tags
        for tag in existingTags {
            if lowerText.contains(tag.lowercased()) {
                entities.insert(tag)
            }
        }
        
        // 2. Simple keyword extraction (Mock logic)
        // In a real app, this would use NaturalLanguage framework (NLTagger)
        let commonKeywords = ["water", "flying", "school", "exam", "teeth", "falling", "chase", "ocean", "forest", "darkness", "light"]
        
        for keyword in commonKeywords {
            if lowerText.contains(keyword) {
                entities.insert(keyword.capitalized)
            }
        }
        
        return Array(entities).sorted()
    }
}
