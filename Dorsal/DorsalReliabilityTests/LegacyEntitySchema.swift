import Foundation
import SwiftData

enum LegacyEntitySchema {
    @Model final class SavedEntity {
        var id: String = ""
        var name: String = ""
        var type: String = ""
        var details: String = ""
        @Attribute(.externalStorage) var imageData: Data? = nil
        var lastUpdated: Date = Date()
        var parentID: String? = nil
        var contactId: String? = nil

        init(name: String, type: String, parentID: String? = nil, contactID: String? = nil) {
            self.name = name
            self.type = type
            self.id = "\(type):\(name)"
            self.parentID = parentID
            self.contactId = contactID
            self.details = "Existing details"
        }
    }
}
