import WidgetKit
import SwiftUI
import AppIntents

struct RecordDreamControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        AppIntentControlConfiguration(
            kind: "com.KelvinMathew.Dorsal.RecordDream",
            intent: RecordDreamIntent()
        ) { _ in
            ControlWidgetButton(action: RecordDreamIntent()) {
                Label("Record Dream", systemImage: "moon.zzz.fill")
            }
        }
        .displayName("Record Dream")
        .description("Quickly start recording a dream in Dorsal")
    }
}
