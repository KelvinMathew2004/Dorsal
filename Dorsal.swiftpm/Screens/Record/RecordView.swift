import SwiftUI
import FoundationModels

struct RecordView: View {
    @ObservedObject var store: DreamStore
    @State private var showRipple = false
    @Namespace private var namespace
    
    private let model = SystemLanguageModel.default
    
    @State private var showAvailabilityAlert = false
    @State private var availabilityMessage = ""
    
    // Greeting logic based on time of day
    private var greetingData: (text: String, icon: String) {
        let hour = Calendar.current.component(.hour, from: Date())
        let name = store.firstName
        
        switch hour {
        case 5..<12:
            return ("Good Morning, \(name)", "sun.max.fill")
        case 12..<17:
            return ("Good Afternoon, \(name)", "sun.haze.fill")
        default:
            return ("Good Evening, \(name)", "moon.stars.fill")
        }
    }
    
    var body: some View {
        NavigationStack(path: $store.navigationPath) {
            ZStack {
                // LAYER 1: Background
                StarryBackground()
                
                // LAYER 2: Visualizer (Background Layer - TOP ALIGNED)
                if store.isRecording {
                    AuroraVisualizer(
                        power: store.audioPower,
                        isPaused: store.isPaused,
                        // Use Purple/Pink as requested
                        color: Color(red: 0.8, green: 0.2, blue: 0.9)
                    )
                    .mask(
                        LinearGradient(
                            stops: [
                                .init(color: .black, location: 0.0), // Solid at top
                                .init(color: .black, location: 0.4),
                                .init(color: .clear, location: 1.0)  // Fade out at bottom
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    // FORCE TOP ALIGNMENT
                    .frame(maxHeight: .infinity, alignment: .top)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .transition(.opacity)
                    .zIndex(0)
                }
                
                // LAYER 3: Main UI (Foreground)
                VStack {
                    Spacer()
                    
                    // MARK: - Prompts
                    if store.isRecording {
                        if store.activeQuestion == nil {
                            // ENCOURAGING TEXT
                            VStack(spacing: 12) {
                                Image(systemName: "mic.circle.fill")
                                    .font(.system(size: 50))
                                    .foregroundStyle(.green)
                                    .symbolEffect(.pulse)
                                
                                Text("Listening...")
                                    .font(.title2.bold())
                                    .foregroundStyle(.white)
                                
                                Text("You're doing great, \(store.firstName). Describe any other details you remember.")
                                    .font(.subheadline)
                                    .foregroundStyle(.white.opacity(0.8))
                                    .multilineTextAlignment(.center)
                            }
                            .padding(24)
                            .frame(maxWidth: .infinity)
                            .glassEffect(.clear.tint(Color.black.opacity(0.5)), in: RoundedRectangle(cornerRadius: 24))
                            .padding(.horizontal, 30)
                            .transition(.scale.combined(with: .opacity))
                        } else {
                            // QUESTIONS
                            ChecklistOverlay(store: store)
                                .transition(.asymmetric(
                                    insertion: .move(edge: .bottom).combined(with: .opacity),
                                    removal: .move(edge: .top).combined(with: .opacity)
                                ))
                        }
                    } else {
                        // Welcome State (Dynamic)
                        VStack(spacing: 16) {
                            Image(systemName: greetingData.icon)
                                .font(.system(size: 60))
                                .foregroundStyle(Theme.accent)
                                .symbolEffect(.bounce, value: true)
                            
                            Text(greetingData.text)
                                .font(.largeTitle.weight(.bold))
                            
                            Text("Ready to capture your dreams?")
                                .font(.body)
                                .foregroundStyle(Theme.secondary)
                        }
                        .padding(.bottom, 50)
                    }
                    
                    Spacer()
                    
                    // MARK: - Controls
                    GlassEffectContainer(spacing: 0) {
                        HStack(spacing: store.isPaused ? 20 : 40) {
                            
                            // 1. Pause Button
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
                                .glassEffect(.clear.interactive(), in: Circle())
                                .glassEffectID("pauseButton", in: namespace)
                            }
                            
                            // 2. Record/Stop
                            ZStack {
                                // Ripple Layer (Behind Button)
                                if store.isRecording && !store.isPaused {
                                    Circle()
                                        .stroke(.red.opacity(0.5), lineWidth: 2)
                                        .frame(width: 80, height: 80)
                                        .scaleEffect(showRipple ? 2.5 : 1.0)
                                        .opacity(showRipple ? 0 : 1)
                                        .onAppear {
                                            showRipple = false
                                            withAnimation(.easeOut(duration: 1.5).repeatForever(autoreverses: false)) {
                                                showRipple = true
                                            }
                                        }
                                }
                                
                                Button {
                                    handleRecordButtonTap()
                                } label: {
                                    Image(systemName: store.isRecording ? "stop.fill" : "mic.fill")
                                        .contentTransition(.symbolEffect(.replace))
                                        .padding(15)
                                }
                                .font(.title)
                                .foregroundStyle(.white)
                                .frame(width: 80, height: 80)
                                .contentShape(Circle())
                                .glassEffect(.clear.interactive().tint(store.isRecording ? .red.opacity(0.8) : Theme.accent.opacity(0.8)), in: Circle())
                                .disabled(store.isProcessing)
                                .glassEffectID("recordButton", in: namespace)
                            }
                            
                            // 3. Cancel
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
                                .glassEffect(.clear.interactive(), in: Circle())
                                .glassEffectID("cancelButton", in: namespace)
                            }
                        }
                    }
                    .padding(.bottom, (store.isRecording && !store.isPaused) ? 120 : 80)
                    .animation(.spring(response: 0.5, dampingFraction: 0.7), value: store.isRecording)
                    .animation(.spring(response: 0.5, dampingFraction: 0.7), value: store.isPaused)
                }
                .zIndex(1) // Ensure UI is ON TOP
            }
            .navigationTitle("Record")
            .navigationDestination(for: Dream.self) { dream in
                DreamDetailView(store: store, dream: dream)
            }
            .alert("Feature Unavailable", isPresented: $showAvailabilityAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(availabilityMessage)
            }
            .onChange(of: store.selectedTab) {
                if store.selectedTab == 0 {
                    store.navigationPath = NavigationPath()
                }
            }
        }
    }
    
    func handleRecordButtonTap() {
        if store.isProcessing { return }
        
        if store.isRecording {
            store.stopRecording(save: true)
            return
        }
        
        switch SystemLanguageModel.default.availability {
        case .available:
            store.startRecording()
            
        case .unavailable(let reason):
            handleUnavailability(reason)
            
        @unknown default:
            availabilityMessage = "An unknown error occurred with Apple Intelligence."
            showAvailabilityAlert = true
        }
    }
    
    private func handleUnavailability(_ reason: SystemLanguageModel.Availability.UnavailableReason) {
        switch reason {
        case .appleIntelligenceNotEnabled:
            availabilityMessage = "Enable Apple Intelligence in Settings to use this feature."
        case .modelNotReady:
            availabilityMessage = "Downloading model assets. Please wait a moment..."
        case .deviceNotEligible:
            availabilityMessage = "This feature requires iPhone 15 Pro or newer."
        @unknown default:
            availabilityMessage = "Feature temporarily unavailable."
        }
        showAvailabilityAlert = true
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
                    isSatisfied: store.isQuestionSatisfied,
                    recommendations: store.getRecommendations(for: question)
                )
                .id(question.id)
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .move(edge: .top).combined(with: .opacity)
                ))
            }
        }
    }
}

private struct QuestionCard: View {
    let questionText: String
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
            
            if !recommendations.isEmpty {
                SimpleWrappedPills(items: recommendations)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .glassEffect(
            .clear.tint(isSatisfied ? Color.green.opacity(0.15) : Color.black.opacity(0.5)),
            in: RoundedRectangle(cornerRadius: 24)
        )
        .padding(.horizontal, 30)
        .offset(y: isSatisfied ? -20 : 0)
        .animation(.spring(response: 0.4, dampingFraction: 0.6), value: isSatisfied)
    }
}

struct SimpleWrappedPills: View {
    let items: [String]
    
    var body: some View {
        // Enforce maximum of 3 items
        HStack(spacing: 8) {
            ForEach(Array(items.prefix(3)), id: \.self) { item in
                RecommendationPill(text: item.capitalized)
            }
        }
    }
}

struct RecommendationPill: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.caption)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .glassEffect(.clear.tint(Theme.secondary.opacity(0.2)))
            .fixedSize(horizontal: true, vertical: false)
    }
}
