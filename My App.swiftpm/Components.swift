import SwiftUI

// MARK: - Theme & Shared UI
struct Theme {
    static let bgStart = Color(red: 0.05, green: 0.05, blue: 0.1)
    static let bgEnd = Color(red: 0.1, green: 0.1, blue: 0.2)
    static let accent = Color(red: 0.3, green: 0.8, blue: 0.9) // Cyan/Teal
    static let secondary = Color(red: 0.6, green: 0.4, blue: 0.9) // Soft Violet
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
            .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(LinearGradient(colors: [.white.opacity(0.3), .clear], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
            )
    }
}

struct StatBox: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 50, height: 50)
                .background(color.opacity(0.2))
                .clipShape(Circle())
            
            VStack(spacing: 2) {
                Text(value)
                    .font(.headline)
                    .bold()
                    .foregroundStyle(.white)
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.gray)
                    .textCase(.uppercase)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 15)
        .background(Color.black.opacity(0.3))
        .cornerRadius(16)
    }
}

// Helper for Tag Cloud
struct FlowLayout: View {
    let items: [String]
    let fontSize: CGFloat
    
    var body: some View {
        HStack(spacing: 10) {
            ForEach(items, id: \.self) { item in
                Text("#\(item)")
                    .font(.system(size: fontSize, weight: .medium))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Theme.secondary.opacity(0.2))
                    .foregroundStyle(Theme.secondary)
                    .cornerRadius(20)
            }
        }
    }
}
