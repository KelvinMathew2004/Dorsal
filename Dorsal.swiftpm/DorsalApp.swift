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
            Tab(value: 0) {
                RecordView(store: store)
            } label: {
                Label("Record", systemImage: "zzz")
                    .symbolColorRenderingMode(.gradient)
                    .labelStyle(iPhoneIconOnlyLabelStyle())
            }
            
            Tab(value: 1) {
                HistoryView(store: store)
            } label: {
                Label("Journal", systemImage: "book.pages.fill")
                    .symbolColorRenderingMode(.gradient)
                    .labelStyle(iPhoneIconOnlyLabelStyle())
            }
            
            Tab(value: 2) {
                WeeklyInsightsView(store: store)
            } label: {
                Label("Insights", systemImage: "chart.bar.xaxis.ascending.badge.clock")
                    .symbolColorRenderingMode(.gradient)
                    .labelStyle(iPhoneIconOnlyLabelStyle())
            }
            
            Tab(value: 3) {
                ProfileView(store: store)
            } label: {
                Label("Profile", systemImage: "person.crop.circle")
                    .symbolColorRenderingMode(.gradient)
                    .labelStyle(iPhoneIconOnlyLabelStyle())
            }
        }
        .tint(Theme.accent)
        .preferredColorScheme(.dark)
        .onAppear {
            store.setContext(modelContext)
            Task { DreamAnalyzer.shared.prewarmModel() }
        }
    }
}

struct iPhoneIconOnlyLabelStyle: LabelStyle {
    @Environment(\.horizontalSizeClass) var sizeClass
    
    func makeBody(configuration: Configuration) -> some View {
        if sizeClass == .compact {
            configuration.icon
        } else {
            Label(configuration)
        }
    }
}
