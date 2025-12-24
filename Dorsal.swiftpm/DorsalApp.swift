import SwiftUI
import SwiftData

@main
struct DorsalApp: App {
    
    @State private var analyzer = DreamAnalyzer()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(analyzer)
                .modelContainer(for: SavedDream.self)
        }
    }
}
