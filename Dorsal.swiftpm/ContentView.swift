import SwiftUI

struct ContentView: View {
    @StateObject private var store = DreamStore()
    
    var body: some View {
        TabView(selection: $store.selectedTab) {
            RecordView(store: store)
                .tabItem {
                    Label("Record", systemImage: "sparkles")
                }
                .tag(0)
            
            HistoryView(store: store)
                .tabItem {
                    Label("Journal", systemImage: "book.pages.fill")
                }
                .tag(1)
            
            StatsView(store: store)
                .tabItem {
                    Label("Insights", systemImage: "chart.xyaxis.line")
                }
                .tag(2)
        }
        .preferredColorScheme(.dark)
        .tint(Theme.accent)
    }
}
