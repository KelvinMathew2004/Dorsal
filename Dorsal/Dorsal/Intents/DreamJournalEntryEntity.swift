import AppIntents
import GeoToolbox
import UniformTypeIdentifiers

@AppEntity(schema: .journal.entry)
struct DreamJournalEntryEntity {
    struct Query: EntityQuery {
        func entities(for identifiers: [UUID]) async throws -> [DreamJournalEntryEntity] {
            try await DreamIntentRepository.journalEntries(for: identifiers)
        }
    }

    static let defaultQuery = Query()
    let id: UUID

    @Property(title: "Title") var title: String?
    @Property(title: "Message") var message: AttributedString?
    @Property(title: "Media Items") var mediaItems: [IntentFile]
    @Property(title: "Entry Date") var entryDate: Date?
    @Property(title: "Location") var location: GeoToolbox.PlaceDescriptor?

    init(id: UUID, title: String?, message: AttributedString?, mediaItems: [IntentFile], entryDate: Date?) {
        self.id = id
        self.title = title
        self.message = message
        self.mediaItems = mediaItems
        self.entryDate = entryDate
        self.location = nil
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title ?? "Dream Entry")")
    }
}
