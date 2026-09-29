import ActivityKit
import AppIntents
import SwiftUI
import UIKit
import WidgetKit

nonisolated struct DreamRecordingActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var isPaused: Bool
        var timerStartDate: Date
        var pauseTime: Date?
    }

    var startedAt: Date
}

@MainActor
final class DreamRecordingActivityCoordinator {
    static let shared = DreamRecordingActivityCoordinator()
    private var activity: Activity<DreamRecordingActivityAttributes>?
    private var timerStartDate: Date?
    private var pauseTime: Date?

    private init() {}

    func startIfAvailable() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let now = Date.now
        let attributes = DreamRecordingActivityAttributes(startedAt: now)
        let state = DreamRecordingActivityAttributes.ContentState(
            isPaused: false,
            timerStartDate: now,
            pauseTime: nil
        )
        do {
            activity = try Activity.request(
                attributes: attributes,
                content: ActivityContent(state: state, staleDate: nil),
                pushType: nil
            )
            timerStartDate = now
            pauseTime = nil
        } catch {
            // Live Activities are optional; a failure must never prevent recording.
            print("Recording Live Activity couldn’t start: \(error)")
        }
    }

    func setPaused(_ isPaused: Bool) async {
        guard let activity, var timerStartDate else { return }
        let now = Date.now

        if isPaused {
            guard pauseTime == nil else { return }
            pauseTime = now
        } else {
            guard let pauseTime else { return }
            timerStartDate = timerStartDate.addingTimeInterval(now.timeIntervalSince(pauseTime))
            self.timerStartDate = timerStartDate
            self.pauseTime = nil
        }

        await activity.update(ActivityContent(
            state: DreamRecordingActivityAttributes.ContentState(
                isPaused: isPaused,
                timerStartDate: timerStartDate,
                pauseTime: isPaused ? now : nil
            ),
            staleDate: nil
        ))
    }

    func end() async {
        guard let activity else { return }
        await activity.end(nil, dismissalPolicy: .immediate)
        self.activity = nil
        timerStartDate = nil
        pauseTime = nil
    }
}

private enum RecordingActivityStyle {
    static let gold = Color(red: 1, green: 0.78, blue: 0.43)
    static let violet = Color(red: 0.19, green: 0.10, blue: 0.34)
    static let midnight = Color(red: 0.045, green: 0.035, blue: 0.10)
    static let activityBackground = Color(red: 0.12, green: 0.065, blue: 0.22)
    static let appIcon: UIImage? = {
        let bundle = Bundle.main
        let image = UIImage(named: "DorsalActivityIcon", in: bundle, compatibleWith: nil)
            ?? bundle.url(forResource: "DorsalActivityIcon", withExtension: "png")
                .flatMap { UIImage(contentsOfFile: $0.path) }
        return image?.withRenderingMode(.alwaysOriginal)
    }()
}

private struct RecordingElapsedTime: View {
    let state: DreamRecordingActivityAttributes.ContentState
    var compact = false

    var body: some View {
        TimelineView(.periodic(
            from: state.pauseTime ?? state.timerStartDate,
            by: state.isPaused ? 3_600 : 60
        )) { timeline in
            Text(
                timerInterval: state.timerStartDate...Date.distantFuture,
                pauseTime: state.pauseTime,
                countsDown: false,
                showsHours: false
            )
            .font((compact ? Font.subheadline : Font.headline).weight(.semibold))
            .monospacedDigit()
            .foregroundStyle(state.isPaused ? .white.opacity(0.6) : .white)
            .multilineTextAlignment(.trailing)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(width: compact ? compactWidth(at: timeline.date) : 88, alignment: .trailing)
            .contentTransition(.numericText())
        }
    }

    private func compactWidth(at date: Date) -> CGFloat {
        let endDate = state.pauseTime ?? date
        let elapsedMinutes = max(0, Int(endDate.timeIntervalSince(state.timerStartDate) / 60))
        let minuteDigits = max(1, String(elapsedMinutes).count)
        // Reserve width for the current minute digits, colon, and two second digits.
        return CGFloat(max(40, (minuteDigits + 3) * 9 + 4))
    }
}

private struct DreamRecordingLockScreenView: View {
    let state: DreamRecordingActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 12) {
            if let appIcon = RecordingActivityStyle.appIcon {
                Image(uiImage: appIcon)
                    .renderingMode(.original)
                    .resizable()
                    .widgetAccentedRenderingMode(.fullColor)
                    .scaledToFit()
                    .frame(width: 40, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(state.isPaused ? "Paused" : "Recording…")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .layoutPriority(1)
                Text("Dorsal")
                    .font(.caption)
                    .foregroundStyle(RecordingActivityStyle.gold)
            }

            Spacer(minLength: 8)

            RecordingElapsedTime(state: state)
            RecordingActivityStopButton()
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
        .background {
            LinearGradient(
                colors: [RecordingActivityStyle.violet.opacity(0.9), RecordingActivityStyle.midnight],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        }
        .widgetURL(URL(string: "dorsal://record"))
    }
}

private struct RecordingActivityStopButton: View {
    var labeled = false

    @ViewBuilder
    private func label(_ title: String) -> some View {
        if labeled {
            Label(title, systemImage: "stop.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(RecordingActivityStyle.midnight)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(RecordingActivityStyle.gold, in: Capsule())
        } else {
            Image(systemName: "stop.fill")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(RecordingActivityStyle.midnight)
                .frame(width: 44, height: 44)
                .background(RecordingActivityStyle.gold, in: Circle())
        }
    }

    @ViewBuilder
    var body: some View {
        if #available(iOS 27.0, *) {
            Button(intent: StopAndAnalyzeDreamRecordingIntent()) { label("Stop & Analyze") }
                .buttonStyle(.plain)
                .accessibilityLabel("Stop and analyze recording")
        } else {
            Button(intent: StopDreamRecordingIntent()) { label("Stop Recording") }
                .buttonStyle(.plain)
                .accessibilityLabel("Stop recording")
        }
    }
}

struct DreamRecordingActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DreamRecordingActivityAttributes.self) { context in
            DreamRecordingLockScreenView(state: context.state)
                .activityBackgroundTint(RecordingActivityStyle.activityBackground)
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: context.state.isPaused ? "pause.circle.fill" : "waveform")
                        .font(.title3)
                        .foregroundStyle(RecordingActivityStyle.gold)
                        .symbolRenderingMode(.hierarchical)
                        .padding(.leading, 6)
                        .padding(.top, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    RecordingElapsedTime(state: context.state)
                        .padding(.trailing, 6)
                        .padding(.top, 4)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 8) {
                        Text(context.state.isPaused ? "Recording paused" : "Recording…")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white.opacity(0.82))
                            .lineLimit(1)
                        RecordingActivityStopButton(labeled: true)
                    }
                    .padding(.top, 4)
                }
            } compactLeading: {
                Image(systemName: context.state.isPaused ? "pause.fill" : "waveform")
                    .foregroundStyle(RecordingActivityStyle.gold)
            } compactTrailing: {
                RecordingElapsedTime(state: context.state, compact: true)
            } minimal: {
                Image(systemName: context.state.isPaused ? "pause.fill" : "waveform")
                    .foregroundStyle(RecordingActivityStyle.gold)
            }
            .keylineTint(RecordingActivityStyle.gold)
            .widgetURL(URL(string: "dorsal://record"))
        }
    }
}
