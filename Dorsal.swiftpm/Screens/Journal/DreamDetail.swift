import SwiftUI

struct DreamDetailView: View {
    @ObservedObject var store: DreamStore
    let dream: Dream
    
    // Interaction State
    @State private var activeEntity: EntityIdentifier?
    @State private var selectedEntity: EntityIdentifier?
    @State private var entityToDelete: EntityIdentifier?
    @State private var showDeleteAlert = false
    
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
    
    var body: some View {
        ZStack {
            Theme.gradientBackground.ignoresSafeArea()
            
            // ERROR STATE
            if let error = liveDream.analysisError {
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
            } else {
                ScrollView {
                    VStack(spacing: 24) {
                        
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
                                            Text("Dream Visualizer")
                                                .font(.caption2.bold())
                                                .tracking(1)
                                        }
                                        .padding(8)
                                        .glassEffect(.regular)
                                        .padding()
                                    }
                            }
                            
                            if let summary = liveDream.core?.summary {
                                Text("\(Text("Summary: ").bold())\(summary)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.leading)
                                    .padding(20)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 32))
                        .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
                        .padding(.horizontal)
                        
                        // 3. Core Analysis (Context Tags)
                        if let core = liveDream.core {
                            DreamContextSection(
                                core: core,
                                activeEntity: $activeEntity,
                                selectedEntity: $selectedEntity,
                                entityToDelete: $entityToDelete,
                                showDeleteAlert: $showDeleteAlert,
                                store: store
                            )
                            .transition(.opacity)
                        }
                        
                        if let interp = liveDream.core?.interpretation {
                            MagicCard(title: "Interpretation", icon: "sparkles.rectangle.stack", color: .purple) {
                                // Animate only if processing
                                TypewriterText(text: interp, animates: isProcessingThisDream)
                                    .lineSpacing(4)
                            }
                            .padding(.horizontal)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                        
                        if let advice = liveDream.core?.actionableAdvice {
                            MagicCard(title: "Actionable Advice", icon: "brain.head.profile", color: .green) {
                                // Animate only if processing
                                TypewriterText(text: advice, animates: isProcessingThisDream)
                                    .italic()
                            }
                            .padding(.horizontal)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                        
                        // Vocal Fatigue & Tone Section
                        if let fatigue = liveDream.core?.voiceFatigue {
                            HStack(spacing: 16) {
                                // Vocal Fatigue Card
                                NavigationLink(destination: TrendDetailView(metric: .fatigue, store: store)) {
                                    VStack(alignment: .leading, spacing: 12) {
                                        Label("Vocal Fatigue", systemImage: "battery.50")
                                            .font(.headline)
                                            .foregroundStyle(.red)
                                        
                                        Spacer()
                                        
                                        Text("\(fatigue)%").font(.title3.bold()).foregroundStyle(.white)
                                        
                                        ProgressView(value: Double(fatigue), total: 100)
                                            .progressViewStyle(LinearProgressViewStyle(tint: .red))
                                            .frame(height: 8)
                                            .scaleEffect(x: 1, y: 2, anchor: .center)
                                    }
                                    .padding(20)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24))
                                    .overlay(alignment: .trailing) {
                                        Image(systemName: "chevron.right")
                                            .font(.body.bold())
                                            .foregroundStyle(.white.opacity(0.3))
                                            .padding(.trailing, 20)
                                    }
                                    .contentShape(RoundedRectangle(cornerRadius: 24))
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                                // Tone Card
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
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                        .padding(20)
                                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                                        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24))
                                        .overlay(alignment: .trailing) {
                                            Image(systemName: "chevron.right")
                                                .font(.body.bold())
                                                .foregroundStyle(.white.opacity(0.3))
                                                .padding(.trailing, 20)
                                        }
                                        .contentShape(RoundedRectangle(cornerRadius: 24))
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                        
                        DreamTranscriptSection(transcript: liveDream.rawTranscript)
                    }
                    .padding(.top)
                    .padding(.bottom, 50)
                    .animation(.default, value: liveDream.core)
                    .animation(.default, value: liveDream.extras)
                }
                .scrollDisabled(isProcessingThisDream)
                .overlay {
                    if isProcessingThisDream {
                        ZStack {
                            Color.black.opacity(0.3)
                                .ignoresSafeArea()
                            
                            VStack(spacing: 16) {
                                ProgressView()
                                    .scaleEffect(1.5)
                                    .tint(.white)
                                Text("Analyzing...")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                            }
                            .padding(32)
                            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24))
                        }
                    }
                }
            }
        }
        .navigationTitle(liveDream.core?.title ?? liveDream.date.formatted(date: .abbreviated, time: .shortened))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    store.regenerateDream(liveDream)
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(store.isProcessing)
            }
        }
        // Only global alert for deletion; ConfirmationDialog is now local to ContextRow
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
        .navigationDestination(item: $selectedEntity) { entity in
            EntityDetailView(store: store, name: entity.name, type: entity.type)
        }
    }
}

// MARK: - COMPONENTS

struct DreamContextSection: View {
    let core: DreamCoreAnalysis
    
    @Binding var activeEntity: DreamDetailView.EntityIdentifier?
    @Binding var selectedEntity: DreamDetailView.EntityIdentifier?
    @Binding var entityToDelete: DreamDetailView.EntityIdentifier?
    @Binding var showDeleteAlert: Bool
    @ObservedObject var store: DreamStore
    
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
                    store: store
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
                    store: store
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
                    store: store
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
                    store: store
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.caption.bold())
                .foregroundStyle(color)
                .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(items, id: \.self) { item in
                        Button {
                            if type == "emotion" {
                                // Emotions bypass dialog and jump directly to filter
                                store.jumpToFilter(type: type, value: item)
                            } else {
                                // Other types trigger the dialog
                                activeEntity = DreamDetailView.EntityIdentifier(name: item, type: type)
                            }
                        } label: {
                            Text(item.capitalized).font(.caption.bold())
                        }
                        .buttonStyle(.glassProminent)
                        .tint(color.opacity(0.2))
                        .foregroundStyle(color)
                        // ATTACHMENT: Confirmation Dialog attached directly to the button for the specific item
                        .confirmationDialog(
                            "Options",
                            isPresented: Binding(
                                get: { activeEntity?.id == DreamDetailView.EntityIdentifier(name: item, type: type).id },
                                set: { if !$0 { activeEntity = nil } }
                            )
                        ) {
                            Button("View Details") {
                                selectedEntity = DreamDetailView.EntityIdentifier(name: item, type: type)
                            }
                            Button("Filter Dreams") {
                                store.jumpToFilter(type: type, value: item)
                            }
                            Button("Delete Details", role: .destructive) {
                                entityToDelete = DreamDetailView.EntityIdentifier(name: item, type: type)
                                showDeleteAlert = true
                            }
                            Button("Cancel", role: .cancel) { }
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
        MagicCard(title: "Transcript", icon: "quote.opening", color: .secondary) {
            Text(transcript)
                .font(.callout.monospaced())
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal)
    }
}
