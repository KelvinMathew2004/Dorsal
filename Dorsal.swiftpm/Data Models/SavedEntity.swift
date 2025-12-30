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
    
    init(name: String, type: String, details: String = "", imageData: Data? = nil) {
        self.name = name
        self.type = type
        self.id = "\(type):\(name)"
        self.details = details
        self.imageData = imageData
        self.lastUpdated = Date()
    }
}
