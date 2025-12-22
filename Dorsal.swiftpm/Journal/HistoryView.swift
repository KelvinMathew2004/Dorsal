import SwiftUI

struct HistoryView: View {
    @ObservedObject var store: DreamStore
    
    var body: some View {
        NavigationStack(path: $store.navigationPath) {
            ZStack {
                Theme.gradientBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        
                        // Active Filter
                        if let tag = store.filterTag {
                            HStack {
                                Text("Filtered by")
                                    .foregroundStyle(.secondary)
                                
                                if #available(iOS 26, *) {
                                    Button(action: { withAnimation { store.clearFilter() }}) {
                                        HStack(spacing: 4) {
                                            Text("#\(tag)")
                                            Image(systemName: "xmark.circle.fill")
                                        }
                                    }
                                    .buttonStyle(.glass)
                                } else {
                                    Button(action: { withAnimation { store.clearFilter() }}) {
                                        HStack(spacing: 4) {
                                            Text("#\(tag)")
                                            Image(systemName: "xmark.circle.fill")
                                        }
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(.white)
                                    .clipShape(Capsule())
                                }
                                Spacer()
                            }
                            .padding(.horizontal)
                        }
                        
                        LazyVStack(spacing: 16) {
                            ForEach(store.filteredDreams) { dream in
                                NavigationLink(value: dream) {
                                    DreamRow(dream: dream)
                                }
                                .buttonStyle(.plain)
                            }
                            
                            if store.filteredDreams.isEmpty {
                                ContentUnavailableView(
                                    "No Dreams Found",
                                    systemImage: "moon.zzz",
                                    description: Text("Try recording a new dream or adjusting your search.")
                                )
                                .padding(.top, 50)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 100)
                    }
                    .padding(.top, 10)
                }
            }
            .navigationTitle("Journal")
            .navigationBarTitleDisplayMode(.large)
            .searchable(
                text: $store.searchQuery,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search dreams, emotions..."
            )
            .navigationDestination(for: Dream.self) { dream in
                DreamDetailView(store: store, dream: dream)
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
}

struct DreamRow: View {
    let dream: Dream
    
    var body: some View {
        let content = HStack(spacing: 16) {
            // Hex Color Indicator
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(hex: dream.generatedImageHex ?? "#333333").gradient)
                .frame(width: 50, height: 50)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.1)))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(dream.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.accent)
                
                Text(dream.smartSummary)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(.tertiary)
        }
        .padding(16)
        
        if #available(iOS 26, *) {
            content.glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20))
        } else {
            content
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.1), lineWidth: 1))
        }
    }
}
