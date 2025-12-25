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
                    // 1. Image Header
                    DreamImageHeader(dream: liveDream)
                    
                    // 2. Summary (Core)
                    if let summary = liveDream.core?.summary {
                        Text(summary)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                            .transition(.opacity)
                    }
                    
                    // 3. Core Analysis (Context Tags, Emotion)
                    // FIX: Pass the concrete 'core' object.
                    if let core = liveDream.core {
                        DreamContextSection(core: core)
                            .transition(.opacity)
                    }
                    
                    // 4. Interpretation & Advice (Core now)
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
                    
                    // 5. Voice/Tone (Core)
                    if let fatigue = liveDream.core?.voiceFatigue {
                        HStack(spacing: 16) {
                            MagicCard(title: "Voice Fatigue", icon: "battery.50", color: .red) {
                                VStack(alignment: .leading) {
                                    Text("\(fatigue)%")
                                        .font(.title3.bold())
                                    ProgressView(value: Double(fatigue), total: 100).tint(.red)
                                }
                            }
                            
                            if let tone = liveDream.core?.tone?.label {
                                MagicCard(title: "Tone", icon: "waveform", color: .orange) {
                                    VStack(alignment: .leading) {
                                        Text(tone).font(.title3.bold())
                                        if let conf = liveDream.core?.tone?.confidence {
                                            Text("\(conf)% Confidence").font(.caption).foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    
                    // 6. Loading State for Extras
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
                .animation(.default, value: liveDream.core) // Re-render when core updates
                .animation(.default, value: liveDream.extras) // Re-render when extras updates
            }
        }
        .navigationTitle(liveDream.core?.title ?? liveDream.date.formatted(date: .abbreviated, time: .shortened))
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - COMPONENTS

struct DreamImageHeader: View {
    let dream: Dream
    
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if let imageData = dream.generatedImageData, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 380)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 32))
            } else {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .frame(height: 380)
                    .clipShape(RoundedRectangle(cornerRadius: 32))
                    .overlay {
                        if dream.core == nil {
                            // Show shimmer only if we don't have core data yet (waiting for prompt)
                            Rectangle().fill(.clear).shimmering()
                        }
                    }
            }
            
            HStack(spacing: 6) {
                Image(systemName: "apple.intelligence")
                    .symbolEffect(.pulse)
                Text("Dream Visualizer")
                    .font(.caption.weight(.semibold))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: Capsule())
            .padding(20)
        }
        .padding(.horizontal)
        .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
    }
}

struct DreamContextSection: View {
    // FIX: Updated type to DreamCoreAnalysis (concrete) instead of PartiallyGenerated
    let core: DreamCoreAnalysis
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let people = core.people, !people.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(people, id: \.self) { person in
                            TagPill(text: person).glassEffect(.regular.tint(.blue.opacity(0.2)))
                        }
                    }
                    .padding(.horizontal)
                }
            }
            if let places = core.places, !places.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(places, id: \.self) { place in
                            TagPill(text: place).glassEffect(.regular.tint(.green.opacity(0.2)))
                        }
                    }
                    .padding(.horizontal)
                }
            }
            if let emotions = core.emotions, !emotions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(emotions, id: \.self) { emotion in
                            TagPill(text: emotion).glassEffect(.regular.tint(.pink.opacity(0.2)))
                        }
                    }
                    .padding(.horizontal)
                }
            }
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
