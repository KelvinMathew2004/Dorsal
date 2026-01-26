import SwiftUI
import Photos

struct DreamDetailView: View {
    @ObservedObject var store: DreamStore
    let dream: Dream
    
    @Namespace private var namespace
    
    @State private var activeEntity: EntityIdentifier?
    @State private var selectedEntity: EntityIdentifier?
    @State private var entityToDelete: EntityIdentifier?
    @State private var showDeleteAlert = false
    
    @State private var selectedInsight: InsightType?
    
    @State private var gradientColors: [Color] = []
    
    @State private var showSaveSuccess = false
    
    var textColor: Color {
        let baseColor = gradientColors.first ?? .purple
        return baseColor.mix(with: .white, by: 0.7)
    }
    
    var secondaryColor: Color {
        let baseColor = gradientColors.first ?? .purple
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
    
    var body: some View {
        ZStack {
            Theme.gradientBackground()
                .ignoresSafeArea()
            
            if !gradientColors.isEmpty {
                Group {
                    MeshGradient(
                        width: 3, height: 3,
                        points: [
                            [0.0, 0.0], [0.5, 0.0], [1.0, 0.0],
                            [0.0, 0.5], [0.5, 0.5], [1.0, 0.5],
                            [0.0, 1.0], [0.5, 1.0], [1.0, 1.0]
                        ],
                        colors: [
                            gradientColors[0].mix(with: .black, by: 0.6), gradientColors[1].mix(with: .black, by: 0.6), gradientColors[2].mix(with: .black, by: 0.6),
                            gradientColors[2].mix(with: .black, by: 0.6), gradientColors[0].mix(with: .black, by: 0.6), gradientColors[1].mix(with: .black, by: 0.6),
                            gradientColors[1].mix(with: .black, by: 0.6), gradientColors[2].mix(with: .black, by: 0.6), gradientColors[0].mix(with: .black, by: 0.6)
                        ]
                    )
                }
                .ignoresSafeArea()
                .transition(.opacity)
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
        .navigationTitle(liveDream.core?.title ?? liveDream.date.formatted(date: .abbreviated, time: .shortened))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if !store.isProcessing && liveDream.generatedImageData != nil && selectedInsight == nil {
                    Button {
                        saveImageToGallery()
                    } label: {
                        Image(systemName: "square.and.arrow.down")
                            .foregroundStyle(.white)
                    }
                }
                
                if !store.isProcessing && selectedInsight == nil {
                    Button {
                        store.regenerateDream(liveDream)
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .foregroundStyle(.white)
                    }
                }
            }
        }
        .onAppear {
            if let data = liveDream.generatedImageData, let uiImage = UIImage(data: data) {
                let color = uiImage.dominantColor
                self.gradientColors = [color, color.opacity(0.8), color.opacity(0.6)]
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
                    let newColors = [color, color.opacity(0.8), color.opacity(0.6)]
                    withAnimation(.easeInOut(duration: 1.0)) {
                        self.gradientColors = newColors
                    }
                }
            }
        } else {
            withAnimation(.easeInOut(duration: 1.0)) {
                self.gradientColors = []
            }
        }
    }
    
    @ViewBuilder
    var contentLayer: some View {
        if let error = liveDream.analysisError {
            errorView(error: error)
        } else {
            mainScrollView
        }
    }
    
    @ViewBuilder
    func errorView(error: String) -> some View {
        ContentUnavailableView {
            Label("Analysis Failed", systemImage: "hand.raised.fill")
        } description: {
            Text(error)
                .multilineTextAlignment(.center)
        } actions: {
            if liveDream.core?.summary != nil {
                Button("Remove Entry", role: .destructive) {
                    store.deleteDream(liveDream)
                    store.navigationPath = NavigationPath()
                }
                .buttonStyle(.glass)
                .tint(.red)
                
                Button("Continue", role: .confirm) {
                    store.ignoreErrorAndKeepDream(liveDream)
                }
                .buttonStyle(.glassProminent)
                .foregroundStyle(Theme.accent)
                .tint(Theme.secondary.opacity(0.2))
            } else {
                Button("Remove Entry", role: .destructive) {
                    store.deleteDream(liveDream)
                    store.navigationPath = NavigationPath()
                }
                .buttonStyle(.glassProminent)
                .tint(.red)
            }
        }
        .transition(.opacity)
    }
    
    @ViewBuilder
    var mainScrollView: some View {
        ScrollView {
            VStack(spacing: 24) {
                
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
                
                DreamTranscriptSection(transcript: liveDream.rawTranscript, secondary: secondaryColor)
            }
            .padding(.top)
            .padding(.bottom, 50)
            .animation(.default, value: liveDream.core)
            .animation(.default, value: liveDream.extras)
        }
        .scrollIndicators(.hidden)
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
                        try? await Task.sleep(nanoseconds: 800_000_000)
                        if !isProcessingThisDream { break }
                        
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
        
        // Only show header content if we have an image, are generating one (AND supported), or have a summary
        if image != nil || (isGeneratingImage && store.isImageGenerationAvailable) || liveDream.core?.summary != nil {
            VStack(spacing: 20) {
                // Only show Lens if we have an image OR if generation is actually supported
                if image != nil || (isGeneratingImage && store.isImageGenerationAvailable) {
                    LensView(
                        image: image,
                        shadowColor: gradientColors.first ?? .black
                    )
                    .aspectRatio(1.0, contentMode: .fit)
                    .frame(maxWidth: 400)
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
    var metricsSection: some View {
        if let fatigue = liveDream.voiceFatigue {
            HStack(spacing: 24) {
                NavigationLink(destination: TrendDetailView(metric: .fatigue, store: store)) {
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
                    .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 24))
                    .overlay(alignment: .trailing) {
                        Image(systemName: "chevron.right")
                            .font(.body.bold())
                            .foregroundStyle(secondaryColor)
                            .padding(.trailing, 20)
                    }
                    .contentShape(RoundedRectangle(cornerRadius: 24))
                }
                
                if let tone = liveDream.core?.tone?.label {
                    NavigationLink(destination: TrendDetailView(metric: .tone, store: store)) {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Tone", systemImage: "waveform")
                                .font(.headline)
                                .foregroundStyle(.orange)
                            
                            Spacer()
                            
                            Text(tone.capitalized).font(.title3.bold()).foregroundStyle(.white)
                            
                            if let conf = liveDream.core?.tone?.confidence {
                                Text("\(conf)% Confidence")
                                    .font(.caption)
                                    .foregroundStyle(secondaryColor)
                            }
                        }
                        .padding(20)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 24))
                        .overlay(alignment: .trailing) {
                            Image(systemName: "chevron.right")
                                .font(.body.bold())
                                .foregroundStyle(secondaryColor)
                                .padding(.trailing, 20)
                        }
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
                let answer = try await DreamAnalyzer.shared.DreamQuestion(
                    transcript: dream.rawTranscript,
                    analysis: rawText,
                    question: questionText
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
                .font(.caption.bold())
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
                            Text(item.capitalized).font(.caption.bold())
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
