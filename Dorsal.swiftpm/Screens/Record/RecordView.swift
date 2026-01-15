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
    
    // GRADIENT COLORS
    // 1. Top: Dark Start
    private let skyTopColor = Color(red: 0.05, green: 0.02, blue: 0.10)
    
    // 2. Middle: Slightly Darker to smooth out the diagonal band (was 0.11 -> 0.08)
    private let skyMidColor = Color(red: 0.08, green: 0.03, blue: 0.14)
    
    // 3. Horizon: Darker (was 0.04 -> 0.025)
    private let skyHorizonColor = Color(red: 0.025, green: 0.01, blue: 0.05)
    
    var body: some View {
        NavigationStack(path: $store.navigationPath) {
            ZStack {
                // LAYER 0: Authentic Night Sky Gradient (Behind Stars)
                // Diagonal Gradient with Smoother colors
                LinearGradient(
                    colors: [skyTopColor, skyMidColor, skyHorizonColor],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                // LAYER 1: Star System (Optimized: Top 70% Only)
                // Water is 30%, so Stars occupy 70% (0.7)
                GeometryReader { proxy in
                    StarryBackground()
                        .frame(height: proxy.size.height * 0.70)
                        .allowsHitTesting(false)
                        // Gradient Mask to fade stars near the horizon
                        .mask(
                            LinearGradient(
                                stops: [
                                    .init(color: .black, location: 0.0),
                                    .init(color: .black, location: 0.5),
                                    .init(color: .clear, location: 1.0)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .clipped()
                }
                .ignoresSafeArea()
                
                // LAYER 2: Visualizer (Always Visible, Transparent Sky, Opaque Water)
                AuroraVisualizer(
                    power: store.isRecording ? store.audioPower : 0,
                    isPaused: store.isPaused,
                    isRecording: store.isRecording, // Pass recording state for enter/exit animation
                    // Use Default/Original Shader color (Pale Blue/White) to allow rainbow hues
                    color: Color(red: 0.84, green: 0.84, blue: 0.9)
                )
                // FORCE TOP ALIGNMENT and Full Screen
                .frame(maxHeight: .infinity, alignment: .top)
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .transition(.opacity)
                .zIndex(0)
                
                // LAYER 2.5: GLOBAL RECORDING OVERLAY
                Color.black
                    .opacity(store.isRecording ? 0.25 : 0.0)
                    .ignoresSafeArea()
                    .animation(.easeInOut(duration: 1.5), value: store.isRecording)
                    .allowsHitTesting(false)
                
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
                                    .foregroundStyle(Theme.secondary)
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
                                .foregroundStyle(store.themeAccentColor)
                                .symbolRenderingMode(.hierarchical)
                                .symbolColorRenderingMode(.gradient)
                                .symbolEffect(.bounce, value: true)
                            
                            Text(greetingData.text)
                                .font(.largeTitle.weight(.bold))
                                .multilineTextAlignment(.center)
                            
                            Text("Ready to capture your dreams?")
                                .font(.body)
                                .foregroundStyle(Theme.secondary)
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 50)
                    }
                    
                    Spacer()
                    
                    // MARK: - Controls
                    GlassEffectContainer(spacing: 20) {
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
                            .glassEffect(.clear.interactive().tint(store.isRecording ? .red.opacity(0.8) : store.themeAccentColor.opacity(0.7)), in: Circle())
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
                                .glassEffect(.clear.interactive(), in: Circle())
                                .glassEffectID("cancelButton", in: namespace)
                            }
                        }
                    }
                    .padding(.bottom, (store.isRecording && !store.isPaused) ? 80 : 40)
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
