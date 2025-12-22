import SwiftUI

struct HistoryView: View {
    @ObservedObject var store: DreamStore
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bgStart.ignoresSafeArea()
                
                ScrollView {
                    LazyVStack(spacing: 15) {
                        ForEach(store.dreams) { dream in
                            NavigationLink(value: dream) {
                                DreamRow(dream: dream)
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Dream Log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .navigationDestination(for: Dream.self) { dream in
                DreamDetailView(dream: dream)
            }
        }
    }
}

struct DreamRow: View {
    let dream: Dream
    
    var body: some View {
        HStack {
            // Emoji Badge
            Text(dream.sentimentEmoji)
                .font(.largeTitle)
                .frame(width: 60, height: 60)
                .background(Circle().fill(Color.white.opacity(0.1)))
            
            VStack(alignment: .leading, spacing: 5) {
                Text(dream.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(Theme.accent)
                
                Text(dream.smartSummary)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(2)
            }
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundStyle(.gray)
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.white.opacity(0.1), lineWidth: 1)
        )
    }
}
