import SwiftUI

struct DreamDetailView: View {
    @ObservedObject var store: DreamStore
    let dream: Dream
    
    @Namespace private var namespace
    
    @State private var activeEntity: EntityIdentifier?
    @State private var selectedEntity: EntityIdentifier?
    @State private var entityToDelete: EntityIdentifier?
    @State private var showDeleteAlert = false
    
    @State private var selectedInsight: InsightType?
    
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
            Theme.gradientBackground.ignoresSafeArea()
            
            contentLayer
            
            VStack {
                Spacer()
                if let error = store.generationError {
                    Text(error)
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                        .padding()
                        .background(Color.red.opacity(0.8))
                        .clipShape(Capsule())
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                                withAnimation { store.generationError = nil }
                            }
                        }
                        .padding(.bottom, 20)
                }
            }
            .zIndex(200)
            
            if let insight = selectedInsight {
                InsightDetailView(
                    store: store,
                    dream: liveDream,
                    insight: insight,
                    namespace: namespace,
                    selectedInsight: $selectedInsight
                )
                .zIndex(100)
            }
        }
        .navigationTitle(liveDream.core?.title ?? liveDream.date.formatted(date: .abbreviated, time: .shortened))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if !store.isProcessing && selectedInsight == nil {
                    Button {
                        store.regenerateDream(liveDream)
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
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
                
                DreamTranscriptSection(transcript: liveDream.rawTranscript)
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
                    animates: false
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
                        animates: isProcessing
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
    
    @ViewBuilder
    var headerSection: some View {
        if liveDream.generatedImageData != nil || isGeneratingImage || liveDream.core?.summary != nil {
            VStack(spacing: 0) {
                if let imageData = liveDream.generatedImageData, let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 350)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 32))
                        .overlay(alignment: .bottomLeading) {
                            HStack {
                                Image(systemName: "apple.intelligence")
                                    .symbolRenderingMode(.palette)
                                    .symbolColorRenderingMode(.gradient)
                                Text("Dream Visualizer")
                                    .font(.caption2.bold())
                                    .tracking(1)
                            }
                            .padding(8)
                            .glassEffect(.regular)
                            .padding()
                        }
                } else if isGeneratingImage {
                    GeneratingGradientView()
                        .frame(height: 350)
                        .clipShape(RoundedRectangle(cornerRadius: 32))
                        .overlay {
                            Text("Visualizing...")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .shadow(radius: 5)
                        }
                }
                
                if let summary = liveDream.core?.summary {
                    Text("\(Text("Summary: ").bold())\(summary)")
                        .font(.caption)
                        .foregroundStyle(Theme.secondary)
                        .multilineTextAlignment(.leading)
                        .padding(20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 32))
            .padding(.horizontal)
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
                            .foregroundStyle(Theme.secondary)
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
                                    .foregroundStyle(Theme.secondary)
                            }
                        }
                        .padding(20)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 24))
                        .overlay(alignment: .trailing) {
                            Image(systemName: "chevron.right")
                                .font(.body.bold())
                                .foregroundStyle(Theme.secondary)
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
                            isExpanded: true
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
                        .foregroundStyle(Theme.secondary)
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
    var body: some View {
        TranscriptCard(title: "Transcript", icon: "quote.opening", color: Theme.secondary) {
            Text(transcript)
                .font(.callout.monospaced())
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal)
    }
}
