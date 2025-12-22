import SwiftUI
import Charts

struct StatsView: View {
    @ObservedObject var store: DreamStore
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.gradientBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 25) {
                        
                        // Header
                        VStack(alignment: .leading) {
                            Text("The Subconscious")
                                .font(.title)
                                .bold()
                                .foregroundStyle(.white)
                            Text("Pattern recognition & trends")
                                .font(.caption)
                                .foregroundStyle(.gray)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        
                        // 1. Emotional Stability Chart
                        GlassCard {
                            VStack(alignment: .leading, spacing: 15) {
                                Text("Sentiment Variance")
                                    .font(.headline)
                                    .foregroundStyle(Theme.accent)
                                
                                Chart(store.dreams.sorted(by: { $0.date < $1.date })) { dream in
                                    LineMark(
                                        x: .value("Date", dream.date),
                                        y: .value("Sentiment", dream.sentimentScore)
                                    )
                                    .interpolationMethod(.catmullRom)
                                    .foregroundStyle(Gradient(colors: [.pink, Theme.secondary]))
                                    
                                    AreaMark(
                                        x: .value("Date", dream.date),
                                        y: .value("Sentiment", dream.sentimentScore)
                                    )
                                    .foregroundStyle(Gradient(colors: [Theme.secondary.opacity(0.3), .clear]))
                                }
                                .frame(height: 220)
                                .chartYScale(domain: -1.0...1.0)
                            }
                        }
                        
                        // 2. Quick Stats Grid
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 15) {
                            let totalDreams = store.dreams.count
                            let positiveDreams = store.dreams.filter { $0.sentimentScore > 0 }.count
                            let avgFatigue = store.dreams.reduce(0) { $0 + $1.voiceFatigue } / Double(max(1, totalDreams))
                            
                            StatBox(icon: "book.closed", title: "Total Entries", value: "\(totalDreams)", color: .white)
                            StatBox(icon: "star.fill", title: "Positive", value: "\(positiveDreams)", color: .yellow)
                            StatBox(icon: "waveform", title: "Avg Fatigue", value: String(format: "%.0f%%", avgFatigue * 100), color: .orange)
                            StatBox(icon: "moon.stars.fill", title: "Lucidity", value: "Low", color: .purple) // Placeholder logic
                        }
                        .padding(.horizontal)
                        
                        // 3. Recurring Entities
                        GlassCard {
                            VStack(alignment: .leading, spacing: 15) {
                                Text("Recurring Symbols")
                                    .font(.headline)
                                    .foregroundStyle(Theme.accent)
                                
                                FlowLayout(items: Array(store.allTags.prefix(10))) { tag in
                                    store.selectTagFilter(tag)
                                }
                            }
                        }
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Insights")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    struct StatBox: View {
        let icon: String
        let title: String
        let value: String
        let color: Color
        
        var body: some View {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)
                    .frame(width: 45, height: 45)
                    .background(color.opacity(0.15))
                    .clipShape(Circle())
                
                VStack(spacing: 2) {
                    Text(value)
                        .font(.title3.bold())
                        .foregroundStyle(.white)
                    Text(title)
                        .font(.caption2)
                        .foregroundStyle(.gray.opacity(0.8))
                        .textCase(.uppercase)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(.ultraThinMaterial)
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.1), lineWidth: 1))
        }
    }
}
