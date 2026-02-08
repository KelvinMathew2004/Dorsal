import AppIntents
import Foundation
import SwiftUI

enum DorsalDestination: String, AppEnum {
    case record
    case journal
    case insights
    case profile

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Dorsal Destination")
    }

    static var caseDisplayRepresentations: [DorsalDestination: DisplayRepresentation] {
        [
            .record: DisplayRepresentation(title: "Record"),
            .journal: DisplayRepresentation(title: "Journal"),
            .insights: DisplayRepresentation(title: "Insights"),
            .profile: DisplayRepresentation(title: "Profile")
        ]
    }
}

struct OpenDorsalIntent: OpenIntent {
    static var title: LocalizedStringResource { "Open Dorsal" }
    static var openAppWhenRun: Bool { true }

    @Parameter(title: "Destination")
    var target: DorsalDestination

    @MainActor
    func perform() async throws -> some IntentResult {
        DreamStore.shared.openDestination(target)
        return .result()
    }
}

struct StartDreamRecordingIntent: AppIntent, AudioRecordingIntent {
    static var title: LocalizedStringResource { "Start Dream Recording" }
    static var description: IntentDescription { IntentDescription("Open Dorsal and begin recording a dream.") }
    static var openAppWhenRun: Bool { true }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let store = DreamStore.shared
        let result = store.startRecordingFromIntent()

        switch result {
        case .started:
            return .result(dialog: "Recording started in Dorsal.")
        case .alreadyRecording:
            return .result(dialog: "Dorsal is already recording.")
        case .busy:
            return .result(dialog: "Dorsal is processing a previous recording. Try again shortly.")
        case .noMicPermission:
            return .result(dialog: "Microphone access is required. Open Dorsal and enable it in Settings.")
        }
    }
}

struct DorsalShortcuts: AppShortcutsProvider {
    @AppShortcutsBuilder
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartDreamRecordingIntent(),
            phrases: [
                "Record a dream in \(.applicationName)",
                "Start a dream recording in \(.applicationName)",
                "Capture my dream in \(.applicationName)"
            ],
            shortTitle: "Record Dream",
            systemImageName: "mic.circle.fill"
        )
    }
}
