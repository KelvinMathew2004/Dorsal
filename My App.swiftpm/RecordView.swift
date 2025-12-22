import SwiftUI

struct RecordView: View {
    @ObservedObject var store: DreamStore
    
    var body: some View {
        ZStack {
            Theme.gradientBackground.ignoresSafeArea()
            
            VStack(spacing: 30) {
                // Top Header
                if !store.isRecording {
                    VStack(spacing: 8) {
                        Text("Dorsal")
                            .font(.system(size: 40, weight: .thin, design: .serif))
                            .foregroundStyle(.white.opacity(0.9))
                        Text("Capture the subconscious")
                            .font(.caption)
                            .tracking(2)
                            .foregroundStyle(Theme.accent)
                    }
                    .padding(.top, 60)
                    .transition(.opacity)
                }
                
                Spacer()
                
                // FLOATING QUESTION UI
                if store.isRecording {
                    ZStack {
                        if let question = store.activeQuestion {
                            Text(question.question)
                                .font(.system(size: 28, weight: .light, design: .rounded))
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.center)
                                .padding()
                                .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity), removal: .move(edge: .top).combined(with: .opacity)))
                                .id("Question-\(question.id)") // Force redraw for transition
                        } else {
                            Text("Describe anything else...")
                                .font(.title2)
                                .foregroundStyle(Theme.accent)
                                .transition(.opacity)
                        }
                    }
                    .frame(height: 150)
                    .animation(.spring(response: 0.6), value: store.currentQuestionIndex)
                }
                
                Spacer()
                
                // Visualizer
                HStack(spacing: 4) {
                    ForEach(0..<25, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(LinearGradient(colors: [Theme.accent, Theme.secondary], startPoint: .bottom, endPoint: .top))
                            .frame(width: 4, height: store.isRecording && !store.isPaused ? CGFloat.random(in: 10...60) + CGFloat(store.audioPower * 100) : 4)
                            .animation(.easeInOut(duration: 0.1), value: store.audioPower)
                    }
                }
                .frame(height: 80)
                .opacity(store.isRecording ? 1 : 0)
                
                // Controls
                HStack(spacing: 50) {
                    if store.isRecording {
                        // Pause
                        Button {
                            store.pauseRecording()
                        } label: {
                            Circle()
                                .fill(.ultraThinMaterial)
                                .frame(width: 60, height: 60)
                                .overlay(
                                    Image(systemName: store.isPaused ? "play.fill" : "pause.fill")
                                        .font(.title3)
                                        .foregroundStyle(.white)
                                )
                        }
                        
                        // Submit
                        Button {
                            store.stopRecording(save: true)
                        } label: {
                            Circle()
                                .fill(Theme.accent)
                                .frame(width: 60, height: 60)
                                .overlay(
                                    Image(systemName: "arrow.up")
                                        .font(.title3)
                                        .foregroundStyle(.black)
                                        .bold()
                                )
                                .shadow(color: Theme.accent.opacity(0.4), radius: 10)
                        }
                    } else {
                        // Record
                        Button {
                            store.startRecording()
                        } label: {
                            ZStack {
                                Circle()
                                    .stroke(LinearGradient(colors: [Theme.accent, Theme.secondary], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 2)
                                    .frame(width: 80, height: 80)
                                
                                Circle()
                                    .fill(Theme.secondary.opacity(0.2))
                                    .frame(width: 70, height: 70)
                                
                                Image(systemName: "mic.fill")
                                    .font(.title)
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                }
                .padding(.bottom, 50)
            }
        }
    }
}
