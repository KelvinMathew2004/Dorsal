import SwiftUI
import PhotosUI
import CoreImage
import Contacts
import ContactsUI
import ImagePlayground

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
    
    @Environment(\.supportsImagePlayground) private var supportsImagePlayground
    
    // Contact Linking State
    @State private var contactId: String?
    @State private var resolvedContact: CNContact?
    @State private var showingContactPicker = false
    @State private var showingContactDetail = false
    
    @FocusState private var isDescriptionFocused: Bool
    
    // Gradient State
    @State private var gradientColors: [Color] = []
    
    var textColor: Color {
        let baseColor = gradientColors.first ?? .white
        return baseColor.mix(with: .white, by: 0.7)
    }
    
    var buttonColor: Color {
        let baseColor = gradientColors.first ?? .black
        return baseColor.mix(with: .black, by: 0.7)
    }
    
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
                Theme.gradientBackground()
                    .ignoresSafeArea()
                
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
                                gradientColors[0].mix(with: .black, by: 0.6), gradientColors[1].mix(with: .black, by: 0.6), gradientColors[2].mix(with: .black, by: 0.6),
                                gradientColors[2].mix(with: .black, by: 0.6), gradientColors[0].mix(with: .black, by: 0.6), gradientColors[1].mix(with: .black, by: 0.6),
                                gradientColors[1].mix(with: .black, by: 0.6), gradientColors[2].mix(with: .black, by: 0.6), gradientColors[0].mix(with: .black, by: 0.6)
                            ]
                        )
                    }
                    .ignoresSafeArea()
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
                                        .overlay {
                                            GeneratingGradientView()
                                                .clipShape(Circle())
                                        }
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
                                            .foregroundStyle(textColor.opacity(0.7))
                                            .glassEffect(.clear, in: Circle())
                                    }
                                }
                                
                                // The Edit Pill
                                if !isGenerating {
                                    Menu {
                                        Button { showingPhotoPicker = true } label: { Label("Photo Library", systemImage: "photo").tint(textColor) }
                                        
                                        if supportsImagePlayground {
                                            Button { showingImagePlayground = true } label: { Label("Create with AI", systemImage: "apple.image.playground").tint(textColor) }
                                        }
                                        
                                        if store.isImageGenerationAvailable && type != "person" {
                                            Button { generateAutoImage() } label: { Label("Generate with AI", systemImage: "sparkles").tint(textColor) }
                                        }
                                        
                                        if imageData != nil {
                                            Divider()
                                            
                                            Button(role: .destructive) {
                                                withAnimation { imageData = nil }
                                                saveData()
                                            } label: {
                                                Label("Remove Image", systemImage: "trash")
                                                    .tint(.red)
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
                                        .glassEffect(.clear.tint(buttonColor.opacity(0.8)).interactive())
                                    }
                                    .offset(y: 12)
                                }
                            }
                        }
                        .padding(.top, 40)
                        .padding(.bottom, 20)
                        
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
                            .glassEffect(.clear.interactive(), in: RoundedRectangle(cornerRadius: 24))
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
                                            .foregroundStyle(textColor.opacity(0.8))
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
                                        }
                                        .buttonStyle(.glassProminent)
                                        .tint(Color.orange.opacity(0.1))
                                    }
                                    .padding()
                                    .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 24))
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        // MARK: - Contact Linking (People Only)
                        if type == "person" {
                            if let contact = resolvedContact {
                                // Linked Contact View
                                Button {
                                    showingContactDetail = true
                                } label: {
                                    HStack(spacing: 16) {
                                        if let contactImageData = contact.thumbnailImageData, let uiImage = UIImage(data: contactImageData) {
                                            Image(uiImage: uiImage)
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .frame(width: 50, height: 50)
                                                .clipShape(Circle())
                                                .overlay(Circle().stroke(.white.opacity(0.3), lineWidth: 1))
                                        } else {
                                            ZStack {
                                                Circle().fill(.white.opacity(0.1))
                                                Text(String(contact.givenName.prefix(1)) + String(contact.familyName.prefix(1)))
                                                    .font(.headline)
                                                    .foregroundStyle(.white)
                                            }
                                            .frame(width: 50, height: 50)
                                        }
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("\(contact.givenName) \(contact.familyName)")
                                                .font(.headline)
                                                .foregroundStyle(textColor.opacity(0.9))
                                            Text("Linked Contact")
                                                .font(.caption)
                                                .foregroundStyle(textColor.opacity(0.7))
                                        }
                                        
                                        Spacer()
                                        
                                        // Unlink Button
                                        Button {
                                            unlinkContact()
                                        } label: {
                                            Image(systemName: "personalhotspot.slash")
                                                .foregroundStyle(.orange.opacity(0.8))
                                                .symbolRenderingMode(.palette)
                                                .symbolColorRenderingMode(.gradient)
                                        }
                                        .buttonStyle(.glassProminent)
                                        .tint(Color.orange.opacity(0.1))
                                    }
                                    .padding()
                                    .glassEffect(.clear.interactive(), in: RoundedRectangle(cornerRadius: 24))
                                }
                                .buttonStyle(.plain)
                                .padding(.horizontal)
                                .sheet(isPresented: $showingContactDetail) {
                                    ContactDetailView(contact: contact)
                                        .presentationDetents([.medium, .large])
                                }
                            } else {
                                // Add Link Button
                                Button {
                                    showingContactPicker = true
                                } label: {
                                    HStack {
                                        Image(systemName: "person.crop.circle.badge.plus")
                                        Text("Link to Contact")
                                    }
                                    .font(.subheadline.bold())
                                    .foregroundStyle(textColor.opacity(0.9))
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .glassEffect(.clear.interactive(), in: RoundedRectangle(cornerRadius: 24))
                                }
                                .padding(.horizontal)
                            }
                        }

                        Spacer()
                    }
                }
                .scrollIndicators(.hidden)
                
                VStack {
                    Spacer()
                    if let error = store.generationError {
                        Text(error)
                            .font(.subheadline.bold())
                            .foregroundStyle(.white)
                            .padding()
                            .glassEffect(.clear.tint(Color.red.opacity(0.2)))
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                            .onAppear {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                                    withAnimation { store.generationError = nil }
                                }
                            }
                            .padding(.bottom, 20)
                    }
                }
            }
            .navigationTitle(name.capitalized)
            .navigationSubtitle("\(appearanceCount) \(appearanceCount == 1 ? "Dream" : "Dreams")")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .confirm) {
                        dismiss()
                    }
                    .tint(buttonColor)
                }
            }
            .onAppear {
                loadData()
                
                if let data = imageData, let uiImage = UIImage(data: data) {
                    let color = uiImage.dominantColor
                    let newColors = [color, color.opacity(0.8), color.opacity(0.6)]
                    self.gradientColors = newColors
                } else {
                    setInitialGradient()
                }
                
                updateGradient()
            }
            .onDisappear {
                saveData()
            }
            .sheet(isPresented: $showingContactPicker) {
                ContactPicker { contact in
                    self.resolvedContact = contact
                    self.contactId = contact.identifier
                    // Re-fetch to ensure keys
                    self.fetchContact()
                    
                    if let contactImage = contact.imageData ?? contact.thumbnailImageData {
                        // Animate the image change
                        withAnimation(.easeInOut(duration: 0.5)) {
                            self.imageData = contactImage
                        }
                    }
                    saveData()
                }
            }
            .photosPicker(isPresented: $showingPhotoPicker, selection: $selectedPhoto, matching: .images)
            .onChange(of: selectedPhoto) {
                Task {
                    if let data = try? await selectedPhoto?.loadTransferable(type: Data.self) {
                        // Smooth transition for image change
                        withAnimation(.easeInOut(duration: 0.5)) {
                            imageData = data
                        }
                        saveData()
                    }
                }
            }
            // MARK: - Native Image Playground Sheet
            .imagePlaygroundSheet(
                isPresented: $showingImagePlayground,
                concepts: {
                    var concepts: [ImagePlaygroundConcept] = [.text(name)]
                    if !descriptionText.isEmpty {
                        concepts.append(.text(descriptionText))
                    } else if type == "place" {
                        concepts.append(.text(type))
                    }
                    return concepts
                }()
            ) { url in
                if let data = try? Data(contentsOf: url) {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        self.imageData = data
                    }
                    saveData()
                }
            }
            // Update gradient when image data changes
            .onChange(of: imageData) {
                // Ensure this transition is animated
                withAnimation(.easeInOut(duration: 1.0)) {
                    updateGradient()
                }
            }
        }
    }
    
    private func setInitialGradient() {
        if gradientColors.isEmpty {
            let fallbackColor: Color
            switch type {
            case "person": fallbackColor = .blue.opacity(0.6)
            case "place": fallbackColor = .green.opacity(0.6)
            case "tag": fallbackColor = .yellow.opacity(0.6)
            default: fallbackColor = .gray.opacity(0.6)
            }
            self.gradientColors = [fallbackColor, fallbackColor.opacity(0.8), fallbackColor.opacity(0.6)]
        }
    }
    
    private func updateGradient() {
        if let data = imageData, let uiImage = UIImage(data: data) {
            DispatchQueue.global(qos: .userInitiated).async {
                let color = uiImage.dominantColor
                DispatchQueue.main.async {
                    let newColors = [color, color.opacity(0.8), color.opacity(0.6)]
                    // Use withAnimation inside the async callback to smooth the transition
                    withAnimation(.easeInOut(duration: 1.0)) {
                        self.gradientColors = newColors
                    }
                }
            }
        } else {
            withAnimation(.easeInOut(duration: 1.0)) {
                setInitialGradient()
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
    
    private func fetchContact() {
        guard let id = contactId else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            let store = CNContactStore()
            let keys = [
                CNContactGivenNameKey,
                CNContactFamilyNameKey,
                CNContactThumbnailImageDataKey,
                CNContactImageDataKey,
                CNContactPhoneNumbersKey,
                CNContactEmailAddressesKey,
                CNContactBirthdayKey,
                CNContactOrganizationNameKey,
                CNContactJobTitleKey,
                CNContactPostalAddressesKey,
                CNContactSocialProfilesKey
            ] as [CNKeyDescriptor]
            
            do {
                let contact = try store.unifiedContact(withIdentifier: id, keysToFetch: keys)
                DispatchQueue.main.async {
                    self.resolvedContact = contact
                }
            } catch {
                print("Failed to fetch contact: \(error)")
            }
        }
    }
    
    private func unlinkContact() {
        withAnimation {
            self.contactId = nil
            self.resolvedContact = nil
        }
        saveData()
    }
    
    private func loadData() {
        if let entity = store.getEntity(name: name, type: type) {
            self.descriptionText = entity.details
            self.imageData = entity.imageData
            self.contactId = entity.contactId
            
            if let id = self.contactId {
                fetchContact()
            }
        }
    }
    
    private func saveData() {
        store.updateEntity(name: name, type: type, description: descriptionText, image: imageData, contactId: contactId)
    }
    
    private func generateAutoImage() {
        guard store.isImageGenerationAvailable else { return }
        isGenerating = true
        Task {
            let entityContext = "Name: \(name). Type: \(type). Description: \(descriptionText)"
            
            do {
                let sanitizedPrompt = try await DreamAnalyzer.shared.generateVisualPrompt(transcript: entityContext)
                let data = try await store.generateImageFromPrompt(prompt: sanitizedPrompt)
                
                withAnimation(.easeInOut(duration: 0.5)) {
                    self.imageData = data
                }
                saveData()
            } catch {
                await MainActor.run {
                    store.generationError = "Please try again or create an image instead."
                }
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

// MARK: - Contact Picker Helper
struct ContactPicker: UIViewControllerRepresentable {
    var onSelect: (CNContact) -> Void
    
    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: CNContactPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, CNContactPickerDelegate {
        let parent: ContactPicker
        
        init(_ parent: ContactPicker) {
            self.parent = parent
        }
        
        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            parent.onSelect(contact)
        }
    }
}
