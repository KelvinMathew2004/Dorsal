import AppIntents
import WidgetKit
import SwiftUI

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

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Latest Dream", systemImage: "moon.stars.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer(minLength: 2)
            if entry.title == nil && entry.emotion == nil {
                Text("No dreams yet").font(.headline)
                Text("Record one in Dorsal.").font(.caption).foregroundStyle(.secondary)
            } else {
                if entry.metric != .emotionOnly, let title = entry.title {
                    Text(title).font(.headline).lineLimit(2).privacySensitive()
                }
                if entry.metric != .titleOnly {
                    if let emotion = entry.emotion {
                        Label(emotion, systemImage: "heart.fill")
                            .font(.caption).foregroundStyle(.secondary).lineLimit(1).privacySensitive()
                    } else {
                        Text("Emotion analysis pending").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            if let recordedAt = entry.recordedAt {
                Text(recordedAt, style: .date)
                    .font(.caption2).foregroundStyle(.tertiary).privacySensitive()
            }
        }
        .padding()
        .containerBackground(.ultraThinMaterial, for: .widget)
        .widgetURL(entry.dreamID.flatMap { URL(string: "dorsal://dream/\($0.uuidString)") })
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
        .description("Choose whether to show your latest dream title, its emotion, or both.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
