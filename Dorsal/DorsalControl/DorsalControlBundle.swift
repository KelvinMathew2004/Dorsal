import WidgetKit
import SwiftUI

@main
struct DorsalControlBundle: WidgetBundle {
    var body: some Widget {
        RecordDreamControl()
        LatestDreamWidget()
        DreamRecordingActivityWidget()
    }
}
