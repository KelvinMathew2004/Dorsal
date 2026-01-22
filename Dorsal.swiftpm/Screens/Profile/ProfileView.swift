import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import CoreImage
import ImagePlayground

struct ProfileView: View {
    @ObservedObject var store: DreamStore
    
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedCategory: String = "People"
    @State private var showEditSheet = false
    
    @State private var isImagePlaygroundPresented = false
    @Environment(\.supportsImagePlayground) private var supportsImagePlayground
    
    @State private var showPhotoPicker = false
    @State private var showSettings = false
    @State private var showOnboarding = false
    
    @State private var selectedEntity: EntityIdentifier?
    
    @State private var showDeleteAlert = false
    @State private var itemToDelete: EntityIdentifier?
    
    @State private var draggedItem: EntityIdentifier?
    @State private var dropTargetItem: EntityIdentifier?
    
    @State private var gradientColors: [Color] = {
        if let saved = UserDefaults.standard.string(forKey: "profileColorComponents") {
            let components = saved.split(separator: ",").compactMap { Double($0) }
            if components.count >= 3 {
                let color = Color(.sRGB, red: components[0], green: components[1], blue: components[2], opacity: components.count > 3 ? components[3] : 1)
                return [color, color.opacity(0.8), color.opacity(0.6)]
            }
        }
        return []
    }()
    
    var textColor: Color {
        let baseColor: Color
        if let customBase = gradientColors.first {
            baseColor = customBase
        } else {
            baseColor = Color(red: 0.10, green: 0.05, blue: 0.20)
        }
        
        return baseColor.mix(with: .white, by: 0.5)
    }
    
    struct EntityIdentifier: Hashable, Identifiable, Codable {
        let name: String
        let type: String
        var id: String { "\(type):\(name)" }
    }
    
    @State private var editFirstName = ""
    @State private var editLastName = ""
    
    var availableCategories: [String] {
        var cats: [String] = []
        if !store.allPeople.isEmpty { cats.append("People") }
        if !store.allPlaces.isEmpty { cats.append("Places") }
        if !store.allTags.isEmpty { cats.append("Symbols") }
        return cats
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.05, green: 0.02, blue: 0.10), Color(red: 0.10, green: 0.05, blue: 0.20), Color(red: 0.02, green: 0.02, blue: 0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
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
                }
                
                ScrollViewReader { proxy in
                    scrollableContent(proxy: proxy)
                }
            }
            .animation(.easeInOut(duration: 1.0), value: gradientColors)
            .navigationTitle("Profile")
            .navigationBarTitleColor(textColor)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .foregroundStyle(textColor)
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        editFirstName = store.firstName
                        editLastName = store.lastName
                        showEditSheet = true
                    } label: {
                        Image(systemName: "pencil")
                            .foregroundStyle(textColor)
                    }
                }
            }
            .fullScreenCover(isPresented: $showOnboarding) {
                OnboardingView(store: store)
            }
            .sheet(isPresented: $showSettings) {
                SettingsView(store: store, showOnboarding: $showOnboarding)
                    .presentationDetents([.large])
            }
            .sheet(isPresented: $showEditSheet) {
                NavigationStack {
                    Form {
                        Section {
                            HStack {
                                Spacer()
                                ZStack(alignment: .bottom) {
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
                                                .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 1))
                                            Image(systemName: "person.fill").font(.system(size: 50)).foregroundStyle(Color.white.opacity(0.7))
                                        }
                                    }
                                    
                                    if !isImagePlaygroundPresented {
                                        Menu {
                                            Button { showPhotoPicker = true } label: { Label("Photo Library", systemImage: "photo") }
                                            
                                            if supportsImagePlayground {
                                                Button {
                                                    isImagePlaygroundPresented = true
                                                } label: {
                                                    Label("Create with AI", systemImage: "apple.image.playground")
                                                }
                                            }
                                            
                                            if store.profileImageData != nil {
                                                Divider()
                                                
                                                Button(role: .destructive) { store.profileImageData = nil } label: { Label("Remove Photo", systemImage: "trash").tint(.red) }
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
                    .imagePlaygroundSheet(isPresented: $isImagePlaygroundPresented) { url in
                        if let data = try? Data(contentsOf: url) { withAnimation { store.profileImageData = data } }
                    }
                }
                .presentationDetents([.medium, .large])
                .photosPicker(isPresented: $showPhotoPicker, selection: $selectedItem, matching: .images)
            }
            .onChange(of: selectedItem) {
                Task {
                    if let data = try? await selectedItem?.loadTransferable(type: Data.self) {
                        withAnimation { store.profileImageData = data }
                    }
                }
            }
            .onChange(of: store.profileImageData) { updateGradient() }
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
                    
                    store.saveProfileColor(color)
                }
            }
        } else {
            self.gradientColors = []
            store.clearProfileColor()
        }
    }
    
    @ViewBuilder
    private func scrollableContent(proxy: ScrollViewProxy) -> some View {
        ScrollView {
            VStack(spacing: 40) {
                headerView.id("top")
                statsRow
                categorySection(proxy: proxy)
            }
            .padding(.bottom, 100)
        }
        .coordinateSpace(name: "scroll")
        .onDrop(of: [UTType.text], delegate: RootDropDelegate(draggedItem: $draggedItem, store: store))
        
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
    
    private var headerView: some View {
        HStack(spacing: 24) {
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
                        .foregroundStyle(textColor.opacity(0.5))
                        .glassEffect(.clear, in: Circle())
                }
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(store.firstName)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)
                Text(store.lastName)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(textColor.opacity(0.7))
            }
        }
        .padding(.top, 40)
        .padding(.horizontal)
        .frame(maxWidth: .infinity)
    }
    
    private var statsRow: some View {
        HStack(spacing: 6) {
            ContinuousStatBlock(title: "Streak", value: "\(store.currentStreak)", icon: "flame.fill", color: .orange, corners: [.topLeft, .bottomLeft])
            ContinuousStatBlock(title: "Dreams", value: "\(store.dreams.count)", icon: "moon.fill", color: .purple, corners: [])
            
            let placesCount = store.allPlaces.filter { placeName in
                store.getEntity(name: placeName, type: "place")?.parentID == nil
            }.count
            
            ContinuousStatBlock(title: "Places", value: "\(placesCount)", icon: "map.fill", color: .green, corners: [])
            
            let peopleCount = store.allPeople.filter { personName in
                store.getEntity(name: personName, type: "person")?.parentID == nil
            }.count
            
            ContinuousStatBlock(title: "People", value: "\(peopleCount)", icon: "person.2.fill", color: .blue, corners: [.topRight, .bottomRight])
        }
        .padding(.horizontal)
    }
    
    private func categorySection(proxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            if !availableCategories.isEmpty {
                Picker("Category", selection: $selectedCategory) {
                    ForEach(availableCategories, id: \.self) { cat in
                        Text(cat).tag(cat)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .onAppear {
                    if !availableCategories.contains(selectedCategory), let first = availableCategories.first {
                        selectedCategory = first
                    }
                }
                .onChange(of: availableCategories) {
                    if !availableCategories.contains(selectedCategory), let first = availableCategories.first {
                        selectedCategory = first
                    }
                }
            }
            
            VStack(spacing: 0) {
                ForEach(itemsForCategory, id: \.self) { item in
                    let itemIdentifier = EntityIdentifier(name: item, type: filterTypeForCategory)
                    let children = store.getChildren(for: item, type: filterTypeForCategory)
                    let hasChildren = !children.isEmpty
                    
                    VStack(spacing: 0) {
                        HStack(spacing: 16) {
                            Button {
                                selectedEntity = itemIdentifier
                            } label: {
                                HStack(spacing: 16) {
                                    EntityListImage(store: store, name: itemIdentifier.name, type: itemIdentifier.type, icon: iconForCategory, textColor: textColor)
                                    
                                    Text(itemIdentifier.name.capitalized)
                                        .font(.body.weight(.medium))
                                        .foregroundStyle(.white)
                                    
                                    Spacer()
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            
                            Menu {
                                Button {
                                    selectedEntity = itemIdentifier
                                } label: {
                                    Label("View Details", systemImage: "richtext.page")
                                        .tint(textColor)
                                }
                                
                                Button {
                                    store.jumpToFilter(type: itemIdentifier.type, value: itemIdentifier.name)
                                } label: {
                                    Label("Filter Dreams", systemImage: "line.3.horizontal.decrease")
                                        .tint(textColor)
                                }
                                
                                Divider()
                                
                                Button(role: .destructive) {
                                    itemToDelete = itemIdentifier
                                    showDeleteAlert = true
                                } label: {
                                    Label("Delete Details", systemImage: "trash")
                                        .tint(.red)
                                }
                            } label: {
                                Image(systemName: "ellipsis")
                                    .foregroundStyle(textColor)
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
                            
                            HStack(spacing: 16) {
                                Button {
                                    selectedEntity = itemIdentifier
                                } label: {
                                    HStack(spacing: 16) {
                                        Image(systemName: "arrow.turn.down.right")
                                            .font(.system(size: 20, weight: .regular))
                                            .foregroundStyle(textColor.opacity(0.7))
                                            .frame(width: 40, height: 40)
                                        
                                        Text(child.name.capitalized)
                                            .font(.body.weight(.medium))
                                            .foregroundStyle(.white)
                                        
                                        Spacer()
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                
                                Menu {
                                    Button {
                                        selectedEntity = itemIdentifier
                                    } label: {
                                        Label("View Details", systemImage: "richtext.page")
                                            .tint(textColor)
                                    }
                                    
                                    Button {
                                        store.jumpToFilter(type: itemIdentifier.type, value: itemIdentifier.name)
                                    } label: {
                                        Label("Filter Dreams", systemImage: "line.3.horizontal.decrease")
                                            .tint(textColor)
                                    }
                                    
                                    Divider()
                                    
                                    Button(role: .destructive) {
                                        withAnimation {
                                            store.unlinkEntity(name: child.name, type: child.type)
                                        }
                                    } label: {
                                        Label("Unlink", systemImage: "personalhotspot.slash")
                                            .tint(.red)
                                    }
                                } label: {
                                    Image(systemName: "ellipsis")
                                        .foregroundStyle(textColor)
                                        .font(.title2)
                                        .padding()
                                }
                            }
                            .padding()
                            .glassEffect(.clear.interactive(), in: Capsule())
                            .padding(.vertical, 8)
                            .padding(.horizontal)
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
    let textColor: Color
    
    var forceUpdate: Int { store.entityUpdateTrigger }
    var imageData: Data? { _ = forceUpdate; return store.getEntity(name: name, type: type)?.imageData }
    
    var body: some View {
        if let data = imageData, let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable().aspectRatio(contentMode: .fill).frame(width: 40, height: 40)
                .clipShape(Circle()).overlay(Circle().stroke(.white.opacity(0.3), lineWidth: 1))
        } else {
            Image(systemName: icon)
                .foregroundStyle(textColor)
                .frame(width: 40, height: 40)
                .background(Circle().fill(.white.opacity(0.1)))
                .overlay(Circle().stroke(.white.opacity(0.2), lineWidth: 1))
        }
    }
}

struct RootDropDelegate: DropDelegate {
    @Binding var draggedItem: ProfileView.EntityIdentifier?
    let store: DreamStore
    
    func dropUpdated(info: DropInfo) -> DropProposal {
        guard let dragged = draggedItem else { return DropProposal(operation: .cancel) }
        
        if let entity = store.getEntity(name: dragged.name, type: dragged.type), entity.parentID != nil {
            return DropProposal(operation: .move)
        }
        
        return DropProposal(operation: .forbidden)
    }
    
    func performDrop(info: DropInfo) -> Bool {
        guard let dragged = draggedItem else { return false }
        
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
        
        if !store.getChildren(for: dragged.name, type: dragged.type).isEmpty {
            return
        }
        
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
        guard let dragged = draggedItem, dragged.id != item.id else {
            if dropTargetItem?.id == item.id {
                DispatchQueue.main.async {
                    withAnimation { dropTargetItem = nil }
                }
            }
            return DropProposal(operation: .cancel)
        }
        
        let isValid = store.getChildren(for: dragged.name, type: dragged.type).isEmpty &&
                      !(store.getEntity(name: dragged.name, type: dragged.type)?.parentID == item.id)
        
        if isValid && dropTargetItem?.id == item.id {
            return DropProposal(operation: .copy)
        } else {
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
            Image(systemName: icon).font(.system(size: 50)).foregroundStyle(color.opacity(0.2))
            VStack(spacing: 2) {
                Text(value).font(.system(size: 24, weight: .bold, design: .rounded)).foregroundStyle(.white).minimumScaleFactor(0.8).lineLimit(1)
                Text(title.uppercased()).font(.system(size: 10, weight: .bold)).foregroundStyle(.white.opacity(0.6)).tracking(0.5)
            }.padding(.vertical, 24)
        }.frame(maxWidth: .infinity).frame(height: 80).glassEffect(.clear.tint(color.opacity(0.3)), in: CustomCorner(corners: corners, radius: 20))
    }
}

struct CustomCorner: Shape {
    var corners: UIRectCorner; var radius: CGFloat
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}
