import SwiftUI
import Charts

struct StatsView: View {
    @ObservedObject var store: DreamStore
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bgStart.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 30) {
                        
                        // Header
                        VStack(alignment: .leading) {
                            Text("Your Sleep Mind")
                                .font(.title2.bold())
                                .foregroundStyle(.white)
                            Text("Recent patterns analysis")
                                .font(.caption)
                                .foregroundStyle(.gray)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        
                        // Chart 1: Sentiment Flow
                        GlassCard {
                            VStack(alignment: .leading) {
                                Text("Emotional Resilience")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                
                                Chart(store.dreams.sorted(by: { $0.date < $1.date })) { dream in
                                    LineMark(
                                        x: .value("Date", dream.date),
                                        y: .value("Sentiment", dream.sentimentScore)
                                    )
                                    .interpolationMethod(.catmullRom)
                                    .foregroundStyle(LinearGradient(colors: [.pink, Theme.accent], startPoint: .bottom, endPoint: .top))
                                    .symbol(by: .value("Type", "Sentiment"))
                                    
                                    AreaMark(
                                        x: .value("Date", dream.date),
                                        y: .value("Sentiment", dream.sentimentScore)
                                    )
                                    .foregroundStyle(LinearGradient(colors: [Theme.accent.opacity(0.3), .clear], startPoint: .top, endPoint: .bottom))
                                }
                                .frame(height: 200)
                                .chartYScale(domain: -1.0...1.0)
                            }
                        }
                        
                        // Chart 2: Entity Cloud (Simulated List)
                        GlassCard {
                            VStack(alignment: .leading, spacing: 15) {
                                Text("Common Themes")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                
                                FlowLayout(items: ["Flying", "Water", "Late", "School", "Forest", "Falling"], fontSize: 14)
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Insights")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
}
