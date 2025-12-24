import SwiftUI
import SwiftData
import Charts

struct StatsView: View {
    // Use SwiftData @Query instead of DreamStore if possible, or correct the EnvironmentObject
    @Query private var savedDreams: [SavedDream]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if savedDreams.isEmpty {
                        ContentUnavailableView("No Data Yet", systemImage: "chart.bar.xaxis", description: Text("Record some dreams to see your stats."))
                    } else {
                        // Sentiment Chart
                        Chart(savedDreams) { dream in
                            BarMark(
                                x: .value("Sentiment", dream.sentiment),
                                y: .value("Count", 1)
                            )
                            .foregroundStyle(by: .value("Sentiment", dream.sentiment))
                        }
                        .frame(height: 250)
                        .padding()
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                        
                        Text("Total Dreams: \(savedDreams.count)")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
            }
            .navigationTitle("Insights")
        }
    }
}
