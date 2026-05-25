import Foundation
import SwiftData

@Model
final class SavedEntity {
    var id: String = ""
    var name: String = ""
    var type: String = "" // "person", "place", "tag"
    var details: String = ""
    @Attribute(.externalStorage) var imageData: Data? = nil
    var lastUpdated: Date = Date()
    var parentID: String? = nil
    var contactId: String? = nil
    
    init(
        name: String = "",
        type: String = "",
        details: String = "",
        imageData: Data? = nil,
        parentID: String? = nil,
        contactId: String? = nil
    ) {
        self.name = name
        self.type = type
        self.id = "\(type):\(name)"
        self.details = details
        self.imageData = imageData
        self.lastUpdated = Date()
        self.parentID = parentID
        self.contactId = contactId
    }
}
