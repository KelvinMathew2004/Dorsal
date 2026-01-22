import SwiftUI

struct GeneratingGradientView: View {
    @State private var animate = false
    
    var body: some View {
        MeshGradient(
            width: 3,
            height: 3,
            points: [
                .init(0, 0), .init(0.5, 0), .init(1, 0),
                .init(0, 0.5), .init(0.5, 0.5), .init(1, 0.5),
                .init(0, 1), .init(0.5, 1), .init(1, 1)
            ],
            colors: [
                animate ? .orange : .purple, animate ? .purple : .blue, animate ? .blue : .orange,
                animate ? .blue : .orange, animate ? .orange : .purple, animate ? .purple : .blue,
                animate ? .purple : .blue, animate ? .blue : .orange, animate ? .orange : .purple
            ]
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                animate.toggle()
            }
        }
    }
}
