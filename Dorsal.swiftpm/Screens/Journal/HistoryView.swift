import SwiftUI

struct HistoryView: View {
    @ObservedObject var store: DreamStore
    
    var body: some View {
        NavigationStack(path: $store.navigationPath) {
            ZStack {
                Theme.gradientBackground.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Filter Bar
                    FilterBar(store: store)
                        .padding(.vertical, 10)
                        .padding(.horizontal)
                    
                    // Active Filters
                    if !store.activeFilter.isEmpty {
                        ActiveFiltersView(store: store)
                            .padding(.horizontal)
                            .padding(.bottom, 8)
                    }
                    
                    // List
                    if store.filteredDreams.isEmpty {
                        ContentUnavailableView(
                            "No Dreams Found",
                            systemImage: "moon.zzz",
                            description: Text("Try adjusting your filters or recording a new dream.")
                        )
                        .padding(.top, 50)
                        Spacer()
                    } else {
                        List {
                            ForEach(store.filteredDreams) { dream in
                                ZStack {
                                    NavigationLink(value: dream) {
                                        EmptyView()
                                    }
                                    .opacity(0)
                                    
                                    DreamRow(dream: dream)
                                }
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        withAnimation {
                                            store.deleteDream(dream)
                                        }
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                    }
                }
            }
            .navigationTitle("Journal")
            .navigationBarTitleDisplayMode(.large)
            .searchable(
                text: $store.searchQuery,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search transcripts..."
            )
            .navigationDestination(for: Dream.self) { dream in
                DreamDetailView(store: store, dream: dream)
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
}

// MARK: - Subviews

struct FilterBar: View {
    @ObservedObject var store: DreamStore
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // Dropdowns with ICON ONLY (empty title string) as requested
                FilterDropdown(title: "", icon: "person.2", options: store.allPeople, selected: store.activeFilter.people) { store.togglePersonFilter($0) }
                FilterDropdown(title: "", icon: "map", options: store.allPlaces, selected: store.activeFilter.places) { store.togglePlaceFilter($0) }
                FilterDropdown(title: "", icon: "heart", options: store.allEmotions, selected: store.activeFilter.emotions) { store.toggleEmotionFilter($0) }
                FilterDropdown(title: "", icon: "tag", options: store.allTags, selected: store.activeFilter.tags) { store.toggleTagFilter($0) }
                
                if !store.activeFilter.isEmpty {
                    Button("Clear", role: .destructive) { withAnimation { store.clearFilter() } }
                    .font(.caption.bold())
                    .buttonStyle(.bordered)
                    .tint(.red)
                }
            }
            .padding(.vertical, 4)
        }
    }
}

struct FilterDropdown: View {
    let title: String
    let icon: String
    let options: [String]
    let selected: Set<String>
    let onSelect: (String) -> Void
    
    var body: some View {
        Menu {
            ForEach(options, id: \.self) { option in
                Button { onSelect(option) } label: { HStack { Text(option); if selected.contains(option) { Image(systemName: "checkmark") } } }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.body)
                if !title.isEmpty {
                    Text(title)
                }
                Image(systemName: "chevron.down")
                    .font(.caption2)
            }
            .font(.subheadline.bold())
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
//            .background(.ultraThinMaterial, in: Capsule())
//            .overlay(Capsule().stroke(.white.opacity(0.1), lineWidth: 1))
            .glassEffect(.regular)
        }
        .menuActionDismissBehavior(.disabled)
    }
}

struct ActiveFiltersView: View {
    @ObservedObject var store: DreamStore
    var body: some View {
        FlowLayout {
            ForEach(Array(store.activeFilter.people), id: \.self) { item in RemovablePill(text: item, icon: "person.fill", color: .blue) { store.togglePersonFilter(item) } }
            ForEach(Array(store.activeFilter.places), id: \.self) { item in RemovablePill(text: item, icon: "map.fill", color: .green) { store.togglePlaceFilter(item) } }
            ForEach(Array(store.activeFilter.emotions), id: \.self) { item in RemovablePill(text: item, icon: "heart.fill", color: .pink) { store.toggleEmotionFilter(item) } }
            ForEach(Array(store.activeFilter.tags), id: \.self) { item in RemovablePill(text: item, icon: "tag.fill", color: .purple) { store.toggleTagFilter(item) } }
        }
    }
}

struct RemovablePill: View {
    let text: String; let icon: String; let color: Color; let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) { Image(systemName: icon).font(.caption); Text(text).font(.caption.bold()); Image(systemName: "xmark").font(.caption2) }
                .foregroundStyle(.white).padding(.horizontal, 12).padding(.vertical, 8)
                .background(color.opacity(0.3), in: Capsule())
                .overlay(Capsule().stroke(color.opacity(0.5), lineWidth: 1))
        }
    }
}

struct DreamRow: View {
    let dream: Dream
    var body: some View {
        HStack(spacing: 16) {
            if let imageData = dream.generatedImageData, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage).resizable().aspectRatio(contentMode: .fill).frame(width: 50, height: 50).clipShape(RoundedRectangle(cornerRadius: 12)).overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.1)))
            } else {
                RoundedRectangle(cornerRadius: 12).fill(Color(hex: dream.generatedImageHex ?? "#333").gradient).frame(width: 50, height: 50).overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.1)))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(dream.date.formatted(date: .abbreviated, time: .shortened)).font(.caption.weight(.semibold)).foregroundStyle(Theme.accent)
                Text(dream.smartSummary).font(.subheadline).foregroundStyle(.primary).lineLimit(2)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(.tertiary)
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.1), lineWidth: 1))
    }
}
