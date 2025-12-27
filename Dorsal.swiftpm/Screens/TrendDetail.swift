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
        case .lucidity: return .cyan
        case .vividness: return .orange
        case .fatigue: return .red
        case .tone: return .orange
        case .coherence: return .teal
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

struct TrendDetailView: View {
    let metric: DreamMetric
    @ObservedObject var store: DreamStore
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedTimeFrame: TimeFrame = .week
    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date())
    
    // Tone Specific State
    @State private var toneReferenceDate: Date = Date()
    @State private var selectedToneYear: Int = Calendar.current.component(.year, from: Date())
    
    // Dynamic available years based on data
    var availableYears: [Int] {
        let years = store.dreams.map { Calendar.current.component(.year, from: $0.date) }
        let uniqueYears = Set(years)
        // Ensure current year is always available even if empty
        let allYears = uniqueYears.isEmpty ? [Calendar.current.component(.year, from: Date())] : Array(uniqueYears)
        return allYears.sorted()
    }
    
    // MARK: - Data Processing
    
    var chartData: [ChartDataPoint] {
        let calendar = Calendar.current
        let now = Date()
        let rawDreams = store.dreams
        
        var points: [ChartDataPoint] = []
        
        switch selectedTimeFrame {
        case .day:
            // Domain: Today 00:00 to 23:59. Bin by Hour.
            let startOfDay = calendar.startOfDay(for: now)
            for i in 0..<24 {
                if let hourDate = calendar.date(byAdding: .hour, value: i, to: startOfDay) {
                    let nextHour = calendar.date(byAdding: .hour, value: 1, to: hourDate)!
                    let dreamsInHour = rawDreams.filter { $0.date >= hourDate && $0.date < nextHour }
                    let val = calculateValue(for: dreamsInHour)
                    points.append(ChartDataPoint(date: hourDate, value: val))
                }
            }
            
        case .week:
            // Domain: Past 7 days (ensure 7 full days: 6 days ago + today)
            for i in (0...6).reversed() {
                if let dayDate = calendar.date(byAdding: .day, value: -i, to: now) {
                    let startOfD = calendar.startOfDay(for: dayDate)
                    let endOfD = calendar.date(byAdding: .day, value: 1, to: startOfD)!
                    let dreamsInDay = rawDreams.filter { $0.date >= startOfD && $0.date < endOfD }
                    let val = calculateValue(for: dreamsInDay)
                    points.append(ChartDataPoint(date: startOfD, value: val))
                }
            }
            
        case .month:
            // Domain: Current month, daily averages (1-30/31)
            let currentComponents = calendar.dateComponents([.year, .month], from: now)
            guard let startOfMonth = calendar.date(from: currentComponents),
                  let range = calendar.range(of: .day, in: .month, for: startOfMonth) else { return [] }
            
            for day in range {
                if let date = calendar.date(byAdding: .day, value: day - 1, to: startOfMonth) {
                    let nextDay = calendar.date(byAdding: .day, value: 1, to: date)!
                    let dreamsInDay = rawDreams.filter { $0.date >= date && $0.date < nextDay }
                    let val = calculateValue(for: dreamsInDay)
                    points.append(ChartDataPoint(date: date, value: val))
                }
            }
            
        case .year:
            // Domain: Selected Year (Jan-Dec)
            let yearStart = calendar.date(from: DateComponents(year: selectedYear, month: 1, day: 1))!
            
            for month in 0..<12 {
                if let monthDate = calendar.date(byAdding: .month, value: month, to: yearStart) {
                    let nextMonth = calendar.date(byAdding: .month, value: 1, to: monthDate)!
                    let dreamsInMonth = rawDreams.filter { $0.date >= monthDate && $0.date < nextMonth }
                    let val = calculateValue(for: dreamsInMonth)
                    points.append(ChartDataPoint(date: monthDate, value: val))
                }
            }
        }
        
        return points
    }
    
    func calculateValue(for dreams: [Dream]) -> Double {
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
    
    var aggregateValue: String {
        let allValues = chartData.map { $0.value }
        if allValues.isEmpty || allValues.allSatisfy({ $0 == 0 }) {
            // Return "None" for count-based metrics if 0 or empty
            if metric == .dreams || metric == .nightmares || metric == .positive {
                return "None"
            }
            return "No Data"
        }
        
        if metric.isPercentage {
            let nonZeroBins = allValues.filter { $0 > 0 }
            if nonZeroBins.isEmpty { return "0%" }
            let avg = nonZeroBins.reduce(0, +) / Double(nonZeroBins.count)
            return String(format: "%.0f", avg) + "%"
        } else {
            // For counts in Week/Month/Year, user requested "Average"
            if selectedTimeFrame == .day {
                 let total = allValues.reduce(0, +)
                 return "\(Int(total))"
            } else {
                let total = allValues.reduce(0, +)
                let count = Double(allValues.count)
                let avg = count > 0 ? total / count : 0
                return String(format: "%.1f", avg)
            }
        }
    }
    
    var aggregateLabel: String {
        switch selectedTimeFrame {
        case .day: return "Total Today"
        case .week: return "Average This Week"
        case .month: return "Average This Month"
        case .year: return "Average \(selectedYear)"
        }
    }
    
    var xAxisDomain: ClosedRange<Date> {
        let calendar = Calendar.current
        let now = Date()
        switch selectedTimeFrame {
        case .day:
            let start = calendar.startOfDay(for: now)
            let end = calendar.date(byAdding: .hour, value: 23, to: start)!
            return start...end
        case .week:
            let start = calendar.date(byAdding: .day, value: -6, to: now)!
            return start...now
        case .month:
            let currentComponents = calendar.dateComponents([.year, .month], from: now)
            let start = calendar.date(from: currentComponents)!
            let range = calendar.range(of: .day, in: .month, for: start)!
            let end = calendar.date(byAdding: .day, value: range.count - 1, to: start)!
            return start...end
        case .year:
             let start = calendar.date(from: DateComponents(year: selectedYear, month: 1, day: 1))!
             let end = calendar.date(from: DateComponents(year: selectedYear, month: 12, day: 31))!
             return start...end
        }
    }
    
    // Tone Logic
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
                        // MARK: - TONE VIEW
                        
                        // Week Navigator with Year Dropdown to Right
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
                            
                            // Year Dropdown (Right Side)
                            Menu {
                                ForEach(availableYears, id: \.self) { year in
                                    Button(String(year)) {
                                        selectedToneYear = year
                                        // Update reference date to Jan 1 of that year
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
                                .background(Theme.accent.opacity(0.1), in: Capsule())
                                .foregroundStyle(Theme.accent)
                            }
                        }
                        .padding(16)
                        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal)
                        
                        // Vertical Calendar List
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
                                                .foregroundStyle(metric.color) // Matched to Metric Color (Orange)
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
                        
                    } else {
                        // MARK: - STANDARD CHART VIEW
                        
                        // 1. Time Frame Picker
                        Picker("Time Frame", selection: $selectedTimeFrame) {
                            ForEach(TimeFrame.allCases, id: \.self) { frame in
                                Text(frame.rawValue).tag(frame)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)
                        
                        // 2. Data Header
                        VStack(alignment: .leading, spacing: 4) {
                            Text(aggregateLabel.uppercased())
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                            
                            Text(aggregateValue)
                                .font(.system(size: 42, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                            
                            // Year Dropdown BELOW the average statistic
                            if selectedTimeFrame == .year {
                                Menu {
                                    ForEach(availableYears, id: \.self) { year in
                                        Button(String(year)) { selectedYear = year }
                                    }
                                } label: {
                                    HStack(spacing: 4) {
                                        Text(String(selectedYear))
                                        Image(systemName: "chevron.down")
                                            .font(.caption.bold())
                                    }
                                    .font(.subheadline.bold())
                                    .foregroundStyle(Theme.accent)
                                    .padding(.top, 4)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .padding(.top, 16)
                        
                        // 3. Graph
                        ChartCard {
                            Chart {
                                ForEach(chartData) { data in
                                    if selectedTimeFrame == .day {
                                        BarMark(
                                            x: .value("Time", data.date, unit: .hour),
                                            y: .value("Value", data.value)
                                        )
                                        .foregroundStyle(metric.color.gradient)
                                    } else if selectedTimeFrame == .year {
                                        BarMark(
                                            x: .value("Month", data.date, unit: .month),
                                            y: .value("Value", data.value)
                                        )
                                        .foregroundStyle(metric.color.gradient)
                                    } else {
                                        // Week / Month - Line Chart
                                        LineMark(
                                            x: .value("Date", data.date, unit: .day),
                                            y: .value("Value", data.value)
                                        )
                                        .interpolationMethod(.linear)
                                        .symbol(.circle)
                                        .foregroundStyle(metric.color)
                                        
                                        AreaMark(
                                            x: .value("Date", data.date, unit: .day),
                                            y: .value("Value", data.value)
                                        )
                                        .interpolationMethod(.linear)
                                        .foregroundStyle(
                                            LinearGradient(
                                                colors: [metric.color.opacity(0.3), metric.color.opacity(0.0)],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            )
                                        )
                                    }
                                }
                            }
                            .chartXScale(domain: xAxisDomain)
                            .chartYScale(domain: metric.isPercentage ? .automatic(includesZero: true) : .automatic)
                            .chartYAxis {
                                AxisMarks { value in
                                    AxisGridLine()
                                    AxisTick()
                                    AxisValueLabel()
                                }
                            }
                            .modifier(PercentageScaleModifier(isPercentage: metric.isPercentage))
                            .chartXAxis {
                                if selectedTimeFrame == .day {
                                    AxisMarks(values: .stride(by: .hour, count: 4)) { _ in
                                        AxisValueLabel(format: .dateTime.hour())
                                        AxisGridLine()
                                    }
                                } else if selectedTimeFrame == .week {
                                    AxisMarks(values: .stride(by: .day)) { _ in
                                        AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                                    }
                                } else if selectedTimeFrame == .month {
                                    AxisMarks(values: .stride(by: .day, count: 5)) { _ in
                                        AxisValueLabel(format: .dateTime.day())
                                    }
                                } else {
                                    // Year
                                    AxisMarks(values: .stride(by: .month)) { _ in
                                        AxisValueLabel(format: .dateTime.month(.narrow))
                                    }
                                }
                            }
                            .frame(height: 250)
                        } caption: {
                            EmptyView()
                        }
                        .padding(.horizontal)
                    }
                    
                    // 4. Description & Learn More (Common)
                    VStack(alignment: .leading, spacing: 12) {
                        Text(metric.description)
                            .font(.body)
                            .foregroundStyle(.white.opacity(0.8))
                        + Text(" Learn more...")
                            .font(.body.bold())
                            .foregroundStyle(Theme.accent)
                    }
                    .lineSpacing(4)
                    .padding(24)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal)
                    .onTapGesture {
                        print("Navigate to learn more about \(metric.rawValue)")
                    }
                    
                    Spacer()
                }
                .padding(.top)
            }
        }
        .navigationTitle(metric.rawValue)
        .navigationBarTitleDisplayMode(.large)
    }
}

// Workaround to conditionally apply chartYScale domain
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
