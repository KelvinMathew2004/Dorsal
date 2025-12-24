import SwiftUI
import Charts

struct StatsView: View {
    @ObservedObject var store: DreamStore
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.gradientBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        
                        // NEW: Therapeutic Insights Section
                        if !store.insights.isEmpty {
                            VStack(alignment: .leading, spacing: 16) {
                                Label("Therapeutic Insights", systemImage: "brain.head.profile")
                                    .font(.headline)
                                    .foregroundStyle(.purple)
                                    .padding(.horizontal)
                                
                                ForEach(store.insights) { insight in
                                    InsightCard(insight: insight)
                                }
                            }
                        }
                        
                        SentimentChart(dreams: store.dreams)
                        
                        RecurringThemes(
                            tags: Array(store.allTags.prefix(8)),
                            onSelect: { tag in
                                store.selectedTab = 1
                                store.jumpToFilter(type: "tag", value: tag)
                            }
                        )
                    }
                    .padding(.vertical, 16)
                }
            }
            .navigationTitle("Insights")
        }
    }
}

struct InsightCard: View {
    let insight: TherapeuticInsight
    
    var body: some View {
        let content = VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(.yellow)
                Text(insight.title)
                    .font(.headline)
                Spacer()
            }
            
            Text(insight.observation)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Text(insight.suggestion)
                .font(.body)
                .foregroundStyle(.primary)
                .padding(.top, 4)
        }
        .padding(20)
        
        if #available(iOS 26, *) {
            content.glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20))
                .padding(.horizontal)
        } else {
            content
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
                .padding(.horizontal)
        }
    }
}

// ... (Existing SentimentChart and RecurringThemes remain, ensuring they compile)
struct SentimentChart: View {
    let dreams: [Dream]
    var body: some View {
        let content = VStack(alignment: .leading, spacing: 20) {
            Label("Sentiment Flow", systemImage: "waveform.path.ecg")
                .font(.headline)
                .foregroundStyle(Theme.accent)
            
            if dreams.isEmpty {
                Text("Record more dreams to see data.")
                    .foregroundStyle(.secondary)
                    .frame(height: 200)
                    .frame(maxWidth: .infinity)
            } else {
                Chart(dreams.sorted(by: { $0.date < $1.date })) { dream in
                    LineMark(x: .value("Date", dream.date), y: .value("Sentiment", dream.sentimentScore))
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(Gradient(colors: [.pink, Theme.secondary]))
                }
                .frame(height: 200)
                .chartYScale(domain: -1.0...1.0)
            }
        }
        .padding(24)
        content.glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24))
            .padding(.horizontal)
    }
}

struct RecurringThemes: View {
    let tags: [String]
    let onSelect: (String) -> Void
    var body: some View {
        VStack(alignment: .leading) {
            Text("Recurring Symbols").font(.headline).foregroundStyle(.secondary).padding(.horizontal)
            GlassEffectContainer {
                FlowLayout {
                    ForEach(tags, id: \.self) { tag in
                        Button(tag) { onSelect(tag) }
                        .buttonStyle(.glassProminent)
                        .foregroundColor(.secondary)
                        .tint(.secondary.opacity(0.2))
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}
