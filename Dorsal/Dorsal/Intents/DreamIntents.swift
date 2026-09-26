import AppIntents
import SwiftUI

// 1. RecordDreamIntent - opens app to RecordView (tab 0)
struct RecordDreamIntent: AppIntent {
    static let title: LocalizedStringResource = "Record a Dream"
    static let description = IntentDescription("Open the recorder to capture a dream in Dorsal", categoryName: "Recording")
    static let supportedModes: IntentModes = .foreground(.immediate)
    static let authenticationPolicy: IntentAuthenticationPolicy = .requiresLocalDeviceAuthentication
    
    @MainActor
    func perform() async throws -> some IntentResult {
        DreamStore.shared.openSectionFromIntent(.recorder)
        DreamStore.shared.startRecording()
        return .result()
    }
}

// 2. ViewLatestDreamIntent - opens most recent dream
struct ViewLatestDreamIntent: AppIntent {
    static let title: LocalizedStringResource = "View Latest Dream"
    static let description = IntentDescription("Open your most recent dream entry", categoryName: "Journal")
    static let supportedModes: IntentModes = .foreground(.immediate)
    static let authenticationPolicy: IntentAuthenticationPolicy = .requiresLocalDeviceAuthentication
    
    @MainActor
    func perform() async throws -> some IntentResult {
        DreamStore.shared.openDreamFromIntent()
        return .result()
    }
}

// 3. DreamSummaryIntent - returns text summary without opening app
struct DreamSummaryIntent: AppIntent {
    static let title: LocalizedStringResource = "Summarize My Dreams"
    static let description = IntentDescription("Get a quick summary of your recent dream patterns", categoryName: "Insights")
    static let authenticationPolicy: IntentAuthenticationPolicy = .requiresLocalDeviceAuthentication
    static let supportedModes: IntentModes = .background
    
    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let text = try await DreamIntentRepository.recentEmotionSummary()
        return .result(value: text, dialog: IntentDialog(stringLiteral: text))
    }

    nonisolated static func summary(for dreams: [Dream]) -> String {
        let recent = dreams.sorted { $0.date > $1.date }.prefix(7)
        let count = recent.count
        if count == 0 {
            return "You haven't recorded any dreams yet. Open Dorsal to get started!"
        }
        let allEmotions = recent.flatMap { $0.emotions }
        let topEmotions = Dictionary(grouping: allEmotions, by: { $0 })
            .sorted { $0.value.count == $1.value.count ? $0.key < $1.key : $0.value.count > $1.value.count }
            .prefix(3)
            .map { $0.key }
        guard !topEmotions.isEmpty else { return "You have \(count) recent saved dreams. No emotion analysis is available for those entries yet." }
        let emotionText = topEmotions.joined(separator: ", ")
        return "In your last \(count) dreams, dominant emotions were: \(emotionText)."
    }
}

// 4. CheckTrendsIntent - opens insights tab
struct CheckTrendsIntent: AppIntent {
    static let title: LocalizedStringResource = "Check Dream Trends"
    static let description = IntentDescription("View your dream patterns and insights", categoryName: "Insights")
    static let supportedModes: IntentModes = .foreground(.immediate)
    static let authenticationPolicy: IntentAuthenticationPolicy = .requiresLocalDeviceAuthentication
    
    @MainActor
    func perform() async throws -> some IntentResult {
        DreamStore.shared.openSectionFromIntent(.insights)
        return .result()
    }
}

struct OpenDreamIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Dream"
    static let description = IntentDescription("Open a saved dream from your journal", categoryName: "Journal")
    static let supportedModes: IntentModes = .foreground(.immediate)
    static let authenticationPolicy: IntentAuthenticationPolicy = .requiresLocalDeviceAuthentication
    @Parameter(title: "Dream") var dream: DreamEntryEntity
    static var parameterSummary: some ParameterSummary { Summary("Open \(\.$dream)") }

    @MainActor func perform() async throws -> some IntentResult {
        DreamStore.shared.openDreamFromIntent(id: dream.id)
        return .result()
    }
}

struct SearchDreamsIntent: AppIntent {
    static let title: LocalizedStringResource = "Search Dreams"
    static let description = IntentDescription("Search dream transcripts in your journal", categoryName: "Journal")
    static let supportedModes: IntentModes = .foreground(.immediate)
    static let authenticationPolicy: IntentAuthenticationPolicy = .requiresLocalDeviceAuthentication
    @Parameter(title: "Search Text") var query: String
    static var parameterSummary: some ParameterSummary { Summary("Search dreams for \(\.$query)") }

    @MainActor func perform() async throws -> some IntentResult {
        let store = DreamStore.shared
        store.searchDreamsFromIntent(query)
        return .result()
    }
}
