import SwiftUI

struct HistoryView: View {
    @ObservedObject var store: DreamStore
    
    @State private var showingDeleteAlert = false
    @State private var dreamToDelete: Dream?
    
    var body: some View {
        NavigationStack(path: $store.navigationPath) {
            ZStack {
                Theme.gradientBackground.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Filter Bar
                    FilterBar(store: store)
                        .padding(.bottom, 10)
                    
                    // Active Filters
                    if !store.activeFilter.isEmpty {
                        ActiveFiltersView(store: store)
                            .padding(.horizontal)
                            .padding(.bottom, 8)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    
                    // List
                    if store.filteredDreams.isEmpty {
                        // NO DREAMS FOUND - FIXED AT TOP
                        VStack(spacing: 20) {
                            Color.clear.frame(height: 20)
                            
                            ContentUnavailableView(
                                "No Dreams Found",
                                systemImage: "moon.zzz",
                                description: Text("Try adjusting your filters or recording a new dream.")
                            )
                            
                            Spacer()
                        }
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
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        dreamToDelete = dream
                                        showingDeleteAlert = true
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                    .labelStyle(.iconOnly)
                                    .tint(.red)
                                }
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                        .animation(.default, value: store.filteredDreams)
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
            .alert("Delete Dream?", isPresented: $showingDeleteAlert, presenting: dreamToDelete) { dream in
                Button("Delete", role: .destructive) {
                    withAnimation {
                        store.deleteDream(dream)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: { dream in
                Text("Are you sure you want to delete this dream? This action cannot be undone.")
            }
        }
    }
}

// MARK: - Subviews
struct FilterBar: View {
    @ObservedObject var store: DreamStore

    var body: some View {
        HStack(spacing: 12) {
            FilterDropdown(
                icon: "person.2",
                options: store.allPeople,
                selected: store.activeFilter.people
            ) { item in
                withAnimation { store.togglePersonFilter(item) }
            }
            .frame(maxWidth: .infinity)

            FilterDropdown(
                icon: "map",
                options: store.allPlaces,
                selected: store.activeFilter.places
            ) { item in
                withAnimation { store.togglePlaceFilter(item) }
            }
            .frame(maxWidth: .infinity)

            FilterDropdown(
                icon: "heart",
                options: store.allEmotions,
                selected: store.activeFilter.emotions
            ) { item in
                withAnimation { store.toggleEmotionFilter(item) }
            }
            .frame(maxWidth: .infinity)

            FilterDropdown(
                icon: "star",
                options: store.allTags,
                selected: store.activeFilter.tags
            ) { item in
                withAnimation { store.toggleTagFilter(item) }
            }
            .frame(maxWidth: .infinity)

            if !store.activeFilter.isEmpty {
                Button("Clear", role: .destructive) {
                    withAnimation { store.clearFilter() }
                }
                .font(.subheadline.bold())
                .foregroundStyle(.red)
                .tint(.red.opacity(0.2))
                .buttonStyle(.glassProminent)
                .transition(.opacity.combined(with: .scale))
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
    }
}

struct FilterDropdown: View {
    let icon: String
    let options: [String]
    let selected: Set<String>
    let onSelect: (String) -> Void

    var body: some View {
        Menu {
            ForEach(options, id: \.self) { option in
                Button {
                    onSelect(option)
                } label: {
                    HStack {
                        Text(option.capitalized)
                        if selected.contains(option) {
                            Image(systemName: "checkmark")
                        }
                    }
                }
                .menuActionDismissBehavior(.disabled)
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                Image(systemName: "chevron.down")
            }
            .font(.subheadline.bold())
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 40)
            .glassEffect()
        }
    }
}

struct ActiveFiltersView: View {
    @ObservedObject var store: DreamStore
    var body: some View {
        FlowLayout {
            ForEach(Array(store.activeFilter.people), id: \.self) { item in RemovablePill(text: item, icon: "person.fill", color: .blue) { withAnimation { store.togglePersonFilter(item) } } }
            ForEach(Array(store.activeFilter.places), id: \.self) { item in RemovablePill(text: item, icon: "map.fill", color: .green) { withAnimation { store.togglePlaceFilter(item) } } }
            ForEach(Array(store.activeFilter.emotions), id: \.self) { item in RemovablePill(text: item, icon: "heart.fill", color: .pink) { withAnimation { store.toggleEmotionFilter(item) } } }
            ForEach(Array(store.activeFilter.tags), id: \.self) { item in RemovablePill(text: item, icon: "star.fill", color: .purple) { withAnimation { store.toggleTagFilter(item) } } }
        }
    }
}

struct RemovablePill: View {
    let text: String; let icon: String; let color: Color; let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) { Image(systemName: icon).font(.caption); Text(text.capitalized).font(.caption.bold()); Image(systemName: "xmark").font(.caption2) }
                .foregroundStyle(.white)
        }
        .buttonStyle(.glassProminent)
        .tint(color.opacity(0.3))
    }
}

struct DreamRow: View {
    let dream: Dream
    var body: some View {
        HStack(spacing: 16) {
            if let imageData = dream.generatedImageData, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage).resizable().aspectRatio(contentMode: .fill).frame(width: 50, height: 50).clipShape(RoundedRectangle(cornerRadius: 12)).overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.1)))
            } else {
                RoundedRectangle(cornerRadius: 12).fill(Color.gray.gradient).frame(width: 50, height: 50).overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.1)))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(dream.date.formatted(date: .abbreviated, time: .shortened)).font(.caption.weight(.semibold)).foregroundStyle(Color.accentColor)
                Text(dream.core?.title ?? "Processing...").font(.subheadline).foregroundStyle(.primary).lineLimit(2)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(.tertiary)
        }
        .padding(16)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20))
    }
}
