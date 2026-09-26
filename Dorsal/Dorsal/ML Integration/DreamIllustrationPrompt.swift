import Foundation

nonisolated enum DreamIllustrationPrompt {
    static let defaultStyle = ["High quality 3D animated illustration", "Detailed 3D rendering", "Stable composition", "Exceptional cinematic lighting"]
    static let cinematicStyle = ["Photorealistic cinematic shot", "Epic environmental concept art", "Ultra-detailed textures", "Dramatic cinematography", "Deep depth of field", "Grounded realism"]
    static let warmStyle = ["Ethereal dreamlike 3D illustration", "Golden hour luminous lighting", "Soft glowing aura", "Vibrant warm colors", "Gentle floating surrealism"]
    static let comicStyle = ["Epic highly detailed modern inked illustration", "Clean sharp black ink outlines", "Deep dramatic high-contrast shadows", "Vivid cinematic digital coloring with rich gradients", "Intense ambient rim lighting", "Ultra-premium polished graphic art style", "Full of kinetic energy", "Dynamic forced perspective and foreshortening"]
    static let ghibliStyle = ["1990s Japanese cel animation", "Matte gouache background textures", "Delicate hand-drawn linework", "Color palette of mossy greens and warm earth tones", "Soft diffused daylight"]
    static let cyberpunkStyle = ["Cyberpunk sci-fi aesthetic", "Neon-lit environment", "Futuristic high-tech", "Vibrant glowing accents", "Cinematic sci-fi lighting"]
    static let watercolorStyle = ["Traditional watercolor painting", "Loose expressive brushstrokes", "Bleeding wet-on-wet colors", "Soft textured edges", "Artistic illustration on thick paper"]
    static let painterlyAnimationStyle = ["Stylized 3D animation", "Hand-painted surface textures", "Visible painterly brushstrokes", "Layered illustrative lighting", "Dramatic chiaroscuro shading", "Expressive character design"]
        static let lofiStyle = ["Chill lo-fi anime illustration aesthetic", "Soft muted pastel color palette", "Flat 2D digital illustration without outlines", "Moody atmospheric lighting with a soft glow", "Nostalgic retro 1990s anime undertones", "Relaxing and cozy visual tone"]
    static let noirStyle = ["Vintage 1940s film noir photography", "High-contrast black and white", "Harsh chiaroscuro shading", "Cinematic moody atmosphere", "Cinematographic silhouette lighting"]

    static func styled(_ scene: String) -> [String] {
        let styleChoice = UserDefaults.standard.string(forKey: "imageGenerationStyle") ?? "pixar"
        let chosenStyle: [String]
        switch styleChoice {
        case "cinematic": chosenStyle = cinematicStyle
        case "warm": chosenStyle = warmStyle
        case "comic": chosenStyle = comicStyle
        case "ghibli": chosenStyle = ghibliStyle
        case "cyberpunk": chosenStyle = cyberpunkStyle
        case "watercolor": chosenStyle = watercolorStyle
        case "arcane": chosenStyle = painterlyAnimationStyle
        case "lofi": chosenStyle = lofiStyle
        case "noir": chosenStyle = noirStyle
        default: chosenStyle = defaultStyle
        }
        var concepts = [String(scene.prefix(400))]
        concepts.append(contentsOf: chosenStyle)
        concepts.append("Wordless visual narrative")
        concepts.append("Unmarked blank surfaces")
        return concepts
    }
}
