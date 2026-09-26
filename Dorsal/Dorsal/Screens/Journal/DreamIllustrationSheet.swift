import SwiftUI
import ImagePlayground

/// Snapshot the inputs when the sheet opens so background prompt preparation and
/// profile changes cannot restart a generation the person is already editing.
struct DreamIllustrationRequest {
    let promptTags: [String]
    let profileImage: UIImage?

    init(promptTags: [String], profileImageData: Data?) {
        self.promptTags = promptTags
        let includesMyself = UserDefaults.standard.object(forKey: "imageIncludeMyself") as? Bool ?? true
        if includesMyself {
            self.profileImage = profileImageData.flatMap(UIImage.init(data:))
        } else {
            self.profileImage = nil
        }
    }

        var conceptText: [String] {
        var result = promptTags
        let includesMyself = UserDefaults.standard.object(forKey: "imageIncludeMyself") as? Bool ?? true
        if includesMyself && profileImage != nil {
            result.append("The person in the reference profile photo is the dreamer. Use their appearance for the dreamer, not for other characters.")
            result.append("Create the dream scene described. The photo is a reference for the dreamer's appearance, not the setting.")
        } else if !includesMyself {
            result.append("Do not depict the dream narrator or use any reference likeness; other dream characters and animals may appear when described in the dream.")
        }
        return result
    }

    @available(iOS 27, *)
    var options: ImagePlaygroundOptions {
        var options = ImagePlaygroundOptions()
        options.creationStrategy = .generateNew
        let includesMyself = UserDefaults.standard.object(forKey: "imageIncludeMyself") as? Bool ?? true
        options.personalization = (includesMyself && profileImage != nil) ? .enabled : .disabled
        return options
    }
}

struct DreamIllustrationSheet: ViewModifier {
    @Binding var isPresented: Bool
    let request: DreamIllustrationRequest?
    let onCompletion: (URL) -> Void

    @AppStorage("imageGenerationStyle") var imageGenerationStyle: String = "pixar"

    @available(iOS 27, *)
    var dynamicStyle: ImagePlaygroundStyle? {
        switch imageGenerationStyle {
        case "warm", "pixar", "lofi": .animation
        case "watercolor", "comic", "noir", "cinematic", "cyberpunk", "ghibli", "arcane": .illustration
        default: nil
        }
    }

    func body(content: Content) -> some View {
        if #available(iOS 27, *) {
            let base = content
                .imagePlaygroundSheet(
                    isPresented: $isPresented,
                    concepts: (request?.conceptText ?? []).map(ImagePlaygroundConcept.text),
                    sourceImage: request?.profileImage.map { Image(uiImage: $0) },
                    onCompletion: onCompletion
                )
                .imagePlaygroundOptions(request?.options ?? ImagePlaygroundOptions())

            if let style = dynamicStyle {
                base.imagePlaygroundGenerationStyle(style)
            } else {
                base
            }
        } else {
            content
        }
    }
}
