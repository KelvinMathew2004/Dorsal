import SwiftUI
import Charts

struct StatsView: View {
    @ObservedObject var store: DreamStore
    
    // Computed Metrics
    var totalDreams: Int { store.dreams.count }
    var positiveDreams: Int { store.dreams.filter { ($0.extras?.sentimentScore ?? 50) > 60 }.count }
    var nightmareCount: Int { store.dreams.filter { $0.extras?.isNightmare ?? false }.count }
    var avgLucidity: Double {
        guard !store.dreams.isEmpty else { return 0 }
        let total = store.dreams.reduce(0) { $0 + ($1.extras?.lucidityScore ?? 0) }
        return Double(total) / Double(store.dreams.count)
    }
    var recentFatigue: [Dream] { store.dreams.prefix(7).reversed() }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.gradientBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        
                        // Header Title (Big, not inline)
                        HStack {
                            Text("Insights")
                                .font(.largeTitle.bold())
                                .foregroundStyle(.white)
                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.top, 20)
                        
                        if store.dreams.isEmpty {
                            ContentUnavailableView(
                                "No Data Available",
                                systemImage: "chart.bar.xaxis",
                                description: Text("Record some dreams to see your insights.")
                            )
                            .frame(height: 400)
                        } else {
                            
                            // MARK: - AI Weekly Overview
                            if let insights = store.weeklyInsight {
                                VStack(alignment: .leading, spacing: 16) {
                                    Label("Weekly Overview", systemImage: "sparkles.rectangle.stack")
                                        .font(.headline)
                                        .foregroundStyle(.white)
                                    
                                    MagicCard(title: "Period Summary", icon: "calendar", color: .indigo) {
                                        VStack(alignment: .leading, spacing: 12) {
                                            // FIX: Unwrap optionals
                                            Text(insights.periodOverview ?? "Generating summary...")
                                                .fixedSize(horizontal: false, vertical: true)
                                            
                                            Divider().background(.white.opacity(0.2))
                                            
                                            HStack {
                                                Label(insights.dominantTheme ?? "Theme", systemImage: "crown.fill")
                                                    .font(.caption.bold())
                                                    .foregroundStyle(.yellow)
                                                Spacer()
                                                Text(insights.mentalHealthTrend ?? "Trend Analysis")
                                                    .font(.caption)
                                                    .foregroundStyle(.white.opacity(0.7))
                                            }
                                        }
                                    }
                                    
                                    MagicCard(title: "Strategic Advice", icon: "lightbulb.fill", color: .yellow) {
                                        Text(insights.strategicAdvice ?? "No advice available.")
                                            .italic()
                                    }
                                }
                                .padding(.horizontal)
                                .transition(.move(edge: .top).combined(with: .opacity))
                            } else if store.isGeneratingInsights {
                                HStack {
                                    ProgressView().tint(.white)
                                    Text("Analyzing weekly trends...").font(.caption).foregroundStyle(.white.opacity(0.8))
                                }
                                .frame(maxWidth: .infinity).padding().background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12)).padding(.horizontal)
                            } else if !store.dreams.isEmpty {
                                Button { Task { await store.refreshWeeklyInsights() } } label: {
                                    Label("Generate Weekly Insights", systemImage: "wand.and.stars")
                                        .frame(maxWidth: .infinity).padding().background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12)).foregroundStyle(.white)
                                }
                                .padding(.horizontal)
                            }
                            
                            // MARK: - Mental Health Trends
                            VStack(alignment: .leading, spacing: 12) {
                                Label("Mental Health Trends", systemImage: "brain.head.profile")
                                    .font(.headline)
                                    .foregroundStyle(.white.opacity(0.8))
                                    .padding(.horizontal)
                                
                                ChartCard {
                                    Chart {
                                        ForEach(recentFatigue) { dream in
                                            LineMark(
                                                x: .value("Date", dream.date, unit: .day),
                                                y: .value("Anxiety", dream.extras?.anxietyLevel ?? 0)
                                            )
                                            .foregroundStyle(.pink)
                                            .interpolationMethod(.catmullRom)
                                            
                                            LineMark(
                                                x: .value("Date", dream.date, unit: .day),
                                                y: .value("Sentiment", dream.extras?.sentimentScore ?? 50)
                                            )
                                            .foregroundStyle(.green)
                                            .interpolationMethod(.catmullRom)
                                        }
                                    }
                                    .chartYScale(domain: 0...100)
                                    .frame(height: 200)
                                } caption: {
                                    HStack(spacing: 16) {
                                        Label("Anxiety", systemImage: "circle.fill").foregroundStyle(.pink)
                                        Label("Sentiment", systemImage: "circle.fill").foregroundStyle(.green)
                                    }
                                    .font(.caption)
                                }
                            }
                            
                            // MARK: - Key Stats
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                                StatCard(title: "Total Entries", value: "\(totalDreams)", icon: "book.fill", color: .blue)
                                StatCard(title: "Nightmares", value: "\(nightmareCount)", icon: "exclamationmark.triangle.fill", color: .purple)
                                StatCard(title: "Avg Lucidity", value: "\(Int(avgLucidity))%", icon: "eye.fill", color: .cyan)
                                StatCard(title: "Positive Dreams", value: "\(positiveDreams)", icon: "hand.thumbsup.fill", color: .green)
                            }
                            .padding(.horizontal)
                            
                            // MARK: - Sleep Fatigue
                            VStack(alignment: .leading, spacing: 12) {
                                Label("Sleep Fatigue", systemImage: "waveform.path.ecg")
                                    .font(.headline)
                                    .foregroundStyle(.white.opacity(0.8))
                                    .padding(.horizontal)
                                
                                ChartCard {
                                    Chart {
                                        ForEach(recentFatigue) { dream in
                                            BarMark(
                                                x: .value("Date", dream.date, unit: .day),
                                                y: .value("Fatigue", dream.core?.voiceFatigue ?? 0)
                                            )
                                            .foregroundStyle(gradient(for: dream.core?.voiceFatigue ?? 0))
                                        }
                                    }
                                    .frame(height: 180)
                                } caption: {
                                    Text("Higher bars indicate higher vocal fatigue.").font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            
                            // MARK: - Memory Health
                            VStack(alignment: .leading, spacing: 12) {
                                Label("Memory Recall & Coherence", systemImage: "memorychip")
                                    .font(.headline)
                                    .foregroundStyle(.white.opacity(0.8))
                                    .padding(.horizontal)
                                
                                HStack(spacing: 16) {
                                    RingView(percentage: Double(avgMetric { $0.extras?.vividnessScore ?? 0 }), title: "Vividness", color: .orange)
                                    RingView(percentage: Double(avgMetric { $0.extras?.coherenceScore ?? 0 }), title: "Coherence", color: .teal)
                                }
                                .padding(.horizontal)
                            }
                        }
                        
                        Spacer(minLength: 50)
                    }
                    .padding(.top)
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                if store.weeklyInsight == nil && !store.dreams.isEmpty {
                    Task { await store.refreshWeeklyInsights() }
                }
            }
        }
    }
    
    // Helpers
    func avgMetric(_ keyPath: (Dream) -> Int) -> Int {
        guard !store.dreams.isEmpty else { return 0 }
        let total = store.dreams.reduce(0) { $0 + keyPath($1) }
        return total / store.dreams.count
    }
    
    func gradient(for score: Int) -> LinearGradient {
        let color = score > 70 ? Color.red : (score > 40 ? Color.yellow : Color.blue)
        return LinearGradient(colors: [color.opacity(0.8), color.opacity(0.3)], startPoint: .top, endPoint: .bottom)
    }
}
