import Foundation

enum ImageScenePreference {
    static let settingOnly = "settingOnly"
    static let dreamScene = "dreamScene"

    static var includesPeople: Bool {
        if let mode = UserDefaults.standard.string(forKey: "imageSceneMode") {
            return mode == dreamScene
        }
        // Preserve the preference saved by earlier versions.
        return UserDefaults.standard.object(forKey: "imageIncludeMyself") as? Bool ?? false
    }
}
