import SwiftUI

struct DreamDetailView: View {
    @ObservedObject var store: DreamStore
    let dream: Dream
    
    var body: some View {
        ZStack {
            Theme.gradientBackground.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 25) {
                    
                    // 1. GENERATIVE ART
                    ZStack {
                        DreamArtCanvas(dream: dream, isThumbnail: false)
                            .frame(height: 300)
                            .clipShape(RoundedRectangle(cornerRadius: 24))
                            .overlay(
                                RoundedRectangle(cornerRadius: 24)
                                    .strokeBorder(LinearGradient(colors: [.white.opacity(0.5), .clear], startPoint: .top, endPoint: .bottom), lineWidth: 1)
                            )
                            .shadow(color: Color(hex: dream.dominantColorHex).opacity(0.6), radius: 20, x: 0, y: 10)
                        
                        VStack {
                            Spacer()
                            HStack {
                                Image(systemName: "sparkles")
                                Text("Generated from Dream DNA")
                                    .font(.caption2.bold())
                                    .tracking(1)
                            }
                            .padding(8)
                            .background(.ultraThinMaterial, in: Capsule())
                            .padding()
                        }
                    }
                    .padding(.horizontal)
                    
                    // 2. SUMMARY CARD
                    GlassCard {
                        VStack(alignment: .leading, spacing: 15) {
                            HStack {
                                Text(dream.sentimentEmoji)
                                    .font(.title)
                                Text("Dream Analysis")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                Spacer()
                            }
                            
                            Text(dream.smartSummary)
                                .font(.body)
                                .foregroundStyle(.white.opacity(0.9))
                                .lineSpacing(6)
                        }
                    }
                    .padding(.horizontal)
                    
                    // 3. CONTEXT & ATMOSPHERE
                    if !dream.people.isEmpty || !dream.places.isEmpty || !dream.emotions.isEmpty {
                        VStack(alignment: .leading, spacing: 15) {
                            Text("Context & Atmosphere")
                                .font(.caption)
                                .foregroundStyle(.gray)
                                .textCase(.uppercase)
                                .padding(.leading)
                            
                            // A. People
                            if !dream.people.isEmpty {
                                HStack(alignment: .top, spacing: 15) {
                                    Image(systemName: "person.2.fill")
                                        .foregroundStyle(Theme.accent)
                                        .frame(width: 24)
                                    
                                    FlowLayout(items: dream.people) { _ in }
                                }
                                .padding(.horizontal)
                            }
                            
                            // B. Places
                            if !dream.places.isEmpty {
                                HStack(alignment: .top, spacing: 15) {
                                    Image(systemName: "map.fill")
                                        .foregroundStyle(Theme.secondary)
                                        .frame(width: 24)
                                    
                                    FlowLayout(items: dream.places) { _ in }
                                }
                                .padding(.horizontal)
                            }
                            
                            // C. Emotions (Row)
                            if !dream.emotions.isEmpty {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 12) {
                                        Image(systemName: "heart.text.square.fill")
                                            .foregroundStyle(.pink)
                                            .padding(.trailing, 5)
                                        
                                        ForEach(dream.emotions, id: \.self) { emotion in
                                            Text(emotion)
                                                .font(.subheadline.bold())
                                                .padding(.horizontal, 16)
                                                .padding(.vertical, 8)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .fill(LinearGradient(colors: [.pink.opacity(0.2), .purple.opacity(0.2)], startPoint: .top, endPoint: .bottom))
                                                )
                                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.1)))
                                                .foregroundStyle(.white)
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                            }
                        }
                    }
                    
                    // 4. ENTITY TAGS
                    VStack(alignment: .leading) {
                        Text("Entities & Symbols")
                            .font(.caption)
                            .foregroundStyle(.gray)
                            .padding(.leading)
                        
                        FlowLayout(items: dream.keyEntities) { tag in
                            store.selectTagFilter(tag)
                        }
                        .padding(.horizontal)
                    }
                    
                    // 5. TRANSCRIPT
                    VStack(alignment: .leading) {
                        Text("Transcript")
                            .font(.caption)
                            .foregroundStyle(.gray)
                        Text(dream.rawTranscript)
                            .font(.system(.callout, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.6))
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.black.opacity(0.3))
                            .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 50)
                }
                .padding(.top)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - GENERATIVE ART ENGINE
struct DreamArtCanvas: View {
    let dream: Dream
    let isThumbnail: Bool
    
    var body: some View {
        Canvas { context, size in
            // Base Gradient
            let color1 = Color(hex: dream.dominantColorHex)
            let color2 = dream.sentimentScore > 0 ? Color.orange : Color.indigo
            
            let gradient = Gradient(colors: [color1, color2, .black])
            
            // FIXED: Using CGPoint instead of UnitPoint (.topLeading) for GraphicsContext
            context.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .linearGradient(
                    gradient,
                    startPoint: CGPoint(x: 0, y: 0),
                    endPoint: CGPoint(x: size.width, y: size.height)
                )
            )
            
            // Procedural Orbs
            let count = isThumbnail ? 3 : 8
            for i in 0..<count {
                let x = Double((dream.id.hashValue &+ i) % 100) / 100.0 * size.width
                let y = Double((dream.id.hashValue &+ (i*2)) % 100) / 100.0 * size.height
                let radius = Double((dream.id.hashValue &+ (i*3)) % 50) + (isThumbnail ? 10 : 30)
                
                let path = Path(ellipseIn: CGRect(x: x, y: y, width: radius, height: radius))
                context.fill(path, with: .color(.white.opacity(0.1)))
                context.addFilter(.blur(radius: 10))
            }
            
            // Waveform Lines based on Voice Fatigue
            let midY = size.height / 2
            var path = Path()
            path.move(to: CGPoint(x: 0, y: midY))
            
            for x in stride(from: 0, to: size.width, by: 5) {
                let relativeX = x / size.width
                let sine = sin(relativeX * 10 + Double(dream.voiceFatigue * 10))
                let y = midY + (sine * (isThumbnail ? 10 : 40))
                path.addLine(to: CGPoint(x: x, y: y))
            }
            
            context.stroke(path, with: .color(.white.opacity(0.3)), lineWidth: 2)
        }
    }
}

struct FlowLayout: View {
    let items: [String]
    let action: (String) -> Void
    
    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], alignment: .leading, spacing: 10) {
            ForEach(items, id: \.self) { item in
                Button {
                    action(item)
                } label: {
                    TagPill(text: item)
                }
            }
        }
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
