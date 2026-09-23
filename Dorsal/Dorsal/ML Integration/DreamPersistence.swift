import Foundation
import SwiftData

@MainActor
enum DreamPersistence {
    static func save(_ dream: Dream, in context: ModelContext, commit: () throws -> Void) throws {
        let dreamID = dream.id

        let descriptor = FetchDescriptor<SavedDream>(predicate: #Predicate { $0.id == dreamID })
        let saved: SavedDream

        if let existing = try context.fetch(descriptor).first {
            saved = existing
        } else {
            saved = SavedDream(id: dreamID)
            context.insert(saved)
        }

        // Map properties manually
        saved.analysisError = dream.analysisError
        saved.imageError = dream.imageError
        saved.transcriptionError = dream.transcriptionError
        saved.recordingFileName = dream.recordingFileName
        saved.needsAnalysis = dream.needsAnalysis
        saved.needsTranscription = dream.needsTranscription
        saved.hasCoreAnalysis = dream.core != nil
        saved.hasExtraAnalysis = dream.extras != nil
        saved.hasVoiceFatigue = dream.voiceFatigue != nil
        saved.date = dream.date
        saved.rawText = dream.rawTranscript
        saved.generatedImageData = dream.generatedImageData
        saved.isBookmarked = dream.isBookmarked
        saved.voiceFatigue = dream.voiceFatigue ?? 0

        if let core = dream.core {
            saved.title = core.title ?? ""
            saved.summary = core.summary ?? ""
            saved.people = core.people ?? []
            saved.places = core.places ?? []
            saved.emotions = core.emotions ?? []
            saved.symbols = core.symbols ?? []
            saved.interpretation = core.interpretation ?? ""
            saved.actionableAdvice = core.actionableAdvice ?? ""
            saved.toneLabel = core.tone?.label ?? ""
            saved.toneConfidence = core.tone?.confidence ?? 0
        }

        if let extras = dream.extras {
            saved.sentimentScore = extras.sentimentScore ?? 50
            saved.isNightmare = extras.isNightmare ?? false
            saved.lucidityScore = extras.lucidityScore ?? 0
            saved.vividnessScore = extras.vividnessScore ?? 0
            saved.coherenceScore = extras.coherenceScore ?? 0
            saved.anxietyLevel = extras.anxietyLevel ?? 0
        }

        try commit()
    }
}

@MainActor
struct DreamRecoveryStore {
    var directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("DreamRecovery", isDirectory: true)

    func write(_ dream: Dream) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONEncoder().encode(dream).write(to: file(for: dream.id), options: .atomic)
    }

    func load() throws -> [Dream] {
        guard FileManager.default.fileExists(atPath: directory.path) else { return [] }
        return try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
            .map { try JSONDecoder().decode(Dream.self, from: Data(contentsOf: $0)) }
    }

    func remove(_ id: UUID) throws {
        let url = file(for: id)
        if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
    }

    private func file(for id: UUID) -> URL { directory.appendingPathComponent(id.uuidString).appendingPathExtension("json") }
}
