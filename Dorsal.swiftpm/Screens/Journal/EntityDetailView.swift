import SwiftUI
import PhotosUI
import CoreImage

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
    
    // Gradient State
    @State private var gradientColors: [Color] = EntityDetailView.cachedGradientColors
    var textColor: Color {
        let baseColor = gradientColors.first ?? .white
        return baseColor.mix(with: .white, by: 0.7)
    }
    static var cachedGradientColors: [Color] = []
    
    @Environment(\.dismiss) var dismiss
    
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
                
                ScrollView {
                    VStack(spacing: 32) {
                        
                        // MARK: - Header
                        VStack(spacing: 24) {
                            
                            // Profile Image Circle with Pill
                            ZStack(alignment: .bottom) {
                                if isGenerating {
                                    Circle()
                                        .fill(.white.opacity(0.1))
                                        .frame(width: 140, height: 140)
                                        .overlay { ProgressView().tint(.white) }
                                } else if let data = imageData, let uiImage = UIImage(data: data) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 140, height: 140)
                                        .clipShape(Circle())
                                        .overlay(Circle().stroke(textColor.opacity(0.3), lineWidth: 3))
                                        .shadow(color: .black.opacity(0.3), radius: 15)
                                } else {
                                    ZStack {
                                        Image(systemName: iconForType)
                                            .font(.system(size: 50))
                                            .frame(width: 140, height: 140)
                                            .foregroundStyle(.white.opacity(0.5))
                                            .glassEffect(.clear, in: Circle())
                                    }
                                }
                                
                                // The Edit Pill
                                Menu {
                                    Button { showingPhotoPicker = true } label: { Label("Photo Library", systemImage: "photo") }
                                    
                                    if store.isImageGenerationAvailable {
                                        Button { showingImagePlayground = true } label: { Label("Create with Image Playground", systemImage: "wand.and.stars") }
                                        Button { generateAutoImage() } label: { Label("Generate Automatically", systemImage: "sparkles") }
                                    }
                                    
                                    if imageData != nil {
                                        Button(role: .destructive) {
                                            withAnimation { imageData = nil }
                                            saveData()
                                        } label: {
                                            Label("Remove Image", systemImage: "trash")
                                        }
                                    }
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "camera.fill")
                                        Text("Edit")
                                    }
                                    .font(.subheadline.bold())
                                    .foregroundStyle(textColor)
                                    .padding(.vertical, 6)
                                    .padding(.horizontal, 12)
                                    .glassEffect(.clear.tint((gradientColors.first ?? .white).opacity(0.3)).interactive())
                                }
                                .offset(y: 12)
                            }
                        }
                        .padding(.top, 40)
                        .padding(.bottom, 40)
                        
                        // MARK: - Description Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Description")
                                .font(.headline.bold())
                                .foregroundStyle(textColor.opacity(0.8))
                                .padding(.leading, 4)
                            
                            ZStack(alignment: .topLeading) {
                                // Placeholder
                                if descriptionText.isEmpty && !isDescriptionFocused {
                                    Text("Add a description for \(name)...")
                                        .foregroundStyle(textColor.opacity(0.5))
                                        .allowsHitTesting(false)
                                }
                                
                                // Standard Vertical TextField
                                TextField("", text: $descriptionText, axis: .vertical)
                                    .focused($isDescriptionFocused)
                                    .lineLimit(4...15)
                                    .foregroundStyle(textColor)
                            }
                            .padding(16)
                            .frame(minHeight: 120, alignment: .topLeading)
                            .glassEffect(.clear.interactive(), in: RoundedRectangle(cornerRadius: 16))
                            .onTapGesture {
                                isDescriptionFocused = true
                            }
                        }
                        .padding(.horizontal)
                        
                        // MARK: - Alternative Names (Children)
                        if !childrenEntities.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Alternative Names")
                                    .font(.headline.bold())
                                    .foregroundStyle(textColor.opacity(0.8))
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
                                                .symbolRenderingMode(.palette)
                                                .symbolColorRenderingMode(.gradient)
                                                .padding(8)
                                        }
                                        .buttonStyle(.glassProminent)
                                        .tint(Color.orange.opacity(0.1))
                                    }
                                    .padding()
                                    .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 16))
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        Spacer()
                    }
                }
            }
            .navigationTitle(name.capitalized)
            .navigationSubtitle("\(appearanceCount) \(appearanceCount == 1 ? "Dream" : "Dreams")")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .confirm) {
                        dismiss()
                    }
                    .tint(gradientColors.first)
                }
            }
            .onAppear {
                loadData()
                updateGradient()
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
            // Update gradient when image data changes
            .onChange(of: imageData) { updateGradient() }
        }
    }
    
    private func updateGradient() {
        if let data = imageData, let uiImage = UIImage(data: data) {
            DispatchQueue.global(qos: .userInitiated).async {
                let color = uiImage.dominantColor
                DispatchQueue.main.async {
                    let newColors = [color, color.opacity(0.8), color.opacity(0.6)]
                    self.gradientColors = newColors
                    EntityDetailView.cachedGradientColors = newColors
                }
            }
        } else {
            // Fallback for no image based on category
            let fallbackColor: Color
            switch type {
            case "person": fallbackColor = .blue.opacity(0.6) // Darker blue
            case "place": fallbackColor = .green.opacity(0.6) // Darker green
            case "tag": fallbackColor = .yellow.opacity(0.6) // Darker yellow
            default: fallbackColor = .gray.opacity(0.6)
            }
            
            self.gradientColors = [fallbackColor, fallbackColor.opacity(0.8), fallbackColor.opacity(0.6)]
            EntityDetailView.cachedGradientColors = self.gradientColors
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

// Updated Extension for Single Dominant Color
extension UIImage {
    var dominantColor: Color {
        guard let inputImage = CIImage(image: self) else { return .clear }
        let extentVector = CIVector(x: inputImage.extent.origin.x, y: inputImage.extent.origin.y, z: inputImage.extent.size.width, w: inputImage.extent.size.height)

        guard let filter = CIFilter(name: "CIAreaAverage", parameters: [kCIInputImageKey: inputImage, kCIInputExtentKey: extentVector]) else { return .clear }
        guard let outputImage = filter.outputImage else { return .clear }

        var bitmap = [UInt8](repeating: 0, count: 4)
        let context = CIContext(options: [.workingColorSpace: kCFNull!])
        context.render(outputImage, toBitmap: &bitmap, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: nil)

        return Color(red: Double(bitmap[0]) / 255.0, green: Double(bitmap[1]) / 255.0, blue: Double(bitmap[2]) / 255.0)
    }
}
