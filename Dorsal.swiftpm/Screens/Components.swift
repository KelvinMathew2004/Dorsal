import SwiftUI

// MARK: - THEME
struct Theme {
    static let bgStart = Color(red: 0.05, green: 0.02, blue: 0.10)
    static let bgMid = Color(red: 0.10, green: 0.05, blue: 0.20)
    static let bgEnd = Color(red: 0.02, green: 0.02, blue: 0.05)
        
    static let gradientBackground = LinearGradient(
        colors: [bgStart, bgMid, bgEnd],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - VISUAL EFFECTS

struct StarryBackground: View {
    var body: some View {
        ZStack {
            Theme.gradientBackground
                .ignoresSafeArea()
            
            GeometryReader { proxy in
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
        let duration: Double
    }
    
    @State private var activeStar: StarConfig?
    
    var body: some View {
        ZStack {
            if let star = activeStar {
                ShootingStar(startPoint: star.start, endPoint: star.end, duration: star.duration)
                    .id(star.id)
                    // FIX 2: Explicit transition prevents the view from vanishing instantly
                    .transition(.opacity)
            }
        }
        .task {
            // DEBUG: Reduced delay to 3 seconds for testing; change back to 15+ later
            try? await Task.sleep(for: .seconds(3))
            
            while !Task.isCancelled {
                spawnStar()
                // Frequency: Wait 5-10 seconds for testing visibility
                try? await Task.sleep(for: .seconds(Double.random(in: 5.0...10.0)))
            }
        }
    }
    
    private func spawnStar() {
        let width = containerSize.width
        let height = containerSize.height
        
        guard width > 0 && height > 0 else { return }
        
        // Pick a start point
        let startX = CGFloat.random(in: 0...width * 0.8)
        let startY = CGFloat.random(in: 0...height * 0.5)
        let start = CGPoint(x: startX, y: startY)
        
        // Calculate end point (aiming downwards and right)
        let angle = Double.random(in: 0.3...0.8)
        let distance = max(width, height)
        let end = CGPoint(
            x: startX + (distance * cos(angle)),
            y: startY + (distance * sin(angle))
        )
        
        // FIX 3: Ensure UI updates happen on main thread
        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 0.5)) {
                self.activeStar = StarConfig(start: start, end: end, duration: 1.5)
            }
        }
    }
}

struct ShootingStar: View {
    let startPoint: CGPoint
    let endPoint: CGPoint
    let duration: Double
    @State private var progress: CGFloat = 0.0
    
    var body: some View {
        // FIX 4: Removed nested GeometryReader which was resetting coordinates
        HStack(spacing: 0) {
            LinearGradient(
                colors: [.white.opacity(0), .white.opacity(0.5)],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: 100, height: 2)
            
            Circle()
                .fill(.white)
                .frame(width: 3, height: 3)
                .shadow(color: .white, radius: 3)
        }
        // Rotate around the "head" (the circle)
        .rotationEffect(.degrees(calculateAngle()), anchor: .trailing)
        .position(
            x: startPoint.x + (endPoint.x - startPoint.x) * progress,
            y: startPoint.y + (endPoint.y - startPoint.y) * progress
        )
        .opacity(progress < 0.1 ? progress * 10 : (progress > 0.9 ? (1 - progress) * 10.0 : 1))
        .onAppear {
            withAnimation(.linear(duration: duration)) {
                progress = 1.0
            }
            // Auto-cleanup after animation completes
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                progress = 0
            }
        }
    }
    
    private func calculateAngle() -> Double {
        let deltaX = endPoint.x - startPoint.x
        let deltaY = endPoint.y - startPoint.y
        return atan2(deltaY, deltaX) * 180 / .pi
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
            
            content
                .font(.body)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(24)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24))
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
            
            // Icon and Optional Arrow centered vertically to the right
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)
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
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
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
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20))
    }
}

struct RingView: View {
    let percentage: Double
    let title: String
    let color: Color
    var showArrow: Bool = false
    
    var body: some View {
        // Changed back to .topTrailing to position arrow in the corner
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
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
    }
}

struct TagPill: View {
    let text: String
    var isSelected: Bool = false
    
    var body: some View {
        Text(text)
            .font(.caption.bold())
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .foregroundStyle(isSelected ? .black : .secondary)
            .glassEffect(isSelected ? .regular.tint(Color.accentColor) : .regular, in: .capsule)
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
