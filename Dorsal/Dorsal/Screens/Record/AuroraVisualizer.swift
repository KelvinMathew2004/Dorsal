import SwiftUI
import MetalKit
#if canImport(UIKit)
import UIKit
#endif
import QuartzCore

// MARK: - SWIFTUI VIEW
struct AuroraVisualizer: View {
    var power: Float      // Audio power
    var isPaused: Bool
    var isRecording: Bool // Control visibility/animation
    var color: Color = .cyan
    
    var body: some View {
        GeometryReader { proxy in
            if MTLCreateSystemDefaultDevice() != nil {
                ZStack {
                    // LAYER 1: The Sky (Metal + Atmosphere Vignette)
                    ZStack {
                        // A. The Aurora Shader
                        MetalAuroraView(
                            power: isPaused ? 0 : power,
                            color: color,
                            isPaused: isPaused,
                            isRecording: isRecording
                        )
                        
                        // B. Horizon Vignette (Sky Side)
                        // This darkens the sky slightly as it approaches the horizon
                        // to simulate distance, but keeps it transparent enough to blend.
                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: 0.0),
                                .init(color: .clear, location: 0.5),
                                .init(color: Color.black.opacity(0.2), location: 0.8), // Very subtle darken
                                .init(color: Color.black.opacity(0.4), location: 1.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    // LAYER 2: The Water (Native)
                    NativeWaterView(
                        power: power,
                        color: color,
                        isPaused: isPaused,
                        isRecording: isRecording,
                        screenSize: proxy.size
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .ignoresSafeArea()
            } else {
                Color.black.opacity(0.8)
            }
        }
    }
}

// MARK: - NATIVE WATER VIEW
private struct NativeWaterView: View {
    var power: Float
    var color: Color
    var isPaused: Bool
    var isRecording: Bool
    var screenSize: CGSize
    
    // Constants for 30% Water Height (Horizon at 0.70)
    let waterHeightRatio: CGFloat = 0.30
    let horizonYRatio: CGFloat = 0.70
    
    // Texture Tint: Bright Lavender/Purple
    // This tints the WHITE waves to look purple.
    // The BLACK background stays black (and becomes transparent in Screen mode).
    private let waterTextureTint = Color(
        red: 0.65,
        green: 0.60,
        blue: 0.95
    )
    
    var body: some View {
        ZStack {
            // 1. REFLECTION (Flipped Sky)
            // Sits behind the texture.
            MetalAuroraView(
                power: isPaused ? 0 : power,
                color: color,
                isPaused: isPaused,
                isRecording: isRecording
            )
            .scaleEffect(y: -1) // Flip vertically
            .offset(y: screenSize.height * 0.4) // Re-align horizon
            .blur(radius: 2.0)
            .opacity(isRecording ? 0.3 : 0.1)
            .mask(
                // FADE IN MASK
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.65),
                        .init(color: .black, location: 0.8),
                        .init(color: .black, location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            
            // 2. WATER TEXTURE (Bottom 30%)
            VStack(spacing: 0) {
                // Clear top part
                Color.clear.frame(height: screenSize.height * horizonYRatio)
                
                // Water bottom part
                ZStack {
                    // A. Texture (Image Asset)
                    GeometryReader { geo in
                        Image("Ocean")
                            .resizable()
                            .renderingMode(.original)
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
                            .clipped()
                            .colorMultiply(waterTextureTint)
                            .blendMode(.screen)
                            .opacity(isRecording ? 0.3 : 0.2)
                    }
                }
                .frame(height: screenSize.height * waterHeightRatio)
                .clipped()
            }
        }
        .allowsHitTesting(false)
        .animation(.easeInOut(duration: 2.0), value: isRecording)
    }
}

// MARK: - METAL VIEW REPRESENTABLE
struct MetalAuroraView: UIViewRepresentable {
    var power: Float
    var color: Color
    var isPaused: Bool
    var isRecording: Bool
    
    func makeUIView(context: Context) -> MTKView {
        let view = MTKView()
        view.device = MTLCreateSystemDefaultDevice()
        view.delegate = context.coordinator
        view.framebufferOnly = true
        view.colorPixelFormat = .bgra8Unorm
        view.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        view.preferredFramesPerSecond = 30
        #if canImport(UIKit)
        view.contentScaleFactor = 1.0
        #endif
        view.isPaused = !isRecording
        view.enableSetNeedsDisplay = false
        view.layer.isOpaque = false
        view.backgroundColor = .clear
        
        if let device = view.device {
            context.coordinator.setupPipeline(device: device)
        }
        return view
    }
    
    func updateUIView(_ uiView: MTKView, context: Context) {
        context.coordinator.targetPower = power
        context.coordinator.targetColor = color.toMetalSimd()
        context.coordinator.isPaused = isPaused
        context.coordinator.isRecording = isRecording
        
        if isRecording && uiView.isPaused {
            uiView.isPaused = false
        }
    }
    
    func makeCoordinator() -> AuroraCoordinator {
        AuroraCoordinator()
    }
}

// MARK: - COORDINATOR
class AuroraCoordinator: NSObject, MTKViewDelegate {
    var device: MTLDevice!
    var commandQueue: MTLCommandQueue!
    var pipelineState: MTLRenderPipelineState!
    
    var startTime: CFTimeInterval = CACurrentMediaTime()
    var pausedTimeAccumulator: TimeInterval = 0
    var lastDrawTime: CFTimeInterval = CACurrentMediaTime()
    
    var isPaused: Bool = false
    var isRecording: Bool = false
    var animationProgress: Float = 0.0
    
    var targetPower: Float = 0.0
    var currentPower: Float = 0.0
    var targetColor: SIMD4<Float> = SIMD4(0.8, 0.4, 0.9, 1)
    var currentColor: SIMD4<Float> = SIMD4(0.8, 0.4, 0.9, 1)
    
    struct Uniforms {
        var time: Float
        var resolution: SIMD2<Float>
        var power: Float
        var color: SIMD4<Float>
        var isRecording: Float
        var entranceFactor: Float
    }
    
    func setupPipeline(device: MTLDevice) {
        self.device = device
        self.commandQueue = device.makeCommandQueue()
        
        do {
            guard let library = device.makeDefaultLibrary() else {
                print("Default Metal library not found")
                return
            }
            let vert = library.makeFunction(name: "aurora_vertex_main")
            let frag = library.makeFunction(name: "aurora_fragment_main")
            
            let desc = MTLRenderPipelineDescriptor()
            desc.vertexFunction = vert
            desc.fragmentFunction = frag
            desc.colorAttachments[0].pixelFormat = .bgra8Unorm
            desc.colorAttachments[0].isBlendingEnabled = true
            desc.colorAttachments[0].rgbBlendOperation = .add
            desc.colorAttachments[0].alphaBlendOperation = .add
            desc.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
            desc.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
            desc.colorAttachments[0].sourceAlphaBlendFactor = .one
            desc.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
            
            self.pipelineState = try device.makeRenderPipelineState(descriptor: desc)
        } catch {
            print("Metal Shader Error: \(error)")
        }
    }
    
    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let desc = view.currentRenderPassDescriptor,
              let pipeline = pipelineState else {
            return
        }
        
        let now = CACurrentMediaTime()
        let deltaTimeRaw = Float(now - lastDrawTime)
        let deltaTime = min(max(deltaTimeRaw, 1.0 / 120.0), 1.0 / 30.0)

        let powerSmoothing = min(1.0, deltaTime * 8.0)
        currentPower += (targetPower - currentPower) * powerSmoothing
        currentColor = mix(currentColor, targetColor, t: min(1.0, deltaTime * 4.0))
        
        let commandBuffer = commandQueue.makeCommandBuffer()!
        let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: desc)!
        
        encoder.setRenderPipelineState(pipeline)
        
        if isPaused {
            pausedTimeAccumulator += Double(deltaTime)
        }
        
        let speedFactor: Float = 0.5
        let time = Float(now - startTime - pausedTimeAccumulator) * speedFactor
        
        lastDrawTime = now
        
        let animationSpeed: Float = 1.0 / 3.0
        if isRecording {
            animationProgress += deltaTime * animationSpeed
        } else {
            animationProgress -= deltaTime * animationSpeed
        }
        animationProgress = max(0.0, min(1.0, animationProgress))
        
        if !isRecording && animationProgress <= 0.0 {
            DispatchQueue.main.async {
                view.isPaused = true
            }
        }
        
        let smoothEntrance = smoothstep(0.0, 1.0, animationProgress)
        let res = SIMD2<Float>(Float(view.drawableSize.width), Float(view.drawableSize.height))
        
        var uniforms = Uniforms(
            time: time,
            resolution: res,
            power: currentPower,
            color: currentColor,
            isRecording: isRecording ? 1.0 : 0.0,
            entranceFactor: smoothEntrance
        )
        
        encoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 1)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 1)
        
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        
        encoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
    
    func mix(_ a: SIMD4<Float>, _ b: SIMD4<Float>, t: Float) -> SIMD4<Float> {
        return a + (b - a) * t
    }
    
    func smoothstep(_ edge0: Float, _ edge1: Float, _ x: Float) -> Float {
        let t = max(0, min(1, (x - edge0) / (edge1 - edge0)))
        return t * t * (3 - 2 * t)
    }
}

private extension Color {
    func toMetalSimd() -> SIMD4<Float> {
        #if canImport(UIKit)
        let uiColor = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        return SIMD4(Float(r), Float(g), Float(b), Float(a))
        #else
        return SIMD4(0, 1, 1, 1)
        #endif
    }
}
