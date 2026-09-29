import AppIntents
import SwiftUI
import UIKit
import UniformTypeIdentifiers
import VisualIntelligence

// 1. RecordDreamIntent - opens app to RecordView (tab 0)
@AppIntent(schema: .journal.createAudioEntry)
struct RecordDreamIntent: AudioRecordingIntent {
    static let title: LocalizedStringResource = "Record a Dream"
    static let description = IntentDescription("Open the recorder to capture a dream in Dorsal", categoryName: "Recording")
    static let supportedModes: IntentModes = .foreground(.immediate)
    static let authenticationPolicy: IntentAuthenticationPolicy = .requiresLocalDeviceAuthentication
    
    @MainActor
    func perform() async throws -> some ReturnsValue<DreamJournalEntryEntity> {
        guard let dream = await DreamStore.shared.recordDreamForIntent() else {
            throw RecordDreamIntentError.notSaved
        }

        let generatedTitle = dream.core?.title?.trimmingCharacters(in: .whitespacesAndNewlines)
        let transcript = dream.rawTranscript.isEmpty ? nil : AttributedString(dream.rawTranscript)
        let mediaItems = RecordingFiles.url(for: dream.recordingFileName).map { url in
            [IntentFile(fileURL: url, filename: url.lastPathComponent,
                        type: UTType(filenameExtension: url.pathExtension))]
        } ?? []

        return .result(value: DreamJournalEntryEntity(
            id: dream.id,
            title: generatedTitle?.isEmpty == false ? generatedTitle : nil,
            message: transcript,
            mediaItems: mediaItems,
            entryDate: dream.date
        ))
    }
}

struct RecordDreamIntentError: Error, CustomLocalizedStringResourceConvertible {
    static let notSaved = RecordDreamIntentError()

    var localizedStringResource: LocalizedStringResource {
        "The recording wasn’t saved, so no dream entry was created. Check microphone access, then try again."
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
    
    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog & ShowsSnippetIntent {
        let text = try DreamIntentRepository.recentEmotionSummary()
        let (latestDream, _) = try DreamIntentRepository.latestSummarySnapshot()
        return .result(
            value: text,
            dialog: IntentDialog(stringLiteral: text),
            snippetIntent: DreamSummarySnippetIntent(dream: latestDream)
        )
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

@available(iOS 26.0, *)
struct DreamSummarySnippetIntent: SnippetIntent {
    static let title: LocalizedStringResource = "Latest Dream Summary"
    @Parameter var dream: DreamEntryEntity?

    init() {}
    init(dream: DreamEntryEntity?) { self.dream = dream }

    @MainActor
    func perform() async throws -> some IntentResult & ShowsSnippetView {
        guard let selectedDream = dream else {
            return .result(view: DreamSummarySnippetView(dream: nil, imageData: nil))
        }
        let (snapshot, imageData) = try DreamIntentRepository.summarySnapshot(for: selectedDream.id)
        guard let snapshot else { return .result(view: DreamSummarySnippetView(dream: nil, imageData: nil)) }
        return .result(view: DreamSummarySnippetView(dream: snapshot, imageData: imageData))
    }
}

@available(iOS 26.0, *)
private struct DreamSummarySnippetView: View {
    let dream: DreamEntryEntity?
    let imageData: Data?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let imageData, let image = UIImage(data: imageData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 110)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .privacySensitive()
            }
            if let dream {
                Text("Latest Dream").font(.caption).foregroundStyle(.secondary)
                Text(dream.title).font(.headline).lineLimit(2)
                if let emotion = dream.emotions.first {
                    Label(emotion, systemImage: "heart.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Button(intent: OpenDreamIntent(dream: dream)) {
                    Label("View Dream", systemImage: "arrow.up.right.square")
                }
            } else {
                Text("No dreams yet").font(.headline)
                Text("Record a dream to see it here.").font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding()
        .privacySensitive()
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

    init() {}
    init(dream: DreamEntryEntity) { self.dream = dream }

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

@available(iOS 26.0, *)
@AppIntent(schema: .visualIntelligence.semanticContentSearch)
struct SearchDreamsVisualIntelligenceIntent: TargetContentProvidingIntent {
    static let title: LocalizedStringResource = "Search in Dorsal"
    static let description = IntentDescription("See more dreams related to what Visual Intelligence recognized.")
    static let supportedModes: IntentModes = .foreground(.immediate)
    static let authenticationPolicy: IntentAuthenticationPolicy = .requiresLocalDeviceAuthentication

    var semanticContent: SemanticContentDescriptor

    @MainActor
    func perform() async throws -> some IntentResult {
        return .result()
    }
}
