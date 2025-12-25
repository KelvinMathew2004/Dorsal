import SwiftUI

struct DreamDetailView: View {
    @ObservedObject var store: DreamStore
    let dream: Dream
    
    var body: some View {
        ZStack {
            Theme.gradientBackground.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // 1. Image Header (Visual)
                    DreamImageHeader(dream: dream)
                    
                    // 2. Context Tags (People, Places, Emotions, Tags)
                    DreamContextSection(dream: dream, store: store)
                    
                    // 3. Deep Analysis (Foundation Models)
                    DreamDeepAnalysisCard(dream: dream)
                    
                    // 4. Advice (Therapeutic)
                    DreamAdviceCard(dream: dream)
                    
                    // 5. Tone & Voice Stats
                    VoiceAnalysisCard(dream: dream)
                    
                    // 6. Transcript
                    DreamTranscriptSection(dream: dream)
                }
                .padding(.top)
                .padding(.bottom, 50)
            }
        }
        .navigationTitle(dream.date.formatted(date: .abbreviated, time: .shortened))
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
                // Skeleton/Loading State if image isn't ready
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .frame(height: 380)
                    .redacted(reason: .placeholder)
                    .shimmering()
                    .clipShape(RoundedRectangle(cornerRadius: 32))
            }
            
            // Badge
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
    let dream: Dream
    @ObservedObject var store: DreamStore
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            // People
            if !dream.analysis.people.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(dream.analysis.people, id: \.self) { person in
                            Button {
                                // store.jumpToFilter(type: "person", value: person)
                            } label: {
                                Label(person, systemImage: "person.fill")
                                    .font(.caption.bold())
                                    .foregroundStyle(.blue)
                            }
                            .tint(.blue.opacity(0.2))
                            .buttonStyle(.borderedProminent) // Using standard styles compatible with glass context
                            .glassEffect(.regular.tint(.blue.opacity(0.2)), in: Capsule())
                        }
                    }
                    .padding(.horizontal)
                }
                .scrollClipDisabled()
            }

            // Places
            if !dream.analysis.places.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(dream.analysis.places, id: \.self) { place in
                            Button {
                                // store.jumpToFilter(type: "place", value: place)
                            } label: {
                                Label(place, systemImage: "map.fill")
                                    .font(.caption.bold())
                                    .foregroundStyle(.green)
                            }
                            .tint(.green.opacity(0.2))
                            .buttonStyle(.borderedProminent)
                            .glassEffect(.regular.tint(.green.opacity(0.2)), in: Capsule())
                        }
                    }
                    .padding(.horizontal)
                }
                .scrollClipDisabled()
            }

            // Emotions
            if !dream.analysis.emotions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(dream.analysis.emotions, id: \.self) { emotion in
                            Button {
                                // store.jumpToFilter(type: "emotion", value: emotion)
                            } label: {
                                Label(emotion, systemImage: "heart.fill")
                                    .font(.caption.bold())
                                    .foregroundStyle(.pink)
                            }
                            .tint(.pink.opacity(0.2))
                            .buttonStyle(.borderedProminent)
                            .glassEffect(.regular.tint(.pink.opacity(0.2)), in: Capsule())
                        }
                    }
                    .padding(.horizontal)
                }
                .scrollClipDisabled()
            }

            // Tags / Symbols
            if !dream.analysis.symbols.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Symbols")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)

                    FlowLayout {
                        ForEach(dream.analysis.symbols, id: \.self) { tag in
                            Button(tag) {
                                // store.jumpToFilter(type: "tag", value: tag)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial, in: Capsule())
                            .glassEffect(.regular, in: Capsule())
                            .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
}

struct DreamDeepAnalysisCard: View {
    let dream: Dream
    
    var body: some View {
        MagicCard(title: "Interpretation", icon: "sparkles.rectangle.stack", color: Theme.accent) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Spacer()
                    Text(dream.analysis.tone.label)
                        .font(.caption.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .glassEffect(.regular.tint(Color.white.opacity(0.1)), in: Capsule())
                }
                
                Text(dream.analysis.interpretation)
                    .lineSpacing(4)
                
                Divider().background(Color.white.opacity(0.2))
                
                HStack {
                    Text("Summary")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                
                Text(dream.analysis.summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal)
    }
}

struct DreamAdviceCard: View {
    let dream: Dream
    
    var body: some View {
        MagicCard(title: "Actionable Advice", icon: "brain.head.profile", color: .green) {
            Text(dream.analysis.actionableAdvice)
                .italic()
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassEffect(.regular.tint(Color.green.opacity(0.1)), in: RoundedRectangle(cornerRadius: 16))
        }
        .padding(.horizontal)
    }
}

struct VoiceAnalysisCard: View {
    let dream: Dream
    
    var body: some View {
        MagicCard(title: "Voice Analysis", icon: "waveform", color: .orange) {
            HStack(spacing: 20) {
                VStack(alignment: .leading) {
                    Text("Fatigue Level")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(String(format: "%d%%", dream.analysis.voiceFatigue))
                        .font(.title3.bold())
                }
                
                VStack(alignment: .leading) {
                    Text("Detected Tone")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(dream.analysis.tone.label.isEmpty ? "Neutral" : dream.analysis.tone.label)
                        .font(.title3.bold())
                }
                
                Spacer()
            }
        }
        .padding(.horizontal)
    }
}

struct DreamTranscriptSection: View {
    let dream: Dream
    
    var body: some View {
        MagicCard(title: "Transcript", icon: "quote.opening", color: .secondary) {
            Text(dream.rawTranscript)
                .font(.callout.monospaced())
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal)
    }
}
