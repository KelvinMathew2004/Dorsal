import SwiftUI
import PhotosUI

struct EntityDetailView: View {
    @ObservedObject var store: DreamStore
    let name: String
    let type: String
    
    @State private var descriptionText: String = ""
    @State private var imageData: Data?
    @State private var showingImageOptions = false
    @State private var showingImagePlayground = false
    @State private var showingPhotoPicker = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isGenerating = false
    
    @FocusState private var isDescriptionFocused: Bool
    
    // Computed count
    var appearanceCount: Int {
        switch type {
        case "person": return store.dreams.filter { $0.people.contains(name) }.count
        case "place": return store.dreams.filter { $0.places.contains(name) }.count
        case "tag": return store.dreams.filter { $0.keyEntities.contains(name) }.count
        default: return 0
        }
    }
    
    // Children Fetching
    var childrenEntities: [SavedEntity] {
        return store.getChildren(for: name, type: type)
    }
    
    var body: some View {
        ZStack {
            Theme.gradientBackground.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 32) {
                    
                    // MARK: - Header
                    VStack(spacing: 24) {
                        
                        // Profile Image Circle
                        Button {
                            showingImageOptions = true
                        } label: {
                            ZStack {
                                if isGenerating {
                                    Circle()
                                        .fill(.white.opacity(0.1))
                                        .overlay { ProgressView().tint(.white) }
                                } else if let data = imageData, let uiImage = UIImage(data: data) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 140, height: 140)
                                        .clipShape(Circle())
                                        .overlay(Circle().stroke(.white.opacity(0.3), lineWidth: 3))
                                        .shadow(color: .black.opacity(0.3), radius: 15)
                                } else {
                                    ZStack {
                                        Circle()
                                            .fill(.white.opacity(0.1))
                                            .overlay(Circle().stroke(.white.opacity(0.2), lineWidth: 2))
                                        
                                        Image(systemName: iconForType)
                                            .font(.system(size: 50))
                                            .foregroundStyle(.white.opacity(0.3))
                                    }
                                    .frame(width: 140, height: 140)
                                }
                                
                                // Edit Badge
                                Image(systemName: "pencil.circle.fill")
                                    .font(.title)
                                    .foregroundStyle(.white)
                                    .background(Circle().fill(Color.black))
                                    .offset(x: 50, y: 50)
                            }
                        }
                        .confirmationDialog("Change Image", isPresented: $showingImageOptions) {
                            Button("Photo Library") { showingPhotoPicker = true }
                            
                            // Only show generation options if supported
                            if store.isImageGenerationAvailable {
                                Button("Create with Image Playground") { showingImagePlayground = true }
                                Button("Generate Automatically") { generateAutoImage() }
                            }
                            
                            if imageData != nil {
                                Button("Remove Image", role: .destructive) {
                                    withAnimation { imageData = nil }
                                    saveData()
                                }
                            }
                            Button("Cancel", role: .cancel) { }
                        }
                        
                        // Text Info
                        VStack(spacing: 4) {
                            Text("\(appearanceCount)")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundStyle(.white)
                            
                            Text(appearanceCount == 1 ? "Dream" : "Dreams")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundStyle(Theme.secondary)
                        }
                    }
                    .padding(.top, 20)
                    
                    // MARK: - Description Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("DESCRIPTION")
                            .font(.caption.bold())
                            .foregroundStyle(Theme.secondary)
                            .padding(.leading, 4)
                        
                        ZStack(alignment: .topLeading) {
                            // Placeholder
                            if descriptionText.isEmpty && !isDescriptionFocused {
                                Text("Add a description for \(name)...")
                                    .foregroundStyle(.white.opacity(0.3))
                                    .allowsHitTesting(false)
                            }
                            
                            // Standard Vertical TextField
                            TextField("", text: $descriptionText, axis: .vertical)
                                .focused($isDescriptionFocused)
                                .lineLimit(4...15)
                                .foregroundStyle(.white)
                        }
                        .padding(16)
                        .frame(minHeight: 120, alignment: .topLeading)
                        .background(Color.white.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(.white.opacity(0.1), lineWidth: 1)
                        )
                        .onTapGesture {
                            isDescriptionFocused = true
                        }
                    }
                    .padding(.horizontal)
                    
                    // MARK: - Alternative Names (Children)
                    if !childrenEntities.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("ALTERNATIVE NAMES")
                                .font(.caption.bold())
                                .foregroundStyle(Theme.secondary)
                                .padding(.leading, 4)
                            
                            ForEach(childrenEntities, id: \.id) { child in
                                HStack(spacing: 16) {
                                    // "L" Arrow visual
                                    Image(systemName: "arrow.turn.down.right")
                                        .font(.system(size: 20, weight: .regular))
                                        .foregroundStyle(.white.opacity(0.3))
                                        .frame(width: 40, height: 40)
                                    
                                    Text(child.name.capitalized)
                                        .font(.body.weight(.medium))
                                        .foregroundStyle(.white)
                                    
                                    Spacer()
                                    
                                    // Unlink Button on right end
                                    Button(role: .destructive) {
                                        withAnimation {
                                            store.unlinkEntity(name: child.name, type: child.type)
                                        }
                                    } label: {
                                        Image(systemName: "personalhotspot.slash")
                                            .foregroundStyle(.orange.opacity(0.8))
                                            .padding(8)
                                    }
                                    .buttonStyle(.glassProminent)
                                    .tint(Color.orange.opacity(0.1))
                                }
                                .padding()
                                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    Spacer()
                }
            }
        }
        .navigationTitle(name.capitalized) // Native large title
        .navigationBarTitleDisplayMode(.large)
        // Add a toolbar with a Done button to dismiss keyboard
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    isDescriptionFocused = false
                }
                .fontWeight(.bold)
            }
        }
        .onAppear {
            loadData()
        }
        .onDisappear {
            saveData()
        }
        .photosPicker(isPresented: $showingPhotoPicker, selection: $selectedPhoto, matching: .images)
        .onChange(of: selectedPhoto) {
            Task {
                if let data = try? await selectedPhoto?.loadTransferable(type: Data.self) {
                    withAnimation { imageData = data }
                    saveData() // Save immediately on image change
                }
            }
        }
        .sheet(isPresented: $showingImagePlayground) {
            ImagePlaygroundSheet(
                store: store,
                entityName: name,
                entityDescription: descriptionText
            ) { data in
                withAnimation { self.imageData = data }
                saveData()
            }
        }
    }
    
    private var iconForType: String {
        switch type {
        case "person": return "person.fill"
        case "place": return "map.fill"
        default: return "star.fill"
        }
    }
    
    private func loadData() {
        if let entity = store.getEntity(name: name, type: type) {
            self.descriptionText = entity.details
            self.imageData = entity.imageData
        }
    }
    
    private func saveData() {
        store.updateEntity(name: name, type: type, description: descriptionText, image: imageData)
    }
    
    private func generateAutoImage() {
        guard store.isImageGenerationAvailable else { return }
        isGenerating = true
        Task {
            // Standardized Styling from Dream Analyzer
            let prompt = "\(name) \(descriptionText). Artistic style: Dreamlike, surreal, soft lighting."
            
            do {
                let data = try await store.generateImageFromPrompt(prompt: prompt)
                withAnimation {
                    self.imageData = data
                }
                saveData()
            } catch {
                print("Auto generation failed")
            }
            isGenerating = false
        }
    }
}
