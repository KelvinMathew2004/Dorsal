import SwiftUI

// MARK: - THEME
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

    // MARK: Colors
    static let accent = Color(red: 212/255, green: 175/255, blue: 55/255)   // Gold
    static let secondary = Color(red: 175/255, green: 143/255, blue: 233/255) // Purple
}

// MARK: - VISUAL EFFECTS

struct StarryBackground: View {
    var body: some View {
        ZStack {
            Theme.gradientBackground
                .ignoresSafeArea()
            
            GeometryReader { proxy in
                // Force full size
                Color.clear
                
                ZStack {
                    // Static & Pulsing Stars
                    ForEach(0..<80, id: \.self) { _ in
                        PulsingStar(containerSize: proxy.size)
                    }
                    
                    // Random Shooting Star System
                    ShootingStarSystem(containerSize: proxy.size)
                }
            }
        }
        .ignoresSafeArea()
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
                withAnimation(.linear(duration: 4.0)) {
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
                    .symbolRenderingMode(.palette)
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
        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 16))
    }
}

struct ChartCard<Content: View, Caption: View>: View {
    @ViewBuilder var content: Content
    @ViewBuilder var caption: Caption
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content
            caption
        }
        .padding(20)
        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 20))
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
        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 16))
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
                        .fill(LinearGradient(colors: [.clear, .white.opacity(0.1), .clear], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .rotationEffect(.degrees(30))
                        .offset(x: -geo.size.width + (geo.size.width * 2 * phase))
                }
            )
            .mask(content)
            .onAppear { withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) { phase = 1 } }
    }
}

extension View {
    func shimmering() -> some View { modifier(ShimmerEffect()) }
}
