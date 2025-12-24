import SwiftUI
import SwiftData

struct HistoryView: View {
    @Query(sort: \SavedDream.date, order: .reverse) private var savedDreams: [SavedDream]
    
    // ModelContext is needed for deletion
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        NavigationStack {
            List {
                if savedDreams.isEmpty {
                    ContentUnavailableView("No Dreams Yet", systemImage: "moon.stars.fill", description: Text("Your dream journal is empty. Record a new dream to get started."))
                } else {
                    ForEach(savedDreams) { dream in
                        // Correctly passing the 'SavedDream' object to the destination view
                        NavigationLink(destination: DreamDetailView(dream: dream)) {
                            VStack(alignment: .leading) {
                                Text(dream.title)
                                    .font(.headline)
                                Text(dream.date, style: .date)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onDelete(perform: deleteDreams)
                }
            }
            .navigationTitle("Journal")
            #if os(iOS)
            .toolbar {
                EditButton()
            }
            #endif
        }
    }
    
    private func deleteDreams(at offsets: IndexSet) {
        for index in offsets {
             modelContext.delete(savedDreams[index])
        }
    }
}
