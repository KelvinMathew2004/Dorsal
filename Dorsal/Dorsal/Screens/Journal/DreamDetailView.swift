import SwiftUI
import Photos
import PhotosUI
import AVFoundation
import ImagePlayground

struct DreamDetailView: View {
    @ObservedObject var store: DreamStore
    let dream: Dream
    
    @Environment(\.supportsImagePlayground) private var supportsImagePlayground
    @State private var showImagePlayground = false
    @State private var illustrationRequest: DreamIllustrationRequest?
    @State private var preparedImagePlaygroundPrompt: String?
    @State private var sleepSummary: SleepSummary?
    @Namespace private var namespace
    
    @State private var activeEntity: EntityIdentifier?
    @State private var selectedEntity: EntityIdentifier?
    @State private var entityToDelete: EntityIdentifier?
    @State private var showDeleteAlert = false
    
    @State private var selectedInsight: InsightType?
    
    @State private var dominantColor: Color?
    @State private var showSaveSuccess = false
    
    var textColor: Color {
        let baseColor = dominantColor ?? Color(red: 0.10, green: 0.05, blue: 0.20)
        return baseColor.mix(with: .white, by: 0.9)
    }
    
    var secondaryColor: Color {
        let baseColor = dominantColor ?? .purple
        return baseColor.mix(with: .white, by: 0.8).opacity(0.8)
    }
    
    @State private var currentAnalysisIconIndex = 0
    private let analysisIcons: [(name: String, color: Color)] = [
        ("sparkles.rectangle.stack", .purple),
        ("brain.head.profile", .green),
        ("person.2.fill", .blue),
        ("map.fill", .green),
        ("heart.fill", .pink),
        ("star.fill", .yellow),
        ("battery.50", .red),
        ("waveform", .orange)
    ]
    
    enum InsightType: String, Identifiable {
        case interpretation = "Interpretation"
        case advice = "Actionable Advice"
        var id: String { rawValue }
        
        var title: String { rawValue }
        
        var icon: String {
            switch self {
            case .interpretation: return "sparkles.rectangle.stack"
            case .advice: return "brain.head.profile"
            }
        }
        
        var color: Color {
            switch self {
            case .interpretation: return .purple
            case .advice: return .green
            }
        }
    }
    
    struct EntityIdentifier: Hashable, Identifiable {
        let name: String
        let type: String
        var id: String { "\(type):\(name)" }
    }
    
    var liveDream: Dream {
        store.dreams.first(where: { $0.id == dream.id }) ?? dream
    }
    
    var isProcessingThisDream: Bool {
        store.isProcessing && liveDream.id == store.currentDreamID
    }
    
    var isGeneratingImage: Bool {
        isProcessingThisDream && liveDream.generatedImageData == nil && liveDream.core?.summary != nil
    }
    
    var isAnalyzingFatigue: Bool {
        store.isAnalyzingFatigue && liveDream.id == store.currentDreamID
    }
    
    private func presentImagePlayground() async {
        guard #available(iOS 27, *), supportsImagePlayground else { return }
        let basePrompt = preparedImagePlaygroundPrompt
            ?? liveDream.imagePrompt
            ?? liveDream.core?.imagePrompt
        guard let basePrompt,
              !basePrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        var subjectCutoutData: Data?
        if ImageScenePreference.includesPeople {
            subjectCutoutData = await store.profileSubjectCutoutForImagePlayground()
        }
        illustrationRequest = DreamIllustrationRequest(
            promptTags: DreamIllustrationPrompt.styled(basePrompt),
            profileImageData: store.profileImageData,
            profileSubjectCutoutData: subjectCutoutData,
            styleChoice: DreamIllustrationPrompt.activeStyleChoice
        )
        showImagePlayground = true
    }

    var body: some View {
        ZStack(alignment: .top) {
            Group {
                if let color = dominantColor {
                    color.mix(with: .black, by: 0.6)
                } else {
                    Theme.gradientBackground()
                }
            }
            .ignoresSafeArea()
            .transition(.opacity)
            
            if let data = liveDream.generatedImageData, let uiImage = UIImage(data: data) {
                GeometryReader { geo in
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                        .blur(radius: 30)
                        .opacity(0.2)
                }
                .ignoresSafeArea()
            }
            
            contentLayer
            
            if let insight = selectedInsight {
                InsightDetailView(
                    store: store,
                    dream: liveDream,
                    insight: insight,
                    namespace: namespace,
                    secondary: secondaryColor,
                    selectedInsight: $selectedInsight
                )
                .zIndex(100)
            }
            
            if showSaveSuccess {
                VStack {
                    Spacer()
                    Label("Saved to Photos", systemImage: "checkmark.circle.fill")
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                        .padding()
                        .glassEffect(.clear.tint(Color.green.opacity(0.2)))
                        .padding(.bottom, 60)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .zIndex(300)
            }
        }
        .navigationTitle(liveDream.core?.title ?? DreamDateLabel.string(liveDream.date))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // Bookmark — highest priority: never gets truncated by iOS 27 overflow
            ToolbarItem(placement: .primaryAction) {
                Button {
                    store.toggleBookmark(id: liveDream.id)
                } label: {
                    Image(systemName: liveDream.isBookmarked ? "bookmark.fill" : "bookmark")
                }
                .accessibilityLabel(liveDream.isBookmarked ? "Remove Bookmark" : "Bookmark")
            }

            if #available(iOS 27, *) {
                if !store.isProcessing && selectedInsight == nil {
                    ToolbarOverflowMenu {
                        // Illustration — shown when Image Playground is supported
                        if supportsImagePlayground, !liveDream.rawTranscript.isEmpty {
                            if liveDream.generatedImageData != nil {
                                Button("Regenerate Illustration", systemImage: "apple.image.playground") {
                                    Task { await presentImagePlayground() }
                                }
                            } else {
                                Button("Create Illustration", systemImage: "apple.image.playground") {
                                    Task { await presentImagePlayground() }
                                }
                            }
                        }
                        if liveDream.generatedImageData != nil {
                            Button("Save Image", systemImage: "square.and.arrow.down") {
                                saveImageToGallery()
                            }
                        }
                        if store.isImageGenerationAvailable {
                            Button("Regenerate Image", systemImage: "sparkles") {
                                store.regenerateDreamImage(liveDream)
                            }
                        }
                        Button("Regenerate Analysis", systemImage: "arrow.clockwise") {
                            store.regenerateDream(liveDream)
                        }
                    }
                }
            } else {
                ToolbarItemGroup(placement: .primaryAction) {
                    if !store.isProcessing && selectedInsight == nil {
                        if supportsImagePlayground, !liveDream.rawTranscript.isEmpty {
                            Button {
                                Task { await presentImagePlayground() }
                            } label: {
                                Image(systemName: "apple.image.playground")
                            }
                        }
                        if liveDream.generatedImageData != nil {
                            Button("Save Image", systemImage: "square.and.arrow.down") { saveImageToGallery() }
                        }
                        if store.isImageGenerationAvailable {
                            Button("Regenerate Image", systemImage: "sparkles") { store.regenerateDreamImage(liveDream) }
                        }
                        Button("Regenerate Analysis", systemImage: "arrow.clockwise") { store.regenerateDream(liveDream) }
                    }
                }
            }
        }
        .modifier(DreamIllustrationSheet(isPresented: $showImagePlayground, request: illustrationRequest) { url in
            store.keepCreatedImage(for: liveDream, from: url)
        })

        .task { await store.refreshAvailability() }
        .task(id: liveDream.id) {
            if let savedPrompt = liveDream.imagePrompt ?? liveDream.core?.imagePrompt,
               !savedPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                preparedImagePlaygroundPrompt = savedPrompt
                return
            }
            guard !liveDream.rawTranscript.isEmpty else { return }
            do {
                let prompt = try await DreamAnalyzer.shared.generateVisualPrompt(
                    transcript: liveDream.rawTranscript,
                    people: liveDream.people,
                    places: liveDream.places
                )
                guard !Task.isCancelled else { return }
                preparedImagePlaygroundPrompt = prompt
                store.updateImagePrompt(for: liveDream.id, prompt: prompt)
            } catch {
                // Backfill the prompt when the on-device model is available.
            }
        }
        .task(id: store.usesSleepData) {
            sleepSummary = nil
            guard store.usesSleepData else { return }
            let summary = try? await store.sleepSummary(for: liveDream.date)
            guard !Task.isCancelled, store.usesSleepData else { return }
            sleepSummary = summary
        }
        .onAppear {
            if let data = liveDream.generatedImageData, let uiImage = UIImage(data: data) {
                self.dominantColor = uiImage.dominantColor
            }
        }
        .onChange(of: liveDream.generatedImageData) {
            updateColor()
        }
        .alert("Delete Details?", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                if let entity = entityToDelete {
                    store.deleteEntity(name: entity.name, type: entity.type)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will remove the custom image and description. The item will remain in the dream list.")
        }
        .sheet(item: $selectedEntity) { entity in
            EntityDetailView(store: store, name: entity.name, type: entity.type)
                .presentationDetents([.large])
                .navigationTransition(.zoom(sourceID: entity.id, in: namespace))
        }
    }
    
    private func saveImageToGallery() {
        guard let data = liveDream.generatedImageData, let image = UIImage(data: data) else { return }
        
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        
        withAnimation {
            showSaveSuccess = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showSaveSuccess = false
            }
        }
    }
    
    private func updateColor() {
        if let data = liveDream.generatedImageData, let uiImage = UIImage(data: data) {
            DispatchQueue.global(qos: .userInitiated).async {
                let color = uiImage.dominantColor
                DispatchQueue.main.async {
                    withAnimation(.easeInOut(duration: 1.0)) {
                        self.dominantColor = color
                    }
                }
            }
        } else {
            withAnimation(.easeInOut(duration: 1.0)) {
                self.dominantColor = nil
            }
        }
    }
    
    var contentLayer: some View { mainScrollView }

    @ViewBuilder
    var recoveryNotices: some View {
        if let message = liveDream.transcriptionError {
            VStack(alignment: .leading, spacing: 8) {
                Label("Transcription", systemImage: "waveform")
                Text(message).font(.subheadline)
                if store.transcribingDreamID == liveDream.id {
                    ProgressView("Transcribing recording…")
                } else {
                    Button("Retry Transcription") { store.retryTranscription(liveDream) }
                        .disabled(store.isProcessing || store.transcribingDreamID != nil || store.isRecording || store.recordingIsBusy)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 24))
        }
        if let message = liveDream.analysisError ?? ((!isProcessingThisDream && liveDream.needsAnalysis == true && !liveDream.rawTranscript.isEmpty)
            ? "Analysis hasn’t finished. You can read your dream now and retry analysis when Apple Intelligence is available." : nil) {
            VStack(alignment: .leading, spacing: 8) {
                Label("Analysis Unavailable", systemImage: "sparkles")
                Text(message).font(.subheadline)
                Button("Retry Analysis") { store.regenerateDream(liveDream) }
                    .disabled(store.isProcessing || liveDream.rawTranscript.isEmpty || store.isRecording || store.recordingIsBusy || store.transcribingDreamID != nil)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding().background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
        if let message = liveDream.imageError {
            VStack(alignment: .leading, spacing: 8) {
                Label("Illustration Unavailable", systemImage: "photo")
                Text(message).font(.subheadline)
                if #available(iOS 27, *) {
                    if supportsImagePlayground {
                        Button("Create in Image Playground") { Task { await presentImagePlayground() } }
                    }
                } else {
                    Button("Retry Illustration") { store.regenerateDreamImage(liveDream) }
                        .disabled(store.isProcessing || store.isRecording || store.recordingIsBusy || store.transcribingDreamID != nil)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding().background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
    }

    @ViewBuilder
    var mainScrollView: some View {
        ScrollView {
            VStack(spacing: 24) {
                
                recoveryNotices.padding(.horizontal)
                headerSection
                
                if let core = liveDream.core {
                    DreamContextSection(
                        core: core,
                        activeEntity: $activeEntity,
                        selectedEntity: $selectedEntity,
                        entityToDelete: $entityToDelete,
                        showDeleteAlert: $showDeleteAlert,
                        store: store,
                        namespace: namespace
                    )
                    .padding()
                }
                
                
                if let interp = liveDream.core?.interpretation {
                    insightCardRow(
                        type: .interpretation,
                        text: interp,
                        isProcessing: isProcessingThisDream
                    )
                }
                
                if let advice = liveDream.core?.actionableAdvice {
                    insightCardRow(
                        type: .advice,
                        text: advice,
                        isProcessing: isProcessingThisDream
                    )
                }
                
                metricsSection
                
                sleepArchitectureSection
                DreamTranscriptSection(transcript: liveDream.rawTranscript, secondary: secondaryColor)

                if let url = RecordingFiles.url(for: liveDream.recordingFileName) {
                    RecordingPlaybackView(url: url).padding(.horizontal)
                }
            }
            .padding(.top)
            .padding(.bottom, 50)
            .animation(.default, value: liveDream.core)
            .animation(.default, value: liveDream.extras)
        }
        .scrollIndicators(.hidden)
        .upgradeScrollEdgeEffect()
        .scrollDisabled(isProcessingThisDream || selectedInsight != nil)
        .blur(radius: selectedInsight != nil ? 10 : 0)
        .overlay {
            if isProcessingThisDream {
                ZStack {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()

                    VStack(spacing: 40) {
                        Image(systemName: analysisIcons[currentAnalysisIconIndex].name)
                            .font(.system(size: 48, weight: .semibold))
                            .foregroundStyle(analysisIcons[currentAnalysisIconIndex].color)
                            .symbolRenderingMode(.hierarchical)
                            .symbolColorRenderingMode(.gradient)
                            .contentTransition(.symbolEffect(.replace))
                            .frame(width: 64, height: 64)

                        Text("Analyzing...")
                            .font(.headline)
                            .foregroundStyle(.white)
                    }
                    .padding(40)
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24))
                }
                .onAppear {
                    currentAnalysisIconIndex = 0
                }
                .task {
                    while !Task.isCancelled {
                        do { try await Task.sleep(for: .milliseconds(800)) }
                        catch { break }
                        guard isProcessingThisDream else { break }

                        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                            currentAnalysisIconIndex = (currentAnalysisIconIndex + 1) % analysisIcons.count
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    func insightCardRow(type: InsightType, text: String, isProcessing: Bool) -> some View {
        ZStack {
            if !store.isProcessing {
                InsightCardView(
                    type: type,
                    text: text,
                    animates: false,
                    secondary: secondaryColor
                )
                .opacity(0)
            }
            
            if selectedInsight != type {
                Button {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        selectedInsight = type
                    }
                } label: {
                    InsightCardView(
                        type: type,
                        text: text,
                        animates: isProcessing,
                        secondary: secondaryColor
                    )
                    .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 24))
                    .matchedGeometryEffect(id: "bg_\(type.id)", in: namespace)
                }
                .buttonStyle(.plain)
                .transition(.identity)
            }
        }
        .padding(.horizontal)
    }
    
    // MARK: - FIXED HEADER SECTION
    @ViewBuilder
    var headerSection: some View {
        let image: UIImage? = {
            if let data = liveDream.generatedImageData {
                return UIImage(data: data)
            }
            return nil
        }()
        
        if image != nil || (isGeneratingImage && store.isImageGenerationAvailable) || liveDream.core?.summary != nil || !liveDream.rawTranscript.isEmpty {
            VStack(spacing: 20) {
                if image != nil || (isGeneratingImage && store.isImageGenerationAvailable) {
                    LensView(
                        image: image,
                        shadowColor: dominantColor ?? Color(red: 0.05, green: 0.02, blue: 0.10)
                    )
                    .aspectRatio(1.0, contentMode: .fit)
                    .frame(maxWidth: 400)
                }
                
                if #available(iOS 27, *), supportsImagePlayground,
                   image == nil, liveDream.imageError == nil,
                   !isProcessingThisDream, !liveDream.rawTranscript.isEmpty {
                    Button {
                        Task { await presentImagePlayground() }
                    } label: {
                        Label("Create Illustration", systemImage: "apple.image.playground")
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                    .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 24))
                }

                if let summary = liveDream.core?.summary {
                    Text("\(Text("Summary: ").bold())\(summary)")
                        .font(.caption)
                        .foregroundStyle(secondaryColor)
                        .multilineTextAlignment(.leading)
                        .padding(24)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 32))
                }
            }
            .padding(.horizontal)
            .frame(maxWidth: 500)
        }
    }
    
    @ViewBuilder
    var sleepArchitectureSection: some View {
        if store.usesSleepData, let sleep = sleepSummary {
            VStack(alignment: .leading, spacing: 16) {
                Label("Sleep Architecture", systemImage: "bed.double.fill")
                    .font(.headline)
                    .foregroundStyle(store.themeAccentColor)
                
                HStack(spacing: 24) {
                    let totalMinutes = sleep.totalSleepMinutes
                    let hours = totalMinutes / 60
                    let minutes = totalMinutes % 60
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(hours)h \(minutes)m")
                            .font(.title2.bold())
                            .foregroundStyle(.white)
                        Text("Total Sleep")
                            .font(.caption)
                            .foregroundStyle(secondaryColor)
                    }
                    
                    Spacer()
                    
                    if let efficiency = sleep.sleepEfficiency {
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("\(efficiency)%")
                                .font(.title2.bold())
                                .foregroundStyle(.green)
                            Text("Recorded Asleep")
                                .font(.caption)
                                .foregroundStyle(secondaryColor)
                        }
                    }
                }
                
                if sleep.hasStageData {
                    SleepStageBar(
                        rem: Double(sleep.remMinutes), deep: Double(sleep.deepSleepMinutes),
                        core: Double(sleep.coreSleepMinutes), awake: Double(sleep.awakeMinutes),
                        total: Double(sleep.totalSleepMinutes + sleep.awakeMinutes)
                    )
                }
                Text("Based on available Health samples.")
                    .font(.caption)
                    .foregroundStyle(secondaryColor)
            }
            .padding(24)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24))
            .padding(.horizontal)
        }
    }
    
    @ViewBuilder
    var metricsSection: some View {
        if let fatigue = liveDream.voiceFatigue {
            HStack(spacing: 24) {
                
                // MARK: - Vocal Fatigue Card (ZStack)
                NavigationLink(destination: TrendDetailView(metric: .fatigue, store: store)) {
                    ZStack(alignment: .trailing) {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Vocal Fatigue", systemImage: "battery.50")
                                .font(.headline)
                                .foregroundStyle(.red)
                            
                            Spacer()
                            
                            Text("\(fatigue)%").font(.title3.bold()).foregroundStyle(.white)
                            
                            ProgressBarView(value: Double(fatigue), total: 100, color: .red)
                        }
                        .padding(20)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                        
                        Image(systemName: "chevron.right")
                            .font(.body.bold())
                            .foregroundStyle(secondaryColor)
                            .padding(.trailing, 20)
                    }
                    .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 24))
                    .contentShape(RoundedRectangle(cornerRadius: 24))
                }
                
                // MARK: - Tone Card (HStack)
                if let tone = liveDream.core?.tone?.label {
                    NavigationLink(destination: TrendDetailView(metric: .tone, store: store)) {
                        HStack {
                            VStack(alignment: .leading, spacing: 12) {
                                Label("Tone", systemImage: "waveform")
                                    .font(.headline)
                                    .foregroundStyle(.orange)
                                
                                Spacer()
                                
                                Text(tone.capitalized)
                                    .font(.title3.bold())
                                    .foregroundStyle(.white)
                                    .multilineTextAlignment(.leading) // Forces wrapped text to align left
                                    .minimumScaleFactor(0.5)
                                
                                if let conf = liveDream.core?.tone?.confidence {
                                    Text("\(conf)% Confidence")
                                        .font(.caption)
                                        .foregroundStyle(secondaryColor)
                                }
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                            
                            Image(systemName: "chevron.right")
                                .font(.body.bold())
                                .foregroundStyle(secondaryColor)
                        }
                        .padding(20)
                        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 24))
                        .contentShape(RoundedRectangle(cornerRadius: 24))
                    }
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal)
        }
    }
}

struct InsightDetailView: View {
    @ObservedObject var store: DreamStore
    let dream: Dream
    let insight: DreamDetailView.InsightType
    var namespace: Namespace.ID
    var secondary: Color
    @Binding var selectedInsight: DreamDetailView.InsightType?
    
    @State private var questionText: String = ""
    @State private var answerText: String = ""
    @State private var isAsking: Bool = false
    @State private var showContent = false
    
    var rawText: String {
        insight == .interpretation ? (dream.core?.interpretation ?? "") : (dream.core?.actionableAdvice ?? "")
    }
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture { }
                .transition(.opacity)
            
            ScrollView {
                GlassEffectContainer(spacing: 24) {
                    VStack(spacing: 24) {
                        InsightCardView(
                            type: insight,
                            text: formatText(rawText),
                            animates: false,
                            isExpanded: true,
                            secondary: secondary
                        )
                        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24))
                        .matchedGeometryEffect(id: "bg_\(insight.id)", in: namespace)
                        .glassEffectID("card", in: namespace)
                        .onTapGesture { }
                        
                        if showContent {
                            qnaSection
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 60)
            }
            .scrollIndicators(.hidden)
            .upgradeScrollEdgeEffect()
            .safeAreaInset(edge: .bottom) {
                if showContent {
                    Button {
                        close()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .frame(width: 60, height: 60)
                    }
                    .contentShape(Circle())
                    .glassEffect(.regular.interactive(), in: Circle())
                    .padding(.bottom, 24)
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: showContent)
        }
        .onAppear {
            withAnimation(.easeIn(duration: 0.3).delay(0.2)) {
                showContent = true
            }
        }
    }
    
    var qnaSection: some View {
        VStack(spacing: 24) {
            HStack(spacing: 12) {
                TextField("Ask a question about this...", text: $questionText)
                    .font(.body)
                    .textFieldStyle(.plain)
                    .padding(16)
                    .glassEffect(.regular.interactive())
                    .glassEffectID("input", in: namespace)
                    .disabled(isAsking || !answerText.isEmpty)
                
                Button {
                    if !answerText.isEmpty {
                        resetQnA()
                    } else {
                        askQuestion()
                    }
                } label: {
                    Image(systemName: answerText.isEmpty ? "arrow.up" : "arrow.counterclockwise")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(questionText.isEmpty || isAsking ? .white.opacity(0.35) : .white.opacity(0.7))
                        .frame(width: 44, height: 44)
                        .contentTransition(.symbolEffect(.replace))
                }
                .contentShape(Circle())
                .glassEffect(
                    questionText.isEmpty || isAsking
                    ? .clear.tint(.gray.opacity(0.8))
                    : .clear.interactive().tint(store.themeAccentColor.opacity(0.8)),
                    in: Circle()
                )
                .glassEffectID("action", in: namespace)
                .disabled(questionText.isEmpty || isAsking)
            }
            
            if !answerText.isEmpty || isAsking {
                VStack(alignment: .leading, spacing: 24) {
                    Label("Answer", systemImage: "sparkles")
                        .font(.headline)
                        .foregroundStyle(store.themeAccentColor)
                    
                    if isAsking && answerText.isEmpty {
                        Text("Thinking...")
                            .font(.body)
                            .foregroundStyle(Theme.secondary)
                            .shimmering()
                    } else {
                        Text(LocalizedStringKey(formatText(answerText)))
                            .font(.body)
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 24))
                .glassEffectID("answer", in: namespace)
                .padding(.bottom, 24)
            }
        }
    }
    
    func close() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            showContent = false
            selectedInsight = nil
        }
    }
    
    func resetQnA() {
        questionText = ""
        answerText = ""
        isAsking = false
    }
    
    func formatText(_ text: String) -> String {
        var formatted = text
        formatted = formatted.replacingOccurrences(
            of: "(?m)^#{1,4}\\s+(.+)$",
            with: "**$1**",
            options: .regularExpression
        )
        
        formatted = formatted.replacingOccurrences(
            of: "(?m)^\\d+\\.\\s+(.+:)$",
            with: "**$0**",
            options: .regularExpression
        )
        
        formatted = formatted.replacingOccurrences(
            of: "(?m)^[\\-\\*]\\s+",
            with: "   • ",
            options: .regularExpression
        )
        
        return formatted
    }
    
    func askQuestion() {
        guard !questionText.isEmpty else { return }
        isAsking = true
        
        Task {
            do {
                let answer = try await DreamAnalyzer.shared.DreamQuestionWithContext(
                    transcript: dream.rawTranscript,
                    analysis: rawText,
                    question: questionText,
                    searcher: store,
                    dreamDate: dream.date,
                    includeSleep: store.usesSleepData
                )
                withAnimation {
                    self.answerText = answer
                    self.isAsking = false
                }
            } catch {
                withAnimation {
                    self.answerText = "Sorry, I couldn't generate an answer. Please try again."
                    self.isAsking = false
                }
            }
        }
    }
}

struct InsightCardView: View {
    let type: DreamDetailView.InsightType
    let text: String
    let animates: Bool
    var isExpanded: Bool = false
    var secondary: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label(type.title, systemImage: type.icon)
                    .font(.headline)
                    .foregroundStyle(type.color)
                    .symbolRenderingMode(.palette)
                    .symbolColorRenderingMode(.gradient)
                
                Spacer()
                
                if !isExpanded {
                    Image(systemName: "questionmark.bubble")
                        .font(.body)
                        .foregroundStyle(secondary)
                }
            }
            
            if animates {
                TypewriterText(text: text, animates: true)
                    .lineSpacing(4)
                    .multilineTextAlignment(.leading)
                    .font(type == .advice ? .body.italic() : .body)
                    .foregroundStyle(.primary)
            } else {
                Text(LocalizedStringKey(text))
                    .lineSpacing(4)
                    .multilineTextAlignment(.leading)
                    .font(type == .advice ? .body.italic() : .body)
                    .foregroundStyle(.primary)
            }
        }
        .padding(24)
        .contentShape(RoundedRectangle(cornerRadius: 24))
    }
}

struct DreamContextSection: View {
    let core: DreamCoreAnalysis
    
    @Binding var activeEntity: DreamDetailView.EntityIdentifier?
    @Binding var selectedEntity: DreamDetailView.EntityIdentifier?
    @Binding var entityToDelete: DreamDetailView.EntityIdentifier?
    @Binding var showDeleteAlert: Bool
    @ObservedObject var store: DreamStore
    var namespace: Namespace.ID
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            
            if let people = core.people, !people.isEmpty {
                ContextRow(
                    title: "People",
                    icon: "person.2.fill",
                    color: .blue,
                    items: people,
                    type: "person",
                    activeEntity: $activeEntity,
                    selectedEntity: $selectedEntity,
                    entityToDelete: $entityToDelete,
                    showDeleteAlert: $showDeleteAlert,
                    store: store,
                    namespace: namespace
                )
            }
            
            if let places = core.places, !places.isEmpty {
                ContextRow(
                    title: "Places",
                    icon: "map.fill",
                    color: .green,
                    items: places,
                    type: "place",
                    activeEntity: $activeEntity,
                    selectedEntity: $selectedEntity,
                    entityToDelete: $entityToDelete,
                    showDeleteAlert: $showDeleteAlert,
                    store: store,
                    namespace: namespace
                )
            }
            
            if let emotions = core.emotions, !emotions.isEmpty {
                ContextRow(
                    title: "Emotions",
                    icon: "heart.fill",
                    color: .pink,
                    items: emotions,
                    type: "emotion",
                    activeEntity: $activeEntity,
                    selectedEntity: $selectedEntity,
                    entityToDelete: $entityToDelete,
                    showDeleteAlert: $showDeleteAlert,
                    store: store,
                    namespace: namespace
                )
            }
            
            if let symbols = core.symbols, !symbols.isEmpty {
                ContextRow(
                    title: "Symbols",
                    icon: "star.fill",
                    color: .yellow,
                    items: symbols,
                    type: "tag",
                    activeEntity: $activeEntity,
                    selectedEntity: $selectedEntity,
                    entityToDelete: $entityToDelete,
                    showDeleteAlert: $showDeleteAlert,
                    store: store,
                    namespace: namespace
                )
            }
        }
    }
}

struct ContextRow: View {
    let title: String
    let icon: String
    let color: Color
    let items: [String]
    let type: String
    
    @Binding var activeEntity: DreamDetailView.EntityIdentifier?
    @Binding var selectedEntity: DreamDetailView.EntityIdentifier?
    @Binding var entityToDelete: DreamDetailView.EntityIdentifier?
    @Binding var showDeleteAlert: Bool
    @ObservedObject var store: DreamStore
    var namespace: Namespace.ID
    
    func getParentInfo(for itemName: String) -> (name: String, type: String)? {
        guard let entity = store.getEntity(name: itemName, type: type),
              let parentID = entity.parentID else { return nil }
        
        let components = parentID.split(separator: ":")
        if components.count == 2 {
            return (String(components[1]), String(components[0]))
        }
        return nil
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.footnote.bold())
                .foregroundStyle(color)
                .symbolRenderingMode(.palette)
                .symbolColorRenderingMode(.gradient)
                .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(items, id: \.self) { item in
                        Button {
                            if type == "emotion" {
                                store.jumpToFilter(type: type, value: item)
                            } else {
                                activeEntity = DreamDetailView.EntityIdentifier(name: item, type: type)
                            }
                        } label: {
                            Text(item.capitalized).font(.footnote.bold())
                        }
                        .buttonStyle(.glassProminent)
                        .tint(color.opacity(0.2))
                        .foregroundStyle(color)
                        .matchedTransitionSource(id: DreamDetailView.EntityIdentifier(name: item, type: type).id, in: namespace)
                        .confirmationDialog(
                            "Options",
                            isPresented: Binding(
                                get: { activeEntity?.id == DreamDetailView.EntityIdentifier(name: item, type: type).id },
                                set: { if !$0 { activeEntity = nil } }
                            ),
                            titleVisibility: .hidden
                        ) {
                            let parentInfo = getParentInfo(for: item)
                            
                            Button {
                                if let parent = parentInfo {
                                    selectedEntity = DreamDetailView.EntityIdentifier(name: parent.name, type: parent.type)
                                } else {
                                    selectedEntity = DreamDetailView.EntityIdentifier(name: item, type: type)
                                }
                            } label: {
                                Label("View Details", systemImage: "info.circle")
                            }
                            
                            Button {
                                if let parent = parentInfo {
                                    store.jumpToFilter(type: parent.type, value: parent.name)
                                } else {
                                    store.jumpToFilter(type: type, value: item)
                                }
                            } label: {
                                Label("Filter Dreams", systemImage: "line.3.horizontal.decrease.circle")
                            }
                            
                            if let parent = parentInfo {
                                Button(role: .destructive) {
                                    withAnimation {
                                        store.unlinkEntity(name: item, type: type)
                                    }
                                } label: {
                                    Label("Unlink", systemImage: "personalhotspot.slash")
                                }
                            } else {
                                Button(role: .destructive) {
                                    entityToDelete = DreamDetailView.EntityIdentifier(name: item, type: type)
                                    showDeleteAlert = true
                                } label: {
                                    Label("Delete Details", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
            .scrollClipDisabled()
        }
    }
}

struct DreamTranscriptSection: View {
    let transcript: String
    var secondary: Color
    
    var body: some View {
        TranscriptCard(title: "Transcript", icon: "quote.opening", color: secondary) {
            Text(transcript)
                .font(.callout.monospaced())
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal)
    }
}

private struct RecordingPlaybackView: View {
    let url: URL
    @State private var player: AVAudioPlayer?
    @State private var isPlaying = false
    @State private var playbackError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button {
                    if isPlaying { player?.pause(); isPlaying = false }
                    else {
                        do {
                            try AVAudioSession.sharedInstance().setCategory(.playback)
                            try AVAudioSession.sharedInstance().setActive(true)
                            if player == nil {
                                player = try AVAudioPlayer(contentsOf: url)
                            }
                            isPlaying = player?.play() == true
                            playbackError = isPlaying ? nil : "The recording couldn’t be played. You can still export it."
                        } catch { playbackError = "The recording couldn’t be played. You can still export it." }
                    }
                } label: {
                    Label {
                        Text(isPlaying ? "Pause Recording" : "Play Recording")
                    } icon: {
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .contentTransition(.symbolEffect(.replace))
                    }
                }
                Spacer()
                ShareLink(item: url) { Image(systemName: "square.and.arrow.up") }
                    .accessibilityLabel("Export recording")
            }
            if let playbackError { Text(playbackError).font(.footnote) }
        }
        .padding()
        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 24))
        .task(id: isPlaying) {
            while isPlaying && !Task.isCancelled {
                do { try await Task.sleep(for: .milliseconds(250)) } catch { break }
                if player?.isPlaying != true {
                    player?.currentTime = 0
                    isPlaying = false
                }
            }
            if !isPlaying { try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation) }
        }
        .onDisappear {
            player?.stop()
            player = nil
            isPlaying = false
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }
}
