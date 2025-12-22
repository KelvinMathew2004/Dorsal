import SwiftUI

@main
struct DorsalApp: App {
    @StateObject private var dreamStore = DreamStore()
    
    var body: some Scene {
        WindowGroup {
            TabView(selection: $dreamStore.selectedTab) {
                RecordView(store: dreamStore)
                    .tabItem {
                        Label("Capture", systemImage: "mic.circle.fill")
                    }
                    .tag(0)
                
                HistoryView(store: dreamStore)
                    .tabItem {
                        Label("Journal", systemImage: "book.pages.fill")
                    }
                    .tag(1)
                
                StatsView(store: dreamStore)
                    .tabItem {
                        Label("Insights", systemImage: "chart.xyaxis.line")
                    }
                    .tag(2)
            }
            .preferredColorScheme(.dark)
            .tint(Theme.accent)
        }
    }
}
