import SwiftUI
import PhotosUI

struct ImagePlaygroundSheet: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var store: DreamStore
    
    // If provided, we are creating for a specific entity
    var entityName: String?
    var entityDescription: String?
    var onImageCreated: (Data) -> Void
    
    @State private var prompt: String = ""
    @State private var selectedStyle: String = "Illustration"
    @State private var isGenerating = false
    @State private var generatedImage: UIImage?
    @State private var errorMessage: String?
    
    let styles = ["Illustration", "Sketch", "Animation", "Abstract"]
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.gradientBackground.ignoresSafeArea()
                
                VStack(spacing: 20) {
                    // MARK: - Canvas / Preview
                    ZStack {
                        RoundedRectangle(cornerRadius: 24)
                            .fill(.black.opacity(0.3))
                            .stroke(.white.opacity(0.1), lineWidth: 1)
                            .frame(height: 300)
                        
                        if isGenerating {
                            VStack {
                                ProgressView()
                                    .scaleEffect(1.5)
                                    .tint(.white)
                                Text("Dreaming...")
                                    .font(.headline)
                                    .foregroundStyle(Theme.secondary)
                                    .padding(.top)
                            }
                        } else if let image = generatedImage {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(height: 300)
                                .clipShape(RoundedRectangle(cornerRadius: 24))
                        } else {
                            VStack(spacing: 12) {
                                Image(systemName: "wand.and.stars")
                                    .font(.system(size: 40))
                                    .foregroundStyle(.white.opacity(0.3))
                                Text("Your creation will appear here")
                                    .foregroundStyle(Theme.secondary)
                            }
                        }
                    }
                    .padding()
                    
                    // MARK: - Controls
                    ScrollView {
                        VStack(spacing: 24) {
                            // Prompt Input
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Prompt")
                                    .font(.caption.bold())
                                    .foregroundStyle(Theme.secondary)
                                
                                TextEditor(text: $prompt)
                                    .scrollContentBackground(.hidden)
                                    .frame(height: 80)
                                    .padding()
                                    .background(.white.opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                    .foregroundStyle(.white)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(.white.opacity(0.2), lineWidth: 1)
                                    )
                            }
                            
                            // Style Selector
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Style")
                                    .font(.caption.bold())
                                    .foregroundStyle(Theme.secondary)
                                
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 10) {
                                        ForEach(styles, id: \.self) { style in
                                            Button {
                                                selectedStyle = style
                                            } label: {
                                                Text(style)
                                                    .font(.subheadline.bold())
                                                    .padding(.horizontal, 16)
                                                    .padding(.vertical, 8)
                                                    .background(selectedStyle == style ? store.themeAccentColor : .white.opacity(0.1))
                                                    .foregroundStyle(.white)
                                                    .clipShape(Capsule())
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    .scrollIndicators(.hidden)
                    
                    // MARK: - Action Button
                    Button {
                        if generatedImage != nil {
                            // Save Action
                            if let data = generatedImage?.pngData() {
                                onImageCreated(data)
                                dismiss()
                            }
                        } else {
                            // Generate Action
                            generateImage()
                        }
                    } label: {
                        HStack {
                            if isGenerating {
                                ProgressView().tint(.white)
                            } else {
                                Image(systemName: generatedImage != nil ? "checkmark" : "sparkles")
                            }
                            Text(generatedImage != nil ? "Use This Image" : "Create Image")
                        }
                        .font(.headline.bold())
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(prompt.isEmpty ? Color.gray.opacity(0.3) : store.themeAccentColor)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .disabled(prompt.isEmpty || isGenerating || !store.isImageGenerationAvailable)
                    .padding()
                }
            }
            .navigationTitle("Image Playground")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                // Pre-fill prompt if entity info exists
                if let name = entityName {
                    if let desc = entityDescription, !desc.isEmpty {
                        prompt = "\(name): \(desc)"
                    } else {
                        prompt = "\(name) in a dreamlike setting"
                    }
                }
            }
        }
    }
    
    private func generateImage() {
        guard !prompt.isEmpty else { return }
        isGenerating = true
        errorMessage = nil
        
        // Use the store's generation logic but with the custom prompt
        Task {
            do {
                let data = try await store.generateImageFromPrompt(prompt: prompt)
                if let uiImage = UIImage(data: data) {
                    withAnimation {
                        generatedImage = uiImage
                    }
                }
            } catch {
                errorMessage = "Generation failed. Please try again."
            }
            isGenerating = false
        }
    }
}
