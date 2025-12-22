import SwiftUI

struct Theme {
    static let bgStart = Color(red: 0.05, green: 0.02, blue: 0.10)
    static let bgMid = Color(red: 0.10, green: 0.05, blue: 0.20)
    static let bgEnd = Color(red: 0.02, green: 0.02, blue: 0.05)
    
    static let accent = Color(red: 0.4, green: 0.9, blue: 0.8) // Bioluminescent Teal
    static let secondary = Color(red: 0.7, green: 0.4, blue: 0.9) // Dream Violet
    
    static let gradientBackground = LinearGradient(
        colors: [bgStart, bgMid, bgEnd],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

struct GlassCard<Content: View>: View {
    var content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.4), radius: 10, x: 0, y: 5)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(LinearGradient(colors: [.white.opacity(0.15), .clear], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
            )
    }
}

// A reusable Pill tag
struct TagPill: View {
    let text: String
    var isSelected: Bool = false
    
    var body: some View {
        Text("#\(text)")
            .font(.caption.bold())
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Theme.accent : Theme.secondary.opacity(0.2))
            .foregroundStyle(isSelected ? .black : Theme.secondary)
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(Theme.secondary.opacity(0.5), lineWidth: 0.5)
            )
    }
}
