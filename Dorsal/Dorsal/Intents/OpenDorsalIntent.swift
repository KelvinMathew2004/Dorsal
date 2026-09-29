import AppIntents

// Compiled into both the app and its control extension. SwiftUI in the app
// handles navigation; the extension never opens or copies the private journal.
struct OpenDorsalIntent: OpenIntent, TargetContentProvidingIntent {
    static let title: LocalizedStringResource = "Open Dorsal Section"
    static let description = IntentDescription("Open the recorder, journal, insights, or profile in Dorsal")
    static let supportedModes: IntentModes = .foreground(.immediate)
    static let authenticationPolicy: IntentAuthenticationPolicy = .requiresLocalDeviceAuthentication

    @Parameter(title: "Section") var target: DorsalSection
    static var parameterSummary: some ParameterSummary { Summary("Open \(\.$target)") }

    init() {}
    init(target: DorsalSection) { self.target = target }
}

struct StopDreamRecordingIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Stop and Save Dream Recording"
    static let description = IntentDescription("Return to Dorsal and stop the active dream recording.")

    @MainActor
    func perform() async throws -> some IntentResult {
        #if DORSAL_WIDGET_EXTENSION
        .result()
        #else
        await DreamStore.shared.stopRecordingFromLiveActivity()
        return .result()
        #endif
    }
}

@available(iOS 27.0, *)
struct StopAndAnalyzeDreamRecordingIntent: AppIntent, LongRunningIntent, CancellableIntent {
    static let title: LocalizedStringResource = "Stop Recording and Analyze Dream"
    static let description = IntentDescription("Save the active dream recording and analyze it in the background.")
    static let supportedModes: IntentModes = .background
    static let allowedExecutionTargets: IntentExecutionTargets = .main

    func perform() async throws -> some IntentResult {
        #if DORSAL_WIDGET_EXTENSION
        // The system routes this intent to the app target; this copy provides its widget metadata.
        return .result()
        #else
        progress.totalUnitCount = 100
        progress.completedUnitCount = 0
        progress.localizedDescription = "Saving your dream"
        progress.localizedAdditionalDescription = "Finishing the recording"

        let analysisCompleted = try await performBackgroundTask {
            await DreamStore.shared.stopRecordingAndAnalyzeInBackground(progress: progress)
        } onCancel: { reason in
            // The recording is persisted before analysis begins, so cancellation leaves it retryable.
            progress.localizedDescription = reason == .userCancelled ? "Analysis stopped" : "Analysis paused"
            progress.localizedAdditionalDescription = "Your saved dream is ready to retry in Dorsal"
        }

        let message = analysisCompleted
            ? "Your dream was saved and analyzed."
            : "Dorsal couldn’t finish the recording or analysis. Open the app to check your saved dream and retry if needed."
        return .result(dialog: IntentDialog(stringLiteral: message))
        #endif
    }
}

nonisolated enum DorsalSection: String, AppEnum {
    case recorder, journal, insights, profile

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Dorsal Section")
    static let caseDisplayRepresentations: [DorsalSection: DisplayRepresentation] = [
        .recorder: "Recorder", .journal: "Journal", .insights: "Insights", .profile: "Profile"
    ]
}
