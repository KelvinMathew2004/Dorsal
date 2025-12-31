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
    
    func formattedAggregate(for metric: DreamMetric) -> String {
        let points = generatePoints(for: metric)
        let values = points.map { $0.value }
        
        // 1. If there's truly no data recorded (empty array), return "No Data".
        if values.isEmpty {
            return "No Data"
        }
        
        // 2. If data exists but it's all zeros:
        //    - For count-based metrics (Dreams, Nightmares), "None" is a friendly zero.
        //    - For value-based metrics (Fatigue, Anxiety), we want to proceed to show "0%".
        if values.allSatisfy({ $0 == 0 }) {
            if metric == .dreams || metric == .nightmares || metric == .positive { return "None" }
            // For other metrics, fall through to display "0%" or "0"
        }
        
        if metric.isPercentage {
            let nonZero = values.filter { $0 > 0 }
            if nonZero.isEmpty { return "0%" }
            let avg = nonZero.reduce(0, +) / Double(nonZero.count)
            return String(format: "%.0f", avg) + "%"
        } else {
            if selectedTimeFrame == .day {
                return "\(Int(values.reduce(0, +)))"
            } else {
                let avg = values.reduce(0, +) / Double(values.count)
                return String(format: "%.1f", avg)
            }
        }
    }
    
    var aggregateLabel: String {
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
                    Spacer()
                }
                .padding(.top)
            }
        }
        .navigationTitle(viewTitle)
        .navigationBarTitleDisplayMode(.large)
    }
    
    var toneSection: some View {
        VStack(spacing: 24) {
            HStack {
                Button { moveWeek(by: -1) } label: {
                    Image(systemName: "chevron.left.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.white.opacity(0.3))
                }
                Spacer()
                Text("\(toneWeekStart.formatted(.dateTime.month().day())) - \(toneWeekEnd.formatted(.dateTime.month().day()))")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                Button { moveWeek(by: 1) } label: {
                    Image(systemName: "chevron.right.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.white.opacity(0.3))
                }
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
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.accentColor.opacity(0.1), in: Capsule())
                    .foregroundStyle(Color.accentColor)
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
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if let data = data {
                            VStack(alignment: .trailing) {
                                Text(data.tone.capitalized)
                                    .font(.headline)
                                    .foregroundStyle(metric.color)
                                Text("\(data.confidence)% Confidence")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            Text("No Data")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.3))
                        }
                    }
                    .padding()
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(.horizontal)
        }
    }
    
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
                Text(aggregateLabel.uppercased())
                    .font(.headline.bold())
                    .foregroundStyle(.secondary)
                
                if metric == .anxiety || metric == .sentiment {
                    HStack(spacing: 12) {
                        Text("\(formattedAggregate(for: .anxiety))")
                            .foregroundStyle(DreamMetric.anxiety.color)
                        
                        Rectangle()
                                .fill(Color.secondary)
                                .frame(width: 2, height: 28)
                        
                        Text("\(formattedAggregate(for: .sentiment))")
                            .foregroundStyle(DreamMetric.sentiment.color)
                    }
                    .font(.system(size: 35, weight: .bold, design: .rounded))
                } else {
                    Text(formattedAggregate(for: metric))
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundStyle(aggregateColor)
                }
                
                if selectedTimeFrame != .year {
                    Text(timeFrameSubheading)
                        .font(.headline.bold())
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                } else {
                    Menu {
                        ForEach(availableYears, id: \.self) { year in
                            Button(String(year)) { selectedYear = year }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(String(selectedYear))
                                .foregroundStyle(Color.secondary)
                            Image(systemName: "chevron.down")
                                .foregroundStyle(Color.accentColor)
                        }
                        .font(.headline.bold())
                        .padding(.top, 4)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            .padding(.top, 16)
            
            // Separate Chart implementations
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
    
    // MARK: - Dedicated Chart Components
    
    var mentalHealthChart: some View {
        let anxietyPoints = generatePoints(for: .anxiety)
        let sentimentPoints = generatePoints(for: .sentiment)
        let unit: Calendar.Component = selectedTimeFrame == .year ? .month : .day
        
        return ChartCard {
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
                    .symbol(.circle)
                    .foregroundStyle(Color.pink.gradient)
                }
                
                ForEach(sentimentPoints) { point in
                    LineMark(
                        x: .value("Date", point.date, unit: unit),
                        y: .value("Sentiment", point.value),
                        series: .value("Metric", "Sentiment")
                    )
                    .interpolationMethod(.linear)
                    .symbol(.circle)
                    .foregroundStyle(Color.green.gradient)
                }
            }
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
        
        return ChartCard {
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
                    .symbol(.circle)
                }
            }
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
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.top, 4)
        }
        .padding(.horizontal)
    }
    
    var barChartView: some View {
        ChartCard {
            Chart(groupedSeries) { series in
                ForEach(series.points) { point in
                    BarMark(
                        x: .value(selectedTimeFrame == .day ? "Time" : "Month", point.date, unit: selectedTimeFrame == .year ? .month : .hour),
                        y: .value("Value", point.value)
                    )
                    .foregroundStyle(series.metric.color.gradient)
                }
            }
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
        ChartCard {
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
                    .symbol(.circle)
                    .foregroundStyle(series.metric.color.gradient)
                }
            }
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
        VStack(alignment: .leading, spacing: 12) {
            Text(viewDescription)
                .font(.body)
                .foregroundStyle(.white.opacity(0.8))
            + Text(" Learn more...")
                .font(.body.bold())
                .foregroundStyle(Color.accentColor)
        }
        .lineSpacing(4)
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
        .onTapGesture {
            // Updated to use the new variable
            if let url = URL(string: metric.learnMoreLink) {
                UIApplication.shared.open(url)
            } else {
                print("Invalid URL for \(metric.rawValue)")
            }
        }
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
