import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct ProfileView: View {
    @ObservedObject var store: DreamStore
    
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedCategory: String = "People"
    @State private var showEditSheet = false
    
    // Profile Picture Action Sheet
    @State private var showProfilePicOptions = false
    @State private var showImagePlayground = false
    @State private var showPhotoPicker = false
    
    // Navigation for Entity Details
    @State private var selectedEntity: EntityIdentifier?
    // We use a separate state map or binding logic for dialogs to attach them to specific buttons
    // However, for list items, we can track the "active" item for action sheet.
    @State private var activeActionSheetItem: EntityIdentifier?
    
    @State private var showDeleteAlert = false
    @State private var itemToDelete: EntityIdentifier?
    
    // Drag & Drop State
    @State private var draggedItem: EntityIdentifier?
    @State private var dropTargetItem: EntityIdentifier?
    @State private var isTargeted = false
    
    struct EntityIdentifier: Hashable, Identifiable, Codable {
        let name: String
        let type: String
        var id: String { "\(type):\(name)" }
    }
    
    // Temporary state for the sheet editing
    @State private var editFirstName = ""
    @State private var editLastName = ""
    
    let categories = ["People", "Places", "Symbols"]
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.gradientBackground.ignoresSafeArea()
                
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 40) {
                            
                            // MARK: - Header (Photo + Names)
                            HStack {
                                Spacer(minLength: 0)
                                
                                HStack(spacing: 24) {
                                    // Profile Picture
                                    Button {
                                        showProfilePicOptions = true
                                    } label: {
                                        if let data = store.profileImageData,
                                           let uiImage = UIImage(data: data) {
                                            Image(uiImage: uiImage)
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .frame(width: 90, height: 90)
                                                .clipShape(Circle())
                                                .overlay(
                                                    Circle()
                                                        .stroke(.white.opacity(0.3), lineWidth: 2)
                                                )
                                                .shadow(color: .black.opacity(0.3), radius: 10)
                                        } else {
                                            ZStack {
                                                Circle()
                                                    .fill(.white.opacity(0.1))
                                                    .frame(width: 90, height: 90)
                                                    .overlay(
                                                        Circle()
                                                            .stroke(.white.opacity(0.2), lineWidth: 2)
                                                    )
                                                
                                                Image(systemName: "person.fill")
                                                    .font(.system(size: 35))
                                                    .foregroundStyle(.white.opacity(0.5))
                                            }
                                        }
                                    }
                                    .confirmationDialog("Profile Picture", isPresented: $showProfilePicOptions) {
                                        Button("Photo Library") { showPhotoPicker = true }
                                        
                                        // Only show Image Playground if supported
                                        if store.isImageGenerationAvailable {
                                            Button("Create with Image Playground") { showImagePlayground = true }
                                        }
                                        
                                        if store.profileImageData != nil {
                                            Button("Remove Image", role: .destructive) {
                                                store.profileImageData = nil
                                            }
                                        }
                                        Button("Cancel", role: .cancel) { }
                                    }
                                    
                                    // Names (Display Only)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(store.firstName)
                                            .font(.system(size: 28, weight: .bold))
                                            .foregroundStyle(.white)
                                        
                                        Text(store.lastName)
                                            .font(.system(size: 20, weight: .medium))
                                            .foregroundStyle(.secondary)
                                    }
                                    .frame(width: 120, alignment: .leading)
                                }
                                
                                Spacer(minLength: 0)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                            .id("top")
                            
                            // MARK: - Single Line Stats Row
                            HStack(spacing: 6) {
                                // Block 1: Streak (Rounded Left)
                                ContinuousStatBlock(
                                    title: "Streak",
                                    value: "\(store.currentStreak)",
                                    icon: "flame.fill",
                                    color: .orange,
                                    corners: [.topLeft, .bottomLeft]
                                )
                                
                                // Block 2: Dreams (No Rounding)
                                ContinuousStatBlock(
                                    title: "Dreams",
                                    value: "\(store.dreams.count)",
                                    icon: "moon.fill",
                                    color: .purple,
                                    corners: []
                                )
                                
                                // Block 3: Places (No Rounding)
                                ContinuousStatBlock(
                                    title: "Places",
                                    value: "\(store.allPlaces.count)",
                                    icon: "map.fill",
                                    color: .green,
                                    corners: []
                                )
                                
                                // Block 4: People (Rounded Right)
                                ContinuousStatBlock(
                                    title: "People",
                                    value: "\(store.allPeople.count)",
                                    icon: "person.2.fill",
                                    color: .blue,
                                    corners: [.topRight, .bottomRight]
                                )
                            }
                            .padding(.horizontal)
                            
                            // MARK: - Category Filter
                            VStack(alignment: .leading, spacing: 16) {
                                Picker("Category", selection: $selectedCategory) {
                                    ForEach(categories, id: \.self) { cat in
                                        Text(cat).tag(cat)
                                    }
                                }
                                .pickerStyle(.segmented)
                                .padding(.horizontal)
                                
                                // List items based on category
                                LazyVStack(spacing: 12) {
                                    ForEach(itemsForCategory, id: \.self) { item in
                                        let itemIdentifier = EntityIdentifier(name: item, type: filterTypeForCategory)
                                        let children = store.getChildren(for: item, type: filterTypeForCategory)
                                        let isParent = !children.isEmpty
                                        
                                        // Use same spacing as LazyVStack (12) so children look uniform with parents
                                        VStack(spacing: 12) {
                                            // Parent Item
                                            EntityRowView(
                                                store: store,
                                                identifier: itemIdentifier,
                                                iconCategory: iconForCategory,
                                                isActive: activeActionSheetItem?.name == item,
                                                onTap: {
                                                    activeActionSheetItem = itemIdentifier
                                                },
                                                isDropTarget: dropTargetItem?.name == item,
                                                onDelete: {
                                                    itemToDelete = itemIdentifier
                                                    showDeleteAlert = true
                                                },
                                                onViewDetails: {
                                                    selectedEntity = itemIdentifier
                                                },
                                                onFilter: {
                                                    store.jumpToFilter(type: itemIdentifier.type, value: itemIdentifier.name)
                                                }
                                            )
                                            .onDrag {
                                                // Disable dragging if it's a parent
                                                if isParent {
                                                    return NSItemProvider()
                                                }
                                                self.draggedItem = itemIdentifier
                                                return NSItemProvider(object: item as NSString)
                                            }
                                            .onDrop(of: [UTType.text], delegate: EntityDropDelegate(
                                                item: itemIdentifier,
                                                draggedItem: $draggedItem,
                                                dropTargetItem: $dropTargetItem,
                                                store: store,
                                                scrollViewProxy: proxy
                                            ))
                                            
                                            // Children
                                            ForEach(children, id: \.id) { child in
                                                let childIdentifier = EntityIdentifier(name: child.name, type: child.type)
                                                
                                                HStack(spacing: 16) {
                                                    // "L" Arrow visual
                                                    Image(systemName: "arrow.turn.down.right")
                                                        .font(.system(size: 20, weight: .regular))
                                                        .foregroundStyle(.white.opacity(0.3))
                                                        .frame(width: 40, height: 40)
                                                    
                                                    Text(child.name.capitalized)
                                                        .font(.body.weight(.medium))
                                                        .foregroundStyle(.white.opacity(0.8))
                                                    
                                                    Spacer()
                                                    
                                                    // Unlink / Delete Button (Replaces Swipe Actions which require List)
                                                    Button(role: .destructive) {
                                                        withAnimation {
                                                            store.unlinkEntity(name: child.name, type: child.type)
                                                        }
                                                    } label: {
                                                        Image(systemName: "trash")
                                                            .font(.system(size: 16, weight: .semibold))
                                                            .foregroundStyle(.red.opacity(0.8))
                                                            .padding(8)
                                                            .background(Color.red.opacity(0.1))
                                                            .clipShape(Circle())
                                                    }
                                                }
                                                .padding()
                                                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
                                                // Context Menu for alternative unlink access
                                                .contextMenu {
                                                    Button(role: .destructive) {
                                                        withAnimation {
                                                            store.unlinkEntity(name: child.name, type: child.type)
                                                        }
                                                    } label: {
                                                        Label("Unlink (Remove from Parent)", systemImage: "link.badge.minus")
                                                    }
                                                }
                                                // Make children not interactive for details, but enable dragging
                                                .onDrag {
                                                    self.draggedItem = childIdentifier
                                                    return NSItemProvider(object: child.name as NSString)
                                                }
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal)
                                // Make the background hit-testable for drops between items
                                .background(Color.white.opacity(0.001))
                                .onDrop(of: [UTType.text], delegate: RootDropDelegate(
                                    draggedItem: $draggedItem,
                                    store: store
                                ))
                            }
                        }
                        .padding(.bottom, 100)
                    }
                    .coordinateSpace(name: "scroll")
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(item: $selectedEntity) { entity in
                EntityDetailView(store: store, name: entity.name, type: entity.type)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        editFirstName = store.firstName
                        editLastName = store.lastName
                        showEditSheet = true
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                }
            }
            // Alert for Delete Confirmation (Global to view, triggered by list action)
            .alert("Delete Details?", isPresented: $showDeleteAlert) {
                Button("Delete", role: .destructive) {
                    if let entity = itemToDelete {
                        withAnimation {
                            store.deleteEntity(name: entity.name, type: entity.type)
                        }
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will remove the custom image and description. The item will remain in your list as long as it appears in your dreams.")
            }
            // Edit Profile Sheet
            .sheet(isPresented: $showEditSheet) {
                NavigationStack {
                    Form {
                        Section("Profile Details") {
                            TextField("First Name", text: $editFirstName)
                            TextField("Last Name", text: $editLastName)
                        }
                    }
                    .navigationTitle("Edit Profile")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button(role: .cancel) { showEditSheet = false }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button(role: .confirm) {
                                store.firstName = editFirstName
                                store.lastName = editLastName
                                showEditSheet = false
                            }
                        }
                    }
                }
                .presentationDetents([.medium])
            }
            // Image Playground for Profile Pic
            .sheet(isPresented: $showImagePlayground) {
                ImagePlaygroundSheet(store: store, entityName: "Profile Picture", entityDescription: "A cool avatar") { data in
                    withAnimation { store.profileImageData = data }
                }
            }
            // Photo Picker for Profile Pic
            .photosPicker(isPresented: $showPhotoPicker, selection: $selectedItem, matching: .images)
            .onChange(of: selectedItem) {
                Task {
                    if let data = try? await selectedItem?.loadTransferable(type: Data.self) {
                        withAnimation { store.profileImageData = data }
                    }
                }
            }
        }
    }
    
    var itemsForCategory: [String] {
        switch selectedCategory {
        case "People": return store.allPeople
        case "Places": return store.allPlaces
        case "Symbols": return store.allTags
        default: return []
        }
    }
    
    var filterTypeForCategory: String {
        switch selectedCategory {
        case "People": return "person"
        case "Places": return "place"
        case "Symbols": return "tag"
        default: return ""
        }
    }
    
    var iconForCategory: String {
        switch selectedCategory {
        case "People": return "person.fill"
        case "Places": return "map.fill"
        case "Symbols": return "star.fill"
        default: return "circle.fill"
        }
    }
}

// Extracted Subview for cleaner code and better state management of the sheet binding
struct EntityRowView: View {
    @ObservedObject var store: DreamStore
    let identifier: ProfileView.EntityIdentifier
    let iconCategory: String
    let isActive: Bool
    let onTap: () -> Void
    let isDropTarget: Bool
    
    let onDelete: () -> Void
    let onViewDetails: () -> Void
    let onFilter: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Entity Image or Icon
                EntityListImage(store: store, name: identifier.name, type: identifier.type, icon: iconCategory)
                
                Text(identifier.name.capitalized)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.white)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundStyle(.white.opacity(0.3))
            }
            .padding()
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isDropTarget ? Color.white.opacity(0.8) : Color.clear, lineWidth: 4)
            )
        }
        .confirmationDialog(
            "Options",
            isPresented: Binding(
                get: { isActive },
                set: { if !$0 { onTap() } } // This logic handles dismissal, tapping again toggles in parent logic
            )
        ) {
            Button("View Details", action: onViewDetails)
            Button("Filter Dreams", action: onFilter)
            Button("Delete Details", role: .destructive, action: onDelete)
            Button("Cancel", role: .cancel) { }
        }
    }
}

// MARK: - Drop Delegates

struct RootDropDelegate: DropDelegate {
    @Binding var draggedItem: ProfileView.EntityIdentifier?
    let store: DreamStore
    
    func performDrop(info: DropInfo) -> Bool {
        guard let dragged = draggedItem else { return false }
        
        // If we reached here, it means we dropped on the background/root list
        // and NOT on a specific item (since specific item delegate would have handled it if valid)
        // So this is an "unlink" action.
        
        withAnimation {
            store.unlinkEntity(name: dragged.name, type: dragged.type)
        }
        
        draggedItem = nil
        return true
    }
    
    // We allow drop always, so user can drop "anywhere else" to unlink
    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .move)
    }
}

struct EntityDropDelegate: DropDelegate {
    let item: ProfileView.EntityIdentifier
    @Binding var draggedItem: ProfileView.EntityIdentifier?
    @Binding var dropTargetItem: ProfileView.EntityIdentifier?
    let store: DreamStore
    let scrollViewProxy: ScrollViewProxy
    
    func performDrop(info: DropInfo) -> Bool {
        guard let dragged = draggedItem, dragged.id != item.id else { return false }
        
        // Ensure not linking circular or invalid types (handled in store, but good to check)
        withAnimation {
            store.linkEntity(
                childName: dragged.name,
                childType: dragged.type,
                parentName: item.name,
                parentType: item.type
            )
        }
        
        // Reset state
        self.draggedItem = nil
        self.dropTargetItem = nil
        return true
    }
    
    func dropEntered(info: DropInfo) {
        guard let dragged = draggedItem, dragged.id != item.id else { return }
        
        // Circular check is done in store, but visually we allow target
        withAnimation {
            dropTargetItem = item
        }
    }
    
    func dropUpdated(info: DropInfo) -> DropProposal? {
        // Auto-Scroll Logic with Haptics
        let location = info.location.y
        let topThreshold: CGFloat = 100
        
        // We use a global coordinate check if possible, but location is relative to the view usually.
        // Assuming the view is near screen size, < 100 is top.
        
        if location < topThreshold {
             // Scroll up
            DispatchQueue.main.async {
                withAnimation {
                    scrollViewProxy.scrollTo("top", anchor: .top)
                }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
        }
        
        return DropProposal(operation: .move)
    }
    
    func dropExited(info: DropInfo) {
        if dropTargetItem?.id == item.id {
            withAnimation {
                dropTargetItem = nil
            }
        }
    }
}

struct EntityListImage: View {
    @ObservedObject var store: DreamStore
    let name: String
    let type: String
    let icon: String
    
    // We observe this purely to force a redraw when store.entityUpdateTrigger changes
    var forceUpdate: Int { store.entityUpdateTrigger }
    
    // Fetch image from store based on composite ID
    var imageData: Data? {
        // Accessing property to establish dependency
        _ = forceUpdate
        return store.getEntity(name: name, type: type)?.imageData
    }
    
    var body: some View {
        if let data = imageData, let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 40, height: 40)
                .clipShape(Circle())
                .overlay(Circle().stroke(.white.opacity(0.3), lineWidth: 1))
        } else {
            Image(systemName: icon)
                .foregroundStyle(.white.opacity(0.7))
                .frame(width: 40, height: 40)
                .background(Circle().fill(.white.opacity(0.1)))
        }
    }
}

// Custom Continuous Stat Block
struct ContinuousStatBlock: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let corners: UIRectCorner
    
    var body: some View {
        ZStack {
            ZStack {
                Image(systemName: icon)
                    .font(.system(size: 50))
                    .foregroundStyle(color.opacity(0.15))
            }
            
            // Foreground Content: Centered Text
            VStack(spacing: 2) {
                Text(value)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.8) // Allow shrinking if number is huge
                    .lineLimit(1)
                
                Text(title.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white.opacity(0.6))
                    .tracking(0.5)
            }
            .padding(.vertical, 24)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 100)
        .glassEffect(.clear.tint(color.opacity(0.15)), in: CustomCorner(corners: corners, radius: 20))
    }
}

// Helper for custom corners
struct CustomCorner: Shape {
    var corners: UIRectCorner
    var radius: CGFloat
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}
