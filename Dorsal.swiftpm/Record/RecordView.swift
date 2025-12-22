import SwiftUI

struct RecordView: View {
    @ObservedObject var store: DreamStore
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.gradientBackground.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    Spacer()
                    
                    VStack(spacing: 40) {
                        
                        if !store.isRecording {
                            VStack(spacing: 12) {
                                Image(systemName: "mic.circle")
                                    .font(.system(size: 60, weight: .thin))
                                    .foregroundStyle(Theme.accent.gradient)
                                    .symbolEffect(.pulse)
                                
                                Text("Capture Dream")
                                    .font(.title2.weight(.medium))
                                    .foregroundStyle(.primary)
                            }
                            .transition(.opacity)
                        } else {
                            // Question Container
                            let questionView = ZStack {
                                if let question = store.activeQuestion {
                                    VStack(spacing: 16) {
                                        Text(question.question)
                                            .font(.title3.weight(.medium))
                                            .multilineTextAlignment(.center)
                                            .foregroundStyle(store.isQuestionSatisfied ? .green : .primary)
                                            .id("txt_\(question.id)")
                                        
                                        if store.isQuestionSatisfied {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.largeTitle)
                                                .foregroundStyle(.green)
                                                .transition(.scale.combined(with: .opacity))
                                        }
                                    }
                                    .padding(32)
                                } else {
                                    Text("Listening...")
                                        .font(.title)
                                        .foregroundStyle(Theme.accent)
                                }
                            }
                            
                            // Apply container style based on OS version
                            if #available(iOS 26, *) {
                                questionView
                                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24))
                                    .frame(height: 200)
                            } else {
                                questionView
                                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
                                    .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.1), lineWidth: 1))
                                    .frame(height: 200)
                            }
                        }
                        
                        // Visualizer
                        HStack(spacing: 4) {
                            ForEach(0..<20, id: \.self) { _ in
                                Capsule()
                                    .fill(Theme.accent.gradient)
                                    .frame(width: 6, height: store.isRecording && !store.isPaused ? CGFloat.random(in: 10...50) + CGFloat(store.audioPower * 100) : 6)
                                    .animation(.easeInOut(duration: 0.15), value: store.audioPower)
                            }
                        }
                        .frame(height: 60)
                        .opacity(store.isRecording ? 1 : 0)
                    }
                    
                    Spacer()
                    
                    // Controls
                    HStack(spacing: 60) {
                        if store.isRecording {
                            // Pause
                            if #available(iOS 26, *) {
                                Button { store.pauseRecording() } label: {
                                    Image(systemName: store.isPaused ? "play.fill" : "pause.fill").font(.title2)
                                }
                                .buttonStyle(.glassProminent)
                                .tint(.gray)
                            } else {
                                Button { store.pauseRecording() } label: {
                                    Image(systemName: store.isPaused ? "play.fill" : "pause.fill").font(.title2).frame(width: 44, height: 44)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.gray)
                                .clipShape(Circle())
                            }
                            
                            // Stop
                            if #available(iOS 26, *) {
                                Button { store.stopRecording(save: true) } label: {
                                    Image(systemName: "arrow.up").font(.title2)
                                }
                                .buttonStyle(.glassProminent)
                                .tint(.green)
                            } else {
                                Button { store.stopRecording(save: true) } label: {
                                    Image(systemName: "arrow.up").font(.title2).frame(width: 44, height: 44)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.green)
                                .clipShape(Circle())
                            }
                            
                        } else {
                            // Record
                            if #available(iOS 26, *) {
                                Button { store.startRecording() } label: {
                                    Image(systemName: "mic.fill").font(.largeTitle)
                                }
                                .buttonStyle(.glassProminent)
                                .tint(Theme.accent)
                            } else {
                                Button { store.startRecording() } label: {
                                    Image(systemName: "mic.fill").font(.largeTitle).frame(width: 60, height: 60)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(Theme.accent)
                                .clipShape(Circle())
                            }
                        }
                    }
                    .padding(.bottom, 60)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}
