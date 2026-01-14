import SwiftUI
import Charts

// Helper enum to define which metric we are analyzing
enum DreamMetric: String, CaseIterable, Identifiable {
    case dreams = "Dreams"
    case anxiety = "Anxiety"
    case sentiment = "Sentiment"
    case lucidity = "Lucidity"
    case vividness = "Vividness"
    case fatigue = "Vocal Fatigue"
    case tone = "Tone"
    case coherence = "Coherence"
    case nightmares = "Nightmares"
    case positive = "Positive Dreams"
    
    var id: String { self.rawValue }
    
    var color: Color {
        switch self {
        case .dreams: return .blue
        case .anxiety: return .pink
        case .sentiment: return .green
        case .lucidity: return .teal
        case .vividness: return .orange
        case .fatigue: return .red
        case .tone: return .orange
        case .coherence: return .cyan
        case .nightmares: return .purple
        case .positive: return .green
        }
    }
    
    var description: String {
        switch self {
        case .dreams:
            return "The total number of dreams you've recorded. Maintaining a consistent dream journal is the first step to better recall and self-discovery. Regular logging helps identify patterns over time."
        case .anxiety:
            return "Tracks the underlying levels of stress or anxiety detected in your dream narratives. High anxiety scores might indicate unresolved stress in your waking life that is manifesting in your sleep."
        case .sentiment:
            return "Measures the overall emotional tone of your dreams, ranging from negative to positive. Understanding this trend can help you see how your daily mood influences your dream world."
        case .lucidity:
            return "Indicates the degree of awareness you possess that you are dreaming while in the dream state. Higher lucidity is key to controlling dream narratives and exploring the subconscious."
        case .vividness:
            return "Reflects the clarity, sensory detail, and intensity of your dream recall. High vividness often correlates with better sleep quality or heightened emotional engagement."
        case .fatigue:
            return "Analyzes vocal characteristics from your audio recordings to estimate physical and mental tiredness. Changes in voice biomarkers can often predict fatigue levels before you feel them."
        case .tone:
            return "Analyzes the emotional quality of your voice during recording. Tracking tone helps correlate your spoken emotion with the content of your dreams."
        case .coherence:
            return "Measures the logical flow, structure, and narrative consistency of your dream story. Higher coherence suggests better cognitive function during recall and more structured REM sleep."
        case .nightmares:
            return "Tracks the frequency of distressing or frightening dreams. Monitoring this can help identify triggers and measure the effectiveness of stress-reduction techniques."
        case .positive:
            return "Tracks the frequency of uplifting, happy, and constructive dreams. A higher frequency often aligns with positive mental health and overall well-being."
        }
    }
    
    // MARK: - Tips
    var tips: String {
        switch self {
        case .dreams:
            return "Keep a journal or voice recorder by your bed. Capturing even small fragments immediately upon waking trains your brain to recall more details over time."
        case .anxiety:
            return "If you notice high anxiety trends, try a brief mindfulness exercise or deep breathing for 5 minutes before sleep to help calm your subconscious."
        case .sentiment:
            return "Your dream sentiment often mirrors your waking life. Identifying negative patterns here can help you pinpoint and address daily stressors."
        case .lucidity:
            return "Perform 'reality checks' during the day, like looking at your hands or reading text twice. This habit can carry over into sleep, triggering lucidity."
        case .vividness:
            return "To boost vividness, maintain a consistent sleep schedule and avoid screens for an hour before bed to improve melatonin production."
        case .fatigue:
            return "Vocal fatigue can indicate stress or overuse. Ensure you stay hydrated throughout the day and practice vocal rest if this score stays high."
        case .tone:
            return "Listen to your recordings to hear the emotional nuance in your voice. Often, how you say something reveals more than what you say."
        case .coherence:
            return "A structured narrative suggests good cognitive function during REM. If coherence drops, check if your sleep is being fragmented by external noise."
        case .nightmares:
            return "Frequent nightmares? Try 'Imagery Rehearsal Therapy': Write down a nightmare but change the ending to something positive, then visualize it before sleep."
        case .positive:
            return "End your day by noting three good things that happened. This 'gratitude practice' can prime your mind for more positive dream content."
        }
    }
    
    // MARK: - Learn More Links
    var learnMoreLink: String {
        switch self {
        case .dreams: return "https://www.sleepfoundation.org/dreams"
        case .anxiety: return "https://www.apa.org/topics/anxiety"
        case .sentiment: return "https://www.ibm.com/think/topics/sentiment-analysis"
        case .lucidity: return "https://www.webmd.com/sleep-disorders/lucid-dreams-overview"
        case .vividness: return "https://www.sleepfoundation.org/dreams/vivid-dreams"
        case .fatigue: return "https://my.clevelandclinic.org/health/symptoms/21206-fatigue"
        case .tone: return "https://www.nature.com/articles/s41598-019-50859-w"
        case .coherence: return "https://philarchive.org/archive/BOSDAS-2"
        case .nightmares: return "https://hms.harvard.edu/news-events/publications-archive/brain/nightmares-brain"
        case .positive: return "https://dreamsforpeace.org/2025/02/13/positive-dreams-how-do-you-process-them/"
        }
    }
    
    var unit: String {
        switch self {
        case .nightmares, .positive, .dreams: return ""
        default: return "%"
        }
    }
    
    var isPercentage: Bool {
        switch self {
        case .nightmares, .positive, .dreams, .tone: return false
        default: return true
        }
    }
}

enum TimeFrame: String, CaseIterable {
    case day = "Day"
    case week = "Week"
    case month = "Month"
    case year = "Year"
}

struct ChartDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}

// Data wrapper for series
struct MetricSeries: Identifiable {
    let metric: DreamMetric
    let points: [ChartDataPoint]
    var id: String { metric.rawValue }
}

struct TrendDetailView: View {
    let metric: DreamMetric
    @ObservedObject var store: DreamStore
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedTimeFrame: TimeFrame = .week
    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date())
    
    @State private var toneReferenceDate: Date = Date()
    @State private var selectedToneYear: Int = Calendar.current.component(.year, from: Date())
    
    @State private var rawSelectedDate: Date?
    
    var availableYears: [Int] {
        let years = store.dreams.map { Calendar.current.component(.year, from: $0.date) }
        let uniqueYears = Set(years)
        let allYears = uniqueYears.isEmpty ? [Calendar.current.component(.year, from: Date())] : Array(uniqueYears)
        return allYears.sorted()
    }
    
    var viewTitle: String {
        if metric == .anxiety || metric == .sentiment { return "Mental Health" }
        return metric.rawValue
    }
    
    var viewDescription: String {
        if metric == .anxiety || metric == .sentiment {
            return "Tracks the relationship between stress levels (Anxiety) and emotional tone (Sentiment). High anxiety often correlates with lower sentiment scores."
        }
        return metric.description
    }
    
    // MARK: - Native Selection Helpers
    
    struct SelectionData {
        let date: Date
        let items: [(name: String, value: Double, color: Color)]
        
        var maxValue: Double {
            items.map(\.value).max() ?? 0
        }
    }
    
    var chartUnit: Calendar.Component {
        switch selectedTimeFrame {
        case .day: return .hour
        case .week, .month: return .day
        case .year: return .month
        }
    }
    
    var selectionData: SelectionData? {
        guard let rawDate = rawSelectedDate else { return nil }
        let calendar = Calendar.current
        
        let allSeries = groupedSeries
        let allPoints = allSeries.flatMap { $0.points }
        
        let timeThreshold: TimeInterval = {
            switch selectedTimeFrame {
            case .day: return 1800
            case .week, .month: return 43200
            case .year: return 15 * 86400
            }
        }()
        
        let sorted = allPoints.sorted { abs($0.date.timeIntervalSince(rawDate)) < abs($1.date.timeIntervalSince(rawDate)) }
        guard let closest = sorted.first, abs(closest.date.timeIntervalSince(rawDate)) < timeThreshold else { return nil }
        
        let targetDate = closest.date
        
        var items: [(name: String, value: Double, color: Color)] = []
        for series in allSeries {
            if let p = series.points.first(where: { calendar.isDate($0.date, equalTo: targetDate, toGranularity: chartUnit) }) {
                 items.append((series.metric.rawValue, p.value, series.metric.color))
            }
        }
        
        return SelectionData(date: targetDate, items: items)
    }
    
    @ViewBuilder
    func selectionPopover(data: SelectionData) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .glassEffect(.clear.tint(.black.opacity(0.2)), in: RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.3), lineWidth: 0.5)
                )
    
            VStack(alignment: .leading, spacing: 4) {
                Text(data.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(Theme.secondary)
                
                ForEach(data.items, id: \.name) { item in
                    HStack(alignment: .center, spacing: 4) {
                        Circle()
                            .fill(item.color)
                            .frame(width: 6, height: 6)
                        
                        Text(item.name + ":")
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                        
                        Text(String(format: "%.0f%%", item.value))
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                    }
                }
            }
            .padding(10)
        }
        .fixedSize()
    }
    
    // MARK: - Data Processing
    
    // Generates raw points for a specific metric
    func generatePoints(for metric: DreamMetric) -> [ChartDataPoint] {
        var calendar = Calendar.current
        calendar.firstWeekday = 2
        let now = Date()
        let rawDreams = store.dreams
        var points: [ChartDataPoint] = []
        
        switch selectedTimeFrame {
        case .day:
            let startOfDay = calendar.startOfDay(for: now)
            for i in 0..<24 {
                if let hourDate = calendar.date(byAdding: .hour, value: i, to: startOfDay) {
                    let nextHour = calendar.date(byAdding: .hour, value: 1, to: hourDate)!
                    let dreamsInHour = rawDreams.filter { $0.date >= hourDate && $0.date < nextHour }
                    
                    if !dreamsInHour.isEmpty {
                        let val = calculateValue(for: dreamsInHour, metric: metric)
                        points.append(ChartDataPoint(date: hourDate, value: val))
                    }
                }
            }
        case .week:
            let weekInterval = calendar.dateInterval(of: .weekOfYear, for: now) ?? DateInterval(start: now, duration: 0)
            let startOfWeek = weekInterval.start
            
            for i in 0..<7 {
                if let dayDate = calendar.date(byAdding: .day, value: i, to: startOfWeek) {
                    let startOfD = calendar.startOfDay(for: dayDate)
                    let endOfD = calendar.date(byAdding: .day, value: 1, to: startOfD)!
                    
                    let dreamsInDay = rawDreams.filter { $0.date >= startOfD && $0.date < endOfD }
                    
                    if !dreamsInDay.isEmpty {
                        let val = calculateValue(for: dreamsInDay, metric: metric)
                        points.append(ChartDataPoint(date: startOfD, value: val))
                    }
                }
            }
        case .month:
            let currentComponents = calendar.dateComponents([.year, .month], from: now)
            if let startOfMonth = calendar.date(from: currentComponents),
               let range = calendar.range(of: .day, in: .month, for: startOfMonth) {
                // Iterate ALL days in month to ensure daily alignment
                for day in range {
                    if let date = calendar.date(byAdding: .day, value: day - 1, to: startOfMonth) {
                        let nextDay = calendar.date(byAdding: .day, value: 1, to: date)!
                        let dreamsInDay = rawDreams.filter { $0.date >= date && $0.date < nextDay }
                        
                        if !dreamsInDay.isEmpty {
                            let val = calculateValue(for: dreamsInDay, metric: metric)
                            points.append(ChartDataPoint(date: date, value: val))
                        }
                    }
                }
            }
        case .year:
            let yearStart = calendar.date(from: DateComponents(year: selectedYear, month: 1, day: 1))!
            for month in 0..<12 {
                if let monthDate = calendar.date(byAdding: .month, value: month, to: yearStart) {
                    let nextMonth = calendar.date(byAdding: .month, value: 1, to: monthDate)!
                    let dreamsInMonth = rawDreams.filter { $0.date >= monthDate && $0.date < nextMonth }
                    
                    if !dreamsInMonth.isEmpty {
                        let val = calculateValue(for: dreamsInMonth, metric: metric)
                        points.append(ChartDataPoint(date: monthDate, value: val))
                    }
                }
            }
        }
        return points
    }
    
    // Groups data into series for the chart
    var groupedSeries: [MetricSeries] {
        let metricsToShow: [DreamMetric] = (metric == .anxiety || metric == .sentiment) ? [.anxiety, .sentiment] : [metric]
        return metricsToShow.map { metric in
            MetricSeries(metric: metric, points: generatePoints(for: metric))
        }
    }
    
    func calculateValue(for dreams: [Dream], metric: DreamMetric) -> Double {
        if dreams.isEmpty { return 0 }
        switch metric {
        case .dreams: return Double(dreams.count)
        case .nightmares: return Double(dreams.filter { $0.extras?.isNightmare ?? false }.count)
        case .positive: return Double(dreams.filter { ($0.extras?.sentimentScore ?? 0) > 60 }.count)
        default:
            let total = dreams.reduce(0.0) { sum, dream in
                switch metric {
                case .anxiety: return sum + Double(dream.extras?.anxietyLevel ?? 0)
                case .sentiment: return sum + Double(dream.extras?.sentimentScore ?? 50)
                case .lucidity: return sum + Double(dream.extras?.lucidityScore ?? 0)
                case .vividness: return sum + Double(dream.extras?.vividnessScore ?? 0)
                case .fatigue: return sum + Double(dream.core?.voiceFatigue ?? 0)
                case .coherence: return sum + Double(dream.extras?.coherenceScore ?? 0)
                default: return sum
                }
            }
            return total / Double(dreams.count)
        }
    }
    
    // New: Calculate numeric value for trend logic
    func rawAggregateValue(for metric: DreamMetric) -> Double {
        var calendar = Calendar.current
        calendar.firstWeekday = 2
        let now = Date()
        var relevantDreams: [Dream] = []
        
        switch selectedTimeFrame {
        case .day:
            let start = calendar.startOfDay(for: now)
            if let end = calendar.date(byAdding: .day, value: 1, to: start) {
                relevantDreams = store.dreams.filter { $0.date >= start && $0.date < end }
            }
        case .week:
            if let weekInterval = calendar.dateInterval(of: .weekOfYear, for: now) {
                relevantDreams = store.dreams.filter { weekInterval.contains($0.date) }
            }
        case .month:
            let components = calendar.dateComponents([.year, .month], from: now)
            if let start = calendar.date(from: components),
               let range = calendar.range(of: .day, in: .month, for: start),
               let end = calendar.date(byAdding: .day, value: range.count, to: start) {
                relevantDreams = store.dreams.filter { $0.date >= start && $0.date < end }
            }
        case .year:
            if let start = calendar.date(from: DateComponents(year: selectedYear, month: 1, day: 1)),
               let end = calendar.date(from: DateComponents(year: selectedYear + 1, month: 1, day: 1)) {
                relevantDreams = store.dreams.filter { $0.date >= start && $0.date < end }
            }
        }
        
        if relevantDreams.isEmpty { return 0 }
        
        if metric == .dreams { return Double(relevantDreams.count) }
        if metric == .nightmares { return Double(relevantDreams.filter { $0.extras?.isNightmare ?? false }.count) }
        if metric == .positive { return Double(relevantDreams.filter { ($0.extras?.sentimentScore ?? 0) > 60 }.count) }
        
        let total = relevantDreams.reduce(0.0) { sum, dream in
            switch metric {
            case .anxiety: return sum + Double(dream.extras?.anxietyLevel ?? 0)
            case .sentiment: return sum + Double(dream.extras?.sentimentScore ?? 50)
            case .lucidity: return sum + Double(dream.extras?.lucidityScore ?? 0)
            case .vividness: return sum + Double(dream.extras?.vividnessScore ?? 0)
            case .fatigue: return sum + Double(dream.core?.voiceFatigue ?? 0)
            case .coherence: return sum + Double(dream.extras?.coherenceScore ?? 0)
            default: return sum
            }
        }
        return total / Double(relevantDreams.count)
    }
    
    // Replaced static formatting with this builder in usage, but kept if needed elsewhere
    func formattedAggregate(for metric: DreamMetric) -> String {
        let val = rawAggregateValue(for: metric)
        if val == 0 && store.dreams.isEmpty { return "No Data" }
        
        if metric.isPercentage {
            return String(format: "%.0f", val) + "%"
        } else {
            return metric == .dreams || metric == .nightmares || metric == .positive ? String(format: "%.0f", val) : String(format: "%.1f", val)
        }
    }
    
    var aggregateLabel: String {
        if metric == .dreams || metric == .nightmares || metric == .positive {
            return "Total"
        }
        switch selectedTimeFrame {
        case .day: return "Total"
        case .week: return "Daily Average"
        case .month: return "Daily Average"
        case .year: return "Daily Average"
        }
    }
    
    var aggregateColor: Color {
        if metric == .anxiety || metric == .sentiment {
            return .green
        }
        return metric.color
    }
    
    var timeFrameSubheading: String {
        let now = Date()
        let formatter = DateFormatter()

        switch selectedTimeFrame {
        case .day:
            return "Today"

        case .week:
            return "This Week"

        case .month:
            formatter.dateFormat = "MMM yyyy"
            return formatter.string(from: now).uppercased()
            
        case .year:
            return String(selectedYear)
        }
    }
    
    var xAxisDomain: ClosedRange<Date> {
        var calendar = Calendar.current
        calendar.firstWeekday = 2
        let now = Date()
        switch selectedTimeFrame {
        case .day:
            let start = calendar.startOfDay(for: now)
            let end = calendar.date(byAdding: .hour, value: 23, to: start)!
            return start...end
        case .week:
            let weekInterval = calendar.dateInterval(of: .weekOfYear, for: now) ?? DateInterval(start: now, duration: 0)
            return weekInterval.start...weekInterval.end
        case .month:
            let currentComponents = calendar.dateComponents([.year, .month], from: now)
            let start = calendar.date(from: currentComponents)!
            let range = calendar.range(of: .day, in: .month, for: start)!
            let end = calendar.date(byAdding: .day, value: range.count, to: start)!
            return start...end
        case .year:
             let start = calendar.date(from: DateComponents(year: selectedYear, month: 1, day: 1))!
             let end = calendar.date(from: DateComponents(year: selectedYear, month: 12, day: 31))!
             let endBuffered = calendar.date(byAdding: .day, value: 1, to: end)!
             return start...endBuffered
        }
    }
    
    var toneWeekStart: Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: toneReferenceDate)
        return calendar.date(from: components) ?? Date()
    }
    var toneWeekEnd: Date {
        Calendar.current.date(byAdding: .day, value: 6, to: toneWeekStart) ?? Date()
    }
    func toneForDate(_ date: Date) -> (tone: String, confidence: Int)? {
        let calendar = Calendar.current
        let dayDreams = store.dreams.filter { calendar.isDate($0.date, inSameDayAs: date) }
        guard let first = dayDreams.first, let tone = first.core?.tone?.label, let conf = first.core?.tone?.confidence else { return nil }
        return (tone, conf)
    }
    func moveWeek(by value: Int) {
        if let newDate = Calendar.current.date(byAdding: .weekOfYear, value: value, to: toneReferenceDate) {
            toneReferenceDate = newDate
            selectedToneYear = Calendar.current.component(.year, from: newDate)
        }
    }
    
    var body: some View {
        ZStack {
            Theme.gradientBackground.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    if metric == .tone {
                        toneSection
                    } else {
                        standardChartSection
                    }

                    descriptionSection
                    
                    tipsSection
                    
                    Spacer()
                }
                .padding(.top)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle(viewTitle)
        .navigationBarTitleDisplayMode(.large)
    }
    
    var toneSection: some View {
        VStack(spacing: 24) {
            HStack {
                Button { moveWeek(by: -1) } label: {
                    Image(systemName: "chevron.left")
                        .foregroundStyle(Theme.secondary)
                        .fontWeight(.bold)
                }
                .buttonStyle(.glassProminent)
                .tint(metric.color.opacity(0.7))
                Spacer()
                Text("\(toneWeekStart.formatted(.dateTime.month().day())) - \(toneWeekEnd.formatted(.dateTime.month().day()))")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                Button { moveWeek(by: 1) } label: {
                    Image(systemName: "chevron.right")
                        .foregroundStyle(Theme.secondary)
                        .fontWeight(.bold)
                }
                .buttonStyle(.glassProminent)
                .tint(metric.color.opacity(0.7))
                Spacer()
                Menu {
                    ForEach(availableYears, id: \.self) { year in
                        Button(String(year)) {
                            selectedToneYear = year
                            let components = DateComponents(year: year, month: 1, day: 1)
                            if let newDate = Calendar.current.date(from: components) {
                                toneReferenceDate = newDate
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(String(selectedToneYear))
                        Image(systemName: "chevron.down")
                            .font(.caption.bold())
                    }
                    .font(.subheadline.bold())
                    .foregroundStyle(store.themeAccentColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .glassEffect(.regular.interactive().tint(store.themeAccentColor.opacity(0.1)))
                }
            }
            .padding(16)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)
            
            VStack(spacing: 12) {
                ForEach(0..<7, id: \.self) { dayOffset in
                    let date = Calendar.current.date(byAdding: .day, value: dayOffset, to: toneWeekStart) ?? Date()
                    let data = toneForDate(date)
                    HStack {
                        VStack(alignment: .leading) {
                            Text(date.formatted(.dateTime.weekday(.wide)))
                                .font(.headline)
                                .foregroundStyle(.white)
                            Text(date.formatted(.dateTime.month().day()))
                                .font(.caption)
                                .foregroundStyle(Theme.secondary)
                        }
                        Spacer()
                        if let data = data {
                            VStack(alignment: .trailing) {
                                Text(data.tone.capitalized)
                                    .font(.headline)
                                    .foregroundStyle(metric.color)
                                Text("\(data.confidence)% Confidence")
                                    .font(.caption)
                                    .foregroundStyle(Theme.secondary)
                            }
                        } else {
                            Text("No Data")
                                .font(.subheadline)
                                .foregroundStyle(Theme.secondary)
                        }
                    }
                    .padding()
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - Standard Chart Section
    
    var standardChartSection: some View {
        VStack(spacing: 24) {
            Picker("Time Frame", selection: $selectedTimeFrame) {
                ForEach(TimeFrame.allCases, id: \.self) { frame in
                    Text(frame.rawValue).tag(frame)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(aggregateLabel.uppercased())
                            .font(.headline.bold())
                            .foregroundStyle(Theme.secondary)
                        
                        // Main Aggregate Display
                        if metric == .anxiety || metric == .sentiment {
                            HStack(spacing: 12) {
                                animatedStatView(for: .anxiety)
                                    .foregroundStyle(DreamMetric.anxiety.color)
                                
                                Rectangle()
                                        .fill(Theme.secondary)
                                        .frame(width: 2, height: 28)
                                
                                animatedStatView(for: .sentiment)
                                    .foregroundStyle(DreamMetric.sentiment.color)
                            }
                            .font(.system(size: 35, weight: .bold, design: .rounded))
                        } else {
                            animatedStatView(for: metric)
                                .font(.system(size: 42, weight: .bold, design: .rounded))
                                .foregroundStyle(aggregateColor)
                        }
                        
                        // Text/Menu Subheading Part
                        if selectedTimeFrame != .year {
                            Text(timeFrameSubheading)
                                .font(.headline.bold())
                                .foregroundStyle(Theme.secondary)
                        } else {
                            Menu {
                                ForEach(availableYears, id: \.self) { year in
                                    Button(String(year)) { selectedYear = year }
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Text(String(selectedYear))
                                        .foregroundStyle(Theme.secondary)
                                    Image(systemName: "chevron.down")
                                        .foregroundStyle(store.themeAccentColor)
                                }
                                .font(.headline.bold())
                            }
                        }
                    }
                    
                    Spacer()
                    
                    trendIndicatorView
                        .padding(.horizontal)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            .padding(.top, 16)
            
            ZStack(alignment: .top) {
                if (metric == .anxiety || metric == .sentiment) && (selectedTimeFrame == .week || selectedTimeFrame == .month) {
                    mentalHealthChart
                } else if metric == .fatigue && (selectedTimeFrame == .week || selectedTimeFrame == .month) {
                    vocalFatigueChart
                } else if selectedTimeFrame == .day || selectedTimeFrame == .year {
                    barChartView
                } else {
                    lineChartView
                }
            }
        }
    }
    
    @ViewBuilder
    func animatedStatView(for m: DreamMetric) -> some View {
        let val = rawAggregateValue(for: m)
        let hasData = !(val == 0 && store.dreams.isEmpty)
        
        if !hasData {
            Text("No Data")
                .contentTransition(.identity)
        } else {
            // Determine format based on existing logic
            // if percentage -> %.0f
            // if dreams/nightmares/positive -> %.0f
            // else -> %.1f
            let fraction = (m.isPercentage || m == .dreams || m == .nightmares || m == .positive) ? 0 : 1
            
            // Animated Text
            HStack(spacing: 0) {
                Text(val, format: .number.precision(.fractionLength(fraction)))
                    .contentTransition(.numericText())
                
                Text(m.unit)
            }
            .animation(.snappy, value: val)
        }
    }
    
    @ViewBuilder
    var trendIndicatorView: some View {
        let result = determineTrend(for: metric)
        if let icon = result.icon {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3.bold())
                Text(result.text)
                    .font(.caption2.weight(.bold))
                    .textCase(.uppercase)
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(result.color)
            .padding(.horizontal, 15)
            .padding(.vertical, 12)
            .glassEffect(.clear.tint(result.color.opacity(0.15)), in: RoundedRectangle(cornerRadius: 16))
        }
    }
    
    func determineTrend(for metric: DreamMetric) -> (icon: String?, text: String, color: Color) {
        let value = rawAggregateValue(for: metric)
        if value == 0 && store.dreams.isEmpty { return (nil, "", .clear) }
        
        switch metric {
        case .anxiety:
            // Clinical anxiety scales often treat >10 as mild, >15 as moderate. Scaled 0-100:
            // < 25: Low/Normal (Good)
            // 25 - 50: Moderate
            // > 50: High (Concerning)
            if value < 25 { return ("hand.thumbsup.fill", "Low Anxiety", .green) }
            if value < 50 { return ("minus", "Moderate", .yellow) }
            return ("hand.thumbsdown.fill", "High Anxiety", .orange)
            
        case .sentiment:
            // Sentiment -1 to 1 scaled to 0-100. Neutral is 50.
            // > 60: Positive
            // 40 - 60: Neutral
            // < 40: Negative
            if value > 60 { return ("hand.thumbsup.fill", "Positive", .green) }
            if value >= 40 { return ("minus", "Neutral", .yellow) }
            return ("hand.thumbsdown.fill", "Negative", .orange)
            
        case .lucidity:
            // Lucidity is rare. Even low scores indicate some awareness.
            // > 50: High Awareness (Excellent)
            // 20 - 50: Some Awareness (Good)
            // < 20: Low Awareness (Normal)
            if value > 50 { return ("star.fill", "High Lucid", .teal) }
            if value > 20 { return ("star.leadinghalf.filled", "Some Lucid", .green) }
            return ("moon.zzz.fill", "Normal", .blue)
            
        case .vividness:
            // Vividness 0-100.
            // > 75: Highly Vivid (Excellent Recall)
            // 40 - 75: Moderate
            // < 40: Hazy
            if value > 75 { return ("eye.fill", "Vivid", .green) }
            if value > 40 { return ("eye.square", "Moderate", .yellow) }
            return ("eye.slash", "Hazy", .orange)
            
        case .fatigue:
            // Vocal fatigue.
            // < 30: Rested
            // 30 - 60: Normal Use
            // > 60: Strained/Fatigued
            if value < 30 { return ("battery.100", "Rested", .green) }
            if value < 60 { return ("battery.50", "Normal", .yellow) }
            return ("battery.0", "Fatigued", .orange)
            
        case .coherence:
            // Narrative cohesion.
            // > 70: Strong Narrative
            // 40 - 70: Dream Logic
            // < 40: Fragmented
            if value > 70 { return ("text.alignleft", "Coherent", .green) }
            if value > 40 { return ("text.aligncenter", "Dream Logic", .blue) }
            return ("text.alignright", "Fragmented", .orange)
            
        case .nightmares:
            // Count.
            // 0: Great
            // 1-2: Normal/Occasional
            // > 2: Frequent
            if value == 0 { return ("shield.fill", "Peaceful", .green) }
            if value <= 2 { return ("exclamationmark.shield", "Occasional", .yellow) }
            return ("exclamationmark.triangle.fill", "Frequent", .red)
            
        case .positive:
            // Count.
            // > 3: Frequent Positivity
            // 1-3: Occasional
            // 0: Low
            if value >= 3 { return ("sun.max.fill", "Frequent", .green) }
            if value >= 1 { return ("sun.min", "Occasional", .yellow) }
            return ("cloud", "Low", .gray)
            
        case .dreams:
            // Dream recall frequency (per week/period).
            // > 5: High Recall
            // 2 - 5: Moderate
            // < 2: Low Recall
            if value >= 5 { return ("book.fill", "High Recall", .green) }
            if value >= 2 { return ("book.closed", "Moderate", .blue) }
            return ("moon.zzz", "Low Recall", .gray)
            
        default:
            return (nil, "", .clear)
        }
    }
    
    // MARK: - Dedicated Chart Components
    
    var mentalHealthChart: some View {
        let anxietyPoints = generatePoints(for: .anxiety)
        let sentimentPoints = generatePoints(for: .sentiment)
        let unit: Calendar.Component = selectedTimeFrame == .year ? .month : .day
        
        return DetailedChartCard {
            Chart {
                ForEach(anxietyPoints) { point in
                    AreaMark(
                        x: .value("Date", point.date, unit: unit),
                        yStart: .value("Baseline", 0),
                        yEnd: .value("Anxiety", point.value),
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
                }
                
                ForEach(sentimentPoints) { point in
                    AreaMark(
                        x: .value("Date", point.date, unit: unit),
                        yStart: .value("Baseline", 0),
                        yEnd: .value("Sentiment", point.value),
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
                }
                
                ForEach(anxietyPoints) { point in
                    LineMark(
                        x: .value("Date", point.date, unit: unit),
                        y: .value("Anxiety", point.value),
                        series: .value("Metric", "Anxiety")
                    )
                    .interpolationMethod(.linear)
                    .symbol{
                        Circle()
                            .fill(.pink.gradient)
                            .frame(width: 8, height: 8)
                    }
                    .foregroundStyle(Color.pink.gradient)
                }
                
                ForEach(sentimentPoints) { point in
                    LineMark(
                        x: .value("Date", point.date, unit: unit),
                        y: .value("Sentiment", point.value),
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
                
                if let data = selectionData {
                    RuleMark(
                        x: .value("Selected", data.date, unit: unit),
                        yStart: .value("", 0),
                        yEnd: .value("", data.maxValue)
                    )
                    .foregroundStyle(Theme.secondary)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5]))
                    .annotation(position: .top, overflowResolution: .init(x: .fit(to: .chart), y: .fit(to: .chart))) {
                        selectionPopover(data: data)
                    }
                }
            }
            .chartXSelection(value: $rawSelectedDate)
            .chartYScale(domain: 0...100)
            .chartXScale(domain: xAxisDomain)
            .chartYAxis { AxisMarks { _ in AxisGridLine(); AxisTick(); AxisValueLabel() } }
            .chartXAxis {
                AxisMarks(values: selectedTimeFrame == .week ? .stride(by: .day) :
                          selectedTimeFrame == .month ? .stride(by: .day, count: 4) : .automatic(desiredCount: 6)) { value in
                    if selectedTimeFrame == .week { AxisValueLabel(format: .dateTime.weekday(.abbreviated), centered: true) }
                    else if selectedTimeFrame == .month { AxisValueLabel(format: .dateTime.day()) }
                    else { AxisValueLabel() }
                }
            }
            .frame(height: 250)
            .padding(.trailing, 10)
        } caption: {
            HStack(spacing: 16) {
                Label("Anxiety", systemImage: "circle.fill").foregroundStyle(.pink)
                Label("Sentiment", systemImage: "circle.fill").foregroundStyle(.green)
                Spacer()
            }
            .font(.caption)
            .padding(.top, 4)
        }
        .padding(.horizontal)
    }
    
    var vocalFatigueChart: some View {
        let points = generatePoints(for: .fatigue)
        let unit: Calendar.Component = selectedTimeFrame == .year ? .month : .day
        
        return DetailedChartCard {
            Chart {
                ForEach(points) { point in
                    AreaMark(
                        x: .value("Date", point.date, unit: unit),
                        yStart: .value("Baseline", 0),
                        yEnd: .value("Fatigue", point.value)
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
                        x: .value("Date", point.date, unit: unit),
                        y: .value("Fatigue", point.value)
                    )
                    .foregroundStyle(.red.gradient)
                    .interpolationMethod(.linear)
                    .symbol{
                        Circle()
                            .fill(.red.gradient)
                            .frame(width: 8, height: 8)
                    }
                }
                
                if let data = selectionData {
                    RuleMark(
                        x: .value("Selected", data.date, unit: unit),
                        yStart: .value("", 0),
                        yEnd: .value("", data.maxValue)
                    )
                    .foregroundStyle(Theme.secondary)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5]))
                    .annotation(position: .top, overflowResolution: .init(x: .fit(to: .chart), y: .fit(to: .chart))) {
                        selectionPopover(data: data)
                    }
                }
            }
            .chartXSelection(value: $rawSelectedDate)
            .chartYScale(domain: 0...100)
            .chartXScale(domain: xAxisDomain)
            .chartYAxis { AxisMarks { _ in AxisGridLine(); AxisTick(); AxisValueLabel() } }
            .chartXAxis {
                AxisMarks(values: selectedTimeFrame == .week ? .stride(by: .day) :
                          selectedTimeFrame == .month ? .stride(by: .day, count: 4) : .automatic(desiredCount: 6)) { value in
                    if selectedTimeFrame == .week { AxisValueLabel(format: .dateTime.weekday(.abbreviated), centered: true) }
                    else if selectedTimeFrame == .month { AxisValueLabel(format: .dateTime.day()) }
                    else { AxisValueLabel() }
                }
            }
            .frame(height: 250)
            .padding(.trailing, 10)
        } caption: {
            HStack {
                Text("Higher bars indicate higher vocal fatigue.")
                    .font(.caption)
                    .foregroundStyle(Theme.secondary)
                Spacer()
            }
            .padding(.top, 4)
        }
        .padding(.horizontal)
    }
    
    var barChartView: some View {
        DetailedChartCard {
            Chart(groupedSeries) { series in
                ForEach(series.points) { point in
                    BarMark(
                        x: .value(selectedTimeFrame == .day ? "Time" : "Month", point.date, unit: selectedTimeFrame == .year ? .month : .hour),
                        y: .value("Value", point.value)
                    )
                    .foregroundStyle(series.metric.color.gradient)
                }
                
                if let data = selectionData {
                    RuleMark(
                        x: .value("Selected", data.date, unit: selectedTimeFrame == .year ? .month : .hour),
                        yStart: .value("", 0),
                        yEnd: .value("", data.maxValue)
                    )
                    .foregroundStyle(Theme.secondary)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5]))
                    .annotation(position: .top, overflowResolution: .init(x: .fit(to: .chart), y: .fit(to: .chart))) {
                        selectionPopover(data: data)
                    }
                }
            }
            .chartXSelection(value: $rawSelectedDate)
            .chartXScale(domain: xAxisDomain)
            .chartYScale(domain: metric.isPercentage ? .automatic(includesZero: true) : .automatic)
            .chartYAxis {
                AxisMarks { _ in AxisGridLine(); AxisTick(); AxisValueLabel() }
            }
            .modifier(PercentageScaleModifier(isPercentage: metric.isPercentage))
            .chartXAxis {
                if selectedTimeFrame == .day {
                    AxisMarks(values: .automatic(desiredCount: 6)) { _ in
                        AxisValueLabel(format: .dateTime.hour()); AxisGridLine()
                    }
                } else {
                    AxisMarks(values: .stride(by: .month)) { _ in
                        AxisValueLabel(format: .dateTime.month(.narrow), centered: true)
                    }
                }
            }
            .frame(height: 250)
            .padding(.trailing, 10)
        } caption: {
            if metric == .anxiety || metric == .sentiment {
                HStack(spacing: 16) {
                    Label("Anxiety", systemImage: "circle.fill").foregroundStyle(.pink)
                    Label("Sentiment", systemImage: "circle.fill").foregroundStyle(.green)
                    Spacer()
                }
                .font(.caption)
                .padding(.top, 4)
            }
        }
        .padding(.horizontal)
    }
    
    var lineChartView: some View {
        DetailedChartCard {
            Chart(groupedSeries) { series in
                ForEach(series.points) { point in
                    let unit: Calendar.Component = selectedTimeFrame == .year ? .month : .day
                    
                    if groupedSeries.count == 1 || metric == .anxiety || metric == .sentiment {
                        AreaMark(
                            x: .value("Date", point.date, unit: unit),
                            yStart: .value("Baseline", 0),
                            yEnd: .value("Value", point.value),
                            series: .value("Metric", series.metric.id)
                        )
                        .interpolationMethod(.linear)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [series.metric.color.opacity(0.5), .clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .alignsMarkStylesWithPlotArea()
                    }

                    LineMark(
                        x: .value("Date", point.date, unit: unit),
                        y: .value("Value", point.value),
                        series: .value("Metric", series.metric.id)
                    )
                    .interpolationMethod(.linear)
                    .symbol {
                        Circle()
                            .fill(series.metric.color.gradient)
                            .frame(width: 8, height: 8)
                    }
                    .foregroundStyle(series.metric.color.gradient)
                }
                
                if let data = selectionData {
                    RuleMark(
                        x: .value("Selected", data.date, unit: selectedTimeFrame == .year ? .month : .day),
                        yStart: .value("", 0),
                        yEnd: .value("", data.maxValue)
                    )
                    .foregroundStyle(Theme.secondary)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5]))
                    .annotation(position: .top, overflowResolution: .init(x: .fit(to: .chart), y: .fit(to: .chart))) {
                        selectionPopover(data: data)
                    }
                }
            }
            .chartXSelection(value: $rawSelectedDate)
            .chartYScale(domain: 0...100)
            .chartXScale(domain: xAxisDomain)
            .chartYAxis {
                AxisMarks { _ in AxisGridLine(); AxisTick(); AxisValueLabel() }
            }
            .chartXAxis {
                AxisMarks(values: selectedTimeFrame == .week ? .stride(by: .day) :
                                  selectedTimeFrame == .month ? .stride(by: .day, count: 4) :
                                  selectedTimeFrame == .year ? .stride(by: .month) :
                                  .automatic(desiredCount: 6)) { value in
                    
                    if selectedTimeFrame == .week {
                        AxisValueLabel(format: .dateTime.weekday(.abbreviated), centered: true)
                    } else if selectedTimeFrame == .month {
                        AxisValueLabel(format: .dateTime.day())
                    } else if selectedTimeFrame == .year {
                        AxisValueLabel(format: .dateTime.month(.narrow), centered: true)
                    } else {
                        AxisValueLabel()
                    }
                }
            }
            .frame(height: 250)
            .padding(.trailing, 10)
        } caption: {
            if metric == .anxiety || metric == .sentiment {
                HStack(spacing: 16) {
                    Label("Anxiety", systemImage: "circle.fill").foregroundStyle(.pink)
                    Label("Sentiment", systemImage: "circle.fill").foregroundStyle(.green)
                    Spacer()
                }
                .font(.caption)
                .padding(.top, 4)
            }
        }
        .padding(.horizontal)
    }
    
    var descriptionSection: some View {
        let combinedText: AttributedString = {
            var desc = AttributedString(viewDescription)
            desc.foregroundColor = Theme.secondary
            
            var link = AttributedString(" Learn more...")
            link.link = URL(string: metric.learnMoreLink)
            link.font = .body.bold()
            link.foregroundColor = store.themeAccentColor
            
            return desc + link
        }()

        return Text(combinedText)
            .padding(24)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)
    }
    
    var tipsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Tip", systemImage: "heart.text.clipboard.fill")
                .font(.headline)
                .foregroundStyle(store.themeAccentColor)
            
            Text(metric.tips)
                .font(.body)
                .foregroundStyle(Theme.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }
}

struct PercentageScaleModifier: ViewModifier {
    let isPercentage: Bool
    func body(content: Content) -> some View {
        if isPercentage {
            content.chartYScale(domain: 0...100)
        } else {
            content
        }
    }
}
