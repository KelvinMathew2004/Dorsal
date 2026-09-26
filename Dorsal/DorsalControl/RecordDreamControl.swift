import WidgetKit
import SwiftUI
import AppIntents

struct RecordDreamControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(
            kind: "com.kelvinmathew.dorsal.RecordDream"
        ) {
            ControlWidgetButton(action: OpenDorsalIntent(target: .recorder)) {
                Label("Open Recorder", systemImage: "moon.zzz.fill")
            }
        }
        .displayName("Open Recorder")
        .description("Open Dorsal's recorder to capture a dream.")
    }
}
