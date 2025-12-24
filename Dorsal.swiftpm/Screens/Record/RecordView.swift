import SwiftUI

struct RecordView: View {
    @ObservedObject var store: DreamStore
    @State private var showRipple = false
    
    var body: some View {
        NavigationStack(path: $store.navigationPath) {
            ZStack {
                Theme.gradientBackground.ignoresSafeArea()
                
                VStack {
                    Spacer()
                    
                    // MARK: - Smart Checklist / Prompt Overlay
                    if store.isRecording {
                        ChecklistOverlay(store: store)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    } else {
                        // Welcome State
                        VStack(spacing: 16) {
                            Image(systemName: "moon.stars.fill")
                                .font(.system(size: 60))
                                .foregroundStyle(Theme.accent)
                                .symbolEffect(.bounce, value: true)
                            
                            Text("Good Morning")
                                .font(.largeTitle.weight(.bold))
                            
                            Text("Ready to capture your dreams?")
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.bottom, 50)
                    }
                    
                    Spacer()
                    
                    // MARK: - Visualization
                    if store.isRecording {
                        AudioVisualizer(power: store.audioPower)
                            .frame(height: 100)
                            .padding(.bottom, 20)
                            .opacity(store.isPaused ? 0.5 : 1.0)
                    }
                    
                    // MARK: - Controls
                    HStack(spacing: 40) {
                        // PAUSE BUTTON (Restored)
                        if store.isRecording {
                            Button {
                                store.pauseRecording()
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(.ultraThinMaterial)
                                        .frame(width: 60, height: 60)
                                    
                                    Image(systemName: store.isPaused ? "play.fill" : "pause.fill")
                                        .font(.title2)
                                        .foregroundStyle(.white)
                                        .contentTransition(.symbolEffect(.replace))
                                }
                            }
                            .transition(.scale.combined(with: .opacity))
                        }
                        
                        // RECORD / STOP BUTTON
                        ZStack {
                            // Pulse Effect
                            if store.isRecording && !store.isPaused {
                                Circle()
                                    .stroke(Theme.accent.opacity(0.3), lineWidth: 2)
                                    .frame(width: 120, height: 120)
                                    .scaleEffect(showRipple ? 1.5 : 1.0)
                                    .opacity(showRipple ? 0 : 1)
                                    .onAppear {
                                        withAnimation(.easeOut(duration: 1.5).repeatForever(autoreverses: false)) {
                                            showRipple = true
                                        }
                                    }
                            }
                            
                            Button {
                                if store.isRecording {
                                    store.stopRecording(save: true)
                                } else {
                                    store.startRecording()
                                }
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(store.isRecording ? .red : Theme.accent)
                                        .frame(width: 80, height: 80)
                                    
                                    Image(systemName: store.isRecording ? "stop.fill" : "mic.fill")
                                        .font(.title)
                                        .foregroundStyle(.white)
                                        .contentTransition(.symbolEffect(.replace))
                                }
                            }
                            .disabled(store.isProcessing)
                        }
                        
                        // CANCEL BUTTON (Hidden initially)
                        if store.isRecording {
                            Button {
                                store.stopRecording(save: false)
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(.ultraThinMaterial)
                                        .frame(width: 60, height: 60)
                                    
                                    Image(systemName: "xmark")
                                        .font(.title2)
                                        .foregroundStyle(.white)
                                }
                            }
                            .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .padding(.bottom, 40)
                    .animation(.spring(response: 0.4, dampingFraction: 0.7), value: store.isRecording)
                    
                    if store.isProcessing {
                        HStack(spacing: 8) {
                            ProgressView()
                                .tint(.white)
                            Text("Analyzing with Foundation Models...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationTitle("Record")
            .navigationDestination(for: Dream.self) { dream in
                DreamDetailView(store: store, dream: dream)
            }
            .alert("Microphone Access", isPresented: $store.showPermissionAlert) {
                Button("Open Settings", role: .none) { store.openSettings() }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text(store.permissionError ?? "Please enable microphone access in settings.")
            }
        }
    }
}

// MARK: - Subviews

struct ChecklistOverlay: View {
    @ObservedObject var store: DreamStore
    
    var body: some View {
        VStack(spacing: 16) {
            if let question = store.activeQuestion {
                VStack(spacing: 12) {
                    Text(question.question)
                        .font(.title3.weight(.semibold))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white)
                        .id(question.id)
                        .transition(.push(from: .bottom))
                    
                    // DYNAMIC RECOMMENDATIONS
                    // We check if the question relates to people/places and show past data
                    if !store.getRecommendations(for: question).isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(store.getRecommendations(for: question), id: \.self) { item in
                                    Text(item)
                                        .font(.caption)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(Color.white.opacity(0.15), in: Capsule())
                                        .foregroundStyle(.white.opacity(0.9))
                                }
                            }
                        }
                        .frame(height: 30)
                    } else {
                        // Fallback generic keywords if no history
                        HStack {
                            ForEach(question.keywords.prefix(3), id: \.self) { keyword in
                                Text(keyword)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.white.opacity(0.2), in: Capsule())
                            }
                        }
                    }
                }
                .padding(24)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(store.isQuestionSatisfied ? Color.green : Color.white.opacity(0.2), lineWidth: 2)
                )
                .padding(.horizontal, 30)
                .offset(y: store.isQuestionSatisfied ? -20 : 0)
                .animation(.spring(response: 0.4, dampingFraction: 0.6), value: store.isQuestionSatisfied)
            }
        }
    }
}

struct AudioVisualizer: View {
    var power: Float
    let bars = 30 // Increased bar count for better look
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<bars, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Theme.accent.gradient)
                    // Create a wave effect by varying height based on index and power
                    .frame(width: 4, height: 10 + (CGFloat(power) * CGFloat.random(in: 10...80)))
                    .animation(.easeInOut(duration: 0.1), value: power)
            }
        }
    }
}
