import SwiftUI
import SwiftData

@main
struct DorsalApp: App {
    @StateObject private var store = DreamStore()
    
    var body: some Scene {
        WindowGroup {
            ContentView(store: store)
                // Register models for persistence
                .modelContainer(for: [SavedDream.self, SavedWeeklyInsight.self])
        }
    }
}

struct ContentView: View {
    @ObservedObject var store: DreamStore
    @Environment(\.modelContext) var modelContext
    
    var body: some View {
        TabView(selection: $store.selectedTab) {
            RecordView(store: store)
                .tabItem { Label("Record", systemImage: "sparkles") }
                .tag(0)
            
            HistoryView(store: store)
                .tabItem { Label("Journal", systemImage: "book.pages.fill") }
                .tag(1)
            
            StatsView(store: store)
                .tabItem { Label("Insights", systemImage: "chart.xyaxis.line") }
                .tag(2)
        }
        .preferredColorScheme(.dark)
        .onAppear {
            store.setContext(modelContext)
            
            // Pre-warm the model
            Task {
                await DreamAnalyzer.shared.prewarm()
            }
        }
    }
}
