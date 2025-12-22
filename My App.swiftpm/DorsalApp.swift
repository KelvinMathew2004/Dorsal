import SwiftUI

@main
struct DorsalApp: App {
    @StateObject private var dreamStore = DreamStore()
    
    var body: some Scene {
        WindowGroup {
            TabView {
                RecordView(store: dreamStore)
                    .tabItem {
                        Label("Capture", systemImage: "mic.circle.fill")
                    }
                
                HistoryView(store: dreamStore)
                    .tabItem {
                        Label("Journal", systemImage: "book.pages.fill")
                    }
                
                StatsView(store: dreamStore)
                    .tabItem {
                        Label("Insights", systemImage: "chart.xyaxis.line")
                    }
            }
            .preferredColorScheme(.dark)
            .tint(Theme.accent)
        }
    }
}
