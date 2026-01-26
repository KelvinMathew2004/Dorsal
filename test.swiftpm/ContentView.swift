import SwiftUI
import Vision
import CoreImage
import CoreImage.CIFilterBuiltins
import CoreMotion
import PhotosUI

struct ContentView: View {
    @State private var inputImage: UIImage?
    @State private var outputImage: UIImage?
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var showParallax = false
    @State private var imageSelection: PhotosPickerItem? = nil

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if let input = inputImage {
                    Image(uiImage: input).resizable().scaledToFit().frame(height: 250).cornerRadius(12)
                } else {
                    ContentUnavailableView("No Image", systemImage: "photo.badge.plus", description: Text("Select an image to start")).frame(height: 250)
                }
                PhotosPicker(selection: $imageSelection, matching: .images) {
                    Label("Select Photo", systemImage: "photo.on.rectangle").font(.headline).padding().frame(maxWidth: .infinity).background(.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                }.disabled(isProcessing)
                Button { processImage() } label: {
                    if isProcessing { ProgressView().tint(.white) } else { Label("Generate 3D Parallax", systemImage: "cube.transparent") }
                }.font(.headline).foregroundStyle(.white).padding().frame(maxWidth: .infinity).background(inputImage == nil || isProcessing ? Color.gray : Color.blue, in: RoundedRectangle(cornerRadius: 12)).disabled(inputImage == nil || isProcessing)
                if let error = errorMessage { Text(error).font(.caption).foregroundStyle(.red) }
                Spacer()
            }
            .padding().navigationTitle("3D Test")
            .onChange(of: imageSelection) { _, newItem in loadPhoto(newItem) }
            .fullScreenCover(isPresented: $showParallax) {
                if let input = inputImage, let cutout = outputImage {
                    TestParallaxView(originalImage: input, cutoutImage: cutout) { showParallax = false }
                }
            }
        }
    }
    func loadPhoto(_ item: PhotosPickerItem?) {
        guard let item else { return }
        item.loadTransferable(type: Data.self) { result in
            if case .success(let data) = result, let data, let uiImage = UIImage(data: data) { DispatchQueue.main.async { self.inputImage = uiImage } }
        }
    }
    func processImage() {
        guard let input = inputImage else { return }
        isProcessing = true; errorMessage = nil
        Task {
            let result = await VisionSubjectMasker.subjectCutout(from: input)
            await MainActor.run {
                isProcessing = false
                if let result = result { self.outputImage = result; self.showParallax = true } else { self.errorMessage = "Failed." }
            }
        }
    }
}

struct TestParallaxView: View {
    let originalImage: UIImage
    let cutoutImage: UIImage
    var onDismiss: () -> Void
    @State private var offset: CGSize = .zero
    @State private var motionManager = CMMotionManager()
    @State private var dragOffset: CGSize = .zero
    
    var body: some View {
        GeometryReader { outerGeo in
            ZStack {
                Color.black.opacity(0.95).ignoresSafeArea().onTapGesture { onDismiss() }
                
                GeometryReader { geo in
                    let availableWidth = geo.size.width
                    let cornerRadius: CGFloat = 28
                    let margin: CGFloat = 24
                    
                    // Constrain card width to fit screen minus padding
                    let cardWidth = min(outerGeo.size.width - 40, 500)
                    let cardHeight = cardWidth
                    
                    let combinedOffset = CGSize(width: offset.width + dragOffset.width, height: offset.height + dragOffset.height)
                    
                    let leftMargin = margin - (combinedOffset.width * 0.8)
                    let rightMargin = margin + (combinedOffset.width * 0.8)
                    let topMargin = margin - (combinedOffset.height * 0.8)
                    let bottomMargin = margin + (combinedOffset.height * 0.8)
                    
                    ZStack {
                        // Background
                        Image(uiImage: originalImage)
                            .resizable().aspectRatio(contentMode: .fill).frame(width: cardWidth, height: cardHeight)
                            .blur(radius: 3).overlay(Color.black.opacity(0.15))
                            .backgroundExtensionEffect()
                            .safeAreaInset(edge: .leading) { Color.clear.frame(width: max(0, leftMargin)) }
                            .safeAreaInset(edge: .trailing) { Color.clear.frame(width: max(0, rightMargin)) }
                            .safeAreaInset(edge: .top) { Color.clear.frame(height: max(0, topMargin)) }
                            .safeAreaInset(edge: .bottom) { Color.clear.frame(height: max(0, bottomMargin)) }
                        
                        // Foreground
                        Image(uiImage: cutoutImage)
                            .resizable().aspectRatio(contentMode: .fill).frame(width: cardWidth, height: cardHeight)
                            .scaleEffect(1.1)
                            .offset(x: combinedOffset.width * 1.5, y: combinedOffset.height * 1.5)
                            .backgroundExtensionEffect()
                            .safeAreaInset(edge: .leading) { Color.clear.frame(width: max(0, leftMargin)) }
                            .safeAreaInset(edge: .trailing) { Color.clear.frame(width: max(0, rightMargin)) }
                            .safeAreaInset(edge: .top) { Color.clear.frame(height: max(0, topMargin)) }
                            .safeAreaInset(edge: .bottom) { Color.clear.frame(height: max(0, bottomMargin)) }
                        
                        // Proper Inner Shadow - Doubled Thickness (margin * 4.0), Opaque at Edge
                        ZStack {
                            VStack {
                                LinearGradient(
                                    stops: [.init(color: .black, location: 0), .init(color: .clear, location: 1.0)],
                                    startPoint: .top, endPoint: .bottom
                                )
                                .frame(height: max(0, topMargin * 4.0))
                                Spacer()
                            }
                            VStack {
                                Spacer()
                                LinearGradient(
                                    stops: [.init(color: .black, location: 0), .init(color: .clear, location: 1.0)],
                                    startPoint: .bottom, endPoint: .top
                                )
                                .frame(height: max(0, bottomMargin * 4.0))
                            }
                            HStack {
                                LinearGradient(
                                    stops: [.init(color: .black, location: 0), .init(color: .clear, location: 1.0)],
                                    startPoint: .leading, endPoint: .trailing
                                )
                                .frame(width: max(0, leftMargin * 4.0))
                                Spacer()
                            }
                            HStack {
                                Spacer()
                                LinearGradient(
                                    stops: [.init(color: .black, location: 0), .init(color: .clear, location: 1.0)],
                                    startPoint: .trailing, endPoint: .leading
                                )
                                .frame(width: max(0, rightMargin * 4.0))
                            }
                        }
                        .blendMode(.multiply)
                        .allowsHitTesting(false)
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                    }
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                    .contentShape(Rectangle())
                    .onTapGesture { onDismiss() }
                    .gesture(DragGesture().onChanged { v in
                        let maxTilt: CGFloat = 5
                        dragOffset = CGSize(width: (v.translation.width/cardWidth)*maxTilt*2, height: (v.translation.height/cardHeight)*maxTilt*2)
                    }.onEnded { _ in withAnimation(.spring()) { dragOffset = .zero } })
                    .position(x: geo.size.width/2, y: geo.size.height/2)
                }
                .aspectRatio(1, contentMode: .fit)
                .frame(width: min(outerGeo.size.width - 40, 500))
                .padding(.horizontal, 20)
                
                VStack { Spacer(); HStack(spacing: 6) { Image(systemName: "iphone.gen3.motion"); Text("Tilt device") }.font(.caption).foregroundStyle(.white.opacity(0.6)).padding(16).background(.ultraThinMaterial, in: Capsule()).padding(.bottom, 60) }
            }
        }
        .onAppear {
            if motionManager.isDeviceMotionAvailable {
                motionManager.deviceMotionUpdateInterval = 1/60
                motionManager.startDeviceMotionUpdates(to: .main) { m, _ in
                    guard let m = m else { return }
                    let maxOffset: CGFloat = 5.0
                    withAnimation(.linear(duration: 0.1)) {
                        let pitch = max(-0.5, min(0.5, m.attitude.pitch - 0.78))
                        let roll = max(-0.5, min(0.5, m.attitude.roll))
                        offset = CGSize(width: CGFloat(roll)*maxOffset, height: CGFloat(pitch)*maxOffset)
                    }
                }
            }
        }
        .onDisappear { motionManager.stopDeviceMotionUpdates() }
    }
}

enum VisionSubjectMasker {
    static func subjectCutout(from source: UIImage) async -> UIImage? {
        guard let upright = makeUprightRGBA8(source) else { return nil }
        let ciInput = CIImage(cgImage: upright)
        let bg = CIImage(color: .clear).cropped(to: ciInput.extent)
        if #available(iOS 17.0, *) {
            let h = VNImageRequestHandler(cgImage: upright, orientation: .up)
            let r = VNGenerateForegroundInstanceMaskRequest()
            do {
                try h.perform([r])
                guard let obs = r.results?.first else { return nil }
                let m = try obs.generateScaledMaskForImage(forInstances: obs.allInstances, from: h)
                let cm = CIImage(cvPixelBuffer: copyBuffer(m)!)
                let f = CIFilter.blendWithMask(); f.inputImage = ciInput; f.maskImage = cm; f.backgroundImage = bg
                guard let out = f.outputImage, let cg = CIContext().createCGImage(out, from: out.extent) else { return nil }
                return UIImage(cgImage: cg, scale: source.scale, orientation: .up)
            } catch {}
        }
        return nil
    }
    static func makeUprightRGBA8(_ ui: UIImage) -> CGImage? {
        let fmt = UIGraphicsImageRendererFormat(); fmt.scale = ui.scale
        return UIGraphicsImageRenderer(size: ui.size, format: fmt).image { _ in ui.draw(in: CGRect(origin: .zero, size: ui.size)) }.cgImage
    }
    static func copyBuffer(_ s: CVPixelBuffer) -> CVPixelBuffer? {
        var n: CVPixelBuffer?; CVPixelBufferCreate(kCFAllocatorDefault, CVPixelBufferGetWidth(s), CVPixelBufferGetHeight(s), CVPixelBufferGetPixelFormatType(s), [kCVPixelBufferIOSurfacePropertiesKey:[:]] as CFDictionary, &n)
        guard let d = n else { return nil }
        CVPixelBufferLockBaseAddress(s, .readOnly); CVPixelBufferLockBaseAddress(d, [])
        if let sa = CVPixelBufferGetBaseAddress(s), let da = CVPixelBufferGetBaseAddress(d) {
            let h = CVPixelBufferGetHeight(s); let sb = CVPixelBufferGetBytesPerRow(s); let db = CVPixelBufferGetBytesPerRow(d)
            for y in 0..<h { memcpy(da + y*db, sa + y*sb, min(sb, db)) }
        }
        CVPixelBufferUnlockBaseAddress(s, .readOnly); CVPixelBufferUnlockBaseAddress(d, []); return d
    }
}
