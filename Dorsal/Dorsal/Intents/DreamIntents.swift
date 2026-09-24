import AppIntents
import SwiftUI

// 1. RecordDreamIntent - opens app to RecordView (tab 0)
struct RecordDreamIntent: AppIntent {
    static let title: LocalizedStringResource = "Record a Dream"
    static let description = IntentDescription("Start recording a dream in Dorsal", categoryName: "Recording")
    static let openAppWhenRun = true
    
    @MainActor
    func perform() async throws -> some IntentResult {
        DreamStore.shared.selectedTab = 0
        return .result()
    }
}

// 2. ViewLatestDreamIntent - opens most recent dream
struct ViewLatestDreamIntent: AppIntent {
    static let title: LocalizedStringResource = "View Latest Dream"
    static let description = IntentDescription("Open your most recent dream entry", categoryName: "Journal")
    static let openAppWhenRun = true
    
    @MainActor
    func perform() async throws -> some IntentResult {
        let store = DreamStore.shared
        store.selectedTab = 1
        if let latest = store.dreams.first {
            store.navigationPath.append(latest)
        }
        return .result()
    }
}

// 3. DreamSummaryIntent - returns text summary without opening app
struct DreamSummaryIntent: AppIntent {
    static let title: LocalizedStringResource = "Summarize My Dreams"
    static let description = IntentDescription("Get a quick summary of your recent dream patterns", categoryName: "Insights")
    
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let store = await DreamStore.shared
        let recent = await store.dreams.prefix(7)
        let count = recent.count
        if count == 0 {
            return .result(value: "You haven't recorded any dreams yet. Open Dorsal to get started!")
        }
        let allEmotions = recent.flatMap { $0.emotions }
        let topEmotions = Dictionary(grouping: allEmotions, by: { $0 })
            .sorted { $0.value.count > $1.value.count }
            .prefix(3)
            .map { $0.key }
        let emotionText = topEmotions.isEmpty ? "varied" : topEmotions.joined(separator: ", ")
        return .result(value: "In your last \(count) dreams, dominant emotions were: \(emotionText).")
    }
}

// 4. CheckTrendsIntent - opens insights tab
struct CheckTrendsIntent: AppIntent {
    static let title: LocalizedStringResource = "Check Dream Trends"
    static let description = IntentDescription("View your dream and sleep analytics", categoryName: "Insights")
    static let openAppWhenRun = true
    
    @MainActor
    func perform() async throws -> some IntentResult {
        DreamStore.shared.selectedTab = 2
        return .result()
    }
}
