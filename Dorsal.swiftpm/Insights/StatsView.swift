import SwiftUI
import Charts

struct StatsView: View {
    @ObservedObject var store: DreamStore
    
    private var totalDreams: Int { store.dreams.count }
    private var positiveDreams: Int { store.dreams.filter { $0.isPositive }.count }
    private var avgFatigue: Double {
        let count = Double(max(1, totalDreams))
        return store.dreams.reduce(0) { $0 + $1.voiceFatigue } / count
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.gradientBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        
                        SentimentChart(dreams: store.dreams)
                        
                        StatsGrid(
                            total: totalDreams,
                            positive: positiveDreams,
                            fatigue: avgFatigue
                        )
                        
                        RecurringThemes(
                            tags: Array(store.allTags.prefix(8)),
                            onSelect: { tag in store.selectTagFilter(tag) }
                        )
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Insights")
        }
    }
}

struct SentimentChart: View {
    let dreams: [Dream]
    
    var body: some View {
        let content = VStack(alignment: .leading, spacing: 20) {
            Label("Sentiment Flow", systemImage: "waveform.path.ecg")
                .font(.headline)
                .foregroundStyle(Theme.accent)
            
            Chart(dreams.sorted(by: { $0.date < $1.date })) { dream in
                LineMark(
                    x: .value("Date", dream.date),
                    y: .value("Sentiment", dream.sentimentScore)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(Gradient(colors: [.pink, Theme.secondary]))
                .symbol(.circle)
                
                AreaMark(
                    x: .value("Date", dream.date),
                    y: .value("Sentiment", dream.sentimentScore)
                )
                .foregroundStyle(Gradient(colors: [Theme.secondary.opacity(0.3), .clear]))
            }
            .frame(height: 200)
            .chartYScale(domain: -1.0...1.0)
        }
        .padding(24)
        
        if #available(iOS 26, *) {
            content.glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24))
        } else {
            content
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
                .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.1), lineWidth: 1))
        }
    }
}

struct StatsGrid: View {
    let total: Int
    let positive: Int
    let fatigue: Double
    
    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            StatItem(icon: "book.closed.fill", value: "\(total)", label: "Total")
            StatItem(icon: "sparkles", value: "\(positive)", label: "Positive", color: .yellow)
            StatItem(icon: "waveform", value: String(format: "%.0f%%", fatigue * 100), label: "Fatigue", color: .orange)
            StatItem(icon: "brain.head.profile", value: "Low", label: "Lucidity", color: .purple)
        }
    }
}

struct RecurringThemes: View {
    let tags: [String]
    let onSelect: (String) -> Void
    
    var body: some View {
        let content = VStack(alignment: .leading, spacing: 16) {
            Text("Recurring Symbols")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            FlowLayout {
                ForEach(tags, id: \.self) { tag in
                    if #available(iOS 26, *) {
                        Button(tag) { onSelect(tag) }
                            .buttonStyle(.glass)
                    } else {
                        Button(tag) { onSelect(tag) }
                            .buttonStyle(.bordered)
                            .tint(.secondary)
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(24)
        
        if #available(iOS 26, *) {
            content.glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24))
        } else {
            content
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
                .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.1), lineWidth: 1))
        }
    }
}

struct StatItem: View {
    let icon: String
    let value: String
    let label: String
    var color: Color = .white
    
    var body: some View {
        let content = VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 40, height: 40)
                .background(color.opacity(0.1), in: .circle)
            
            Text(value)
                .font(.title3.bold())
                .foregroundStyle(.primary)
            
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        
        if #available(iOS 26, *) {
            content.glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
        } else {
            content.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.1), lineWidth: 1))
        }
    }
}
