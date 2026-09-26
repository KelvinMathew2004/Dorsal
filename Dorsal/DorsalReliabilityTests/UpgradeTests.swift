import Testing
import Foundation
import FoundationModels
import SwiftData
import SwiftUI
import UIKit
@testable import Dorsal

@MainActor
@Suite("Upgrade regression tests", .serialized)
struct UpgradeTests {
    private let origin = Date(timeIntervalSince1970: 1_700_000_000)

    private func segment(_ from: Int, _ to: Int, _ stage: SleepSegment.Stage, source: String = "watch") -> SleepSegment {
        SleepSegment(start: origin.addingTimeInterval(Double(from) * 60),
                     end: origin.addingTimeInterval(Double(to) * 60), stage: stage, source: source)
    }

    @Test func overlappingSleepSamplesDoNotDoubleCount() throws {
        let samples = [segment(0, 480, .inBed), segment(0, 480, .unspecified),
                       segment(0, 300, .core), segment(0, 300, .core),
                       segment(300, 420, .rem), segment(420, 480, .deep)]
        let summary = try #require(SleepAggregation.summarize(samples, from: origin, to: origin.addingTimeInterval(480 * 60)))
        #expect(summary.totalSleepMinutes == 480)
        #expect(summary.coreSleepMinutes == 300)
        #expect(summary.remMinutes == 120)
        #expect(summary.deepSleepMinutes == 60)
    }

    @Test func sleepSourcesRemainSeparate() throws {
        let samples = [segment(0, 420, .core), segment(0, 600, .unspecified, source: "phone")]
        let summary = try #require(SleepAggregation.summarize(samples, from: origin, to: origin.addingTimeInterval(600 * 60)))
        #expect(summary.totalSleepMinutes == 420)
        #expect(summary.sleepEfficiency == nil)
    }

    @Test func inBedAloneDoesNotInventSleep() {
        #expect(SleepAggregation.summarize([segment(0, 480, .inBed)], from: origin, to: origin.addingTimeInterval(480 * 60)) == nil)
        #expect(SleepAggregation.summarize([], from: origin, to: origin.addingTimeInterval(480 * 60)) == nil)
    }

    @Test func sleepIsClippedAndAwakeTimeIsSeparate() throws {
        let samples = [segment(-60, 90, .core), segment(90, 120, .awake), segment(120, 300, .rem)]
        let summary = try #require(SleepAggregation.summarize(samples, from: origin, to: origin.addingTimeInterval(180 * 60)))
        #expect(summary.totalSleepMinutes == 150)
        #expect(summary.awakeMinutes == 30)
        #expect(summary.sleepEfficiency == 83)
        #expect(summary.sleepOnsetTime == origin)
        #expect(summary.wakeUpTime == origin.addingTimeInterval(180 * 60))
    }

    @Test func reorderUsesIdentifiersAndPreservesOtherItems() {
        #expect(ProfileEntityOrder.applying(["c", "a"], before: "b", to: ["a", "b", "c", "d"]) == ["c", "a", "b", "d"])
        #expect(ProfileEntityOrder.applying(["a", "a", "missing"], before: nil, to: ["a", "b", "c"]) == ["b", "c", "a"])
        #expect(ProfileEntityOrder.applying(["a"], before: "a", to: ["a", "b"]) == ["a", "b"])
    }

    @Test func profileGroupingReorderingAndUnlinkingPersist() throws {
        let container = try ModelContainer(for: SavedDream.self, SavedEntity.self, SavedWeeklyInsight.self,
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
        let context = ModelContext(container)
        for name in ["Alice", "Bob", "Charlie"] { context.insert(SavedEntity(name: name, type: "person")) }
        try context.save()
        let store = DreamStore(prepareServices: false, availabilityProvider: { .notReady })
        store.modelContext = context
        let suite = "ProfileOrderTests.\(UUID())"
        let preferences = try #require(UserDefaults(suiteName: suite))
        defer { preferences.removePersistentDomain(forName: suite) }
        #expect(store.moveProfileEntities(["person:Charlie"], type: "person", parentID: nil, before: "person:Alice", preferences: preferences))
        #expect(store.profileEntities(type: "person", preferences: preferences).map(\.name) == ["Charlie", "Alice", "Bob"])
        #expect(store.moveProfileEntities(["person:Alice"], type: "person", parentID: "person:Bob", before: nil, preferences: preferences))
        #expect(store.getEntity(name: "Alice", type: "person")?.parentID == "person:Bob")
        #expect(!store.canMoveProfileEntities(["person:Bob"], type: "person", parentID: "person:Charlie"))
        #expect(!store.canMoveProfileEntities(["person:Bob"], type: "place", parentID: nil))
        #expect(!store.canMoveProfileEntities(["person:Bob"], type: "person", parentID: "person:Bob"))
        #expect(store.moveProfileEntities(["person:Alice"], type: "person", parentID: nil, before: "person:Bob", preferences: preferences))
        #expect(store.getEntity(name: "Alice", type: "person")?.parentID == nil)
        #expect(store.profileEntities(type: "person", preferences: preferences).map(\.name) == ["Charlie", "Alice", "Bob"])
        let reloaded = ModelContext(container)
        let saved = try reloaded.fetch(FetchDescriptor<SavedEntity>())
        #expect(saved.count == 3)
        #expect(saved.first { $0.name == "Alice" }?.parentID == nil)
    }

    @Test func searchClampsArgumentsAndLeavesUnknownScoresMissing() async {
        let store = DreamStore(prepareServices: false, availabilityProvider: { .notReady })
        store.dreams = [Dream(rawTranscript: "I met Alice."), Dream(rawTranscript: "Alice was flying.")]
        #expect(await store.searchDreams(query: "  ", limit: 10).isEmpty)
        let matches = await store.searchDreams(query: " ALICE ", limit: -5)
        #expect(matches.count == 1)
        #expect(matches.first?.anxietyLevel == nil)
        #expect(matches.first?.sentimentScore == nil)
        #expect(await store.fetchMetricHistory(metric: "anxiety", days: 365).isEmpty)
    }

    @Test func toolOutputsAndRepeatedCallsAreBounded() async throws {
        let budget = DreamToolBudget()
        let tool = QueryPastDreamsTool(dreamSearcher: LongDreamSearch(), budget: budget)
        let output = try await tool.call(arguments: .init(query: "ocean", limit: 1000))
        #expect(output.count < 1800)
        _ = try await tool.call(arguments: .init(query: "ocean", limit: 1))
        _ = try await tool.call(arguments: .init(query: "ocean", limit: 1))
        await #expect(throws: DreamToolError.self) {
            _ = try await tool.call(arguments: .init(query: "ocean", limit: 1))
        }
    }

    @Test func toolFallbackDoesNotRetryCancellationOrServiceFailures() {
        let context = LanguageModelSession.GenerationError.Context(debugDescription: "Test")
        #expect(!DreamToolPolicy.mayFallback(after: CancellationError()))
        #expect(!DreamToolPolicy.mayFallback(after: LanguageModelSession.GenerationError.assetsUnavailable(context)))
        #expect(!DreamToolPolicy.mayFallback(after: LanguageModelSession.GenerationError.guardrailViolation(context)))
        #expect(DreamToolPolicy.mayFallback(after: DreamToolError.callLimit))
        #expect(DreamToolPolicy.mayFallback(after: LanguageModelSession.GenerationError.exceededContextWindowSize(context)))
    }

    @Test func automaticImageGenerationStaysOnIOS26() {
        if #available(iOS 27, *) {
            #expect(!ImageGenerationService.supportsAutomaticGeneration)
        } else {
            #expect(ImageGenerationService.supportsAutomaticGeneration)
        }
    }

    @Test func toolDatesUseTheLocalSleepDay() throws {
        let date = try Date("2026-01-01T02:00:00Z", strategy: .iso8601)
        let zone = try #require(TimeZone(secondsFromGMT: -6 * 3600))
        #expect(DreamContextDate.string(date, timeZone: zone) == "2025-12-31")
    }

}

private struct LongDreamSearch: DreamSearchable {
    func searchDreams(query: String, limit: Int) async -> [DreamSearchResult] {
        (0..<10).map { _ in
            DreamSearchResult(date: Date(), title: String(repeating: "T", count: 1000), summary: String(repeating: "S", count: 5000),
                              people: [], places: [], emotions: [], symbols: [], sentimentScore: nil,
                              anxietyLevel: nil, vividnessScore: nil, lucidityScore: nil)
        }
    }
    func fetchMetricHistory(metric: String, days: Int) async -> [MetricDataPoint] { [] }
}
