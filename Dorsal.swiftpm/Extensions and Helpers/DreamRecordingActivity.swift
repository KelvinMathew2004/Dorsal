import Foundation

#if canImport(ActivityKit)
import ActivityKit
#endif

@MainActor
enum DreamRecordingActivityManager {
    #if canImport(ActivityKit)
    struct Attributes: ActivityAttributes {
        public struct ContentState: Codable, Hashable {
            var isPaused: Bool
        }

        var startedAt: Date
    }

    private static var activity: Activity<Attributes>?
    #endif

    static func start() {
        #if canImport(ActivityKit)
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        if activity != nil { return }

        let attributes = Attributes(startedAt: Date())
        let contentState = Attributes.ContentState(isPaused: false)
        let content = ActivityContent(state: contentState, staleDate: nil)

        do {
            activity = try Activity.request(attributes: attributes, content: content)
        } catch {
            print("Live Activity start failed: \(error)")
        }
        #endif
    }

    static func update(isPaused: Bool) {
        #if canImport(ActivityKit)
        guard let activity else { return }
        Task {
            let content = ActivityContent(state: Attributes.ContentState(isPaused: isPaused), staleDate: nil)
            await activity.update(content)
        }
        #endif
    }

    static func stop() {
        #if canImport(ActivityKit)
        guard let activity else { return }
        Task {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        self.activity = nil
        #endif
    }
}
