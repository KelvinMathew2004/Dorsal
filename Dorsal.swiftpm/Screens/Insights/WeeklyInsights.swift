import SwiftUI
import Charts

struct StatsView: View {
    @ObservedObject var store: DreamStore
    
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
                        
                        if store.dreams.isEmpty {
                            ContentUnavailableView(
                                "No Data Available",
                                systemImage: "chart.bar.xaxis",
                                description: Text("Record some dreams to see your insights.")
                            )
                            .frame(height: 400)
                        } else {
                            // Weekly Overview
                            if let insights = store.weeklyInsight {
                                VStack(alignment: .leading, spacing: 16) {
                                    Label("Overview", systemImage: "sparkles.rectangle.stack").font(.headline).foregroundStyle(.white.opacity(0.8))
                                    MagicCard(title: "Period Summary", icon: "calendar", color: .indigo) {
                                        VStack(alignment: .leading, spacing: 12) {
                                            Text(insights.periodOverview ?? "Generating...").fixedSize(horizontal: false, vertical: true)
                                            Divider().background(.white.opacity(0.2))
                                            HStack {
                                                Label((insights.dominantTheme ?? "Theme").capitalized, systemImage: "crown.fill")
                                                    .font(.caption.bold())
                                                    .foregroundStyle(.yellow)
                                                
                                                Spacer()
                                                
                                                let trend = insights.mentalHealthTrend ?? "Trend"
                                                Text(trend.prefix(1).uppercased() + trend.dropFirst())
                                                    .font(.caption)
                                                    .foregroundStyle(.white.opacity(0.7))
                                            }
                                        }
                                    }
                                    MagicCard(title: "General Advice", icon: "lightbulb.fill", color: .green) {
                                        Text(insights.strategicAdvice ?? "").italic()
                                    }
                                }
                                .padding(.horizontal)
                            }
                            
                            // Mental Health Trends - Clickable
                            VStack(alignment: .leading, spacing: 12) {
                                Label("Mental Health", systemImage: "brain.head.profile")
                                    .font(.headline).foregroundStyle(.white.opacity(0.8)).padding(.horizontal)
                                
                                NavigationLink(value: DreamMetric.anxiety) {
                                    ChartCard {
                                        Chart {
                                            ForEach(recentFatigue) { dream in
                                                LineMark(x: .value("Date", dream.date, unit: .day), y: .value("Anxiety", dream.extras?.anxietyLevel ?? 0)).foregroundStyle(.pink).interpolationMethod(.catmullRom)
                                                LineMark(x: .value("Date", dream.date, unit: .day), y: .value("Sentiment", dream.extras?.sentimentScore ?? 50)).foregroundStyle(.green).interpolationMethod(.catmullRom)
                                            }
                                        }
                                        .chartYScale(domain: 0...100)
                                        .chartXAxis { AxisMarks(format: .dateTime.month(.abbreviated).day()) }
                                        .frame(height: 200)
                                    } caption: {
                                        HStack {
                                            HStack(spacing: 16) {
                                                Label("Anxiety", systemImage: "circle.fill").foregroundStyle(.pink)
                                                Label("Sentiment", systemImage: "circle.fill").foregroundStyle(.green)
                                            }
                                            .font(.caption)
                                            Spacer()
                                        }
                                    }
                                }
                                .buttonStyle(PlainButtonStyle())
                                .padding(.horizontal)
                            }
                            
                            // Key Stats - Clickable Grid
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                                NavigationLink(value: DreamMetric.dreams) {
                                    StatCard(title: "Dreams", value: "\(totalDreams)", icon: "book.fill", color: .blue, showArrow: true)
                                        .contentShape(Rectangle()) // Ensure tap target is solid
                                }
                                .buttonStyle(PlainButtonStyle())

                                NavigationLink(value: DreamMetric.nightmares) {
                                    StatCard(title: "Nightmares", value: "\(nightmareCount)", icon: "exclamationmark.triangle.fill", color: .purple, showArrow: true)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(PlainButtonStyle())

                                NavigationLink(value: DreamMetric.lucidity) {
                                    StatCard(title: "Lucidity", value: "\(Int(avgLucidity))%", icon: "eye.fill", color: .cyan, showArrow: true)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(PlainButtonStyle())

                                NavigationLink(value: DreamMetric.positive) {
                                    StatCard(title: "Positive", value: "\(positiveDreams)", icon: "hand.thumbsup.fill", color: .green, showArrow: true)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                            .padding(.horizontal)
                            
                            VStack(alignment: .leading, spacing: 12) {
                                Label("Vocal Fatigue", systemImage: "battery.50")
                                    .font(.headline).foregroundStyle(.white.opacity(0.8)).padding(.horizontal)
                                
                                NavigationLink(value: DreamMetric.fatigue) {
                                    ChartCard {
                                        Chart {
                                            ForEach(recentFatigue) { dream in
                                                BarMark(x: .value("Date", dream.date, unit: .day), y: .value("Fatigue", dream.core?.voiceFatigue ?? 0))
                                                    .foregroundStyle(Color.red.gradient) // Red gradient to match detail view
                                            }
                                        }
                                        .chartXAxis { AxisMarks(format: .dateTime.month(.abbreviated).day()) }
                                        .chartYScale(domain: 0...100)
                                        .frame(height: 180)
                                    } caption: {
                                        HStack {
                                            Text("Higher bars indicate higher vocal fatigue.").font(.caption).foregroundStyle(.secondary)
                                            Spacer()
                                        }
                                    }
                                }
                                .buttonStyle(PlainButtonStyle())
                                .padding(.horizontal)
                            }
                            
                            // Memory Health - Clickable Rings
                            VStack(alignment: .leading, spacing: 12) {
                                Label("Memory Recall", systemImage: "memorychip")
                                    .font(.headline).foregroundStyle(.white.opacity(0.8)).padding(.horizontal)
                                
                                HStack(spacing: 16) {
                                    NavigationLink(value: DreamMetric.vividness) {
                                        RingView(percentage: Double(avgMetric { $0.extras?.vividnessScore ?? 0 }), title: "Vividness", color: .orange, showArrow: true)
                                            .frame(maxWidth: .infinity)
                                            .contentShape(Rectangle())
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    
                                    NavigationLink(value: DreamMetric.coherence) {
                                        RingView(percentage: Double(avgMetric { $0.extras?.coherenceScore ?? 0 }), title: "Coherence", color: .teal, showArrow: true)
                                            .frame(maxWidth: .infinity)
                                            .contentShape(Rectangle())
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                                .padding(.horizontal)
                            }
                        }
                        
                        Spacer(minLength: 50)
                    }
                    .padding(.top)
                }
                .scrollDisabled(store.isGeneratingInsights)
                .overlay {
                    if store.isGeneratingInsights {
                        ZStack {
                            Color.black.opacity(0.3)
                                .ignoresSafeArea()
                            
                            VStack(spacing: 16) {
                                ProgressView()
                                    .scaleEffect(1.5)
                                    .tint(.white)
                                Text("Analyzing...")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                            }
                            .padding(32)
                            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24))
                        }
                    }
                }
            }
            .navigationTitle("Weekly Insights")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        Task { await store.refreshWeeklyInsights() }
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .disabled(store.isGeneratingInsights)
                }
            }
            .navigationDestination(for: DreamMetric.self) { metric in
                TrendDetailView(metric: metric, store: store)
            }
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
