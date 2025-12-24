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
                    
                    // 2. Context Tags (People, Places, Emotions, Tags) - Moved here as requested
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
                Rectangle()
                    .fill(Color(hex: dream.generatedImageHex ?? "#000").gradient)
                    .frame(height: 380)
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
            if !dream.people.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    GlassEffectContainer {
                        HStack {
                            ForEach(dream.people, id: \.self) { person in
                                Button {
                                    store.jumpToFilter(type: "person", value: person)
                                } label: {
                                    Label(person, systemImage: "person.fill")
                                        .font(.caption.bold())
                                        .foregroundStyle(.blue)
                                }
                                .tint(.blue.opacity(0.2))
                                .buttonStyle(.glassProminent)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .scrollClipDisabled()
            }

            // Places
            if !dream.places.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    GlassEffectContainer {
                        HStack {
                            ForEach(dream.places, id: \.self) { place in
                                Button {
                                    store.jumpToFilter(type: "place", value: place)
                                } label: {
                                    Label(place, systemImage: "map.fill")
                                        .font(.caption.bold())
                                        .foregroundStyle(.green)
                                }
                                .tint(.green.opacity(0.2))
                                .buttonStyle(.glassProminent)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .scrollClipDisabled()
            }

            // Emotions
            if !dream.emotions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    GlassEffectContainer {
                        HStack {
                            ForEach(dream.emotions, id: \.self) { emotion in
                                Button {
                                    store.jumpToFilter(type: "emotion", value: emotion)
                                } label: {
                                    Label(emotion, systemImage: "heart.fill")
                                        .font(.caption.bold())
                                        .foregroundStyle(.pink)
                                }
                                .tint(.pink.opacity(0.2))
                                .buttonStyle(.glassProminent)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .scrollClipDisabled()
            }

            // Tags / Symbols
            if !dream.keyEntities.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Symbols")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)

                    GlassEffectContainer {
                        FlowLayout {
                            ForEach(dream.keyEntities, id: \.self) { tag in
                                Button(tag) {
                                    store.jumpToFilter(type: "tag", value: tag)
                                }
                                .buttonStyle(.glassProminent)
                                .foregroundColor(.secondary)
                                .tint(.secondary.opacity(0.2))
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
        }
    }
}

struct DreamDeepAnalysisCard: View {
    let dream: Dream
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("Interpretation", systemImage: "sparkles.rectangle.stack")
                    .font(.headline)
                    .foregroundStyle(Theme.accent)
                Spacer()
                Text(dream.tone)
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .glassEffect(.regular.tint(Color.white.opacity(0.1)))
            }
            
            Text(dream.interpretation)
                .font(.body)
                .foregroundStyle(.primary)
                .lineSpacing(4)
            
            Divider().background(Color.white.opacity(0.2))
            
            HStack {
                Text("Summary")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Spacer()
            }
            
            Text(dream.smartSummary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24))
        .padding(.horizontal)
    }
}

struct DreamAdviceCard: View {
    let dream: Dream
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Actionable Advice", systemImage: "brain.head.profile")
                .font(.headline)
                .foregroundStyle(.green)
            
            Text(dream.actionableAdvice)
                .font(.callout)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassEffect(.regular.tint(Color.green.opacity(0.1)), in: RoundedRectangle(cornerRadius: 16))
        }
        .padding(24)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24))
        .padding(.horizontal)
    }
}

struct VoiceAnalysisCard: View {
    let dream: Dream
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Voice Analysis", systemImage: "waveform")
                .font(.headline)
                .foregroundStyle(.orange)
            
            HStack(spacing: 20) {
                VStack(alignment: .leading) {
                    Text("Fatigue Level")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.0f%%", dream.voiceFatigue * 100))
                        .font(.title3.bold())
                }
                
                VStack(alignment: .leading) {
                    Text("Detected Tone")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(dream.tone.isEmpty ? "Neutral" : dream.tone)
                        .font(.title3.bold())
                }
                
                Spacer()
            }
        }
        .padding(24)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24))
        .padding(.horizontal)
    }
}

struct DreamTranscriptSection: View {
    let dream: Dream
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Transcript")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            Text(dream.rawTranscript)
                .font(.callout.monospaced())
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(24)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24))
        .padding(.horizontal)
    }
}
