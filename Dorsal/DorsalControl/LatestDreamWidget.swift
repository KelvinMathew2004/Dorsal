import AppIntents
import WidgetKit
import SwiftUI
import UIKit

enum DreamWidgetMetric: String, AppEnum {
    case titleAndEmotion = "titleAndEmotion"
    case emotionOnly = "emotionOnly"
    case titleOnly = "titleOnly"

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Widget Content")
    static let caseDisplayRepresentations: [DreamWidgetMetric: DisplayRepresentation] = [
        .titleAndEmotion: "Title & Emotion",
        .emotionOnly: "Emotion Only",
        .titleOnly: "Title Only"
    ]
}

struct LatestDreamWidgetConfigurationIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Latest Dream Widget"
    static let description = IntentDescription("Choose what to show on the widget.")

    @Parameter(title: "Show", default: .titleAndEmotion)
    var metric: DreamWidgetMetric

    init() {}
    init(metric: DreamWidgetMetric) { self.metric = metric }
}

private struct LatestDreamWidgetEntry: TimelineEntry {
    let date: Date
    let recordedAt: Date?
    let dreamID: UUID?
    let title: String?
    let emotion: String?
    let metric: DreamWidgetMetric
}

private struct LatestDreamWidgetProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> LatestDreamWidgetEntry {
        LatestDreamWidgetEntry(date: .now, recordedAt: .now, dreamID: nil,
                               title: "A dream to remember", emotion: "Curious", metric: .titleAndEmotion)
    }

    func snapshot(for configuration: LatestDreamWidgetConfigurationIntent, in context: Context) async -> LatestDreamWidgetEntry {
        currentEntry(for: configuration)
    }

    func timeline(for configuration: LatestDreamWidgetConfigurationIntent, in context: Context) async -> Timeline<LatestDreamWidgetEntry> {
        let entry = currentEntry(for: configuration)
        return Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(60 * 60)))
    }

    private func currentEntry(for configuration: LatestDreamWidgetConfigurationIntent) -> LatestDreamWidgetEntry {
        let values = NSUbiquitousKeyValueStore.default
        let title = values.string(forKey: "latestDreamWidget.title")
        let emotion = values.string(forKey: "latestDreamWidget.emotion")
        let dreamID = values.string(forKey: "latestDreamWidget.id").flatMap(UUID.init(uuidString:))
        let timestamp = values.double(forKey: "latestDreamWidget.date")
        let recordedAt = timestamp > 0 ? Date(timeIntervalSince1970: timestamp) : nil
        return LatestDreamWidgetEntry(date: .now, recordedAt: recordedAt, dreamID: dreamID,
                                      title: title, emotion: emotion, metric: configuration.metric)
    }
}

private struct LatestDreamWidgetView: View {
    let entry: LatestDreamWidgetEntry

    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var renderingMode
    @Environment(\.colorScheme) private var colorScheme

    private var dateLabel: String {
        guard let date = entry.recordedAt else { return "YOUR JOURNAL" }
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "TODAY" }
        if let weekAgo = calendar.date(byAdding: .day, value: -7, to: .now), date >= weekAgo {
            return date.formatted(.dateTime.weekday(.abbreviated)).uppercased()
        }
        return date.formatted(.dateTime.month(.abbreviated).day()).uppercased()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 7) {
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(renderingMode == .fullColor ? Color(red: 1, green: 0.78, blue: 0.43) : .primary)
                    .widgetAccentable()
                Text(dateLabel)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .tracking(0.8)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 0)
            }

            Spacer(minLength: 10)

            if entry.title == nil && entry.emotion == nil {
                Text("A space for your dreams")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(3)
                Text("Record a dream to see it here.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 5)
            } else if entry.metric == .emotionOnly {
                Text("Dream mood")
                    .font(.system(size: 21, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(3)
                    .minimumScaleFactor(0.8)
            } else if entry.metric != .titleOnly {
                Text(entry.title ?? "Dream saved")
                    .font(.system(size: family == .systemSmall ? 21 : 24, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(family == .systemSmall ? 3 : 2)
                    .minimumScaleFactor(0.8)
                    .privacySensitive()
            } else {
                Text(entry.title ?? "Dream saved")
                    .font(.system(size: family == .systemSmall ? 21 : 24, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(family == .systemSmall ? 3 : 2)
                    .minimumScaleFactor(0.8)
                    .privacySensitive()
            }

            Spacer(minLength: 10)

            if (entry.title != nil || entry.emotion != nil), entry.metric != .titleOnly, let emotion = entry.emotion {
                HStack(spacing: 6) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .widgetAccentable()
                    Text(emotion)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .foregroundStyle(renderingMode == .fullColor ? Color(red: 0.91, green: 0.83, blue: 1) : .primary)
                .privacySensitive()
            } else if (entry.title != nil || entry.emotion != nil), entry.metric != .titleOnly {
                Text("Emotion analysis pending")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(17)
        .containerBackground(for: .widget) {
            DorsalWidgetBackground(renderingMode: renderingMode, colorScheme: colorScheme)
        }
        .widgetURL(entry.dreamID.flatMap { URL(string: "dorsal://dream/\($0.uuidString)") })
    }
}

private struct WeeklyInsightWidgetEntry: TimelineEntry {
    let date: Date
    let periodOverview: String?
    let dominantTheme: String?
    let mentalHealthTrend: String?
    let strategicAdvice: String?
}

private struct WeeklyInsightWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> WeeklyInsightWidgetEntry {
        WeeklyInsightWidgetEntry(date: .now,
                                 periodOverview: "Your dreams have a story to tell.",
                                 dominantTheme: "Finding your way",
                                 mentalHealthTrend: "A gentle pattern is taking shape.",
                                 strategicAdvice: "Take a moment to notice what feels meaningful.")
    }

    func getSnapshot(in context: Context, completion: @escaping (WeeklyInsightWidgetEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WeeklyInsightWidgetEntry>) -> Void) {
        completion(Timeline(entries: [currentEntry()], policy: .after(.now.addingTimeInterval(3 * 60 * 60))))
    }

    private func currentEntry() -> WeeklyInsightWidgetEntry {
        let values = NSUbiquitousKeyValueStore.default
        return WeeklyInsightWidgetEntry(
            date: .now,
            periodOverview: values.string(forKey: "weeklyInsightWidget.overview"),
            dominantTheme: values.string(forKey: "weeklyInsightWidget.theme"),
            mentalHealthTrend: values.string(forKey: "weeklyInsightWidget.trend"),
            strategicAdvice: values.string(forKey: "weeklyInsightWidget.advice")
        )
    }
}

private struct WeeklyInsightWidgetView: View {
    let entry: WeeklyInsightWidgetEntry

    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var renderingMode
    @Environment(\.colorScheme) private var colorScheme

    private var hasInsight: Bool {
        entry.periodOverview != nil || entry.dominantTheme != nil || entry.mentalHealthTrend != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: family == .systemLarge ? 13 : 8) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles.rectangle.stack.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(renderingMode == .fullColor ? Color(red: 0.78, green: 0.67, blue: 1) : .primary)
                    .widgetAccentable()
                Text("WEEKLY REFLECTION")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .tracking(1.15)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Image(systemName: "moon.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            if hasInsight {
                if let theme = entry.dominantTheme, !theme.isEmpty {
                    Text(theme)
                        .font(.system(size: family == .systemLarge ? 25 : 21, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.82)
                        .widgetAccentable()
                        .privacySensitive()
                }

                if let overview = entry.periodOverview, !overview.isEmpty {
                    Text(overview)
                        .font(.system(size: 14, weight: .regular, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(family == .systemLarge ? 3 : 2)
                        .fixedSize(horizontal: false, vertical: true)
                        .privacySensitive()
                }

                if family == .systemLarge {
                    Spacer(minLength: 2)
                    if let trend = entry.mentalHealthTrend, !trend.isEmpty {
                        insightSection("The pattern", text: trend, icon: "waveform.path.ecg")
                    }
                    if let advice = entry.strategicAdvice, !advice.isEmpty {
                        insightSection("A thought to carry", text: advice, icon: "sparkle")
                    }
                }
            } else {
                Spacer(minLength: 4)
                Text("Your week, in focus")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                Text("As you record dreams, Dorsal will reflect on the patterns taking shape.")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(family == .systemLarge ? 4 : 3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(17)
        .containerBackground(for: .widget) {
            DorsalWidgetBackground(renderingMode: renderingMode, colorScheme: colorScheme)
        }
        .widgetURL(URL(string: "dorsal://insights"))
    }

    private func insightSection(_ title: String, text: String, icon: String) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(renderingMode == .fullColor ? Color(red: 1, green: 0.78, blue: 0.43) : .primary)
                .widgetAccentable()
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 3) {
                Text(title.uppercased())
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(0.9)
                    .foregroundStyle(.secondary)
                Text(text)
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .privacySensitive()
            }
        }
    }
}

private struct DorsalWidgetBackground: View {
    let renderingMode: WidgetRenderingMode
    let colorScheme: ColorScheme

    var body: some View {
        if renderingMode == .fullColor {
            ZStack {
                LinearGradient(
                    colors: colorScheme == .dark
                        ? [Color(red: 0.14, green: 0.08, blue: 0.28), Color(red: 0.07, green: 0.04, blue: 0.16), Color(red: 0.025, green: 0.025, blue: 0.07)]
                        : [Color(red: 0.88, green: 0.83, blue: 1), Color(red: 0.78, green: 0.74, blue: 0.96), Color(red: 0.65, green: 0.68, blue: 0.9)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Circle()
                    .fill(Color.purple.opacity(colorScheme == .dark ? 0.28 : 0.18))
                    .frame(width: 170, height: 170)
                    .blur(radius: 38)
                    .offset(x: 110, y: -90)
                Circle()
                    .fill(Color.blue.opacity(colorScheme == .dark ? 0.14 : 0.16))
                    .frame(width: 150, height: 150)
                    .blur(radius: 40)
                    .offset(x: -115, y: 100)
            }
        } else {
            Color.clear
        }
    }
}

struct LatestDreamWidget: Widget {
    private let kind = "com.kelvinmathew.dorsal.LatestDream"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: LatestDreamWidgetConfigurationIntent.self,
                               provider: LatestDreamWidgetProvider()) { entry in
            LatestDreamWidgetView(entry: entry)
        }
        .configurationDisplayName("Latest Dream")
        .description("A quiet glimpse of your latest dream and its emotion.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private struct LatestDreamImageWidgetEntry: TimelineEntry {
    let date: Date
    let recordedAt: Date?
    let dreamID: UUID?
    let title: String?
    let emotion: String?
    let imageData: Data?
}

private struct LatestDreamImageWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> LatestDreamImageWidgetEntry {
        LatestDreamImageWidgetEntry(date: .now, recordedAt: .now, dreamID: nil,
                                    title: "A dream to remember", emotion: "Curious", imageData: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (LatestDreamImageWidgetEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<LatestDreamImageWidgetEntry>) -> Void) {
        completion(Timeline(entries: [currentEntry()], policy: .after(.now.addingTimeInterval(60 * 60))))
    }

    private func currentEntry() -> LatestDreamImageWidgetEntry {
        let values = NSUbiquitousKeyValueStore.default
        let groupIdentifier = "group.com.kelvinmathew.dorsal"
        let imageURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: groupIdentifier)?
            .appendingPathComponent("latest-dream-widget.jpg")
        let timestamp = values.double(forKey: "latestDreamWidget.date")
        return LatestDreamImageWidgetEntry(
            date: .now,
            recordedAt: timestamp > 0 ? Date(timeIntervalSince1970: timestamp) : nil,
            dreamID: values.string(forKey: "latestDreamWidget.id").flatMap(UUID.init(uuidString:)),
            title: values.string(forKey: "latestDreamWidget.title"),
            emotion: values.string(forKey: "latestDreamWidget.emotion"),
            imageData: imageURL.flatMap { try? Data(contentsOf: $0) }
        )
    }
}

private struct LatestDreamImageWidgetView: View {
    let entry: LatestDreamImageWidgetEntry

    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var renderingMode
    @Environment(\.colorScheme) private var colorScheme

    private var dateLabel: String {
        guard let date = entry.recordedAt else { return "YOUR JOURNAL" }
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if let weekAgo = calendar.date(byAdding: .day, value: -7, to: .now), date >= weekAgo {
            return date.formatted(.dateTime.weekday(.abbreviated))
        }
        return date.formatted(.dateTime.month(.abbreviated).day())
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottomLeading) {
                if let imageData = entry.imageData, let image = UIImage(data: imageData) {
                    Image(uiImage: image)
                        .resizable()
                        .widgetAccentedRenderingMode(renderingMode == .accented ? .desaturated : .fullColor)
                        .scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
                        .clipped()
                } else {
                    DorsalWidgetBackground(renderingMode: renderingMode, colorScheme: colorScheme)
                }

                LinearGradient(
                    stops: [
                        .init(color: .black.opacity(0.28), location: 0),
                        .init(color: .clear, location: 0.42),
                        .init(color: .black.opacity(0.78), location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                VStack(alignment: .leading, spacing: 0) {
                    Label(dateLabel, systemImage: "moon.stars.fill")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .lineLimit(1)
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.45), radius: 3, y: 1)

                    Spacer(minLength: 8)

                    Text(entry.title ?? "Latest Dream")
                        .font(.system(size: family == .systemSmall ? 19 : 23, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.78)
                        .shadow(color: .black.opacity(0.55), radius: 4, y: 1)
                        .privacySensitive()

                    if let emotion = entry.emotion, !emotion.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 10, weight: .semibold))
                                .widgetAccentable()
                            Text(emotion)
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.55), radius: 3, y: 1)
                        .padding(.top, 7)
                        .privacySensitive()
                    }
                }
                .padding(14)
            }
            .clipShape(RoundedRectangle(cornerRadius: 23, style: .continuous))
            .privacySensitive()
        }
        .containerBackground(for: .widget) { Color.clear }
        .widgetURL(entry.dreamID.flatMap { URL(string: "dorsal://dream/\($0.uuidString)") })
    }
}

struct LatestDreamImageWidget: Widget {
    private let kind = "com.kelvinmathew.dorsal.LatestDreamImage"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LatestDreamImageWidgetProvider()) { entry in
            LatestDreamImageWidgetView(entry: entry)
        }
        .configurationDisplayName("Latest Dream Art")
        .description("Your latest dream illustration with its date and emotion.")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}

struct WeeklyInsightWidget: Widget {
    private let kind = "com.kelvinmathew.dorsal.WeeklyInsight"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WeeklyInsightWidgetProvider()) { entry in
            WeeklyInsightWidgetView(entry: entry)
        }
        .configurationDisplayName("Weekly Reflection")
        .description("A calm look at the themes and patterns in your dreams.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}
