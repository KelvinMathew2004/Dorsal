import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

nonisolated struct DreamRecordingActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var isPaused: Bool
    }

    var startedAt: Date
}

@MainActor
final class DreamRecordingActivityCoordinator {
    static let shared = DreamRecordingActivityCoordinator()
    private var activity: Activity<DreamRecordingActivityAttributes>?

    private init() {}

    func start() throws {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            throw DreamRecordingActivityError.activitiesDisabled
        }

        let attributes = DreamRecordingActivityAttributes(startedAt: .now)
        let state = DreamRecordingActivityAttributes.ContentState(isPaused: false)
        activity = try Activity.request(
            attributes: attributes,
            content: ActivityContent(state: state, staleDate: nil),
            pushType: nil
        )
    }

    func setPaused(_ isPaused: Bool) async {
        guard let activity else { return }
        await activity.update(ActivityContent(
            state: DreamRecordingActivityAttributes.ContentState(isPaused: isPaused),
            staleDate: nil
        ))
    }

    func end() async {
        guard let activity else { return }
        await activity.end(nil, dismissalPolicy: .immediate)
        self.activity = nil
    }
}

enum DreamRecordingActivityError: Error, CustomLocalizedStringResourceConvertible {
    case activitiesDisabled

    var localizedStringResource: LocalizedStringResource {
        "Live Activities are disabled, so Dorsal can’t safely continue this recording. Enable Live Activities in Settings and try again."
    }
}

struct DreamRecordingActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DreamRecordingActivityAttributes.self) { context in
            HStack(spacing: 12) {
                Image(systemName: context.state.isPaused ? "pause.circle.fill" : "waveform")
                    .font(.title2)
                    .foregroundStyle(.yellow)
                VStack(alignment: .leading, spacing: 3) {
                    Text(context.state.isPaused ? "Recording paused" : "Recording a dream")
                        .font(.headline)
                    Text("Open Dorsal to finish and save")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding()
            .activityBackgroundTint(Color.black.opacity(0.88))
            .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: context.state.isPaused ? "pause.circle.fill" : "waveform")
                        .foregroundStyle(.yellow)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.isPaused ? "Recording paused" : "Recording a dream")
                        .font(.headline)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Open Dorsal to finish and save")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } compactLeading: {
                Image(systemName: context.state.isPaused ? "pause.fill" : "waveform")
                    .foregroundStyle(.yellow)
            } compactTrailing: {
                Image(systemName: "moon.stars.fill")
                    .foregroundStyle(.yellow)
            } minimal: {
                Image(systemName: context.state.isPaused ? "pause.fill" : "waveform")
                    .foregroundStyle(.yellow)
            }
        }
    }
}
