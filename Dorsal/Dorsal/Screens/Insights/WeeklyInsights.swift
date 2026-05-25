import SwiftUI
import Charts

struct WeeklyInsightsView: View {
    @ObservedObject var store: DreamStore
    
    // MARK: - Animation & Interaction State
    @Namespace private var namespace
    @State private var selectedInsight: WeeklyInsightType?
    
    // Analysis Animation State
    @State private var currentAnalysisIconIndex = 0
    private let analysisIcons: [(name: String, color: Color)] = [
        ("sparkles.rectangle.stack", .indigo),      // Overview
        ("lightbulb.fill", .green),                 // Advice
        ("stethoscope", .pink),                     // Mental Health
        ("book.fill", .blue),                       // Dreams Count
        ("exclamationmark.triangle.fill", .purple), // Nightmares
        ("battery.50", .red),                       // Fatigue
        ("memorychip", .orange)                     // Memory Recall
    ]
    
    enum WeeklyInsightType: String, Identifiable {
        case overview = "Overview"
        case advice = "General Advice"
        var id: String { rawValue }
    }
    
    // MARK: - Date Logic
    
    private var currentWeekInterval: DateInterval {
        var calendar = Calendar.current
        calendar.firstWeekday = 2
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
        // FIXED: Use date as stable ID instead of UUID() to prevent chart flashing
        var id: Date { date }
        let date: Date
        let anxiety: Double
        let sentiment: Double
        let fatigue: Double
    }
    
    // Compute daily averages for the fixed week
    var weekAggregates: [DailyAggregate] {
        var calendar = Calendar.current
        calendar.firstWeekday = 2 // Ensure consistency with interval
        let startOfWeek = currentWeekInterval.start
        var aggregates: [DailyAggregate] = []
        
        // Iterate through the 7 days of the fixed week
        for i in 0..<7 {
            if let date = calendar.date(byAdding: .day, value: i, to: startOfWeek) {
                let startOfDay = calendar.startOfDay(for: date)
                let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
                
                // Filter dreams for this specific day
                let dreamsForDay = store.dreams.filter { $0.date >= startOfDay && $0.date < endOfDay }
                
                // Only create a data point if dreams exist
                if !dreamsForDay.isEmpty {
                    let totalAnxiety = dreamsForDay.reduce(0.0) { $0 + Double($1.extras?.anxietyLevel ?? 0) }
                    let totalSentiment = dreamsForDay.reduce(0.0) { $0 + Double($1.extras?.sentimentScore ?? 50) }
                    let totalFatigue = dreamsForDay.reduce(0.0) { $0 + Double($1.voiceFatigue ?? 0) }
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
    
    var xAxisDomain: ClosedRange<Date> {
        let start = currentWeekInterval.start
        let end = currentWeekInterval.end
        return start...end
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.gradientBackground(.accent)
                    .ignoresSafeArea()
                
                // MARK: - Main Scroll Content
                ScrollView {
                    VStack(spacing: 24) {
                        if weeklyDreams.isEmpty {
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
                    .padding()
                }
                .scrollIndicators(.hidden)
                .scrollDisabled(store.isGeneratingInsights || selectedInsight != nil)
                .blur(radius: selectedInsight != nil ? 10 : 0) // Darken background when expanded
                .overlay {
                    if store.isGeneratingInsights {
                        loadingOverlay
                    }
                }
                
                // MARK: - Detail View Overlay
                if let type = selectedInsight, let insights = store.weeklyInsight {
                    WeeklyInsightDetailView(
                        store: store, // Added store
                        insights: insights,
                        weeklyDreams: weeklyDreams, // Pass filtered dreams for context
                        type: type,
                        namespace: namespace,
                        selectedInsight: $selectedInsight
                    )
                    .zIndex(100)
                }
            }
            .navigationTitle("Weekly Insights")
            .navigationBarTitleColor(Theme.accent)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if !store.isGeneratingInsights && selectedInsight == nil {
                        Button(action: {
                            Task { await store.refreshWeeklyInsights() }
                        }) {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
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
            description: Text("Record some dreams this week to see your insights.")
        )
        .frame(height: 400)
    }
    
    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 40) {
                Image(systemName: analysisIcons[currentAnalysisIconIndex].name)
                    .font(.system(size: 48, weight: .semibold))
                    .foregroundStyle(analysisIcons[currentAnalysisIconIndex].color)
                    .symbolRenderingMode(.hierarchical)
                    .symbolColorRenderingMode(.gradient)
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: 64, height: 64)
                
                Text("Analyzing Week...")
                    .font(.headline)
                    .foregroundStyle(.white)
            }
            .padding(40)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24))
        }
        .onAppear {
            currentAnalysisIconIndex = 0
        }
        .task {
            // Loop for animation
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 800_000_000) // 0.8 seconds
                if !store.isGeneratingInsights { break }
                
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    currentAnalysisIconIndex = (currentAnalysisIconIndex + 1) % analysisIcons.count
                }
            }
        }
    }
    
    private func weeklyOverviewSection(insights: WeeklyInsightResult) -> some View {
        VStack(spacing: 16) {
            insightCardRow(type: .overview, insights: insights)
            insightCardRow(type: .advice, insights: insights)
        }
    }
    
    @ViewBuilder
    func insightCardRow(type: WeeklyInsightType, insights: WeeklyInsightResult) -> some View {
        ZStack {
            // 1. Ghost Container (Invisible placeholder for layout)
            if !store.isGeneratingInsights {
                WeeklyInsightCard(type: type, insights: insights, isExpanded: false)
                    .opacity(0)
            }
            
            // 2. Interactive Card (Matched Geometry Source)
            if selectedInsight != type {
                Button {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        selectedInsight = type
                    }
                } label: {
                    WeeklyInsightCard(type: type, insights: insights, isExpanded: false)
                        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 24))
                        .matchedGeometryEffect(id: "weekly_bg_\(type.id)", in: namespace)
                }
                .buttonStyle(.plain)
                .transition(.identity)
            }
        }
    }
    
    private var mentalHealthSection: some View {
        let data = weekAggregates

        return VStack(alignment: .leading, spacing: 12) {
            Label("Mental Health", systemImage: "stethoscope")
                .font(.headline)
                .foregroundStyle(Theme.secondary)
                .symbolRenderingMode(.palette)
                .symbolColorRenderingMode(.gradient)
                .padding(.horizontal)
            
            NavigationLink(value: DreamMetric.anxiety) {
                PreviewChartCard(content: {
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
                            .symbol{
                                Circle()
                                    .fill(.pink.gradient)
                                    .frame(width: 8, height: 8)
                            }
                            .foregroundStyle(Color.pink.gradient)

                            // 4. SENTIMENT LINE (Foreground)
                            LineMark(
                                x: .value("Date", point.date, unit: .day),
                                y: .value("Sentiment", point.sentiment),
                                series: .value("Metric", "Sentiment")
                            )
                            .interpolationMethod(.linear)
                            .symbol{
                                Circle()
                                    .fill(.green.gradient)
                                    .frame(width: 8, height: 8)
                            }
                            .foregroundStyle(Color.green.gradient)
                        }
                    }
                    .chartYScale(domain: 0...100)
                    .chartXScale(domain: xAxisDomain)
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .day)) { _ in
                            AxisTick()
                            AxisValueLabel(format: .dateTime.weekday(.abbreviated), centered: true)
                        }
                    }
                    .chartYAxis {
                        AxisMarks { _ in
                            AxisTick()
                            AxisValueLabel()
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
        }
    }
    
    private var keyStatsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)],
        spacing: 16) {
            NavigationLink(value: DreamMetric.dreams) {
                StatCard(title: "Dreams", value: "\(totalDreams)", icon: "book.fill", color: .blue, showArrow: true)
                    .contentShape(Rectangle())
            }

            NavigationLink(value: DreamMetric.nightmares) {
                StatCard(title: "Nightmares", value: "\(nightmareCount)", icon: "exclamationmark.triangle.fill", color: .purple, showArrow: true)
                    .contentShape(Rectangle())
            }

            NavigationLink(value: DreamMetric.lucidity) {
                StatCard(title: "Lucidity", value: "\(Int(avgLucidity))%", icon: "eye.fill", color: .teal, showArrow: true)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())

            NavigationLink(value: DreamMetric.positive) {
                StatCard(title: "Positive", value: "\(positiveDreams)", icon: "hand.thumbsup.fill", color: .green, showArrow: true)
                    .contentShape(Rectangle())
            }
        }
    }
    
    private var vocalFatigueSection: some View {
        let data = weekAggregates
        
        return VStack(alignment: .leading, spacing: 12) {
            Label("Vocal Fatigue", systemImage: "battery.50")
                .font(.headline)
                .foregroundStyle(Theme.secondary)
                .symbolRenderingMode(.palette)
                .symbolColorRenderingMode(.gradient)
                .padding(.horizontal)
            
            NavigationLink(value: DreamMetric.fatigue) {
                PreviewChartCard(content: {
                    Chart {
                        ForEach(data) { point in
                            AreaMark(x: .value("Date", point.date, unit: .day), yStart: .value("Baseline", 0), yEnd: .value("Fatigue", point.fatigue))
                                .foregroundStyle(LinearGradient(colors: [.red.opacity(0.4), .clear], startPoint: .top, endPoint: .bottom))
                            
                            LineMark(x: .value("Date", point.date, unit: .day), y: .value("Fatigue", point.fatigue))
                                .foregroundStyle(.red.gradient)
                                .symbol{ Circle().fill(.red.gradient).frame(width: 8, height: 8) }
                        }
                    }
                    .chartXScale(domain: xAxisDomain)
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .day)) { _ in
                            AxisTick()
                            AxisValueLabel(format: .dateTime.weekday(.abbreviated), centered: true)
                        }
                    }
                    .chartYAxis {
                        AxisMarks { _ in
                            AxisTick()
                            AxisValueLabel()
                        }
                    }
                    .chartYScale(domain: 0...100)
                    .frame(height: 180)
                }, caption: {
                    HStack {
                        Text("Higher bars indicate higher vocal fatigue.")
                            .font(.caption)
                            .foregroundStyle(Theme.secondary)
                        Spacer()
                    }
                })
                .contentShape(Rectangle())
            }
        }
    }
    
    private var memoryRecallSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Memory Recall", systemImage: "memorychip")
                .font(.headline)
                .foregroundStyle(Theme.secondary)
                .symbolRenderingMode(.palette)
                .symbolColorRenderingMode(.gradient)
                .padding(.horizontal)
            
            HStack(spacing: 16) {
                NavigationLink(value: DreamMetric.vividness) {
                    RingView(percentage: Double(avgMetric { $0.extras?.vividnessScore ?? 0 }), title: "Vividness", color: .orange, showArrow: true)
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                }
                
                NavigationLink(value: DreamMetric.coherence) {
                    RingView(percentage: Double(avgMetric { $0.extras?.coherenceScore ?? 0 }), title: "Coherence", color: .cyan, showArrow: true)
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                }
            }
        }
    }
    
    // Helpers
    func avgMetric(_ keyPath: (Dream) -> Int) -> Int {
        guard !weeklyDreams.isEmpty else { return 0 }
        let total = weeklyDreams.reduce(0) { $0 + keyPath($1) }
        return total / weeklyDreams.count
    }
}

// MARK: - SHARED COMPONENT: Weekly Insight Card
struct WeeklyInsightCard: View {
    let type: WeeklyInsightsView.WeeklyInsightType
    let insights: WeeklyInsightResult
    let isExpanded: Bool
    
    var title: String {
        type == .overview ? "Overview" : "General Advice"
    }
    
    var icon: String {
        type == .overview ? "sparkles.rectangle.stack" : "lightbulb.fill"
    }
    
    var color: Color {
        type == .overview ? .indigo : .green
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label(title, systemImage: icon)
                    .font(.headline)
                    .foregroundStyle(color)
                    .symbolRenderingMode(.palette)
                    .symbolColorRenderingMode(.gradient)
                
                Spacer()
                
                if !isExpanded {
                    Image(systemName: "questionmark.bubble")
                        .font(.body)
                        .foregroundStyle(Theme.secondary)
                }
            }
            
            if type == .overview {
                VStack(alignment: .leading, spacing: 12) {
                    Text(LocalizedStringKey(formatText(insights.periodOverview ?? "Generating...")))
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Divider()
                        .background(Theme.secondary)
                    
                    HStack {
                        Label((insights.dominantTheme ?? "Theme").capitalized, systemImage: "crown.fill")
                            .font(.caption.bold())
                            .foregroundStyle(.yellow)
                        
                        Spacer()
                        
                        let trend = insights.mentalHealthTrend ?? "Trend"
                        Text(trend.prefix(1).uppercased() + trend.dropFirst())
                            .font(.caption)
                            .foregroundStyle(Theme.secondary)
                    }
                }
            } else {
                Text(LocalizedStringKey(formatText(insights.strategicAdvice ?? "")))
                    .italic()
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(24)
        .contentShape(RoundedRectangle(cornerRadius: 24))
    }
}

// MARK: - DETAIL VIEW WITH Q&A
struct WeeklyInsightDetailView: View {
    @ObservedObject var store: DreamStore // ADDED STORE HERE
    let insights: WeeklyInsightResult
    let weeklyDreams: [Dream]
    let type: WeeklyInsightsView.WeeklyInsightType
    var namespace: Namespace.ID
    @Binding var selectedInsight: WeeklyInsightsView.WeeklyInsightType?
    
    // Internal State
    @State private var questionText: String = ""
    @State private var answerText: String = ""
    @State private var isAsking: Bool = false
    @State private var showContent = false
    
    // Data Preparation for AI
    var analysisContent: String {
        switch type {
        case .overview:
            return """
            Period Overview: \(insights.periodOverview ?? "N/A")
            Dominant Theme: \(insights.dominantTheme ?? "N/A")
            Trend: \(insights.mentalHealthTrend ?? "N/A")
            """
        case .advice:
            return insights.strategicAdvice ?? ""
        }
    }
    
    var summariesContext: String {
        weeklyDreams.prefix(20).map { dream in
            let summary = dream.core?.summary ?? "No summary"
            let date = dream.date.formatted(date: .abbreviated, time: .omitted)
            return "- \(date): \(summary)"
        }.joined(separator: "\n")
    }
    
    var body: some View {
        ZStack {
            // Background Dimmer
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture { }
                .transition(.opacity)
            
            ScrollView {
                GlassEffectContainer(spacing: 24) {
                    VStack(spacing: 24) {
                        
                        // 1. The Expanded Card
                        WeeklyInsightCard(
                            type: type,
                            insights: insights,
                            isExpanded: true
                        )
                        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24))
                        .matchedGeometryEffect(id: "weekly_bg_\(type.id)", in: namespace)
                        .onTapGesture { /* Prevent closing when tapping card */ }
                        
                        // 2. Q&A Section
                        if showContent {
                            qnaSection
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 60)
            }
            .scrollIndicators(.hidden)
            
            // Close Button
            .safeAreaInset(edge: .bottom) {
                if showContent {
                    Button {
                        close()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .frame(width: 60, height: 60)
                    }
                    .contentShape(Circle())
                    .glassEffect(.regular.interactive(), in: Circle())
                    .padding(.bottom, 24)
                }
            }
        }
        .onAppear {
            // Delay content fade-in slightly to let card expansion finish
            withAnimation(.easeIn(duration: 0.3).delay(0.2)) {
                showContent = true
            }
        }
    }
    
    var qnaSection: some View {
        VStack(spacing: 24) {
            HStack(spacing: 12) {
                // Input Bubble
                TextField("Ask about your week...", text: $questionText)
                    .font(.body)
                    .textFieldStyle(.plain)
                    .padding(16)
                    .glassEffect(.regular.interactive())
                    .disabled(isAsking || !answerText.isEmpty)
                
                Button {
                    if !answerText.isEmpty {
                        resetQnA()
                    } else {
                        askQuestion()
                    }
                } label: {
                    Image(systemName: answerText.isEmpty ? "arrow.up" : "arrow.counterclockwise")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(questionText.isEmpty || isAsking ? .white.opacity(0.35) : .white.opacity(0.7))
                        .frame(width: 44, height: 44)
                        .contentTransition(.symbolEffect(.replace))
                }
                .contentShape(Circle())
                .glassEffect(
                    questionText.isEmpty || isAsking
                    ? .clear.tint(.gray.opacity(0.8))
                    : .clear.interactive().tint(store.themeAccentColor.opacity(0.8)),
                    in: Circle()
                )
                .disabled(questionText.isEmpty || isAsking)
            }
            
            // Answer Bubble
            if !answerText.isEmpty || isAsking {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Insight", systemImage: "sparkles")
                        .font(.headline)
                        .foregroundStyle(store.themeAccentColor)
                    
                    if isAsking && answerText.isEmpty {
                        Text("Analyzing your week...")
                            .font(.body)
                            .foregroundStyle(Theme.secondary)
                            .shimmering()
                    } else {
                        Text(LocalizedStringKey(formatText(answerText)))
                            .font(.body)
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 24))
                .padding(.bottom, 24)
            }
        }
    }
    
    // Logic
    func close() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            showContent = false
            selectedInsight = nil
        }
    }
    
    func resetQnA() {
        questionText = ""
        answerText = ""
        isAsking = false
    }
    
    func askQuestion() {
        guard !questionText.isEmpty else { return }
        isAsking = true
        
        Task {
            do {
                // Uses the dedicated DreamsQuestion function in DreamAnalyzer
                let answer = try await DreamAnalyzer.shared.DreamsQuestion(
                    summaries: summariesContext,
                    analysis: analysisContent,
                    question: questionText
                )
                withAnimation {
                    self.answerText = answer
                    self.isAsking = false
                }
            } catch {
                withAnimation {
                    self.answerText = "Unable to analyze the week at this moment."
                    self.isAsking = false
                }
            }
        }
    }
}

// MARK: - SHARED FORMATTING HELPER
// specific formatter that handles bullets and bolding for the AI text
private func formatText(_ text: String) -> String {
    var formatted = text
    
    // Bold Headers (Lines starting with #)
    formatted = formatted.replacingOccurrences(
        of: "(?m)^#{1,4}\\s+(.+)$",
        with: "**$1**",
        options: .regularExpression
    )
    
    // Bold Numbered Lists (e.g. "1. Title:")
    formatted = formatted.replacingOccurrences(
        of: "(?m)^\\d+\\.\\s+(.+:)$",
        with: "**$0**",
        options: .regularExpression
    )
    
    // Convert Bullets (Lines starting with - or *)
    formatted = formatted.replacingOccurrences(
        of: "(?m)^[\\-\\*]\\s+",
        with: "   • ",
        options: .regularExpression
    )
    
    return formatted
}
