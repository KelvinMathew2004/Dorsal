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
    // Tracks which specific item currently has its menu open
    @State private var activeActionSheetItem: EntityIdentifier?
    
    @State private var showDeleteAlert = false
    @State private var itemToDelete: EntityIdentifier?
    
    // Drag & Drop State
    @State private var draggedItem: EntityIdentifier?
    @State private var dropTargetItem: EntityIdentifier?
    
    // Swipe Action State (ID of the item currently swiped open)
    @State private var openSwipeItemID: String?
    
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
                Theme.gradientBackground.ignoresSafeArea()
                
                ScrollViewReader { proxy in
                    scrollableContent(proxy: proxy)
                        .simultaneousGesture(
                            TapGesture().onEnded {
                                withAnimation { openSwipeItemID = nil }
                            }
                        )
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
            .sheet(isPresented: $showEditSheet) {
                NavigationStack {
                    Form {
                        Section("Profile Details") {
                            TextField("First Name", text: $editFirstName)
                            TextField("Last Name", text: $editLastName)
                        }
                    }
                    .navigationTitle("Edit Profile")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) { Button(role: .cancel) { showEditSheet = false } }
                        ToolbarItem(placement: .confirmationAction) { Button(role: .confirm) { store.firstName = editFirstName; store.lastName = editLastName; showEditSheet = false } }
                    }
                }
                .presentationDetents([.medium])
            }
            .sheet(isPresented: $showImagePlayground) {
                ImagePlaygroundSheet(store: store, entityName: "Profile Picture", entityDescription: "A cool avatar") { data in
                    withAnimation { store.profileImageData = data }
                }
            }
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
        .confirmationDialog("Options", isPresented: Binding(
            get: { activeActionSheetItem != nil },
            set: { if !$0 { activeActionSheetItem = nil } }
        )) {
            if let item = activeActionSheetItem {
                Button("View Details") {
                    selectedEntity = item
                }
                Button("Filter Dreams") {
                    store.jumpToFilter(type: item.type, value: item.name)
                }
                Button("Delete Details", role: .destructive) {
                    itemToDelete = item
                    showDeleteAlert = true
                }
                Button("Cancel", role: .cancel) { }
            }
        }
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
        .confirmationDialog("Profile Picture", isPresented: $showProfilePicOptions) {
            Button("Photo Library") { showPhotoPicker = true }
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
    }
    
    // MARK: - Subviews
    
    private var headerView: some View {
        HStack {
            Spacer(minLength: 0)
            HStack(spacing: 24) {
                Button {
                    showProfilePicOptions = true
                } label: {
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
                            Circle().fill(.white.opacity(0.1)).frame(width: 90, height: 90)
                                .overlay(Circle().stroke(.white.opacity(0.2), lineWidth: 2))
                            Image(systemName: "person.fill").font(.system(size: 35)).foregroundStyle(.white.opacity(0.5))
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(store.firstName).font(.system(size: 28, weight: .bold)).foregroundStyle(.white)
                    Text(store.lastName).font(.system(size: 20, weight: .medium)).foregroundStyle(.secondary)
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
            
            LazyVStack(spacing: 0) { // Zero spacing to allow dividers to look connected
                ForEach(itemsForCategory, id: \.self) { item in
                    let itemIdentifier = EntityIdentifier(name: item, type: filterTypeForCategory)
                    let children = store.getChildren(for: item, type: filterTypeForCategory)
                    let isParent = !children.isEmpty
                    
                    VStack(spacing: 0) {
                        // Parent Item
                        EntityRowView(
                            store: store,
                            identifier: itemIdentifier,
                            iconCategory: iconForCategory,
                            onTap: { activeActionSheetItem = itemIdentifier },
                            isDropTarget: dropTargetItem?.name == item,
                            onViewDetails: { selectedEntity = itemIdentifier },
                            onFilter: { store.jumpToFilter(type: itemIdentifier.type, value: itemIdentifier.name) },
                            onDelete: { itemToDelete = itemIdentifier; showDeleteAlert = true }
                        )
                        .padding(.vertical, 8)
                        .padding(.horizontal)
                        .onDrag {
                            // If parent has children, prevent dragging
                            if isParent { return NSItemProvider() }
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
                            
                            SwipeActionRow(
                                id: childIdentifier.id,
                                openID: $openSwipeItemID,
                                actionIcon: "link",
                                actionVariant: .slash,
                                actionColor: .orange,
                                onAction: {
                                    withAnimation {
                                        store.unlinkEntity(name: child.name, type: child.type)
                                    }
                                }
                            ) {
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
                                .padding()
                                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal)
                            .contextMenu {
                                Button(role: .destructive) {
                                    withAnimation {
                                        store.unlinkEntity(name: child.name, type: child.type)
                                    }
                                } label: {
                                    Label("Unlink", systemImage: "link")
                                        .symbolVariant(.slash)
                                }
                            }
                            .onDrag {
                                self.draggedItem = childIdentifier
                                return NSItemProvider(object: child.name as NSString)
                            }
                            // Child Drop Delegate: Consumes drop to prevent unlinking when dropped on self/siblings
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

// MARK: - Helper Views

struct SwipeActionRow<Content: View>: View {
    let id: String
    @Binding var openID: String?
    let actionIcon: String
    var actionVariant: SymbolVariants = .none
    let actionColor: Color
    let onAction: () -> Void
    let content: Content
    
    @State private var offset: CGFloat = 0
    
    init(id: String, openID: Binding<String?>, actionIcon: String, actionVariant: SymbolVariants = .none, actionColor: Color, onAction: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.id = id
        self._openID = openID
        self.actionIcon = actionIcon
        self.actionVariant = actionVariant
        self.actionColor = actionColor
        self.onAction = onAction
        self.content = content()
    }
    
    var body: some View {
        ZStack(alignment: .trailing) {
            Button(action: {
                withAnimation {
                    openID = nil
                    offset = 0
                }
                onAction()
            }) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12).fill(actionColor)
                    Image(systemName: actionIcon)
                        .symbolVariant(actionVariant)
                        .font(.title3)
                        .foregroundStyle(.white)
                }
                .frame(width: 80)
            }
            .opacity(offset < -10 ? 1 : 0)
            
            content
                .background(Color.clear) // Transparent to show gradient if needed, relying on button opacity
                .cornerRadius(12)
                .offset(x: offset)
                .gesture(
                    DragGesture(minimumDistance: 20, coordinateSpace: .local)
                        .onChanged { value in
                            // Only allow left swipe
                            if value.translation.width < 0 { offset = value.translation.width }
                        }
                        .onEnded { value in
                            withAnimation(.spring()) {
                                if value.translation.width < -50 {
                                    offset = -80
                                    openID = id
                                } else {
                                    offset = 0
                                    openID = nil
                                }
                            }
                        }
                )
                .onChange(of: openID) { newValue in
                    // If another row is opened (newValue != id) or everything closed (nil), close this one
                    if newValue != id && offset != 0 {
                        withAnimation { offset = 0 }
                    }
                }
        }
    }
}

struct EntityRowView: View {
    @ObservedObject var store: DreamStore
    let identifier: ProfileView.EntityIdentifier
    let iconCategory: String
    let onTap: () -> Void
    let isDropTarget: Bool
    
    var onViewDetails: (() -> Void)?
    var onFilter: (() -> Void)?
    var onDelete: (() -> Void)?
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
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
                    .stroke(isDropTarget ? Color.accentColor.opacity(0.8) : Color.clear, lineWidth: 3)
            )
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
        }
    }
}

// MARK: - Drop Delegates

struct RootDropDelegate: DropDelegate {
    @Binding var draggedItem: ProfileView.EntityIdentifier?
    let store: DreamStore
    
    func dropUpdated(info: DropInfo) -> DropProposal {
        // Drop on background = Move/Unlink
        return DropProposal(operation: .move)
    }
    
    func performDrop(info: DropInfo) -> Bool {
        guard let dragged = draggedItem else { return false }
        // Dropping on the background/root list -> Unlink (Move to top level)
        withAnimation { store.unlinkEntity(name: dragged.name, type: dragged.type) }
        draggedItem = nil
        return true
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
        
        // Prevent highlighting if dragged item is already a child of this parent
        if let childEntity = store.getEntity(name: dragged.name, type: dragged.type),
           childEntity.parentID == item.id {
            return
        }
        withAnimation { dropTargetItem = item }
    }
    
    func dropExited(info: DropInfo) {
        if dropTargetItem?.id == item.id {
            withAnimation { dropTargetItem = nil }
        }
    }
    
    func dropUpdated(info: DropInfo) -> DropProposal {
        if info.location.y < 100 {
            DispatchQueue.main.async { withAnimation { scrollViewProxy.scrollTo("top", anchor: .top) } }
        }
        
        // Return .copy (Plus) if valid link, else .forbidden or .move
        if let dragged = draggedItem,
           let childEntity = store.getEntity(name: dragged.name, type: dragged.type),
           childEntity.parentID == item.id {
             return DropProposal(operation: .forbidden) // Already linked
        }
        return DropProposal(operation: .copy)
    }
    
    func performDrop(info: DropInfo) -> Bool {
        guard let dragged = draggedItem, dragged.id != item.id else { return false }
        
        // Link logic: Make dragged item a child of 'item'
        withAnimation {
            store.linkEntity(childName: dragged.name, childType: dragged.type, parentName: item.name, parentType: item.type)
        }
        
        draggedItem = nil
        dropTargetItem = nil
        return true
    }
}

struct ChildDropDelegate: DropDelegate {
    func performDrop(info: DropInfo) -> Bool { return true }
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
