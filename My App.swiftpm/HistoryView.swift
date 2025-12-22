import SwiftUI

struct HistoryView: View {
    @ObservedObject var store: DreamStore
    
    var body: some View {
        NavigationStack(path: $store.navigationPath) {
            ZStack {
                Theme.gradientBackground.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Filter Bar
                    if store.filterTag != nil {
                        HStack {
                            Text("Filtering by:")
                                .foregroundStyle(.gray)
                                .font(.caption)
                            
                            TagPill(text: store.filterTag!, isSelected: true)
                            
                            Spacer()
                            
                            Button {
                                withAnimation { store.clearFilter() }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                    }
                    
                    ScrollView {
                        LazyVStack(spacing: 15) {
                            ForEach(store.filteredDreams) { dream in
                                NavigationLink(value: dream) {
                                    DreamRow(dream: dream)
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Journal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .navigationDestination(for: Dream.self) { dream in
                DreamDetailView(store: store, dream: dream)
            }
        }
    }
}

struct DreamRow: View {
    let dream: Dream
    
    var body: some View {
        HStack(spacing: 15) {
            // Mini Art Preview
            DreamArtCanvas(dream: dream, isThumbnail: true)
                .frame(width: 60, height: 60)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.2)))
            
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
        }
        .padding(10)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.white.opacity(0.05), lineWidth: 1)
        )
    }
}
