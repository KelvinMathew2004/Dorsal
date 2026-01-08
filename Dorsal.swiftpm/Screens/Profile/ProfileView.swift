import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import CoreImage

struct ProfileView: View {
    @ObservedObject var store: DreamStore
    
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedCategory: String = "People"
    @State private var showEditSheet = false
    
    @State private var showImagePlayground = false
    @State private var showPhotoPicker = false
    
    // Navigation for Entity Details
    @State private var selectedEntity: EntityIdentifier?
    
    @State private var showDeleteAlert = false
    @State private var itemToDelete: EntityIdentifier?
    
    // Drag & Drop State
    @State private var draggedItem: EntityIdentifier?
    @State private var dropTargetItem: EntityIdentifier?
    
    // Gradient State - Cached in View to persist across tab changes
    @State private var gradientColors: [Color] = ProfileView.cachedGradientColors
    static var cachedGradientColors: [Color] = []
    
    struct EntityIdentifier: Hashable, Identifiable, Codable {
        let name: String
        let type: String
        var id: String { "\(type):\(name)" }
    }
    
    @State private var editFirstName = ""
    @State private var editLastName = ""
    
    let categories = ["People", "Places", "Symbols"]
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background Layer 1: Default Theme (Always visible)
                Theme.gradientBackground.ignoresSafeArea()
                
                // Background Layer 2: Dynamic Gradient (Fades in)
                if !gradientColors.isEmpty {
                    Group {
                        MeshGradient(
                            width: 3, height: 3,
                            points: [
                                [0.0, 0.0], [0.5, 0.0], [1.0, 0.0],
                                [0.0, 0.5], [0.5, 0.5], [1.0, 0.5],
                                [0.0, 1.0], [0.5, 1.0], [1.0, 1.0]
                            ],
                            colors: [
                                gradientColors[0], gradientColors[1], gradientColors[2],
                                gradientColors[2], gradientColors[0], gradientColors[1],
                                gradientColors[1], gradientColors[2], gradientColors[0]
                            ]
                        )
                    }
                    .ignoresSafeArea()
                    .overlay(Color.black.opacity(0.6))
                    .transition(.opacity)
                }
                
                ScrollViewReader { proxy in
                    scrollableContent(proxy: proxy)
                }
            }
            .animation(.easeInOut(duration: 1.0), value: gradientColors)
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
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
            .sheet(isPresented: $showEditSheet) {
                NavigationStack {
                    Form {
                        Section {
                            HStack {
                                Spacer()
                                ZStack(alignment: .bottom) {
                                    // Profile Image
                                    if let data = store.profileImageData, let uiImage = UIImage(data: data) {
                                        Image(uiImage: uiImage)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 120, height: 120)
                                            .clipShape(Circle())
                                            .overlay(Circle().stroke(.white.opacity(0.5), lineWidth: 1))
                                    } else {
                                        ZStack {
                                            Circle()
                                                .fill(Color.white.opacity(0.1))
                                                .frame(width: 120, height: 120)
                                                .overlay(Circle().stroke(.white.opacity(0.3), lineWidth: 1))
                                            Image(systemName: "person.fill").font(.system(size: 50)).foregroundStyle(.white.opacity(0.5))
                                        }
                                    }
                                    
                                    // The Edit Pill
                                    Menu {
                                        Button { showPhotoPicker = true } label: { Label("Photo Library", systemImage: "photo") }
                                        if store.isImageGenerationAvailable {
                                            Button { showImagePlayground = true } label: { Label("Generate with AI", systemImage: "wand.and.stars") }
                                        }
                                        if store.profileImageData != nil {
                                            Button(role: .destructive) { store.profileImageData = nil } label: { Label("Remove Photo", systemImage: "trash") }
                                        }
                                    } label: {
                                        HStack(spacing: 4) {
                                            Image(systemName: "camera.fill")
                                            Text("Edit")
                                        }
                                        .font(.subheadline.bold())
                                        .foregroundStyle(.white.opacity(0.8))
                                        .padding(.vertical, 6)
                                        .padding(.horizontal, 12)
                                        .background(Color(.secondarySystemBackground).opacity(0.7))
                                        .clipShape(Capsule())
                                        .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 1))
                                    }
                                    .offset(y: 10)
                                }
                                Spacer()
                            }
                            .listRowBackground(Color.clear)
                            .padding(.bottom, 10)
                        }
                        
                        Section("Profile Details") {
                            TextField("First Name", text: $editFirstName)
                            TextField("Last Name", text: $editLastName)
                        }
                    }
                    .navigationTitle("Edit Profile")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) { Button(role: .cancel) { showEditSheet = false } }
                        ToolbarItem(placement: .confirmationAction) { Button(role: .confirm) { store.firstName = editFirstName; store.lastName = editLastName; showEditSheet = false }
                                .disabled(editFirstName.isEmpty || editLastName.isEmpty)
                        }
                    }
                }
                .presentationDetents([.medium])
                .photosPicker(isPresented: $showPhotoPicker, selection: $selectedItem, matching: .images)
                .sheet(isPresented: $showImagePlayground) {
                    ImagePlaygroundSheet(store: store, entityName: "Profile Picture", entityDescription: "A cool avatar") { data in
                        withAnimation { store.profileImageData = data }
                    }
                }
            }
            .onChange(of: selectedItem) {
                Task {
                    if let data = try? await selectedItem?.loadTransferable(type: Data.self) {
                        withAnimation { store.profileImageData = data }
                    }
                }
            }
            .onChange(of: store.profileImageData) { updateGradient() }
            .task { updateGradient() }
            .sheet(item: $selectedEntity) { entity in
                EntityDetailView(store: store, name: entity.name, type: entity.type)
                    .presentationDetents([.large])
            }
        }
    }
    
    private func updateGradient() {
        if let data = store.profileImageData, let uiImage = UIImage(data: data) {
            DispatchQueue.global(qos: .userInitiated).async {
                let color = uiImage.dominantColor
                DispatchQueue.main.async {
                    let newColors = [color, color.opacity(0.8), color.opacity(0.6)]
                    self.gradientColors = newColors
                    ProfileView.cachedGradientColors = newColors
                }
            }
        } else {
            self.gradientColors = []
            ProfileView.cachedGradientColors = []
        }
    }
    
    // MARK: - Extracted Scroll Content
    @ViewBuilder
    private func scrollableContent(proxy: ScrollViewProxy) -> some View {
        ScrollView {
            VStack(spacing: 40) {
                // MARK: - Header
                headerView.id("top")
                
                // MARK: - Stats
                statsRow
                
                // MARK: - Category Filter & List
                categorySection(proxy: proxy)
            }
            .padding(.bottom, 100)
        }
        .coordinateSpace(name: "scroll")
        // Global Drop Zone for Unlinking (dropping outside list items)
        .onDrop(of: [UTType.text], delegate: RootDropDelegate(draggedItem: $draggedItem, store: store))
        
        // MARK: - Global Dialogs
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
    }
    
    // MARK: - Subviews
    
    private var headerView: some View {
        HStack {
            Spacer(minLength: 0)
            HStack(spacing: 24) {
                // Just Display Image, No Action
                if let data = store.profileImageData, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 90, height: 90)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(.white.opacity(0.3), lineWidth: 2))
                        .shadow(color: .black.opacity(0.3), radius: 10)
                } else {
                    ZStack {
                        Image(systemName: "person.fill")
                            .font(.system(size: 35))
                            .frame(width: 90, height: 90)
                            .foregroundStyle(.white.opacity(0.5))
                            .glassEffect(.clear, in: Circle())
                    }
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(store.firstName).font(.system(size: 28, weight: .bold)).foregroundStyle(.white)
                    Text(store.lastName).font(.system(size: 20, weight: .medium)).foregroundStyle(Theme.secondary)
                }
                .frame(width: 120, alignment: .leading)
            }
            Spacer(minLength: 0)
        }
        .padding(.top, 40)
    }
    
    private var statsRow: some View {
        HStack(spacing: 6) {
            ContinuousStatBlock(title: "Streak", value: "\(store.currentStreak)", icon: "flame.fill", color: .orange, corners: [.topLeft, .bottomLeft])
            ContinuousStatBlock(title: "Dreams", value: "\(store.dreams.count)", icon: "moon.fill", color: .purple, corners: [])
            ContinuousStatBlock(title: "Places", value: "\(store.allPlaces.count)", icon: "map.fill", color: .green, corners: [])
            ContinuousStatBlock(title: "People", value: "\(store.allPeople.count)", icon: "person.2.fill", color: .blue, corners: [.topRight, .bottomRight])
        }
        .padding(.horizontal)
    }
    
    private func categorySection(proxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Picker("Category", selection: $selectedCategory) {
                ForEach(categories, id: \.self) { cat in
                    Text(cat).tag(cat)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            
            LazyVStack(spacing: 0) {
                ForEach(itemsForCategory, id: \.self) { item in
                    let itemIdentifier = EntityIdentifier(name: item, type: filterTypeForCategory)
                    let children = store.getChildren(for: item, type: filterTypeForCategory)
                    let hasChildren = !children.isEmpty
                    
                    VStack(spacing: 0) {
                        // Parent Item Row Container
                        HStack(spacing: 16) {
                            // Navigation Button (Left Side)
                            Button {
                                selectedEntity = itemIdentifier
                            } label: {
                                HStack(spacing: 16) {
                                    EntityListImage(store: store, name: itemIdentifier.name, type: itemIdentifier.type, icon: iconForCategory)
                                    
                                    Text(itemIdentifier.name.capitalized)
                                        .font(.body.weight(.medium))
                                        .foregroundStyle(.white)
                                    
                                    Spacer()
                                }
                                .contentShape(Rectangle()) // Ensures the whole area is tappable for navigation
                            }
                            .buttonStyle(.plain) // Prevents button styling from interfering with the menu
                            
                            // Parent Options Menu (Right Side - Actual Button)
                            Menu {
                                Button {
                                    selectedEntity = itemIdentifier
                                } label: {
                                    Label("View Details", systemImage: "info")
                                }
                                
                                Button {
                                    store.jumpToFilter(type: itemIdentifier.type, value: itemIdentifier.name)
                                } label: {
                                    Label("Filter Dreams", systemImage: "line.3.horizontal.decrease")
                                }
                                
                                Button(role: .destructive) {
                                    itemToDelete = itemIdentifier
                                    showDeleteAlert = true
                                } label: {
                                    Label("Delete Details", systemImage: "trash")
                                }
                            } label: {
                                Image(systemName: "ellipsis")
                                    .foregroundStyle(Theme.secondary)
                                    .font(.title2)
                                    .padding()
                            }
                        }
                        .padding()
                        .glassEffect(.clear.interactive(), in: Capsule())
                        .overlay(
                            Capsule()
                                .stroke(dropTargetItem?.name == item ? Theme.accent.opacity(0.8) : Color.clear, lineWidth: 3)
                        )
                        .padding(.vertical, 8)
                        .padding(.horizontal)
                        // Drag conditional: Only draggable if it DOES NOT have children
                        .draggableIf(!hasChildren) {
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
                        
                        ForEach(children, id: \.id) { child in
                            let childIdentifier = EntityIdentifier(name: child.name, type: child.type)
                            
                            // Child Row Container
                            HStack(spacing: 16) {
                                // Navigation Button (Left Side)
                                Button {
                                    selectedEntity = itemIdentifier // Clicking child goes to parent (as per logic)
                                } label: {
                                    HStack(spacing: 16) {
                                        Image(systemName: "arrow.turn.down.right")
                                            .font(.system(size: 20, weight: .regular))
                                            .foregroundStyle(.white.opacity(0.3))
                                            .frame(width: 40, height: 40)
                                        
                                        Text(child.name.capitalized)
                                            .font(.body.weight(.medium))
                                            .foregroundStyle(.white)
                                        
                                        Spacer()
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                
                                // Child Options Menu (Right Side - Actual Button)
                                Menu {
                                    // Option to view details (Parent)
                                    Button {
                                        selectedEntity = itemIdentifier
                                    } label: {
                                        Label("View Details", systemImage: "info")
                                    }
                                    
                                    // Option to filter by PARENT
                                    Button {
                                        store.jumpToFilter(type: itemIdentifier.type, value: itemIdentifier.name)
                                    } label: {
                                        Label("Filter Dreams", systemImage: "line.3.horizontal.decrease")
                                    }
                                    
                                    Button(role: .destructive) {
                                        withAnimation {
                                            store.unlinkEntity(name: child.name, type: child.type)
                                        }
                                    } label: {
                                        Label("Unlink", systemImage: "personalhotspot.slash")
                                    }
                                } label: {
                                    Image(systemName: "ellipsis")
                                        .foregroundStyle(Theme.secondary)
                                        .font(.title2)
                                        .padding()
                                }
                            }
                            .padding()
                            .glassEffect(.clear.interactive(), in: Capsule())
                            .padding(.vertical, 8)
                            .padding(.horizontal)
                            // Drag conditional for children
                            .draggableIf(true) {
                                self.draggedItem = childIdentifier
                                return NSItemProvider(object: child.name as NSString)
                            }
                            .onDrop(of: [UTType.text], delegate: ChildDropDelegate())
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Computed Props
    
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

// MARK: - Helper Views & Extensions

extension View {
    @ViewBuilder
    func draggableIf(_ condition: Bool, _ payload: @escaping () -> NSItemProvider) -> some View {
        if condition {
            self.onDrag(payload)
        } else {
            self
        }
    }
}

struct EntityListImage: View {
    @ObservedObject var store: DreamStore
    let name: String
    let type: String
    let icon: String
    
    var forceUpdate: Int { store.entityUpdateTrigger }
    var imageData: Data? { _ = forceUpdate; return store.getEntity(name: name, type: type)?.imageData }
    
    var body: some View {
        if let data = imageData, let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable().aspectRatio(contentMode: .fill).frame(width: 40, height: 40)
                .clipShape(Circle()).overlay(Circle().stroke(.white.opacity(0.3), lineWidth: 1))
        } else {
            Image(systemName: icon).foregroundStyle(.white.opacity(0.7)).frame(width: 40, height: 40)
                .background(Circle().fill(.white.opacity(0.1)))
                .overlay(Circle().stroke(.white.opacity(0.2), lineWidth: 1))
        }
    }
}

// MARK: - Drop Delegates

struct RootDropDelegate: DropDelegate {
    @Binding var draggedItem: ProfileView.EntityIdentifier?
    let store: DreamStore
    
    func dropUpdated(info: DropInfo) -> DropProposal {
        guard let dragged = draggedItem else { return DropProposal(operation: .cancel) }
        
        // Check if the dragged item is currently a child of someone
        if let entity = store.getEntity(name: dragged.name, type: dragged.type), entity.parentID != nil {
            // It's a child, so dropping it on root means unlinking (returning to parent/root level)
            return DropProposal(operation: .move)
        }
        
        // If it's already a root item, we don't do anything
        return DropProposal(operation: .forbidden)
    }
    
    func performDrop(info: DropInfo) -> Bool {
        guard let dragged = draggedItem else { return false }
        
        // Perform unlink if it was a child
        if let entity = store.getEntity(name: dragged.name, type: dragged.type), entity.parentID != nil {
            withAnimation { store.unlinkEntity(name: dragged.name, type: dragged.type) }
            draggedItem = nil
            return true
        }
        
        draggedItem = nil
        return false
    }
    
    func dropProposal(operations: DropOperation, session: DropSession, destinationLocation: CGPoint) -> DropProposal? {
        return DropProposal(operation: .move)
    }
}

struct EntityDropDelegate: DropDelegate {
    let item: ProfileView.EntityIdentifier
    @Binding var draggedItem: ProfileView.EntityIdentifier?
    @Binding var dropTargetItem: ProfileView.EntityIdentifier?
    let store: DreamStore
    let scrollViewProxy: ScrollViewProxy
    
    func dropEntered(info: DropInfo) {
        guard let dragged = draggedItem, dragged.id != item.id else { return }
        
        // 1. Forbidden if dragged item is a parent (has children)
        if !store.getChildren(for: dragged.name, type: dragged.type).isEmpty {
            return
        }
        
        // 2. Forbidden if dragging over own parent
        if let childEntity = store.getEntity(name: dragged.name, type: dragged.type),
           childEntity.parentID == item.id {
            return
        }
        
        // If passed checks, it's a valid target
        withAnimation { dropTargetItem = item }
    }
    
    func dropExited(info: DropInfo) {
        if dropTargetItem?.id == item.id {
            withAnimation { dropTargetItem = nil }
        }
    }
    
    func dropUpdated(info: DropInfo) -> DropProposal {
        // ... scroll handling ...
        
        guard let dragged = draggedItem, dragged.id != item.id else {
            // Not dragging anything valid, clear target if it was us
            if dropTargetItem?.id == item.id {
                DispatchQueue.main.async {
                    withAnimation { dropTargetItem = nil }
                }
            }
            return DropProposal(operation: .cancel)
        }
        
        // Validate drop target
        let isValid = store.getChildren(for: dragged.name, type: dragged.type).isEmpty &&
                      !(store.getEntity(name: dragged.name, type: dragged.type)?.parentID == item.id)
        
        if isValid && dropTargetItem?.id == item.id {
            return DropProposal(operation: .copy)
        } else {
            // Clear highlighting if we're no longer valid or not over this item
            if dropTargetItem?.id == item.id {
                DispatchQueue.main.async {
                    withAnimation { dropTargetItem = nil }
                }
            }
            return DropProposal(operation: .forbidden)
        }
    }
    
    func performDrop(info: DropInfo) -> Bool {
        guard let dragged = draggedItem, dragged.id != item.id else { return false }
        
        // Double check validations
        if !store.getChildren(for: dragged.name, type: dragged.type).isEmpty { return false }
        if let childEntity = store.getEntity(name: dragged.name, type: dragged.type), childEntity.parentID == item.id { return false }

        withAnimation {
            store.linkEntity(childName: dragged.name, childType: dragged.type, parentName: item.name, parentType: item.type)
        }
        
        draggedItem = nil
        dropTargetItem = nil
        return true
    }
}

struct ChildDropDelegate: DropDelegate {
    func performDrop(info: DropInfo) -> Bool { return false }
    func dropUpdated(info: DropInfo) -> DropProposal { return DropProposal(operation: .forbidden) }
}

struct ContinuousStatBlock: View {
    let title: String; let value: String; let icon: String; let color: Color; let corners: UIRectCorner
    var body: some View {
        ZStack {
            Image(systemName: icon).font(.system(size: 50)).foregroundStyle(color.opacity(0.15))
            VStack(spacing: 2) {
                Text(value).font(.system(size: 24, weight: .bold, design: .rounded)).foregroundStyle(.white).minimumScaleFactor(0.8).lineLimit(1)
                Text(title.uppercased()).font(.system(size: 10, weight: .bold)).foregroundStyle(.white.opacity(0.6)).tracking(0.5)
            }.padding(.vertical, 24)
        }.frame(maxWidth: .infinity).frame(height: 100).glassEffect(.clear.tint(color.opacity(0.15)), in: CustomCorner(corners: corners, radius: 20))
    }
}

struct CustomCorner: Shape {
    var corners: UIRectCorner; var radius: CGFloat
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}
