import SwiftUI
import Charts

struct StatsView: View {
    @ObservedObject var store: DreamStore
    
    // MARK: - Date Logic
    
    // Determines the fixed week interval (e.g., Sunday to Saturday) for the current date
    private var currentWeekInterval: DateInterval {
        let calendar = Calendar.current
        return calendar.dateInterval(of: .weekOfYear, for: Date()) ?? DateInterval(start: Date(), duration: 0)
    }
    
    // Filter dreams to only include those in the current fixed week
    private var weeklyDreams: [Dream] {
        store.dreams.filter { currentWeekInterval.contains($0.date) }
    }
    
    // MARK: - Computed Stats (Based on Fixed Week)
    
    var totalDreams: Int { weeklyDreams.count }
    
    var positiveDreams: Int {
        weeklyDreams.filter { ($0.extras?.sentimentScore ?? 50) > 60 }.count
    }
    
    var nightmareCount: Int {
        weeklyDreams.filter { $0.extras?.isNightmare ?? false }.count
    }
    
    var avgLucidity: Double {
        guard !weeklyDreams.isEmpty else { return 0 }
        let total = weeklyDreams.reduce(0) { $0 + ($1.extras?.lucidityScore ?? 0) }
        return Double(total) / Double(weeklyDreams.count)
    }
    
    // Helper struct for chart data
    struct DailyAggregate: Identifiable {
        let id = UUID()
        let date: Date
        let anxiety: Double
        let sentiment: Double
        let fatigue: Double
    }
    
    // Compute daily averages for the fixed week
    var weekAggregates: [DailyAggregate] {
        let calendar = Calendar.current
        let startOfWeek = currentWeekInterval.start
        var aggregates: [DailyAggregate] = []
        
        // Iterate through the 7 days of the fixed week
        for i in 0..<7 {
            if let date = calendar.date(byAdding: .day, value: i, to: startOfWeek) {
                let startOfDay = calendar.startOfDay(for: date)
                let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
                
                // Filter dreams for this specific day
                let dreamsForDay = store.dreams.filter { $0.date >= startOfDay && $0.date < endOfDay }
                
                // Only create a data point if dreams exist (aligns with "no zero dots" logic)
                if !dreamsForDay.isEmpty {
                    let totalAnxiety = dreamsForDay.reduce(0.0) { $0 + Double($1.extras?.anxietyLevel ?? 0) }
                    let totalSentiment = dreamsForDay.reduce(0.0) { $0 + Double($1.extras?.sentimentScore ?? 50) }
                    let totalFatigue = dreamsForDay.reduce(0.0) { $0 + Double($1.core?.voiceFatigue ?? 0) }
                    let count = Double(dreamsForDay.count)
                    
                    aggregates.append(DailyAggregate(
                        date: startOfDay,
                        anxiety: totalAnxiety / count,
                        sentiment: totalSentiment / count,
                        fatigue: totalFatigue / count
                    ))
                }
            }
        }
        return aggregates
    }
    
    // X-Axis domain for the charts to ensure the full week is visible
    var xAxisDomain: ClosedRange<Date> {
        let start = currentWeekInterval.start
        let end = currentWeekInterval.end
        return start...end
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.gradientBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        if store.dreams.isEmpty {
                            emptyStateView
                        } else {
                            if let insights = store.weeklyInsight {
                                weeklyOverviewSection(insights: insights)
                            }
                            mentalHealthSection
                            keyStatsGrid
                            vocalFatigueSection
                            memoryRecallSection
                        }
                        Spacer(minLength: 50)
                    }
                    .padding(.top)
                }
                .scrollDisabled(store.isGeneratingInsights)
                .overlay {
                    if store.isGeneratingInsights {
                        loadingOverlay
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
    
    // MARK: - Subviews
    
    private var emptyStateView: some View {
        ContentUnavailableView(
            "No Data Available",
            systemImage: "chart.bar.xaxis",
            description: Text("Record some dreams to see your insights.")
        )
        .frame(height: 400)
    }
    
    private var loadingOverlay: some View {
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
    
    private func weeklyOverviewSection(insights: WeeklyInsightResult) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Overview", systemImage: "sparkles.rectangle.stack")
                .font(.headline)
                .foregroundStyle(.white.opacity(0.8))
            
            MagicCard(title: "Period Summary", icon: "calendar", color: .indigo) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(insights.periodOverview ?? "Generating...")
                        .fixedSize(horizontal: false, vertical: true)
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
    
    private var mentalHealthSection: some View {
        // Use weekAggregates which is now based on fixed week logic
        let data = weekAggregates

        return VStack(alignment: .leading, spacing: 12) {
            Label("Mental Health", systemImage: "stethoscope")
                .font(.headline)
                .foregroundStyle(.white.opacity(0.8))
                .padding(.horizontal)
            
            NavigationLink(value: DreamMetric.anxiety) {
                ChartCard(content: {
                    Chart {
                        ForEach(data) { point in
                            // 1. ANXIETY AREA (Background)
                            AreaMark(
                                x: .value("Date", point.date, unit: .day),
                                yStart: .value("Baseline", 0),
                                yEnd: .value("Anxiety", point.anxiety),
                                series: .value("Metric", "Anxiety")
                            )
                            .interpolationMethod(.linear)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.pink.opacity(0.5), Color.pink.opacity(0)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )

                            // 2. SENTIMENT AREA (Background)
                            AreaMark(
                                x: .value("Date", point.date, unit: .day),
                                yStart: .value("Baseline", 0),
                                yEnd: .value("Sentiment", point.sentiment),
                                series: .value("Metric", "Sentiment")
                            )
                            .interpolationMethod(.linear)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.green.opacity(0.5), Color.green.opacity(0)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )

                            // 3. ANXIETY LINE (Foreground)
                            LineMark(
                                x: .value("Date", point.date, unit: .day),
                                y: .value("Anxiety", point.anxiety),
                                series: .value("Metric", "Anxiety")
                            )
                            .interpolationMethod(.linear)
                            .symbol(.circle)
                            .foregroundStyle(Color.pink.gradient)

                            // 4. SENTIMENT LINE (Foreground)
                            LineMark(
                                x: .value("Date", point.date, unit: .day),
                                y: .value("Sentiment", point.sentiment),
                                series: .value("Metric", "Sentiment")
                            )
                            .interpolationMethod(.linear)
                            .symbol(.circle)
                            .foregroundStyle(Color.green.gradient)
                        }
                    }
                    .chartYScale(domain: 0...100)
                    .chartXScale(domain: xAxisDomain) // Force X-Axis to show full fixed week
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .day)) { _ in
                            AxisGridLine()
                            AxisTick()
                            AxisValueLabel(format: .dateTime.weekday(.abbreviated), centered: true)
                        }
                    }
                    .frame(height: 200)
                }, caption: {
                    HStack(spacing: 16) {
                        Label("Anxiety", systemImage: "circle.fill").foregroundStyle(.pink)
                        Label("Sentiment", systemImage: "circle.fill").foregroundStyle(.green)
                        Spacer()
                    }
                    .font(.caption)
                })
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.horizontal)
        }
    }
    
    private var keyStatsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            NavigationLink(value: DreamMetric.dreams) {
                StatCard(title: "Dreams", value: "\(totalDreams)", icon: "book.fill", color: .blue, showArrow: true)
                    .contentShape(Rectangle())
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
    }
    
    private var vocalFatigueSection: some View {
        let data = weekAggregates
        
        return VStack(alignment: .leading, spacing: 12) {
            Label("Vocal Fatigue", systemImage: "battery.50")
                .font(.headline)
                .foregroundStyle(.white.opacity(0.8))
                .padding(.horizontal)
            
            NavigationLink(value: DreamMetric.fatigue) {
                ChartCard(content: {
                    Chart {
                        ForEach(data) { point in
                            
                            // Area first so Line sits on top
                            AreaMark(
                                x: .value("Date", point.date, unit: .day),
                                yStart: .value("Baseline", 0),
                                yEnd: .value("Fatigue", point.fatigue)
                            )
                            .interpolationMethod(.linear)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.red.opacity(0.4), .clear],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            
                            LineMark(
                                x: .value("Date", point.date, unit: .day),
                                y: .value("Fatigue", point.fatigue)
                            )
                            .foregroundStyle(.red.gradient)
                            .interpolationMethod(.linear)
                            .symbol(.circle)
                        }
                    }
                    .chartXScale(domain: xAxisDomain) // Force X-Axis to show full fixed week
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .day)) { _ in
                            AxisGridLine()
                            AxisTick()
                            AxisValueLabel(format: .dateTime.weekday(.abbreviated), centered: true)
                        }
                    }
                    .chartYScale(domain: 0...100)
                    .frame(height: 180)
                }, caption: {
                    HStack {
                        Text("Higher bars indicate higher vocal fatigue.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                })
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.horizontal)
        }
    }
    
    private var memoryRecallSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Memory Recall", systemImage: "memorychip")
                .font(.headline)
                .foregroundStyle(.white.opacity(0.8))
                .padding(.horizontal)
            
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
    
    // Helpers
    func avgMetric(_ keyPath: (Dream) -> Int) -> Int {
        guard !weeklyDreams.isEmpty else { return 0 }
        let total = weeklyDreams.reduce(0) { $0 + keyPath($1) }
        return total / weeklyDreams.count
    }
}
