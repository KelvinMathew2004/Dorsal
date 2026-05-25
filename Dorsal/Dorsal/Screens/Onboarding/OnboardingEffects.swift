import SwiftUI
import MetalKit

// MARK: - GALAXY BACKGROUND (Simulated Mesh Gradient)
struct GalaxyMeshGradient: View {
    var color: Color
    @State private var animate = false
    
    var body: some View {
        ZStack {
            // Base Deep Space
            Color(red: 0.02, green: 0.0, blue: 0.05).ignoresSafeArea()
            
            GeometryReader { proxy in
                ZStack {
                    // Blob 1: Top Left Rotating
                    Circle()
                        .fill(color.opacity(0.4))
                        .frame(width: proxy.size.width * 1.5)
                        .blur(radius: 100)
                        .offset(x: -proxy.size.width * 0.5, y: -proxy.size.height * 0.5)
                        .rotationEffect(.degrees(animate ? 360 : 0))
                        .animation(.linear(duration: 40).repeatForever(autoreverses: false), value: animate)
                    
                    // Blob 2: Bottom Right Counter-Rotating
                    Circle()
                        .fill(Color(red: 0.1, green: 0.0, blue: 0.2).opacity(0.5))
                        .frame(width: proxy.size.width * 1.2)
                        .blur(radius: 80)
                        .offset(x: proxy.size.width * 0.4, y: proxy.size.height * 0.4)
                        .rotationEffect(.degrees(animate ? -360 : 0))
                        .animation(.linear(duration: 50).repeatForever(autoreverses: false), value: animate)
                    
                    // Blob 3: Center Pulse
                    RadialGradient(
                        colors: [color.opacity(0.3), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: proxy.size.width * 0.8
                    )
                    .scaleEffect(animate ? 1.1 : 0.9)
                    .animation(.easeInOut(duration: 4).repeatForever(autoreverses: true), value: animate)
                    
                    // Overlay Texture (Noise-like)
                    AngularGradient(
                        colors: [
                            color.opacity(0.2),
                            .clear,
                            color.opacity(0.1),
                            .clear,
                            color.opacity(0.2)
                        ],
                        center: .center
                    )
                    .rotationEffect(.degrees(animate ? 180 : 0))
                    .scaleEffect(1.5)
                    .blur(radius: 50)
                    .animation(.linear(duration: 60).repeatForever(autoreverses: false), value: animate)
                }
            }
        }
        .onAppear {
            animate = true
        }
    }
}

// MARK: - WARP DRIVE VIEW
struct WarpDriveView: View {
    var targetSpeed: Double
    var targetColor: Color
    
    var body: some View {
        ZStack {
            // 1. Separate Galaxy Mesh Background
            GalaxyMeshGradient(color: targetColor)
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 2.0), value: targetColor)
            
            // 2. Metal Star Field (Foreground)
            if MTLCreateSystemDefaultDevice() != nil {
                MetalWarpRenderer(speed: targetSpeed, tint: targetColor)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            } else {
                CanvasStarFieldFallback(color: targetColor)
            }
        }
    }
}

// MARK: - METAL RENDERER
struct MetalWarpRenderer: UIViewRepresentable {
    var speed: Double
    var tint: Color
    
    func makeUIView(context: Context) -> MTKView {
        let view = MTKView()
        view.device = MTLCreateSystemDefaultDevice()
        view.delegate = context.coordinator
        view.framebufferOnly = true
        view.colorPixelFormat = .bgra8Unorm
        // Transparent clear color
        view.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        view.preferredFramesPerSecond = 60
        view.isPaused = false
        view.enableSetNeedsDisplay = false
        view.layer.isOpaque = false
        view.backgroundColor = .clear
        
        if let device = view.device {
            context.coordinator.setupPipeline(device: device, view: view)
        }
        
        return view
    }
    
    func updateUIView(_ uiView: MTKView, context: Context) {
        context.coordinator.targetSpeed = Float(speed)
        context.coordinator.targetTint = tint.simd4
    }
    
    func makeCoordinator() -> WarpCoordinator {
        WarpCoordinator()
    }
}

// MARK: - COORDINATOR & SHADER
class WarpCoordinator: NSObject, MTKViewDelegate {
    var device: MTLDevice!
    var commandQueue: MTLCommandQueue!
    var pipelineState: MTLRenderPipelineState!
    var starBuffer: MTLBuffer!
    
    // REDUCED STAR COUNT
    let starCount = 400
    var startTime: Date = Date()
    
    var targetSpeed: Float = 0.0
    var currentSpeed: Float = 0.05
    var targetTint: SIMD4<Float> = SIMD4(1, 1, 1, 1)
    var currentTint: SIMD4<Float> = SIMD4(1, 1, 1, 1)
    
    struct StarData {
        var angle: Float
        var radius: Float
        var zOffset: Float
        var color: SIMD4<Float>
    }
    
    struct Uniforms {
        var time: Float
        var speed: Float
        var resolution: SIMD2<Float>
        var tint: SIMD4<Float>
    }
    
    func setupPipeline(device: MTLDevice, view: MTKView) {
        self.device = device
        self.commandQueue = device.makeCommandQueue()
        
        do {
            guard let library = device.makeDefaultLibrary() else {
                print("Default Metal library not found")
                return
            }
            let vert = library.makeFunction(name: "warp_vertex_main")
            let frag = library.makeFunction(name: "warp_fragment_main")
            
            let desc = MTLRenderPipelineDescriptor()
            desc.vertexFunction = vert
            desc.fragmentFunction = frag
            desc.colorAttachments[0].pixelFormat = .bgra8Unorm
            
            desc.colorAttachments[0].isBlendingEnabled = true
            desc.colorAttachments[0].rgbBlendOperation = .add
            desc.colorAttachments[0].alphaBlendOperation = .add
            desc.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
            desc.colorAttachments[0].destinationRGBBlendFactor = .one
            desc.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
            desc.colorAttachments[0].destinationAlphaBlendFactor = .one
            
            self.pipelineState = try device.makeRenderPipelineState(descriptor: desc)
            setupBuffers()
        } catch {
            print("Metal Error: \(error)")
        }
    }
    
    func setupBuffers() {
        var stars: [StarData] = []
        for _ in 0..<starCount {
            let angle = Float.random(in: 0...(2 * .pi))
            let rScale = Float.random(in: 0.2...3.5)
            let z = Float.random(in: 0...10.0)
            
            var r: Float = 1.0
            var g: Float = 1.0
            var b: Float = 1.0
            
            let type = Int.random(in: 0...10)
            if type < 2 { // Red/Gold
                r=1.0; g=0.8; b=0.6;
            } else if type < 6 { // White
                r=0.9; g=0.9; b=1.0;
            } else { // Blue
                r=0.6; g=0.8; b=1.0;
            }
            
            stars.append(StarData(angle: angle, radius: rScale, zOffset: z, color: SIMD4(r,g,b,1)))
        }
        self.starBuffer = device.makeBuffer(bytes: stars, length: stars.count * MemoryLayout<StarData>.stride, options: [])
    }
    
    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let desc = view.currentRenderPassDescriptor,
              let pipeline = pipelineState else { return }
        
        currentSpeed += (targetSpeed - currentSpeed) * 0.1
        currentTint = mix(currentTint, targetTint, t: 0.05)
        
        let commandBuffer = commandQueue.makeCommandBuffer()!
        let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: desc)!
        
        encoder.setRenderPipelineState(pipeline)
        
        let time = Float(Date().timeIntervalSince(startTime))
        let res = SIMD2<Float>(Float(view.drawableSize.width), Float(view.drawableSize.height))
        
        var uniforms = Uniforms(time: time, speed: currentSpeed, resolution: res, tint: currentTint)
        
        encoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 1)
        encoder.setVertexBuffer(starBuffer, offset: 0, index: 0)
        
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4, instanceCount: starCount)
        
        encoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
    
    func mix(_ a: SIMD4<Float>, _ b: SIMD4<Float>, t: Float) -> SIMD4<Float> {
        return a + (b - a) * t
    }
}

// Fallback
struct CanvasStarFieldFallback: View {
    let color: Color
    var body: some View {
        Color.black
    }
}

// MARK: - EXTENSIONS
extension Color {
    var simd4: SIMD4<Float> {
        #if canImport(UIKit)
        let uiColor = UIColor(self)
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        return SIMD4<Float>(Float(r), Float(g), Float(b), Float(a))
        #else
        return SIMD4<Float>(1, 1, 1, 1)
        #endif
    }
}
