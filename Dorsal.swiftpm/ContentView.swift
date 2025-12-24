import SwiftUI

struct ContentView: View {
    
    @StateObject private var store = DreamStore()
    
    var body: some View {
        TabView(selection: $store.selectedTab) {
            
            // Pass the store to RecordView
            RecordView(store: store)
                .tabItem {
                    Label("Record", systemImage: "mic.circle.fill")
                }
                .tag(0)
            
            HistoryView()
                .tabItem {
                    Label("Journal", systemImage: "book.fill")
                }
                .tag(1)
            
            StatsView()
                .tabItem {
                    Label("Insights", systemImage: "chart.bar.fill")
                }
                .tag(2)
        }
        .environmentObject(store) // Make store available to other views if needed
    }
}
