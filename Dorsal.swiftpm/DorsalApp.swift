import SwiftUI
import SwiftData

@main
struct DorsalApp: App {
    @StateObject private var store = DreamStore()
    
    var body: some Scene {
        WindowGroup {
            Group {
                if store.isOnboardingComplete {
                    ContentView(store: store)
                        // Register models for persistence
                        .modelContainer(for: [SavedDream.self, SavedWeeklyInsight.self, SavedEntity.self])
                        .transition(.opacity)
                } else {
                    OnboardingView(store: store)
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut, value: store.isOnboardingComplete)
        }
    }
}

struct ContentView: View {
    @ObservedObject var store: DreamStore
    @Environment(\.modelContext) var modelContext
    
    var body: some View {
        TabView(selection: $store.selectedTab) {
            Tab("Record", systemImage: "sparkles", value: 0) {
                RecordView(store: store)
            }
            
            Tab("Journal", systemImage: "book.pages.fill", value: 1) {
                HistoryView(store: store)
            }
            
            Tab("Insights", systemImage: "chart.xyaxis.line", value: 2) {
                WeeklyInsightsView(store: store)
            }
            
            Tab("Profile", systemImage: "person.crop.circle", value: 3) {
                ProfileView(store: store)
            }
        }
        .tint(Theme.accent)
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
