import SwiftUI
import ImagePlayground

/// Snapshot the inputs when the sheet opens so background prompt preparation and
/// profile changes cannot restart a generation the person is already editing.
struct DreamIllustrationRequest {
    let promptTags: [String]
    let profileImage: UIImage?
    let usesAnimationStyle: Bool

    init(promptTags: [String], profileImageData: Data?, profileSubjectCutoutData: Data? = nil, styleChoice: String = "warm") {
        self.promptTags = promptTags
        self.usesAnimationStyle = styleChoice == "warm"
        let includesMyself = ImageScenePreference.includesPeople
        if includesMyself {
            self.profileImage = (profileSubjectCutoutData ?? profileImageData)
                .flatMap(UIImage.init(data:))
                .map(Self.squareCanvas)
        } else {
            self.profileImage = nil
        }
    }

    /// Gives Image Playground a square source while preserving the full subject.
    /// Transparent padding avoids cropping the person's head or body to fill a square.
    private static func squareCanvas(_ image: UIImage) -> UIImage {
        let side = max(image.size.width, image.size.height)
        guard side > 0 else { return image }

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side))
        return renderer.image { _ in
            let origin = CGPoint(x: (side - image.size.width) / 2, y: (side - image.size.height) / 2)
            image.draw(in: CGRect(origin: origin, size: image.size))
        }
    }

    var conceptText: [String] {
        var result = promptTags
        let includesPeople = ImageScenePreference.includesPeople
        if includesPeople && profileImage != nil {
            result.append("The person in the reference profile photo is the dreamer. Preserve their facial identity, but freely change their clothing and outfit to fit this dream; do not copy the reference outfit unless it suits the scene. Do not use the profile photo as the setting.")
        } else if !includesPeople {
            result.append("Create only the dream's setting and atmosphere. Do not depict people, animals, the narrator, or any reference likeness.")
        } else {
            result.append("Create the dream scene with people and animals when the dream describes them. Include a generic dreamer only when supported by the scene.")
        }
        // Explicit suppression — Image Playground responds to these as direct concept tags
        result.append("No speech bubbles")
        result.append("No text overlays")
        result.append("No captions or labels")
        return result
    }

    @available(iOS 27, *)
    var options: ImagePlaygroundOptions {
        var options = ImagePlaygroundOptions()
        options.creationStrategy = .generateNew
        options.sizeSpecification = .closest(to: CGSize(width: 1024, height: 1024))
        let includesMyself = ImageScenePreference.includesPeople
        options.personalization = (includesMyself && profileImage != nil) ? .enabled : .disabled
        return options
    }
}

struct DreamIllustrationSheet: ViewModifier {
    @Binding var isPresented: Bool
    let request: DreamIllustrationRequest?
    let onCompletion: (URL) -> Void

    func body(content: Content) -> some View {
        if #available(iOS 27, *) {
            let sheet = content
                .imagePlaygroundSheet(
                    isPresented: $isPresented,
                    concepts: (request?.conceptText ?? []).map(ImagePlaygroundConcept.text),
                    sourceImage: request?.profileImage.map { Image(uiImage: $0) },
                    onCompletion: onCompletion
                )
                .imagePlaygroundOptions(request?.options ?? ImagePlaygroundOptions())
            if request?.usesAnimationStyle == true {
                sheet.imagePlaygroundGenerationStyle(.animation, in: [.animation])
            } else {
                sheet
            }
        } else {
            content
        }
    }
}
