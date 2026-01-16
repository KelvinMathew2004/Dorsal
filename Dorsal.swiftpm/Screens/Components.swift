import SwiftUI

// MARK: - THEME
struct ThemeOption: Identifiable, Hashable {
    let id: String // Unique ID for persistence
    let name: String
    let accent: Color
    let secondary: Color
}

enum Theme {

    // MARK: Background gradient
    static let bgStart = Color(red: 0.05, green: 0.02, blue: 0.10)
    static let bgMid   = Color(red: 0.10, green: 0.05, blue: 0.20)
    static let bgEnd   = Color(red: 0.02, green: 0.02, blue: 0.05)

    static let gradientBackground = LinearGradient(
        colors: [bgStart, bgMid, bgEnd],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // MARK: - PREDEFINED THEMES (Rainbow Order)
    static let availableThemes: [ThemeOption] = [
        // 1. Crimson (Red)
        ThemeOption(
            id: "crimson",
            name: "Crimson",
            accent: Color(red: 1.0, green: 0.25, blue: 0.35),
            secondary: Color(red: 0.75, green: 0.65, blue: 0.67) // Brighter gray-red
        ),
        // 2. Sunset (Orange)
        ThemeOption(
            id: "sunset",
            name: "Sunset",
            accent: Color.orange,
            secondary: Color(red: 0.75, green: 0.70, blue: 0.65) // Brighter gray-orange
        ),
        // 3. Gold (Yellow)
        ThemeOption(
            id: "gold",
            name: "Gold",
            accent: Color(red: 212/255, green: 175/255, blue: 55/255),
            secondary: Color(red: 0.75, green: 0.73, blue: 0.65) // Brighter gray-gold
        ),
        // 4. Emerald (Green)
        ThemeOption(
            id: "emerald",
            name: "Emerald",
            accent: Color(red: 0.0, green: 0.75, blue: 0.45),
            secondary: Color(red: 0.65, green: 0.75, blue: 0.70) // Brighter gray-green
        ),
        // 5. Mint (Light Green)
        ThemeOption(
            id: "mint",
            name: "Mint",
            accent: Color(red: 0.4, green: 0.85, blue: 0.6),
            secondary: Color(red: 0.65, green: 0.75, blue: 0.72) // Brighter gray-mint
        ),
        // 6. Neon (Cyan)
        ThemeOption(
            id: "neon",
            name: "Neon",
            accent: Color.cyan,
            secondary: Color(red: 0.65, green: 0.75, blue: 0.80) // Brighter gray-cyan
        ),
        // 7. Ocean (Blue)
        ThemeOption(
            id: "ocean",
            name: "Ocean",
            accent: Color(red: 0.0, green: 0.55, blue: 1.0),
            secondary: Color(red: 0.65, green: 0.70, blue: 0.80) // Brighter gray-blue
        ),
        // 8. Royal (Purple)
        ThemeOption(
            id: "royal",
            name: "Royal",
            accent: Color(red: 0.65, green: 0.4, blue: 1.0),
            secondary: Color(red: 0.70, green: 0.65, blue: 0.80) // Brighter gray-purple
        ),
        // 9. Berry (Pink)
        ThemeOption(
            id: "berry",
            name: "Berry",
            accent: Color(red: 0.9, green: 0.25, blue: 0.6),
            secondary: Color(red: 0.75, green: 0.65, blue: 0.72) // Brighter gray-pink
        ),
        // 10. Slate (Gray)
        ThemeOption(
            id: "slate",
            name: "Slate",
            accent: Color(white: 0.85),
            secondary: Color(white: 0.70) // Brighter gray
        )
    ]

    // MARK: Colors - Dynamic based on UserDefaults
    
    static var accent: Color {
        let id = UserDefaults.standard.string(forKey: "themeID") ?? "gold"
        return availableThemes.first(where: { $0.id == id })?.accent ?? availableThemes[0].accent
    }
    
    static var secondary: Color {
        let id = UserDefaults.standard.string(forKey: "themeID") ?? "gold"
        return availableThemes.first(where: { $0.id == id })?.secondary ?? availableThemes[0].secondary
    }
}

// MARK: - VISUAL EFFECTS

struct StarryBackground: View {
    var body: some View {
        GeometryReader { proxy in
            Color.clear
            
            ZStack {
                ForEach(0..<150, id: \.self) { _ in
                    PulsingStar(containerSize: proxy.size)
                }
                
                ShootingStarSystem(containerSize: proxy.size)
            }
        }
    }
}

struct PulsingStar: View {
    let containerSize: CGSize
    @State private var normalizedX: Double = Double.random(in: 0...1)
    @State private var normalizedY: Double = Double.random(in: 0...1)
    @State private var size: CGFloat = 2.0
    @State private var opacity: Double = Double.random(in: 0.3...0.7)
    @State private var scale: CGFloat = 1.0
    
    let willPulsate = Bool.random()
    
    var body: some View {
        Circle()
            .fill(.white)
            .frame(width: size, height: size)
            .scaleEffect(scale)
            .opacity(opacity)
            .position(
                x: normalizedX * containerSize.width,
                y: normalizedY * containerSize.height
            )
            .onAppear {
                size = CGFloat.random(in: 1.5...3.0)
                if willPulsate {
                    withAnimation(.easeInOut(duration: Double.random(in: 2.0...4.0)).repeatForever(autoreverses: true)) {
                        opacity = 1.0
                        scale = 1.3
                    }
                }
            }
    }
}

struct ShootingStarSystem: View {
    let containerSize: CGSize
    
    struct StarConfig: Identifiable {
        let id = UUID()
        let start: CGPoint
        let end: CGPoint
    }
    
    @State private var activeStar: StarConfig?
    
    var body: some View {
        ZStack {
            if let star = activeStar {
                ShootingStar(startPoint: star.start, endPoint: star.end)
                    .id(star.id)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            // Initial delay
            try? await Task.sleep(for: .seconds(2))
            
            while !Task.isCancelled {
                spawnStar()
                
                // Frequency: 10 to 20 seconds
                try? await Task.sleep(for: .seconds(Double.random(in: 10.0...20.0)))
            }
        }
    }
    
    private func spawnStar() {
        let width = containerSize.width
        let height = containerSize.height
        
        guard width > 0 && height > 0 else { return }
        
        let startX = CGFloat.random(in: 0...width)
        let startY = CGFloat.random(in: 0...(height * 0.5))
        let start = CGPoint(x: startX, y: startY)
        
        // Go far off screen (3x distance)
        let deltaX = CGFloat.random(in: 100...300) * (Bool.random() ? 1 : -1)
        let deltaY = CGFloat.random(in: 200...500)
        let distanceMultiplier = 3.0
        
        let end = CGPoint(x: startX + (deltaX * distanceMultiplier), y: startY + (deltaY * distanceMultiplier))
        
        withAnimation {
            activeStar = StarConfig(start: start, end: end)
        }
    }
}

struct ShootingStar: View {
    let startPoint: CGPoint
    let endPoint: CGPoint
    
    @State private var progress: CGFloat = 0.0
    
    var body: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [.white, .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: 2, height: 120) // Thinner width, longer tail
            // Correct rotation: Vertical rect needs +90 to align 'top' with 0 degrees (Right)
            .rotationEffect(.degrees(angle() + 90))
            .position(
                x: startPoint.x + (endPoint.x - startPoint.x) * progress,
                y: startPoint.y + (endPoint.y - startPoint.y) * progress
            )
            .onAppear {
                // Linear animation ensures constant speed, no pause at end
                withAnimation(.linear(duration: 2.0)) {
                    progress = 1.0
                }
            }
    }
    
    private func angle() -> Double {
        atan2(
            Double(endPoint.y - startPoint.y),
            Double(endPoint.x - startPoint.x)
        ) * 180 / .pi
    }
}

struct TypewriterText: View {
    let text: String
    let animates: Bool
    @State private var displayedText = ""
    
    init(text: String, animates: Bool = true) {
        self.text = text
        self.animates = animates
    }
    
    var body: some View {
        Text(displayedText)
            .task(id: text) {
                if !animates {
                    displayedText = text
                    return
                }
                
                if !text.hasPrefix(displayedText) {
                    displayedText = ""
                }
                
                let currentCount = displayedText.count
                if currentCount < text.count {
                    for i in currentCount..<text.count {
                        if Task.isCancelled { return }
                        try? await Task.sleep(for: .seconds(0.01))
                        let index = text.index(text.startIndex, offsetBy: i)
                        displayedText.append(text[index])
                    }
                }
            }
            .onAppear {
                if !animates {
                    displayedText = text
                }
            }
    }
}

// MARK: - EXTENSIONS
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(.sRGB, red: Double(r)/255, green: Double(g)/255, blue: Double(b)/255, opacity: Double(a)/255)
    }
    
    // Helper to mix colors
    // Fully implemented using UIColor for component extraction
    func mix(with other: Color, by percentage: Double) -> Color {
        let uiColor1 = UIColor(self)
        let uiColor2 = UIColor(other)
        
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        
        uiColor1.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        uiColor2.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        
        let r = r1 + (r2 - r1) * CGFloat(percentage)
        let g = g1 + (g2 - g1) * CGFloat(percentage)
        let b = b1 + (b2 - b1) * CGFloat(percentage)
        let a = a1 + (a2 - a1) * CGFloat(percentage)
        
        return Color(red: r, green: g, blue: b, opacity: a)
    }
}

// MARK: - SHARED COMPONENTS

struct MagicCard<Content: View>: View {
    let title: String
    let icon: String
    let color: Color
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundStyle(color)
                .symbolRenderingMode(.palette)
                .symbolColorRenderingMode(.gradient)
            
            content
                .font(.body)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(24)
        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 24))
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    var showArrow: Bool = false
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.title.bold())
                    .foregroundStyle(.white)
                
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color, color.opacity(0.7))
                    .symbolRenderingMode(.hierarchical)
                    .symbolColorRenderingMode(.gradient)
                    .frame(width: 44, height: 44)
                    .background(color.opacity(0.15), in: Circle())
                
                if showArrow {
                    Image(systemName: "chevron.right")
                        .font(.body.bold())
                        .foregroundStyle(.white.opacity(0.3))
                }
            }
        }
        .padding()
        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 24))
    }
}

struct PreviewChartCard<Content: View, Caption: View>: View {
    @ViewBuilder var content: Content
    @ViewBuilder var caption: Caption
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content
            caption
        }
        .padding()
        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 24))
    }
}

struct DetailedChartCard<Content: View, Caption: View>: View {
    @ViewBuilder var content: Content
    @ViewBuilder var caption: Caption
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content
            caption
        }
        .padding(.leading)
    }
}

struct RingView: View {
    let percentage: Double
    let title: String
    let color: Color
    var showArrow: Bool = false
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            if showArrow {
                Image(systemName: "chevron.right")
                    .font(.body.bold())
                    .foregroundStyle(.white.opacity(0.3))
                    .padding(12)
            }
            
            VStack(spacing: 20) {
                ZStack {
                    Circle().stroke(.white.opacity(0.1), lineWidth: 10)
                    Circle().trim(from: 0, to: percentage / 100)
                        .stroke(color, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text("\(Int(percentage))%").font(.title3.bold()).foregroundStyle(.white)
                }
                .frame(height: 100)
                Text(title).font(.caption.bold()).foregroundStyle(.white.opacity(0.8)).padding(.top, 8)
            }
            .frame(maxWidth: .infinity)
            .padding(20)
        }
        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 24))
    }
}

struct ProgressBarView: View {
    let value: Double
    let total: Double
    let color: Color
    
    @State private var progress: Double = 0
    
    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(color.opacity(0.2))
                
                Capsule()
                    .fill(color)
                    .frame(width: max(0, min(proxy.size.width * (progress / total), proxy.size.width)))
            }
        }
        .frame(height: 8)
        .onAppear {
            withAnimation(.easeOut(duration: 1.0)) {
                progress = value
            }
        }
        .onChange(of: value) {
            withAnimation(.easeOut(duration: 1.0)) {
                progress = value
            }
        }
    }
}

// MARK: - LAYOUT HELPERS

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        var x: CGFloat = 0
        var y: CGFloat = 0
        var maxHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width {
                x = 0
                y += maxHeight + lineSpacing
                maxHeight = 0
            }
            maxHeight = max(maxHeight, size.height)
            x += size.width + spacing
        }
        return CGSize(width: width, height: y + maxHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x: CGFloat = bounds.minX
        var y: CGFloat = bounds.minY
        var maxHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX + 1 {
                x = bounds.minX
                y += maxHeight + lineSpacing
                maxHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            maxHeight = max(maxHeight, size.height)
            x += size.width + spacing
        }
    }
}

// Shimmer Effect
struct ShimmerEffect: ViewModifier {
    @State private var phase: CGFloat = 0
    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [.clear, .white, .clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .rotationEffect(.degrees(30))
                        .scaleEffect(1.4) // Scale up so rotation doesn't un-cover the content
                        .offset(x: -geo.size.width + (geo.size.width * 2 * phase))
                }
            )
            .mask(content)
            .onAppear {
                phase = 0
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

extension View {
    func shimmering() -> some View { modifier(ShimmerEffect()) }
}
