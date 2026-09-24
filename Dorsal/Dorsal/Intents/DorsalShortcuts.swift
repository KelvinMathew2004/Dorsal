import AppIntents

struct DorsalShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: RecordDreamIntent(),
            phrases: [
                "Record a dream in \(.applicationName)",
                "Log a dream with \(.applicationName)",
                "I had a dream \(.applicationName)"
            ],
            shortTitle: "Record Dream",
            systemImageName: "moon.zzz"
        )
        AppShortcut(
            intent: DreamSummaryIntent(),
            phrases: [
                "What did I dream about in \(.applicationName)",
                "Summarize my dreams in \(.applicationName)"
            ],
            shortTitle: "Dream Summary",
            systemImageName: "text.bubble"
        )
    }
}
