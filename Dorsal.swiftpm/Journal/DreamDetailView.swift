import SwiftUI

struct DreamDetailView: View {
    @ObservedObject var store: DreamStore
    let dream: Dream
    
    var body: some View {
        ZStack {
            Theme.gradientBackground.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    DreamImageHeader(dream: dream)
                    
                    DreamAnalysisCard(dream: dream)
                    
                    DreamContextSection(dream: dream)
                    
                    DreamEntitiesSection(dream: dream, store: store)
                    
                    DreamTranscriptSection(dream: dream)
                }
                .padding(.top)
                .padding(.bottom, 50)
            }
        }
        .navigationTitle(dream.date.formatted(date: .abbreviated, time: .shortened))
        .navigationBarTitleDisplayMode(.large)
    }
}

// MARK: - SUBVIEWS

struct DreamImageHeader: View {
    let dream: Dream
    
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if let hex = dream.generatedImageHex {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: hex), Color.black.opacity(0.2)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: 380)
                    .clipShape(RoundedRectangle(cornerRadius: 32))
                    .overlay(
                        Image(systemName: "photo.artframe")
                            .font(.system(size: 50))
                            .foregroundStyle(.white.opacity(0.2))
                    )
            } else {
                Rectangle()
                    .fill(.black.opacity(0.3))
                    .frame(height: 380)
                    .clipShape(RoundedRectangle(cornerRadius: 32))
            }
            
            // Badge
            let badge = HStack(spacing: 6) {
                Image(systemName: "apple.intelligence")
                    .symbolEffect(.pulse)
                Text("Image Creator")
                    .font(.caption.weight(.semibold))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            
            if #available(iOS 26, *) {
                badge.glassEffect(.clear, in: .capsule)
                    .padding(20)
            } else {
                badge.background(.ultraThinMaterial, in: Capsule())
                    .padding(20)
            }
        }
        .padding(.horizontal)
        .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
    }
}

struct DreamAnalysisCard: View {
    let dream: Dream
    
    var body: some View {
        let content = VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label {
                    Text("Analysis")
                        .font(.headline)
                } icon: {
                    Image(systemName: dream.sentimentSymbol)
                        .foregroundStyle(dream.sentimentColor)
                        .symbolEffect(.bounce, value: true)
                }
                Spacer()
            }
            Text(dream.smartSummary)
                .font(.body)
                .foregroundStyle(.secondary)
                .lineSpacing(5)
        }
        .padding(24)
        
        if #available(iOS 26, *) {
            content
                .glassEffect(.regular, in: .rect(cornerRadius: 24))
                .padding(.horizontal)
        } else {
            content
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
                .padding(.horizontal)
        }
    }
}

struct DreamContextSection: View {
    let dream: Dream
    
    var body: some View {
        if !dream.people.isEmpty || !dream.places.isEmpty || !dream.emotions.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Context")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                
                // Context Groups
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        if !dream.people.isEmpty {
                            ContextGroup(icon: "person.2.fill", items: dream.people)
                        }
                        if !dream.places.isEmpty {
                            ContextGroup(icon: "map.fill", items: dream.places)
                        }
                    }
                    .padding(.horizontal)
                }
                
                // Emotions
                if !dream.emotions.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(dream.emotions, id: \.self) { emotion in
                                EmotionPill(emotion: emotion)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
        }
    }
}

struct EmotionPill: View {
    let emotion: String
    
    var body: some View {
        let text = Text(emotion)
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        
        if #available(iOS 26, *) {
            text.glassEffect(.clear.tint(.pink), in: .capsule)
        } else {
            text
                // FIX: Apply material and color separately to avoid ZStack type errors
                .background(.ultraThinMaterial, in: Capsule())
                .background(Color.pink.opacity(0.1), in: Capsule())
                .overlay(Capsule().stroke(.white.opacity(0.1), lineWidth: 1))
        }
    }
}

struct DreamEntitiesSection: View {
    let dream: Dream
    @ObservedObject var store: DreamStore
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Entities")
                .font(.headline)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            
            FlowLayout {
                ForEach(dream.keyEntities, id: \.self) { tag in
                    if #available(iOS 26, *) {
                        Button(tag) { store.selectTagFilter(tag) }
                            .buttonStyle(.glass)
                    } else {
                        Button(tag) { store.selectTagFilter(tag) }
                            .buttonStyle(.bordered)
                            .tint(.secondary)
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

struct DreamTranscriptSection: View {
    let dream: Dream
    
    var body: some View {
        let content = VStack(alignment: .leading, spacing: 12) {
            Text("Transcript")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            Text(dream.rawTranscript.isEmpty ? "No transcript recorded." : dream.rawTranscript)
                .font(.callout.monospaced())
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(24)
        
        if #available(iOS 26, *) {
            content
                .glassEffect(.regular, in: .rect(cornerRadius: 24))
                .padding(.horizontal)
        } else {
            content
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
                .padding(.horizontal)
        }
    }
}

struct ContextGroup: View {
    let icon: String
    let items: [String]
    
    var body: some View {
        let content = HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
            
            Text(items.joined(separator: ", "))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        
        if #available(iOS 26, *) {
            content.glassEffect(.regular, in: .capsule)
        } else {
            content.background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().stroke(.white.opacity(0.1), lineWidth: 1))
        }
    }
}
