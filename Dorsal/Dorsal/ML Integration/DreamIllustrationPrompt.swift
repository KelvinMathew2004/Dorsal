import Foundation

nonisolated enum DreamIllustrationPrompt {
    static let defaultStyle = ["Whimsical stylized 3D animation", "Rounded friendly forms and expressive faces", "Soft playful proportions", "Vibrant warm colors", "Gentle storybook lighting", "Stable wide composition", "No text or lettering"]
    static let cinematicStyle = ["Photorealistic cinematic shot", "Epic environmental concept art", "Ultra-detailed textures", "Cinematic framing with lighting that follows the dream's emotional tone: soft diffused light for gentle or lighthearted scenes, harder directional light and deeper contrast for tense or ominous scenes", "Deep depth of field", "Grounded realism", "No text or lettering"]
    static let warmStyle = ["Luminous, dreamlike 2D storybook illustration with softly painted surfaces", "Rich warm colors and a gentle golden-hour glow, balanced to suit the scene", "Atmospheric depth, delicate haze, and softly radiant highlights", "Subtle dreamlike touches only where the dream describes them", "Preserve the dream's actual people, setting, action, and objects", "No text or lettering"]
    static let comicStyle = ["Epic highly detailed modern inked illustration", "Clean sharp black ink outlines", "Deep dramatic high-contrast shadows", "Vivid cinematic digital coloring with rich gradients", "Intense ambient rim lighting", "Ultra-premium polished graphic art style", "Full of kinetic energy", "Dynamic forced perspective and foreshortening", "No text or lettering"]
    static let ghibliStyle = ["1990s Japanese cel animation", "Matte gouache background textures", "Delicate hand-drawn linework", "Color palette of mossy greens and warm earth tones", "Soft diffused daylight", "No text or lettering"]
    static let cyberpunkStyle = ["Cyberpunk sci-fi aesthetic", "Neon-lit environment", "Futuristic high-tech", "Vibrant glowing accents", "Cinematic sci-fi lighting", "No text or lettering"]
    static let watercolorStyle = ["Traditional watercolor painting", "Loose expressive brushstrokes", "Bleeding wet-on-wet colors", "Soft textured edges", "Artistic illustration on thick paper", "No text or lettering"]
    // Painterly game-art rendering that preserves the dream's described setting.
    static let painterlyAnimationStyle = [
        "Hand-painted 2D game concept illustration, not a 3D animated render",
        "Visible textured brushwork with layered painterly shading",
        "Confident graphic-novel line accents and expressive silhouettes",
        "Dramatic cinematic lighting and rich, deliberate color",
        "Stylized and hand-shaped rather than smooth or photorealistic",
        "Preserve the dream's actual setting, objects, and events; do not invent a different location",
        "Wide establishing shot",
        "No text or lettering"
    ]
    static let lofiStyle = ["Chill lo-fi anime illustration aesthetic", "Soft muted pastel color palette", "Flat 2D digital illustration without outlines", "Moody atmospheric lighting with a soft glow", "Nostalgic retro 1990s anime undertones", "Relaxing and cozy visual tone", "No text or lettering"]
    static let noirStyle = ["Vintage 1940s film noir photography", "High-contrast black and white", "Harsh chiaroscuro shading", "Cinematic moody atmosphere", "Cinematographic silhouette lighting", "No text or lettering"]

    static var activeStyleChoice: String {
        if #available(iOS 27, *) {
            return UserDefaults.standard.string(forKey: "imageGenerationStyle") ?? "warm"
        }
        return "warm"
    }

    static func styled(_ scene: String) -> [String] {
        let styleChoice = activeStyleChoice
        let chosenStyle: [String]
        switch styleChoice {
        case "cinematic": chosenStyle = cinematicStyle
        case "warm":      chosenStyle = warmStyle
        case "comic":     chosenStyle = comicStyle
        case "ghibli":    chosenStyle = ghibliStyle
        case "cyberpunk": chosenStyle = cyberpunkStyle
        case "watercolor": chosenStyle = watercolorStyle
        case "arcane":    chosenStyle = painterlyAnimationStyle
        case "lofi":      chosenStyle = lofiStyle
        case "noir":      chosenStyle = noirStyle
        default:          chosenStyle = defaultStyle
        }
        var concepts = [String(scene.prefix(400))]
        concepts.append(contentsOf: chosenStyle)
        concepts.append("Wordless visual narrative")
        concepts.append("Unmarked blank surfaces")
        return concepts
    }
}
