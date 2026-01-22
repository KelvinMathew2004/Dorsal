import SwiftUI
import FoundationModels

struct RecordView: View {
    @ObservedObject var store: DreamStore
    @State private var showRipple = false
    @Namespace private var namespace
    
    private let model = SystemLanguageModel.default
    
    @State private var showAvailabilityAlert = false
    @State private var availabilityMessage = ""
    
    @State private var showInstallationAlert = false
    @State private var showProcessingAlert = false
    
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
    
    private let cosmosTop     = Color(red: 0.02, green: 0.00, blue: 0.05)
    private let cosmosMid     = Color(red: 0.08, green: 0.02, blue: 0.18)
    private let cosmosHorizon = Color(red: 0.18, green: 0.06, blue: 0.32)
    private let cosmosBase    = Color(red: 0.04, green: 0.01, blue: 0.10)
    
    var body: some View {
        NavigationStack(path: $store.navigationPath) {
            ZStack {
                if store.isComplexVisualizerEnabled {
                    LinearGradient(
                        stops: [
                            .init(color: cosmosTop, location: 0.0),
                            .init(color: cosmosMid, location: 0.4),
                            .init(color: cosmosHorizon, location: 0.75),
                            .init(color: cosmosBase, location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea()
                    
                    GeometryReader { proxy in
                        StarryBackground()
                            .frame(height: proxy.size.height * 0.70)
                            .allowsHitTesting(false)
                            .mask(
                                LinearGradient(
                                    stops: [
                                        .init(color: .black, location: 0.0),
                                        .init(color: .black, location: 0.8),
                                        .init(color: .clear, location: 1.0)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .clipped()
                    }
                    .ignoresSafeArea()
                    
                    Color.black
                        .opacity(store.isRecording ? 0.5 : 0.0)
                        .ignoresSafeArea()
                        .animation(.easeInOut(duration: 1.5), value: store.isRecording)
                        .allowsHitTesting(false)
                    
                    AuroraVisualizer(
                        power: store.isRecording ? store.audioPower : 0,
                        isPaused: store.isPaused,
                        isRecording: store.isRecording,
                        color: Color(red: 0.84, green: 0.84, blue: 0.9)
                    )
                    .frame(maxHeight: .infinity, alignment: .top)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .transition(.opacity)
                    .zIndex(0)
                    
                    
                } else {
                    LinearGradient(
                        colors: [Color(red: 0.05, green: 0.02, blue: 0.10), Color(red: 0.10, green: 0.05, blue: 0.20), Color(red: 0.02, green: 0.02, blue: 0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .ignoresSafeArea()
                    
                    StarryBackground()
                        .ignoresSafeArea()
                }
                
                VStack {
                    Spacer()
                    
                    if store.isRecording {
                        if store.activeQuestion == nil {
                            VStack(spacing: 12) {
                                Image(systemName: "mic.circle.fill")
                                    .font(.system(size: 50))
                                    .foregroundStyle(.green)
                                    .symbolEffect(.pulse)
                                
                                Text(store.isPaused ? "Paused" : "Listening...")
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
                            ChecklistOverlay(store: store)
                                .transition(.asymmetric(
                                    insertion: .move(edge: .bottom).combined(with: .opacity),
                                    removal: .move(edge: .top).combined(with: .opacity)
                                ))
                        }
                    } else {
                        VStack(spacing: 16) {
                            Image(systemName: greetingData.icon)
                                .font(.system(size: 60))
                                .foregroundStyle(store.themeAccentColor)
                                .symbolRenderingMode(.hierarchical)
                                .symbolColorRenderingMode(.gradient)
                                .symbolEffect(.bounce, value: true)
                            
                            Text(greetingData.text)
                                .font(.largeTitle.weight(.bold))
                                .fontDesign(.rounded)
                                .multilineTextAlignment(.center)
                            
                            Text("Ready to capture your dreams?")
                                .font(.body)
                                .foregroundStyle(Theme.secondary)
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 50)
                    }
                    
                    Spacer()
                    
                    if store.isRecording && !store.isComplexVisualizerEnabled {
                        AudioVisualizer(power: store.audioPower, isPaused: store.isPaused)
                            .padding(.bottom, 20)
                            .transition(.opacity)
                    }
                    
                    GlassEffectContainer(spacing: store.isPaused ? 20 : 40) {
                        HStack(spacing: store.isPaused ? 20 : 40) {
                            
                            if store.isRecording {
                                Button {
                                    if store.isPaused {
                                        store.resumeRecording()
                                    } else {
                                        store.pauseRecording()
                                    }
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
                .zIndex(1)
            }
            .navigationTitle("Record")
            .navigationBarTitleColor(Theme.accent)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if !store.isRecording {
                        Button {
                            withAnimation {
                                store.isComplexVisualizerEnabled.toggle()
                            }
                        } label: {
                            Image(systemName: store.isComplexVisualizerEnabled ? "waveform.mid" : "wand.and.sparkles")
                                .contentTransition(.symbolEffect(.replace))
                        }
                    }
                }
            }
            .navigationDestination(for: Dream.self) { dream in
                DreamDetailView(store: store, dream: dream)
            }
            .alert("Feature Unavailable", isPresented: $showAvailabilityAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(availabilityMessage)
            }
            .alert("Speech Model Updating", isPresented: $showInstallationAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                if store.isSpeechModelInstalling {
                    Text("The high-quality English (US) speech model is currently downloading. Please wait a moment.")
                } else {
                    Text("Checking speech model availability...")
                }
            }
            .alert("Processing in Background", isPresented: $showProcessingAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Please wait for the current dream analysis to complete before starting a new recording.")
            }
            .onChange(of: store.selectedTab) {
                if store.selectedTab == 0 {
                    store.navigationPath = NavigationPath()
                }
            }
        }
    }
    
    func handleRecordButtonTap() {
        if store.isProcessing {
            showProcessingAlert = true
            return
        }
        
        if store.isRecording {
            store.stopRecording(save: true)
            return
        }
        
        if !store.isSpeechModelReady || store.isSpeechModelInstalling {
            showInstallationAlert = true
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

struct AudioVisualizer: View {
    var power: Float
    var isPaused: Bool
    let bars = 25
    
    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<bars, id: \.self) { index in
                let gateThreshold: Float = 0.05
                let rawGatedPower = power < gateThreshold ? 0 : power
                let gatedPower = isPaused ? 0 : rawGatedPower
                
                let normalizedPower = CGFloat(gatedPower)
                let sensitivePower = gatedPower > 0 ? pow(normalizedPower, 0.6) : 0
                let variation = gatedPower > 0 ? CGFloat.random(in: 0.5...1.2) : 1.0
                let dynamicHeight = (sensitivePower * 100 * variation)
                let height = 12 + dynamicHeight
                
                RoundedRectangle(cornerRadius: 3)
                    .fill(Theme.accent.gradient)
                    .frame(width: 6, height: height)
                    .shadow(color: Theme.accent.opacity(0.5), radius: 5, x: 0, y: 0)
                    .animation(.easeOut(duration: 0.15), value: power)
            }
        }
        .frame(height: 120)
        .opacity(isPaused ? 0.5 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isPaused)
    }
}
