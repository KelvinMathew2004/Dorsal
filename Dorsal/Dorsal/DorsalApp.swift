import SwiftUI
import SwiftData
import AppIntents
import VisualIntelligence

@main
struct DorsalApp: App {
    @StateObject private var store = DreamStore.shared

    init() {
        DorsalShortcuts.updateAppShortcutParameters()
        RevenueCatManager.configure()
    }
    
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
            .onAppIntentExecution(OpenDorsalIntent.self) { intent in
                store.openSectionFromIntent(intent.target)
            }
            .onAppIntentExecution(SearchDreamsVisualIntelligenceIntent.self) { intent in
                store.searchDreamsFromIntent(intent.semanticContent.labels.first ?? "")
            }
            .onOpenURL { url in
                guard url.scheme == "dorsal" else { return }
                if url.host == "latest-dream" {
                    store.openDreamFromIntent()
                } else if url.host == "dream",
                          let idString = url.pathComponents.dropFirst().first,
                          let id = UUID(uuidString: idString) {
                    store.openDreamFromIntent(id: id)
                } else if url.host == "insights" {
                    store.openSectionFromIntent(.insights)
                } else if url.host == "record" {
                    store.openSectionFromIntent(.recorder)
                }
            }
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
                JournalView(store: store)
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
        .safeAreaInset(edge: .top) {
            if let message = store.persistenceError {
                VStack(spacing: 8) {
                    Text(message).font(.footnote)
                    Button("Retry Saving") { store.retryPendingSaves() }
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(.regularMaterial)
            }
        }
        .alert("Recording Interrupted", isPresented: Binding(
            get: { store.recordingError != nil },
            set: { if !$0 { store.recordingError = nil } }
        )) {
            Button("OK", role: .cancel) { store.recordingError = nil }
        } message: {
            Text(store.recordingError ?? "")
        }
        .onAppear {
            store.setContext(modelContext)
            Task { await RevenueCatManager.shared.refresh() }
            Task { await DreamAnalyzer.shared.prewarmModel() }
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
