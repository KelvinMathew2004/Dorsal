import AppIntents
import SwiftData

/// The shortcut only needs a stable id and a compact display label. It never
/// includes a transcript, dream interpretation, contact, or health information.
nonisolated struct DreamEntryEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Dream")
    static let defaultQuery = DreamEntryQuery()

    let id: UUID
    let title: String
    let date: Date

    init(id: UUID, title: String, date: Date) {
        self.id = id
        self.title = title.isEmpty ? "Saved Dream" : title
        self.date = date
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)", subtitle: "\(DreamDateLabel.string(date))")
    }
}

nonisolated struct DreamEntryQuery: EntityStringQuery {
    func entities(for identifiers: [UUID]) async throws -> [DreamEntryEntity] {
        try await DreamIntentRepository.entities(for: identifiers)
    }

    func suggestedEntities() async throws -> [DreamEntryEntity] {
        try await DreamIntentRepository.entities(limit: 10)
    }

    func entities(matching string: String) async throws -> [DreamEntryEntity] {
        let query = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return try await suggestedEntities() }
        return try await DreamIntentRepository.entities(matching: query, limit: 20)
    }
}

@MainActor
enum DreamIntentRepository {
    private static var container: ModelContainer?

    static func entities(for identifiers: [UUID]) throws -> [DreamEntryEntity] {
        let context = try makeContext()
        return try identifiers.prefix(50).compactMap { id -> DreamEntryEntity? in
            let descriptor = FetchDescriptor<SavedDream>(predicate: #Predicate { $0.id == id })
            guard let saved = try context.fetch(descriptor).first else { return nil }
            return DreamEntryEntity(id: saved.id, title: saved.title, date: saved.date)
        }
    }

    static func entities(limit: Int) throws -> [DreamEntryEntity] {
        let context = try makeContext()
        var descriptor = FetchDescriptor<SavedDream>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        descriptor.fetchLimit = max(1, min(50, limit))
        descriptor.propertiesToFetch = [\.id, \.title, \.date]
        return try context.fetch(descriptor).map { DreamEntryEntity(id: $0.id, title: $0.title, date: $0.date) }
    }

    static func entities(matching query: String, limit: Int) throws -> [DreamEntryEntity] {
        let context = try makeContext()
        let resultLimit = max(1, min(50, limit))
        let batchSize = 200
        var matches: [DreamEntryEntity] = []
        var offset = 0
        while matches.count < resultLimit {
            var descriptor = FetchDescriptor<SavedDream>(sortBy: [SortDescriptor(\.date, order: .reverse)])
            descriptor.fetchLimit = batchSize
            descriptor.fetchOffset = offset
            descriptor.propertiesToFetch = [\.id, \.title, \.date, \.rawText]
            let batch = try context.fetch(descriptor)
            for saved in batch where saved.title.localizedCaseInsensitiveContains(query)
                || saved.rawText.localizedCaseInsensitiveContains(query) {
                matches.append(DreamEntryEntity(id: saved.id, title: saved.title, date: saved.date))
                if matches.count == resultLimit { break }
            }
            guard batch.count == batchSize else { break }
            offset += batchSize
        }
        return matches
    }

    private static func makeContext() throws -> ModelContext {
        if container == nil {
            container = try ModelContainer(for: SavedDream.self, SavedWeeklyInsight.self, SavedEntity.self)
        }
        return ModelContext(container!)
    }

    static func recentEmotionSummary() throws -> String {
        let context = try makeContext()
        var descriptor = FetchDescriptor<SavedDream>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        descriptor.fetchLimit = 7
        descriptor.propertiesToFetch = [\.date, \.emotions]
        let recent = try context.fetch(descriptor)
        guard !recent.isEmpty else { return "You haven't recorded any dreams yet. Open Dorsal to get started!" }
        let emotions = recent.flatMap(\.emotions)
        guard !emotions.isEmpty else { return "You have \(recent.count) recent saved dreams. No emotion analysis is available for those entries yet." }
        let top = Dictionary(grouping: emotions, by: { $0 })
            .sorted { $0.value.count == $1.value.count ? $0.key < $1.key : $0.value.count > $1.value.count }
            .prefix(3).map(\.key).joined(separator: ", ")
        return "In your last \(recent.count) dreams, dominant emotions were: \(top)."
    }
}
