import SwiftUI

struct DreamDetailView: View {
    @ObservedObject var store: DreamStore
    let dream: Dream
    
    var liveDream: Dream {
        store.dreams.first(where: { $0.id == dream.id }) ?? dream
    }
    
    var body: some View {
        ZStack {
            Theme.gradientBackground.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    
                    // 1. Image Header + Summary Combined Container
                    VStack(spacing: 0) {
                        // Image
                        if let imageData = liveDream.generatedImageData, let uiImage = UIImage(data: imageData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 350)
                                .frame(maxWidth: .infinity)
                                .clipped()
                        } else {
                            Rectangle()
                                .fill(.ultraThinMaterial)
                                .frame(height: 350)
                                .overlay {
                                    if liveDream.core == nil {
                                        Rectangle().fill(.clear).shimmering()
                                    }
                                }
                        }
                        
                        // Summary (Caption) - Left aligned below image
                        if let summary = liveDream.core?.summary {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(summary)
                                    .font(.body)
                                    .foregroundStyle(.primary)
                                    .multilineTextAlignment(.leading)
                                    .padding(20)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.ultraThinMaterial)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 32))
                    .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
                    .padding(.horizontal)
                    
                    // 3. Core Analysis (Context Tags)
                    if let core = liveDream.core {
                        DreamContextSection(core: core, store: store)
                            .transition(.opacity)
                    }
                    
                    // 4. Interpretation & Advice
                    // The MagicCard component now enforces full width alignment internally,
                    // so the text will fill the space even while streaming.
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
                    
                    // 5. Voice/Tone (Equal Height)
                    if let fatigue = liveDream.core?.voiceFatigue {
                        HStack(spacing: 16) {
                            // Fatigue Block
                            VStack(alignment: .leading, spacing: 12) {
                                Label("Voice Fatigue", systemImage: "battery.50")
                                    .font(.headline)
                                    .foregroundStyle(.red)
                                Spacer()
                                Text("\(fatigue)%").font(.title3.bold())
                                ProgressView(value: Double(fatigue), total: 100).tint(.red)
                            }
                            .padding(20)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24))
                            
                            // Tone Block
                            if let tone = liveDream.core?.tone?.label {
                                VStack(alignment: .leading, spacing: 12) {
                                    Label("Tone", systemImage: "waveform")
                                        .font(.headline)
                                        .foregroundStyle(.orange)
                                    Spacer()
                                    Text(tone).font(.title3.bold())
                                    if let conf = liveDream.core?.tone?.confidence {
                                        Text("\(conf)% Confidence").font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                                .padding(20)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24))
                            }
                        }
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    
                    // 6. Loading
                    if store.isProcessing && liveDream.id == store.currentDreamID && liveDream.extras == nil {
                        HStack {
                            ProgressView()
                            Text("Analyzing deeper metrics...")
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .transition(.opacity)
                    }
                    
                    // 7. Transcript
                    DreamTranscriptSection(transcript: liveDream.rawTranscript)
                }
                .padding(.top)
                .padding(.bottom, 50)
                .animation(.default, value: liveDream.core)
                .animation(.default, value: liveDream.extras)
            }
        }
        .navigationTitle(liveDream.core?.title ?? liveDream.date.formatted(date: .abbreviated, time: .shortened))
        .navigationBarTitleDisplayMode(.inline)
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
                        .tint(color.opacity(0.2)) // Glass-like tint
                        .foregroundStyle(color) // Text color matches tint
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
