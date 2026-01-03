import SwiftUI

struct OnboardingView: View {
    @ObservedObject var store: DreamStore
    @State private var animate = false
    
    var body: some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea()
            
            // Animated Stars Background (Simplified)
            Circle()
                .fill(Color.purple.opacity(0.3))
                .frame(width: 300, height: 300)
                .blur(radius: 60)
                .offset(x: -100, y: -200)
            
            Circle()
                .fill(Color.blue.opacity(0.3))
                .frame(width: 300, height: 300)
                .blur(radius: 60)
                .offset(x: 100, y: 200)
            
            VStack(spacing: 40) {
                Spacer()
                
                // Icon / Hero
                Image(systemName: "waveform.circle.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 100, height: 100)
                    .foregroundStyle(
                        LinearGradient(colors: [.cyan, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .symbolEffect(.bounce, value: animate)
                
                VStack(spacing: 16) {
                    Text("Welcome to Dorsal")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                    
                    Text("To analyze your dreams, we need access to your microphone and speech recognition.")
                        .multilineTextAlignment(.center)
                        .font(.body)
                        .foregroundStyle(.gray)
                        .padding(.horizontal, 32)
                }
                
                Spacer()
                
                // Permission Buttons
                VStack(spacing: 16) {
                    PermissionRow(
                        title: "Microphone Access",
                        icon: "mic.fill",
                        isGranted: store.hasMicAccess,
                        action: { store.requestMicrophoneAccess() }
                    )
                    
                    PermissionRow(
                        title: "Speech Recognition",
                        icon: "text.bubble.fill",
                        isGranted: store.hasSpeechAccess,
                        action: { store.requestSpeechAccess() }
                    )
                }
                .padding(.horizontal, 24)
                
                // "Continue" Button (Hidden until permissions granted)
                if store.isOnboardingComplete {
                    Text("You're all set!")
                        .font(.headline)
                        .foregroundStyle(.green)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.bottom, 20)
                } else {
                    Text("Please enable permissions to continue")
                        .font(.caption)
                        .foregroundStyle(.gray.opacity(0.5))
                        .padding(.bottom, 20)
                }
            }
            .padding(.vertical)
        }
        .onAppear { animate = true }
    }
}

struct PermissionRow: View {
    let title: String
    let icon: String
    let isGranted: Bool
    let action: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .frame(width: 24)
                .foregroundStyle(
                        isGranted
                        ? Color(red: 0.6, green: 0.85, blue: 0.6)
                        : .white
                    )
            
            Text(title)
                .foregroundStyle(.white)
                .fontWeight(.medium)
            
            Spacer()
            
            if isGranted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color(red: 0.6, green: 0.85, blue: 0.6))
            } else {
                Button(action: action) {
                    Text("Enable")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.black)
                }
                .buttonStyle(.glassProminent)
                .tint(Color.white)
            }
        }
        .padding()
        .glassEffect(.clear.tint(isGranted ? Color.mint.opacity(0.2) : Color.clear), in: RoundedRectangle(cornerRadius: 16))
    }
}
