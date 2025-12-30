import Foundation
import SwiftData

@Model
final class SavedEntity {
    @Attribute(.unique) var id: String // Composite key: "Type:Name" (e.g., "person:Mom")
    var name: String
    var type: String // "person", "place", "tag"
    var details: String
    @Attribute(.externalStorage) var imageData: Data?
    var lastUpdated: Date
    
    // New field for hierarchy
    var parentID: String?
    
    init(name: String, type: String, details: String = "", imageData: Data? = nil, parentID: String? = nil) {
        self.name = name
        self.type = type
        self.id = "\(type):\(name)"
        self.details = details
        self.imageData = imageData
        self.lastUpdated = Date()
        self.parentID = parentID
    }
}
