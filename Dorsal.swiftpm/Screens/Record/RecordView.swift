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
                        if store.activeQuestion == nil {
                            // ENCOURAGING TEXT (All questions answered)
                            VStack(spacing: 12) {
                                Image(systemName: "mic.circle.fill")
                                    .font(.system(size: 50))
                                    .foregroundStyle(.green)
                                    .symbolEffect(.pulse)
                                
                                Text("Listening...")
                                    .font(.title2.bold())
                                    .foregroundStyle(.white)
                                
                                Text("You're doing great. Describe any other details you remember.")
                                    .font(.subheadline)
                                    .foregroundStyle(.white.opacity(0.8))
                                    .multilineTextAlignment(.center)
                            }
                            .padding(24)
                            .frame(maxWidth: .infinity)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
                            .overlay(
                                RoundedRectangle(cornerRadius: 24)
                                    .stroke(Color.green.opacity(0.5), lineWidth: 2)
                            )
                            .padding(.horizontal, 30)
                            .transition(.scale.combined(with: .opacity))
                        } else {
                            ChecklistOverlay(store: store)
                                .transition(.move(edge: .top).combined(with: .opacity))
                        }
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
                        
                        ZStack {
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
            // Reset logic: ensure path is clear when entering this tab
            .onChange(of: store.selectedTab) { newValue in
                if newValue == 0 {
                    store.navigationPath = NavigationPath()
                }
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
                    HStack {
                        Text(question.question)
                            .font(.title3.weight(.semibold))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(store.isQuestionSatisfied ? .green : .white)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        if store.isQuestionSatisfied {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .id(question.id)
                    .transition(.push(from: .bottom))
                    
                    // DYNAMIC RECOMMENDATIONS with Better Centering Logic
                    let recommendations = store.getRecommendations(for: question)
                    
                    if !recommendations.isEmpty {
                        // Using a GeometryReader to determine if we should scroll or just center
                        GeometryReader { geometry in
                            let totalWidth = recommendations.reduce(0) { $0 + CGFloat($1.count * 8 + 30) } // Rough estimate
                            
                            if totalWidth < geometry.size.width {
                                // Content fits -> Center it without scrolling
                                HStack(spacing: 8) {
                                    Spacer()
                                    ForEach(recommendations, id: \.self) { item in
                                        RecommendationPill(text: item.capitalized)
                                    }
                                    Spacer()
                                }
                            } else {
                                // Content overflows -> Scrollable
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(recommendations, id: \.self) { item in
                                            RecommendationPill(text: item.capitalized)
                                        }
                                    }
                                    .padding(.horizontal, 20)
                                }
                            }
                        }
                        .frame(height: 30)
                    } else {
                        // Fallback generic keywords
                        HStack(alignment: .center, spacing: 8) {
                            ForEach(question.keywords.prefix(3), id: \.self) { keyword in
                                RecommendationPill(text: keyword.capitalized)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity)
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

struct RecommendationPill: View {
    let text: String
    
    var body: some View {
        Text(text)
            .font(.caption)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
//            .background(Color.white.opacity(0.15), in: Capsule())
//            .foregroundStyle(.white.opacity(0.9))
            .glassEffect()
    }
}

struct AudioVisualizer: View {
    var power: Float
    let bars = 30
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<bars, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Theme.accent.gradient)
                    .frame(width: 4, height: 10 + (CGFloat(power) * CGFloat.random(in: 10...80)))
                    .animation(.easeInOut(duration: 0.1), value: power)
            }
        }
    }
}
