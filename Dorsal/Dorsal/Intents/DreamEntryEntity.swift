import AppIntents
import CoreSpotlight
import SwiftData
import VisualIntelligence
import UniformTypeIdentifiers

/// Exposes a stable dream id and only the title, short summary, date, emotions,
/// and people needed by system search and Shortcuts. It excludes transcripts,
/// interpretations, image prompts, contact details, and HealthKit data.
struct DreamEntryEntity: IndexedEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Dream")
    static let defaultQuery = DreamEntryQuery()

    let id: UUID
    @Property(title: "Title", indexingKey: \.title) var title: String
    @Property(title: "Summary", indexingKey: \.textContent) var summary: String
    @Property(title: "Date", indexingKey: \.contentCreationDate) var date: Date
    @Property(title: "Emotions") var emotions: [String]
    @Property(title: "People") var people: [String]
    @ComputedProperty(indexingKey: \.keywords) var searchKeywords: [String] { emotions + people }

    init(id: UUID, title: String, summary: String = "", date: Date, emotions: [String] = [], people: [String] = []) {
        self.id = id
        self.title = title.isEmpty ? "Saved Dream" : title
        self.summary = summary
        self.date = date
        self.emotions = emotions
        self.people = people
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

    static func journalEntries(for identifiers: [UUID]) throws -> [DreamJournalEntryEntity] {
        let ids = Array(identifiers.prefix(50))
        guard !ids.isEmpty else { return [] }
        let context = try makeContext()
        let descriptor = FetchDescriptor<SavedDream>(predicate: #Predicate { ids.contains($0.id) })
        let savedByID = Dictionary(uniqueKeysWithValues: try context.fetch(descriptor).map { ($0.id, $0) })
        return ids.compactMap { id in
            guard let saved = savedByID[id] else { return nil }
            let audioFile = RecordingFiles.url(for: saved.recordingFileName).map { url in
                IntentFile(fileURL: url, filename: url.lastPathComponent,
                           type: UTType(filenameExtension: url.pathExtension))
            }
            let entryTitle = saved.title.trimmingCharacters(in: .whitespacesAndNewlines)
            let transcript = saved.rawText.isEmpty ? nil : AttributedString(saved.rawText)
            return DreamJournalEntryEntity(id: saved.id,
                                           title: entryTitle.isEmpty ? nil : entryTitle,
                                           message: transcript,
                                           mediaItems: audioFile.map { [$0] } ?? [],
                                           entryDate: saved.date)
        }
    }

    static func entities(for identifiers: [UUID]) throws -> [DreamEntryEntity] {
        let context = try makeContext()
        return try identifiers.prefix(50).compactMap { id -> DreamEntryEntity? in
            let descriptor = FetchDescriptor<SavedDream>(predicate: #Predicate { $0.id == id })
            guard let saved = try context.fetch(descriptor).first else { return nil }
            return DreamEntryEntity(id: saved.id, title: saved.title, summary: saved.summary,
                                    date: saved.date, emotions: saved.emotions, people: saved.people)
        }
    }

    static func entities(limit: Int) throws -> [DreamEntryEntity] {
        let context = try makeContext()
        var descriptor = FetchDescriptor<SavedDream>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        descriptor.fetchLimit = max(1, min(50, limit))
        descriptor.propertiesToFetch = [\.id, \.title, \.summary, \.date, \.emotions, \.people]
        return try context.fetch(descriptor).map {
            DreamEntryEntity(id: $0.id, title: $0.title, summary: $0.summary,
                             date: $0.date, emotions: $0.emotions, people: $0.people)
        }
    }

    static func entityBatchForReindexing(offset: Int, limit: Int = 200) throws -> [DreamEntryEntity] {
        let context = try makeContext()
        var descriptor = FetchDescriptor<SavedDream>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        descriptor.fetchLimit = max(1, min(200, limit))
        descriptor.fetchOffset = max(0, offset)
        descriptor.propertiesToFetch = [\.id, \.title, \.summary, \.date, \.emotions, \.people]
        return try context.fetch(descriptor).map {
            DreamEntryEntity(id: $0.id, title: $0.title, summary: $0.summary,
                             date: $0.date, emotions: $0.emotions, people: $0.people)
        }
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
            descriptor.propertiesToFetch = [\.id, \.title, \.summary, \.date, \.emotions, \.people, \.rawText]
            let batch = try context.fetch(descriptor)
            for saved in batch where saved.title.localizedCaseInsensitiveContains(query)
                || saved.rawText.localizedCaseInsensitiveContains(query) {
                matches.append(DreamEntryEntity(id: saved.id, title: saved.title, summary: saved.summary,
                                                date: saved.date, emotions: saved.emotions, people: saved.people))
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

    static func latestSummarySnapshot() throws -> (DreamEntryEntity?, Data?) {
        let context = try makeContext()
        var descriptor = FetchDescriptor<SavedDream>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        descriptor.fetchLimit = 1
        guard let saved = try context.fetch(descriptor).first else { return (nil, nil) }
        let entity = DreamEntryEntity(id: saved.id, title: saved.title, summary: saved.summary,
                                      date: saved.date, emotions: saved.emotions, people: saved.people)
        return (entity, saved.generatedImageData)
    }

    static func summarySnapshot(for id: UUID) throws -> (DreamEntryEntity?, Data?) {
        let context = try makeContext()
        let descriptor = FetchDescriptor<SavedDream>(predicate: #Predicate { $0.id == id })
        guard let saved = try context.fetch(descriptor).first else { return (nil, nil) }
        let entity = DreamEntryEntity(id: saved.id, title: saved.title, summary: saved.summary,
                                      date: saved.date, emotions: saved.emotions, people: saved.people)
        return (entity, saved.generatedImageData)
    }

    static func entities(matchingVisualLabels labels: [String], limit: Int = 10) throws -> [DreamEntryEntity] {
        let normalizedLabels = Set(labels.map(normalize).filter { !$0.isEmpty }).sorted()
        guard !normalizedLabels.isEmpty else { return [] }
        let context = try makeContext()
        var descriptor = FetchDescriptor<SavedDream>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        descriptor.fetchLimit = 500
        descriptor.propertiesToFetch = [\.id, \.title, \.summary, \.date, \.emotions, \.people, \.places, \.symbols]
        let matches = try context.fetch(descriptor).compactMap { saved -> (DreamEntryEntity, Int)? in
            let highValueFields = saved.places + saved.symbols + saved.people + [saved.title]
            let searchableFields = highValueFields + [saved.summary]
            let fieldTokens = searchableFields.map { Set(tokens($0)) }
            let searchableTokens = Set(fieldTokens.flatMap { $0 })

            var relevanceScore = 0
            for label in normalizedLabels {
                let labelTokens = tokens(label)
                guard !labelTokens.isEmpty else { continue }
                let structuredMatch = highValueFields.contains { normalize($0) == label || containsTokenSequence($0, label) }
                if structuredMatch {
                    relevanceScore += 4
                } else if searchableFields.contains(where: { containsTokenSequence($0, label) }) {
                    relevanceScore += 3
                } else if labelTokens.count == 1, searchableTokens.contains(labelTokens[0]) {
                    relevanceScore += 1
                } else if labelTokens.count > 1, labelTokens.allSatisfy(searchableTokens.contains) {
                    relevanceScore += 2
                }
            }
            guard relevanceScore > 0 else { return nil }
            return (DreamEntryEntity(id: saved.id, title: saved.title, summary: saved.summary,
                                     date: saved.date, emotions: saved.emotions, people: saved.people), relevanceScore)
        }
        return matches.sorted {
            $0.1 == $1.1 ? $0.0.date > $1.0.date : $0.1 > $1.1
        }.prefix(max(1, min(20, limit))).map {
            $0.0
        }
    }

    private static func normalize(_ value: String) -> String {
        value.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .split { !$0.isLetter && !$0.isNumber }.joined(separator: " ")
    }

    private static func tokens(_ value: String) -> [String] {
        normalize(value).split(separator: " ").map(String.init)
    }

    private static func containsTokenSequence(_ text: String, _ phrase: String) -> Bool {
        let textTokens = tokens(text)
        let phraseTokens = tokens(phrase)
        guard !phraseTokens.isEmpty, phraseTokens.count <= textTokens.count else { return false }
        return (0...(textTokens.count - phraseTokens.count)).contains { start in
            Array(textTokens[start..<(start + phraseTokens.count)]) == phraseTokens
        }
    }
}

@available(iOS 27.0, *)
extension DreamEntryQuery: IndexedEntityQuery {
    func reindexEntities(for identifiers: [UUID], indexDescription: CSSearchableIndexDescription) async throws {
        let entities = try await entities(for: identifiers)
        try await CSSearchableIndex.default().indexAppEntities(entities)
    }

    func reindexAllEntities(indexDescription: CSSearchableIndexDescription) async throws {
        let batchSize = 200
        var offset = 0
        while true {
            let entities = try await DreamIntentRepository.entityBatchForReindexing(offset: offset, limit: batchSize)
            guard !entities.isEmpty else { break }
            try await CSSearchableIndex.default().indexAppEntities(entities)
            guard entities.count == batchSize else { break }
            offset += batchSize
        }
    }
}

@available(iOS 26.0, *)
struct DreamVisualSearchQuery: IntentValueQuery {
    func values(for input: SemanticContentDescriptor) async throws -> [DreamEntryEntity] {
        try await DreamIntentRepository.entities(matchingVisualLabels: input.labels)
    }
}

@available(iOS 26.0, *)
struct OpenVisualDreamIntent: OpenIntent {
    static let title: LocalizedStringResource = "Open Dream"
    @Parameter(title: "Dream") var target: DreamEntryEntity

    init() {}
    init(target: DreamEntryEntity) { self.target = target }

    @MainActor
    func perform() async throws -> some IntentResult {
        DreamStore.shared.openDreamFromIntent(id: target.id)
        return .result()
    }
}
