import SwiftUI

struct DreamDetailView: View {
    @ObservedObject var store: DreamStore
    let dream: Dream
    
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
                            DreamContextSection(core: core, store: store)
                                .transition(.opacity)
                        }
                        
                        if let interp = liveDream.core?.interpretation {
                            MagicCard(title: "Interpretation", icon: "sparkles.rectangle.stack", color: .purple) {
                                Text(interp)
                                    .lineSpacing(4)
                            }
                            .padding(.horizontal)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                        
                        if let advice = liveDream.core?.actionableAdvice {
                            MagicCard(title: "Actionable Advice", icon: "brain.head.profile", color: .green) {
                                Text(advice)
                                    .italic()
                            }
                            .padding(.horizontal)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                        
                        // Vocal Fatigue & Tone Section (Clickable & Compact with Overlay Arrows)
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
    }
}

// MARK: - COMPONENTS

struct DreamContextSection: View {
    let core: DreamCoreAnalysis
    @ObservedObject var store: DreamStore
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            
            if let people = core.people, !people.isEmpty {
                ContextRow(title: "People", icon: "person.2.fill", color: .blue, items: people) { item in
                    store.jumpToFilter(type: "person", value: item)
                }
            }
            
            if let places = core.places, !places.isEmpty {
                ContextRow(title: "Places", icon: "map.fill", color: .green, items: places) { item in
                    store.jumpToFilter(type: "place", value: item)
                }
            }
            
            if let emotions = core.emotions, !emotions.isEmpty {
                ContextRow(title: "Emotions", icon: "heart.fill", color: .pink, items: emotions) { item in
                    store.jumpToFilter(type: "emotion", value: item)
                }
            }
            
            if let symbols = core.symbols, !symbols.isEmpty {
                ContextRow(title: "Symbols", icon: "star.fill", color: .yellow, items: symbols) { item in
                    store.jumpToFilter(type: "tag", value: item)
                }
            }
        }
    }
}

struct ContextRow: View {
    let title: String
    let icon: String
    let color: Color
    let items: [String]
    let action: (String) -> Void
    
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
                            action(item)
                        } label: {
                            Text(item.capitalized).font(.caption.bold())
                        }
                        .buttonStyle(.glassProminent)
                        .tint(color.opacity(0.2))
                        .foregroundStyle(color)
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
