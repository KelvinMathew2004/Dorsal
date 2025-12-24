import SwiftUI

struct RecordView: View {
    @ObservedObject var store: DreamStore
    @State private var showRipple = false
    
    @Namespace private var namespace
    
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
                            .padding(.bottom, 40)
                            .opacity(store.isPaused ? 0.5 : 1.0)
                    }
                    
                    // MARK: - Controls
                    // Restored GlassEffectContainer for the "capsule" look
                    GlassEffectContainer(spacing: 0) {
                        // Dynamic spacing: buttons get closer (20) when paused, further (40) when recording
                        HStack(spacing: store.isPaused ? 20 : 40) {
                            
                            // 1. Pause Button (Left)
                            if store.isRecording {
                                Button {
                                    store.pauseRecording()
                                } label: {
                                    Image(systemName: store.isPaused ? "play.fill" : "pause.fill")
                                        .contentTransition(.symbolEffect(.replace))
                                }
                                .font(.title2)
                                .foregroundStyle(.white)
                                .frame(width: 60, height: 60)
                                .contentShape(Circle())
                                .glassEffect(.regular.interactive(), in: Circle())
                                .glassEffectID("pauseButton", in: namespace)
                            }
                            
                            // 2. Main Record/Stop Button (Center)
                            Button {
                                if store.isRecording {
                                    store.stopRecording(save: true)
                                } else {
                                    store.startRecording()
                                }
                            } label: {
                                Image(systemName: store.isRecording ? "stop.fill" : "mic.fill")
                                    .contentTransition(.symbolEffect(.replace))
                                    .padding(15)
                            }
                            .font(.title)
                            .foregroundStyle(.white)
                            .frame(width: 80, height: 80) // Fixed layout size prevents jumping
                            .background {
                                // Ripple in background: visible but doesn't affect layout flow
                                if store.isRecording && !store.isPaused {
                                    Circle()
                                        .stroke(.red.opacity(0.5), lineWidth: 2)
                                        .frame(width: 120, height: 120)
                                        .scaleEffect(showRipple ? 1.5 : 1.0)
                                        .opacity(showRipple ? 0 : 1)
                                        .onAppear {
                                            withAnimation(.easeOut(duration: 1.5).repeatForever(autoreverses: false)) {
                                                showRipple = true
                                            }
                                        }
                                }
                            }
                            .contentShape(Circle())
                            .glassEffect(.clear.interactive().tint(store.isRecording ? .red : Theme.accent), in: Circle())
                            .disabled(store.isProcessing)
                            .glassEffectID("recordButton", in: namespace)
                            
                            // 3. Cancel Button (Right)
                            if store.isRecording {
                                Button {
                                    store.stopRecording(save: false)
                                } label: {
                                    Image(systemName: "xmark")
                                }
                                .font(.title2)
                                .foregroundStyle(.white)
                                .frame(width: 60, height: 60)
                                .contentShape(Circle())
                                .glassEffect(.regular.interactive(), in: Circle())
                                .glassEffectID("cancelButton", in: namespace)
                            }
                        }
                    }
                    // Dynamic padding: Moves the controls up (80) when recording actively, settles down (40) when paused or idle
                    .padding(.bottom, (store.isRecording && !store.isPaused) ? 80 : 40)
                    .animation(.spring(response: 0.5, dampingFraction: 0.7), value: store.isRecording)
                    .animation(.spring(response: 0.5, dampingFraction: 0.7), value: store.isPaused)
                    
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
                QuestionCard(
                    questionText: question.question,
                    keywords: question.keywords,
                    isSatisfied: store.isQuestionSatisfied,
                    recommendations: store.getRecommendations(for: question)
                )
                .id(question.id)
                .transition(.push(from: .bottom))
            }
        }
    }
}

private struct QuestionCard: View {
    let questionText: String
    let keywords: [String]
    let isSatisfied: Bool
    let recommendations: [String]
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text(questionText)
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(isSatisfied ? .green : .white)
                    .fixedSize(horizontal: false, vertical: true)
                
                if isSatisfied {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            
            // DYNAMIC RECOMMENDATIONS with Better Centering Logic
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
                    ForEach(keywords.prefix(3), id: \.self) { keyword in
                        RecommendationPill(text: keyword.capitalized)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .glassEffect(.clear.tint(isSatisfied ? Color.green.opacity(0.2) : .clear), in: RoundedRectangle(cornerRadius: 24))
        .padding(.horizontal, 30)
        .offset(y: isSatisfied ? -20 : 0)
        .animation(.spring(response: 0.4, dampingFraction: 0.6), value: isSatisfied)
    }
}

struct RecommendationPill: View {
    let text: String
    
    var body: some View {
        Text(text)
            .font(.caption)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .glassEffect(.regular.tint(.secondary.opacity(0.2)))
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
