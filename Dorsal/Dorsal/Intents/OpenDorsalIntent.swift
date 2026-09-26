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

nonisolated enum DorsalSection: String, AppEnum {
    case recorder, journal, insights, profile

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Dorsal Section")
    static let caseDisplayRepresentations: [DorsalSection: DisplayRepresentation] = [
        .recorder: "Recorder", .journal: "Journal", .insights: "Insights", .profile: "Profile"
    ]
}
