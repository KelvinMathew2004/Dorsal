import SwiftUI

struct RecordView: View {
    @ObservedObject var store: DreamStore
    
    var body: some View {
        ZStack {
            // Background
            LinearGradient(colors: [Theme.bgStart, Theme.bgEnd], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            
            VStack(spacing: 40) {
                // Header
                VStack {
                    Text("Good Morning")
                        .font(.largeTitle.weight(.thin))
                        .foregroundStyle(.white.opacity(0.9))
                    Text(Date().formatted(date: .complete, time: .omitted))
                        .font(.subheadline)
                        .foregroundStyle(Theme.accent)
                }
                .padding(.top, 50)
                
                Spacer()
                
                // Live Transcription Area
                if store.isRecording {
                    Text(store.currentTranscript)
                        .font(.title2)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding()
                        .transition(.opacity)
                } else {
                    Text("Tap to record your dream...")
                        .font(.body)
                        .foregroundStyle(.gray)
                }
                
                Spacer()
                
                // Visualizer
                HStack(spacing: 4) {
                    ForEach(0..<15, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Theme.accent.gradient)
                            .frame(width: 5, height: store.isRecording ? CGFloat.random(in: 20...100) : 10)
                            .animation(.easeInOut(duration: 0.2), value: store.audioPower)
                    }
                }
                .frame(height: 100)
                
                // Record Button
                Button {
                    store.toggleRecording()
                } label: {
                    ZStack {
                        Circle()
                            .fill(store.isRecording ? Color.red.gradient : Theme.accent.gradient)
                            .frame(width: 80, height: 80)
                            .shadow(color: store.isRecording ? .red.opacity(0.5) : Theme.accent.opacity(0.5), radius: 20)
                        
                        Image(systemName: store.isRecording ? "stop.fill" : "mic.fill")
                            .font(.title)
                            .foregroundStyle(.white)
                    }
                }
                .padding(.bottom, 50)
            }
            .padding()
        }
    }
}
