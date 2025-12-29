import SwiftUI
import FoundationModels
import AVFoundation
import Speech

struct RecordView: View {
    @ObservedObject var store: DreamStore
    @State private var showRipple = false
    @Namespace private var namespace
    
    private let model = SystemLanguageModel.default
    
    @State private var showAvailabilityAlert = false
    @State private var availabilityMessage = ""
    
    var body: some View {
        NavigationStack(path: $store.navigationPath) {
            ZStack {
                Theme.gradientBackground.ignoresSafeArea()
                
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
                                
                                Text("You're doing great. Describe any other details you remember.")
                                    .font(.subheadline)
                                    .foregroundStyle(.white.opacity(0.8))
                                    .multilineTextAlignment(.center)
                            }
                            .padding(24)
                            .frame(maxWidth: .infinity)
                            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24))
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
                        // Welcome State
                        VStack(spacing: 16) {
                            Image(systemName: "moon.stars.fill")
                                .font(.system(size: 60))
                                .foregroundStyle(Color.accentColor)
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
                            .animation(.linear(duration: 0.1), value: store.audioPower)
                    }
                    
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
                                .glassEffect(.regular.interactive(), in: Circle())
                                .glassEffectID("pauseButton", in: namespace)
                            }
                            
                            // 2. Record/Stop
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
                            .background {
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
                            .glassEffect(.clear.interactive().tint(store.isRecording ? .red : Color.accentColor), in: Circle())
                            .disabled(store.isProcessing)
                            .glassEffectID("recordButton", in: namespace)
                            
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
                                .glassEffect(.regular.interactive(), in: Circle())
                                .glassEffectID("cancelButton", in: namespace)
                            }
                        }
                    }
                    .padding(.bottom, (store.isRecording && !store.isPaused) ? 80 : 40)
                    .animation(.spring(response: 0.5, dampingFraction: 0.7), value: store.isRecording)
                    .animation(.spring(response: 0.5, dampingFraction: 0.7), value: store.isPaused)
                }
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
        
        guard checkMicrophonePermissions() else {
            availabilityMessage = "Please enable Microphone and Speech Recognition in Settings."
            showAvailabilityAlert = true
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
    
    private func checkMicrophonePermissions() -> Bool {
        let micStatus = AVAudioApplication.shared.recordPermission
        let speechStatus = SFSpeechRecognizer.authorizationStatus()

        let micAllowed = micStatus == .granted || micStatus == .undetermined
        let speechAllowed = speechStatus == .authorized || speechStatus == .notDetermined
        
        return micAllowed && speechAllowed
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
            .regular.tint(isSatisfied ? Color.green.opacity(0.15) : .clear),
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
        if items.count <= 4 {
            HStack(spacing: 8) {
                ForEach(items, id: \.self) { item in
                    RecommendationPill(text: item.capitalized)
                }
            }
        } else {
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    ForEach(items.prefix(3), id: \.self) { item in
                        RecommendationPill(text: item.capitalized)
                    }
                }
                HStack(spacing: 8) {
                    ForEach(items.dropFirst(3), id: \.self) { item in
                        RecommendationPill(text: item.capitalized)
                    }
                }
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
            .glassEffect(.regular.tint(.secondary.opacity(0.2)), in: Capsule())
            .fixedSize(horizontal: true, vertical: false)
    }
}

struct AudioVisualizer: View {
    var power: Float
    let bars = 30
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<bars, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.accentColor.gradient)
                    .frame(width: 4, height: 10 + (CGFloat(power) * CGFloat.random(in: 10...80)))
                    .animation(.easeInOut(duration: 0.1), value: power)
            }
        }
    }
}
