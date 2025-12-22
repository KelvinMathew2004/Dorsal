import SwiftUI

struct DreamDetailView: View {
    let dream: Dream
    
    var body: some View {
        ZStack {
            Theme.bgStart.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 25) {
                    
                    // 1. AI Summary Section
                    GlassCard {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Image(systemName: "wand.and.stars")
                                    .foregroundStyle(Theme.secondary)
                                Text("Apple Intelligence Summary")
                                    .font(.caption.bold())
                                    .foregroundStyle(Theme.secondary)
                            }
                            
                            Text(dream.smartSummary)
                                .font(.body)
                                .foregroundStyle(.white)
                                .lineSpacing(5)
                        }
                    }
                    
                    // 2. Stats Grid
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 15) {
                        StatBox(icon: "heart.text.square", title: "Sentiment", value: String(format: "%.1f", dream.sentimentScore), color: .pink)
                        StatBox(icon: "waveform", title: "Voice Fatigue", value: String(format: "%.0f%%", dream.voiceFatigue * 100), color: .orange)
                        StatBox(icon: "clock", title: "Duration", value: "3m 12s", color: .blue) // Mock duration
                        StatBox(icon: "tag", title: "Entities", value: "\(dream.keyEntities.count)", color: .green)
                    }
                    
                    // 3. Raw Transcript
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Original Transcript")
                            .font(.headline)
                            .foregroundStyle(.gray)
                        
                        Text(dream.rawTranscript)
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.7))
                            .padding()
                            .background(Color.black.opacity(0.2))
                            .cornerRadius(12)
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Dream Analysis")
        .navigationBarTitleDisplayMode(.inline)
    }
}
