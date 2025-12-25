import SwiftUI

// MARK: - THEME
struct Theme {
    static let bgStart = Color(red: 0.05, green: 0.02, blue: 0.10)
    static let bgMid = Color(red: 0.10, green: 0.05, blue: 0.20)
    static let bgEnd = Color(red: 0.02, green: 0.02, blue: 0.05)
    
    static let accent = Color.teal
    static let secondary = Color.purple
    
    static let gradientBackground = LinearGradient(
        colors: [bgStart, bgMid, bgEnd],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
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

/// A generic glass card container used for Analysis, Advice, etc.
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
        }
        .padding(24)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24))
    }
}

/// A smaller card for key-value statistics (e.g. Total Dreams)
struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) { // Increased spacing
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 44, height: 44) // Fixed frame for alignment
                .background(color.opacity(0.15), in: Circle())
            
            VStack(alignment: .leading, spacing: 4) { // Tight spacing for text
                Text(value)
                    .font(.title.bold())
                    .foregroundStyle(.white)
                
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
    }
}

/// A container for Charts in the Insights view
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

/// A circular progress ring for metrics like Lucidty/Vividness
struct RingView: View {
    let percentage: Double
    let title: String
    let color: Color
    
    var body: some View {
        VStack {
            ZStack {
                // Background Track
                Circle()
                    .stroke(.white.opacity(0.1), lineWidth: 10)
                
                // Progress
                Circle()
                    .trim(from: 0, to: percentage / 100)
                    .stroke(color, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                
                Text("\(Int(percentage))%")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
            }
            .frame(height: 100)
            
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(.white.opacity(0.8))
        }
        .padding()
        .frame(maxWidth: .infinity)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
    }
}

/// Standard Tag Pill with Glass Effect
struct TagPill: View {
    let text: String
    var isSelected: Bool = false
    
    var body: some View {
        Text("#\(text)")
            .font(.caption.bold())
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .foregroundStyle(isSelected ? .black : .secondary)
            .glassEffect(isSelected ? .regular.tint(Theme.accent) : .regular, in: .capsule)
    }
}

// MARK: - LAYOUT HELPERS

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        var height: CGFloat = 0
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
        let width = bounds.width
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

// Shimmer Effect for loading states
struct ShimmerEffect: ViewModifier {
    @State private var phase: CGFloat = 0
    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [.clear, .white.opacity(0.1), .clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .rotationEffect(.degrees(30))
                        .offset(x: -geo.size.width + (geo.size.width * 2 * phase))
                }
            )
            .mask(content)
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

extension View {
    func shimmering() -> some View {
        modifier(ShimmerEffect())
    }
}
