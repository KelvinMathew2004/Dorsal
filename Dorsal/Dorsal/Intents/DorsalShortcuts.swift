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
        AppShortcut(intent: ViewLatestDreamIntent(),
                    phrases: ["Open my latest dream in \(.applicationName)"],
                    shortTitle: "Latest Dream", systemImageName: "book.pages")
        AppShortcut(intent: CheckTrendsIntent(),
                    phrases: ["Show my dream trends in \(.applicationName)"],
                    shortTitle: "Dream Trends", systemImageName: "chart.bar.xaxis")
        AppShortcut(intent: SearchDreamsIntent(),
                    phrases: ["Search my dreams in \(.applicationName)"],
                    shortTitle: "Search Dreams", systemImageName: "magnifyingglass")
        AppShortcut(intent: OpenDorsalIntent(),
                    phrases: ["Open \(\.$target) in \(.applicationName)"],
                    shortTitle: "Open Section", systemImageName: "square.grid.2x2")
        AppShortcut(intent: OpenDreamIntent(),
                    phrases: ["Open \(\.$dream) in \(.applicationName)"],
                    shortTitle: "Open Dream", systemImageName: "book.closed")
    }
}
