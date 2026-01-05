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
            RecordView(store: store)
                .tabItem { Label("Record", systemImage: "sparkles") }
                .tag(0)
            
            HistoryView(store: store)
                .tabItem { Label("Journal", systemImage: "book.pages.fill") }
                .tag(1)
            
            WeeklyInsightsView(store: store)
                .tabItem { Label("Insights", systemImage: "chart.xyaxis.line") }
                .tag(2)
                
            ProfileView(store: store)
                .tabItem { Label("Profile", systemImage: "person.crop.circle") }
                .tag(3)
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
