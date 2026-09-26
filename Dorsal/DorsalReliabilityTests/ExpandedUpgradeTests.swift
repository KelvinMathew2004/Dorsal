import Testing
import Foundation
import FoundationModels
import SwiftData
import SwiftUI
import UIKit
import MapKit
import ImagePlayground
@testable import Dorsal

@MainActor
@Suite("Adaptive journal and integration tests", .serialized)
struct ExpandedUpgradeTests {
    @Test func checklistMatchesWholeWordsAndRecognizesCommonRelationshipAndEmotionTerms() {
        let people = ["he", "she", "grandmother", "grandma", "friend"]
        #expect(ChecklistKeywordMatcher.match(in: "I was walking with my grandmother", keywords: people) == "grandmother")
        #expect(ChecklistKeywordMatcher.match(in: "I saw her", keywords: people) == nil)
        let emotions = ["exhilarated", "thrilled"]
        #expect(ChecklistKeywordMatcher.match(in: "I was feeling exhilarated", keywords: emotions) == "exhilarated")
        #expect(ChecklistKeywordMatcher.match(in: "I felt thrilled", keywords: emotions) == "thrilled")
    }

    @Test func onlyAnimationAndGoldAreFreeAndCustomizationFailsOpenUntilConfigured() {
        #expect(RevenueCatManager.canUseImageStyle("pixar", entitlementStatusKnown: true, isPremium: false, hasLifetimePackage: true))
        #expect(!RevenueCatManager.canUseImageStyle("warm", entitlementStatusKnown: true, isPremium: false, hasLifetimePackage: true))
        #expect(!RevenueCatManager.canUseImageStyle("cinematic", entitlementStatusKnown: true, isPremium: false, hasLifetimePackage: true))
        #expect(RevenueCatManager.canUseImageStyle("cinematic", entitlementStatusKnown: false, isPremium: false, hasLifetimePackage: true))
        #expect(RevenueCatManager.canUseImageStyle("cinematic", entitlementStatusKnown: true, isPremium: true, hasLifetimePackage: true))
        #expect(RevenueCatManager.canUseImageStyle("cinematic", entitlementStatusKnown: true, isPremium: false, hasLifetimePackage: false))
        #expect(RevenueCatManager.canUseTheme("gold", entitlementStatusKnown: true, isPremium: false, hasLifetimePackage: true))
        #expect(!RevenueCatManager.canUseTheme("ocean", entitlementStatusKnown: true, isPremium: false, hasLifetimePackage: true))
        #expect(RevenueCatManager.canUseTheme("ocean", entitlementStatusKnown: false, isPremium: false, hasLifetimePackage: true))
        #expect(RevenueCatManager.canUseTheme("ocean", entitlementStatusKnown: true, isPremium: true, hasLifetimePackage: true))
        #expect(RevenueCatManager.canUseTheme("ocean", entitlementStatusKnown: true, isPremium: false, hasLifetimePackage: false))
    }
    }

    @Test func illustrationUsesOnlyADecodableProfilePhotoAsTheDreamer() throws {
        let preferences = UserDefaults.standard
        let priorPreference = preferences.object(forKey: "imageIncludeMyself")
        let priorSceneMode = preferences.object(forKey: "imageSceneMode")
        preferences.set(true, forKey: "imageIncludeMyself")
        preferences.set(ImageScenePreference.dreamScene, forKey: "imageSceneMode")
        defer {
            if let priorPreference { preferences.set(priorPreference, forKey: "imageIncludeMyself") }
            else { preferences.removeObject(forKey: "imageIncludeMyself") }
            if let priorSceneMode { preferences.set(priorSceneMode, forKey: "imageSceneMode") }
            else { preferences.removeObject(forKey: "imageSceneMode") }
        }
        let image = UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8)).image { context in
            UIColor.blue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
        }
        let request = DreamIllustrationRequest(promptTags: ["A moonlit forest"], profileImageData: try #require(image.pngData()))
        #expect(request.profileImage != nil)
        #expect(request.conceptText.contains { $0.contains("is the dreamer") })
        for data in [nil, Data("not an image".utf8)] {
            let missing = DreamIllustrationRequest(promptTags: request.promptTags, profileImageData: data)
            #expect(missing.profileImage == nil)
            #expect(missing.conceptText == request.promptTags)
        }
        if #available(iOS 27, *) {
            #expect(request.options.creationStrategy == .generateNew)
            #expect(request.options.personalization == .enabled)
        }
        preferences.set(ImageScenePreference.settingOnly, forKey: "imageSceneMode")
        let withoutDreamer = DreamIllustrationRequest(promptTags: request.promptTags, profileImageData: try #require(image.pngData()))
        #expect(withoutDreamer.profileImage == nil)
        #expect(withoutDreamer.conceptText.contains { $0.contains("Do not depict people") })
        preferences.set(ImageScenePreference.dreamScene, forKey: "imageSceneMode")
        let dreamScene = DreamIllustrationRequest(promptTags: request.promptTags, profileImageData: try #require(image.pngData()))
        #expect(dreamScene.conceptText.contains { $0.contains("Preserve their facial identity") && $0.contains("freely change their clothing") })
    }

    @Test func newerIntentSupersedesDeferredEntryAndClearsJournalFilters() throws {
        let context = try context()
        let dream = Dream(rawTranscript: "A silver forest")
        try DreamPersistence.save(dream, in: context) { try context.save() }
        let store = DreamStore(prepareServices: false, availabilityProvider: { .notReady })
        store.openDreamFromIntent(id: dream.id)
        store.searchDreamsFromIntent("  forest \n")
        store.setContext(context)
        #expect(store.selectedTab == 1)
        #expect(store.navigationPath.isEmpty)
        #expect(store.searchQuery == "forest")
        store.openSectionFromIntent(.journal)
        #expect(store.searchQuery.isEmpty)
        store.openSectionFromIntent(.profile)
        #expect(store.selectedTab == 3)
        store.openSectionFromIntent(.insights)
        #expect(store.selectedTab == 2)
        store.openSectionFromIntent(.recorder)
        #expect(store.selectedTab == 0)
        #expect(!store.isRecording)
    }

    @Test func entityNamesPreserveFullDescriptorsAndResolveUnambiguousAliases() {
        let people = DreamEntityCanonicalizer.canonicalize(
            ["old", "Shreey", "woman"], linkedNames: ["Shrey"], historicalNames: ["old man", "woman"]
        )
        #expect(people == ["old man", "Shrey", "woman"])
        let places = DreamEntityCanonicalizer.canonicalize(
            ["school"], linkedNames: [], historicalNames: ["high school"]
        )
        #expect(places == ["high school"])
        let ambiguousPlaces = DreamEntityCanonicalizer.canonicalize(
            ["school"], linkedNames: [], historicalNames: ["high school", "elementary school"]
        )
        #expect(ambiguousPlaces == ["school"])
    }

    @Test func spokenSummaryDoesNotInventEmotionAnalysis() {
        #expect(DreamSummaryIntent.summary(for: []).contains("haven't recorded"))
        #expect(DreamSummaryIntent.summary(for: [Dream(rawTranscript: "A forest")]).contains("No emotion analysis"))
    }

    private func context() throws -> ModelContext {
        let container = try ModelContainer(for: SavedDream.self, SavedEntity.self, SavedWeeklyInsight.self,
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
        return ModelContext(container)
    }

    @Test func recentDatesUseWeekdaysAndOlderDatesOmitTime() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        let now = try Date("2026-09-24T12:00:00Z", strategy: .iso8601)
        let locale = Locale(identifier: "en_US")
        #expect(DreamDateLabel.string(now, now: now, calendar: calendar, locale: locale) == "Thursday")
        let sixDaysAgo = try #require(calendar.date(byAdding: .day, value: -6, to: now))
        let sevenDaysAgo = try #require(calendar.date(byAdding: .day, value: -7, to: now))
        #expect(DreamDateLabel.string(sixDaysAgo, now: now, calendar: calendar, locale: locale) == "Friday")
        #expect(DreamDateLabel.string(sevenDaysAgo, now: now, calendar: calendar, locale: locale) == "Sep 17, 2026")
    }

    @Test func contextThatFitsDoesNotNeedAnotherSession() async throws {
        let result = try await DreamContextBudget.compact("A short dream", limit: 30, count: { $0.count }) { _ in
            Issue.record("A fitting context must not be summarized")
            return "unexpected"
        }
        #expect(result == "A short dream")
    }

    @Test func lateJournalEntryDoesNotCombineTwoNightsOfSleep() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        let date = try Date("2026-09-24T23:00:00Z", strategy: .iso8601)
        let interval = try #require(SleepDataManager.queryWindow(endingAt: date, now: date, calendar: calendar))
        #expect(interval.duration == 24 * 3600)
        #expect(interval.end == (try Date("2026-09-24T18:00:00Z", strategy: .iso8601)))
    }

    @Test func longContextUsesEveryChunkAndPreservesSource() async throws {
        let original = String(repeating: "A forest 🌙 and a river. ", count: 9)
        let recorder = ChunkRecorder()
        let result = try await DreamContextBudget.compact(original, limit: 80, count: { $0.count }) { chunk in
            await recorder.append(chunk)
            return String(chunk.prefix(8))
        }
        #expect(result.count <= 80)
        #expect(await recorder.chunks.joined() == original)
    }

    @Test func compactionStopsWhenTheModelDoesNotShortenAnything() async {
        await #expect(throws: DreamError.self) {
            _ = try await DreamContextBudget.compact(String(repeating: "a", count: 100), limit: 40, count: { $0.count }, summarize: { $0 })
        }
    }

    @Test func modernModelErrorsKeepAccurateMessages() {
        guard #available(iOS 27, *) else { return }
        let assets = SystemLanguageModel.Error.assetsUnavailable(.init(debugDescription: "Test"))
        #expect(!DreamFailure.analysisMessage(for: assets).localizedCaseInsensitiveContains("downloading"))
        let context = LanguageModelError.contextSizeExceeded(.init(contextSize: 4096, tokenCount: 5000, debugDescription: "Test"))
        #expect(DreamFailure.analysisMessage(for: context) == DreamError.tooLong.localizedDescription)
        #expect(DreamToolPolicy.mayFallback(after: context))
    }

    @Test func mapsLinkSurvivesReloadAndCanBeUnlinked() throws {
        let context = try context()
        let store = DreamStore(prepareServices: false, availabilityProvider: { .notReady })
        let mapItem = MKMapItem(location: CLLocation(latitude: 41.88, longitude: -87.63), address: nil)
        mapItem.name = "Chicago"
        let place = LinkedPlace(mapItem)
        // Exercise pending-save recovery before the database has been attached.
        store.updateEntity(name: "city", type: "place", description: "My dream city", image: nil, linkedPlace: place)
        #expect(store.persistenceError != nil)
        store.modelContext = context
        store.retryPendingSaves()
        let saved = try #require(store.getEntity(name: "city", type: "place"))
        let data = try #require(saved.linkedPlaceData)
        #expect(try JSONDecoder().decode(LinkedPlace.self, from: data) == place)
        #expect(store.persistenceError == nil)
        store.updateEntity(name: "city", type: "place", description: saved.details, image: nil, linkedPlace: nil)
        #expect(store.getEntity(name: "city", type: "place")?.linkedPlaceData == nil)
        #expect(store.getEntity(name: "city", type: "place")?.details == "My dream city")
    }

    @Test func addingMapsLinksPreservesExistingContactsAndGroups() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let configuration = ModelConfiguration(url: directory.appendingPathComponent("profile.store"), cloudKitDatabase: .none)
        do {
            let old = try ModelContainer(for: LegacyEntitySchema.SavedEntity.self, configurations: configuration)
            let context = ModelContext(old)
            context.insert(LegacyEntitySchema.SavedEntity(name: "Alice", type: "person", parentID: "person:Friend", contactID: "contact-123"))
            try context.save()
        }
        let updated = try ModelContainer(for: SavedEntity.self, configurations: configuration)
        let restored = try #require(ModelContext(updated).fetch(FetchDescriptor<SavedEntity>()).first)
        #expect(restored.contactId == "contact-123")
        #expect(restored.parentID == "person:Friend")
        #expect(restored.details == "Existing details")
        #expect(restored.linkedPlaceData == nil)
    }

    @Test func deferredDreamIntentOpensAfterContextLoads() throws {
        let context = try context()
        let dream = Dream(rawTranscript: "A silver forest", core: DreamCoreAnalysis(title: "Silver Forest", summary: "A forest."))
        try DreamPersistence.save(dream, in: context) { try context.save() }
        #expect(try context.fetch(FetchDescriptor<SavedDream>()).first?.id == dream.id)
        let store = DreamStore(prepareServices: false, availabilityProvider: { .notReady })
        store.openDreamFromIntent(id: dream.id)
        #expect(store.navigationPath.isEmpty)
        store.setContext(context)
        #expect(store.selectedTab == 1)
        #expect(store.navigationPath.count == 1)
        store.openDreamFromIntent(id: dream.id)
        #expect(store.navigationPath.count == 1)
    }

    @Test func wheelStartsInsideRepeatedColors() async throws {
        let theme = try #require(Theme.availableThemes.first)
        let window = try show(ThemeWheelSelector(currentThemeID: .constant(theme.id)).padding(24).background(.black))
        defer { window.isHidden = true }
        try await Task.sleep(for: .seconds(1))
        func scrollViews(_ view: UIView) -> [UIScrollView] {
            (view as? UIScrollView).map { [$0] } ?? view.subviews.flatMap(scrollViews)
        }
        let scroll = try #require(scrollViews(window).first)
        #expect(scroll.contentOffset.x > scroll.bounds.width)
        let selectedSwatchCenter = CGFloat(10 * Theme.availableThemes.count) * 60 + 30
        #expect(abs(scroll.contentOffset.x + scroll.bounds.width / 2 - selectedSwatchCenter) < 1)
        try capture(window, name: "dorsal-theme-wheel")
    }

    @Test func journalRendersAdaptiveCards() async throws {
        let store = DreamStore(prepareServices: false, availabilityProvider: { .notReady })
        for (index, title) in ["Moonlit Ocean", "Silver Forest", "A Familiar Place", "The Quiet Garden", "Above the Clouds", "Morning Light"].enumerated() {
            let renderer = UIGraphicsImageRenderer(size: CGSize(width: 400, height: 400))
            let image = renderer.image { context in
                UIColor(hue: CGFloat(index) / 6, saturation: 0.5, brightness: 0.5, alpha: 1).setFill()
                context.fill(CGRect(x: 0, y: 0, width: 400, height: 400))
                UIImage(systemName: "moon.stars.fill")?.withTintColor(.white).draw(in: CGRect(x: 90, y: 130, width: 220, height: 220))
            }
            store.dreams.append(Dream(date: Date().addingTimeInterval(Double(-index * 86400)), rawTranscript: title,
                                      core: DreamCoreAnalysis(title: title, summary: title), generatedImageData: image.pngData()))
        }
        let window = try show(JournalView(store: store).preferredColorScheme(.dark))
        defer { window.isHidden = true }
        try await Task.sleep(for: .seconds(1))
        try capture(window, name: "dorsal-journal-layout")
    }

    private func show<V: View>(_ view: V) throws -> UIWindow {
        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.rootViewController = UIHostingController(rootView: view)
        window.makeKeyAndVisible()
        return window
    }

    private func capture(_ window: UIWindow, name: String) throws {
        window.layoutIfNeeded()
        let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        let data = try #require(image.pngData())
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(name).png")
        try data.write(to: url)
        print("UI capture: \(url.path)")
    }
}

private actor ChunkRecorder {
    var chunks: [String] = []
    func append(_ chunk: String) { chunks.append(chunk) }
}
