import SwiftUI
import Vision
import CoreImage
import CoreImage.CIFilterBuiltins
import CoreMotion

struct ParallaxImageView: View {
    let image: UIImage
    var namespace: Namespace.ID
    var id: String
    var onDismiss: () -> Void
    
    @State private var foregroundImage: UIImage?
    @State private var isProcessing = true
    @State private var offset: CGSize = .zero
    
    @State private var motionManager = CMMotionManager()
    @State private var dragOffset: CGSize = .zero
    
    var body: some View {
        GeometryReader { outerGeo in
            ZStack {
                Color.black.opacity(0.95).ignoresSafeArea().onTapGesture { onDismiss() }
                
                if isProcessing {
                    ZStack {
                        Image(uiImage: image)
                            .resizable().aspectRatio(contentMode: .fill)
                            .frame(width: 350, height: 350)
                            .blur(radius: 20)
                            .clipShape(RoundedRectangle(cornerRadius: 28))
                            .matchedGeometryEffect(id: id, in: namespace)
                        VStack(spacing: 20) {
                            ProgressView().tint(.white)
                            Text("Creating 3D Scene...").foregroundStyle(.white).font(.headline)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    GeometryReader { geo in
                        let size = geo.size
                        let cornerRadius: CGFloat = 28
                        let margin: CGFloat = 24
                        
                        let combinedOffset = CGSize(width: offset.width + dragOffset.width, height: offset.height + dragOffset.height)
                        
                        let leftMargin = margin - (combinedOffset.width * 0.8)
                        let rightMargin = margin + (combinedOffset.width * 0.8)
                        let topMargin = margin - (combinedOffset.height * 0.8)
                        let bottomMargin = margin + (combinedOffset.height * 0.8)
                        
                        ZStack {
                            // Background
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: size.width, height: size.height)
                                .blur(radius: foregroundImage != nil ? 3 : 0)
                                .overlay(foregroundImage != nil ? Color.black.opacity(0.15) : Color.clear)
                                .backgroundExtensionEffect()
                                .safeAreaInset(edge: .leading) { Color.clear.frame(width: max(0, leftMargin)) }
                                .safeAreaInset(edge: .trailing) { Color.clear.frame(width: max(0, rightMargin)) }
                                .safeAreaInset(edge: .top) { Color.clear.frame(height: max(0, topMargin)) }
                                .safeAreaInset(edge: .bottom) { Color.clear.frame(height: max(0, bottomMargin)) }
                            
                            // Foreground
                            if let fg = foregroundImage {
                                Image(uiImage: fg)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: size.width, height: size.height)
                                    .scaleEffect(1.1)
                                    .offset(x: combinedOffset.width * 1.5, y: combinedOffset.height * 1.5)
                                    .backgroundExtensionEffect()
                                    .safeAreaInset(edge: .leading) { Color.clear.frame(width: max(0, leftMargin)) }
                                    .safeAreaInset(edge: .trailing) { Color.clear.frame(width: max(0, rightMargin)) }
                                    .safeAreaInset(edge: .top) { Color.clear.frame(height: max(0, topMargin)) }
                                    .safeAreaInset(edge: .bottom) { Color.clear.frame(height: max(0, bottomMargin)) }
                            }
                            
                            // Proper Inner Shadow - Doubled Thickness (margin * 4.0)
                            ZStack {
                                VStack {
                                    LinearGradient(colors: [.black.opacity(0.95), .clear], startPoint: .top, endPoint: .bottom)
                                        .frame(height: max(0, topMargin * 4.0))
                                    Spacer()
                                }
                                VStack {
                                    Spacer()
                                    LinearGradient(colors: [.clear, .black.opacity(0.95)], startPoint: .top, endPoint: .bottom)
                                        .frame(height: max(0, bottomMargin * 4.0))
                                }
                                HStack {
                                    LinearGradient(colors: [.black.opacity(0.95), .clear], startPoint: .leading, endPoint: .trailing)
                                        .frame(width: max(0, leftMargin * 4.0))
                                    Spacer()
                                }
                                HStack {
                                    Spacer()
                                    LinearGradient(colors: [.clear, .black.opacity(0.95)], startPoint: .leading, endPoint: .trailing)
                                        .frame(width: max(0, rightMargin * 4.0))
                                }
                            }
                            .blendMode(.multiply)
                            .allowsHitTesting(false)
                            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                            
                            // Removed White Border
                        }
                        .matchedGeometryEffect(id: id, in: namespace)
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                        .contentShape(Rectangle())
                        .onTapGesture { onDismiss() }
                        .gesture(DragGesture().onChanged { v in
                            let maxTilt: CGFloat = 5
                            dragOffset = CGSize(width: (v.translation.width/size.width)*maxTilt*2, height: (v.translation.height/size.height)*maxTilt*2)
                        }.onEnded { _ in withAnimation(.spring()) { dragOffset = .zero } })
                        .position(x: geo.size.width/2, y: geo.size.height/2)
                    }
                    .aspectRatio(1, contentMode: .fit)
                    .padding(.horizontal, 20 + outerGeo.safeAreaInsets.leading + outerGeo.safeAreaInsets.trailing)
                    .padding(.vertical, 40 + outerGeo.safeAreaInsets.top + outerGeo.safeAreaInsets.bottom)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            VStack { Spacer(); HStack(spacing: 6) { Image(systemName: "iphone.gen3.motion"); Text("Tilt device to view 3D effect") }.font(.caption).foregroundStyle(.white.opacity(0.6)).padding(.horizontal, 16).padding(.vertical, 8).background(.ultraThinMaterial, in: Capsule()).padding(.bottom, 60) }
        }
        .onAppear { startParallax() }
        .onDisappear { stopParallax() }
    }
    
    private func startParallax() {
        Task {
            let processedImage = await VisionSubjectMasker.subjectCutout(from: image)
            await MainActor.run {
                if let result = processedImage { self.foregroundImage = result }
                withAnimation { self.isProcessing = false }
            }
        }
        if motionManager.isDeviceMotionAvailable {
            motionManager.deviceMotionUpdateInterval = 1.0 / 60.0
            motionManager.startDeviceMotionUpdates(to: .main) { motion, error in
                guard let motion = motion else { return }
                let maxOffset: CGFloat = 8.0
                withAnimation(.linear(duration: 0.1)) {
                    let pitch = max(-0.5, min(0.5, motion.attitude.pitch - 0.78))
                    let roll = max(-0.5, min(0.5, motion.attitude.roll))
                    offset = CGSize(width: CGFloat(roll) * maxOffset, height: CGFloat(pitch) * maxOffset)
                }
            }
        }
    }
    private func stopParallax() { motionManager.stopDeviceMotionUpdates() }
}

enum VisionSubjectMasker {
    static func makeUprightRGBA8(_ ui: UIImage) -> CGImage? {
        if let cg = ui.cgImage, ui.imageOrientation == .up { return normalizeRGBA8(cg) }
        let fmt = UIGraphicsImageRendererFormat(); fmt.scale = ui.scale
        return UIGraphicsImageRenderer(size: ui.size, format: fmt).image { _ in ui.draw(in: CGRect(origin: .zero, size: ui.size)) }.cgImage.flatMap { normalizeRGBA8($0) }
    }
    static func normalizeRGBA8(_ cg: CGImage) -> CGImage? {
        guard let cs = CGColorSpace(name: CGColorSpace.sRGB), let ctx = CGContext(data: nil, width: cg.width, height: cg.height, bitsPerComponent: 8, bytesPerRow: 0, space: cs, bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue) else { return nil }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: cg.width, height: cg.height)); return ctx.makeImage()
    }
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
    private static func copyBuffer(_ s: CVPixelBuffer) -> CVPixelBuffer? {
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
