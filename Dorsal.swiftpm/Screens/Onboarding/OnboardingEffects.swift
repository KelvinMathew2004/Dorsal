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
                        .fill(color.opacity(0.4)) // Increased opacity for visibility
                        .frame(width: proxy.size.width * 1.5)
                        .blur(radius: 100)
                        .offset(x: -proxy.size.width * 0.5, y: -proxy.size.height * 0.5)
                        .rotationEffect(.degrees(animate ? 360 : 0))
                        .animation(.linear(duration: 40).repeatForever(autoreverses: false), value: animate)
                    
                    // Blob 2: Bottom Right Counter-Rotating
                    Circle()
                        .fill(Color(red: 0.1, green: 0.0, blue: 0.2).opacity(0.5)) // Increased opacity
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
                    // Allow touches to pass through metal view if needed
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
        // Transparent clear color is CRITICAL for seeing background
        view.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        view.preferredFramesPerSecond = 60
        view.isPaused = false
        view.enableSetNeedsDisplay = false
        // Ensure background is transparent
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
    
    let starCount = 1_500
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
        
        // --- SHADER FIXES ---
        // 1. Fixed "bookmark" shape by ensuring UV masking makes round stars.
        // 2. Fixed aspect ratio stretching logic.
        // 3. Ensuring transparency output for background visibility.
        
        let shader = """
        #include <metal_stdlib>
        using namespace metal;

        struct VertexOut {
            float4 position [[position]];
            float4 color;
            float2 uv;
            float fade;
            float speed;
            float distFromCenter;
        };

        struct Uniforms {
            float time;
            float speed;
            float2 resolution;
            float4 tint;
        };

        struct StarData {
            float angle;
            float radius;
            float zOffset;
            float4 color;
        };

        vertex VertexOut vertex_main(uint vertexID [[vertex_id]],
                                     uint instanceID [[instance_id]],
                                     constant StarData* stars [[buffer(0)]],
                                     constant Uniforms& uniforms [[buffer(1)]]) {
            
            StarData star = stars[instanceID];
            VertexOut out;
            
            // Speed scaling
            float effectiveSpeed = 0.2 + (uniforms.speed * 6.0);
            
            // Z Depth: 10.0 (Far) -> 0.0 (Near)
            float z = fmod(star.zOffset - (uniforms.time * effectiveSpeed), 10.0);
            if (z < 0) z += 10.0;
            
            // Perspective
            float depth = max(z, 0.01);
            float perspective = 1.0 / depth;
            
            // Position on screen
            float x = cos(star.angle) * star.radius;
            float y = sin(star.angle) * star.radius;
            
            float2 projectedPos = float2(x * perspective, y * perspective);
            out.distFromCenter = length(projectedPos);
            
            // Aspect Ratio Correction
            float aspect = uniforms.resolution.x / uniforms.resolution.y;
            projectedPos.x /= aspect;
            
            // --- QUAD GENERATION ---
            
            // Base size
            float baseSize = 0.05 * perspective;
            baseSize = max(0.002, min(baseSize, 0.1));
            
            // Warp/Streak Logic
            // If fast, stretch length. If slow, length == width (Square/Circle)
            float warpFactor = max(1.0, uniforms.speed * 8.0);
            float streakLen = baseSize * warpFactor;
            float width = baseSize * (uniforms.speed > 1.0 ? 0.4 : 1.0);
            
            // Direction vector for alignment
            float2 dir = normalize(projectedPos);
            // Fix degenerate direction at center
            if (length(projectedPos) < 0.0001) dir = float2(0, 1);
            
            // Perpendicular vector
            float2 perp = float2(-dir.y, dir.x);
            
            // Vertex Offset
            float2 offset = float2(0,0);
            float2 uv = float2(0,0);
            
            // 0: Tail Left, 1: Tail Right, 2: Head Left, 3: Head Right
            if (vertexID == 0) {
                offset = (-dir * streakLen) - (perp * width);
                uv = float2(0, 0);
            } else if (vertexID == 1) {
                offset = (-dir * streakLen) + (perp * width);
                uv = float2(1, 0);
            } else if (vertexID == 2) {
                offset = (perp * width); // Head
                uv = float2(0, 1);
            } else if (vertexID == 3) {
                offset = -(perp * width); // Head
                uv = float2(1, 1);
            }
            
            out.position = float4(projectedPos + offset, 0.0, 1.0);
            out.uv = uv;
            out.speed = uniforms.speed;
            
            // --- COLOR & FADE ---
            float alpha = 1.0;
            // Fade in from distance
            if (z > 7.0) alpha = (10.0 - z) * 0.3;
            // Fade out near camera
            if (z < 0.5) alpha = z * 2.0;
            
            float4 c = mix(star.color, uniforms.tint, 0.3);
            
            // Brighten slightly during warp
            if (uniforms.speed > 1.0) {
                c.rgb += 0.2;
            }
            
            out.color = c;
            out.fade = alpha;
            
            return out;
        }

        fragment float4 fragment_main(VertexOut in [[stage_in]]) {
            float alpha = 0.0;
            
            if (in.speed > 1.0) {
                // -- WARP MODE (Streak) --
                // Gaussian fade width-wise
                float distX = abs(in.uv.x - 0.5) * 2.0;
                float coreX = 1.0 - smoothstep(0.0, 1.0, distX);
                
                // Linear fade length-wise (Head brightest)
                float tail = in.uv.y; 
                alpha = coreX * tail;
                
                // Center Fade to avoid blob
                float centerFade = smoothstep(0.0, 0.5, in.distFromCenter);
                alpha *= centerFade;
                
            } else {
                // -- NORMAL MODE (Round Star) --
                // Use Circular Mask! This fixes the "bookmark" shape.
                float2 center = in.uv - 0.5;
                float dist = length(center) * 2.0; // 0.0 to 1.0 edge
                
                // Hard circular cut + soft glow
                if (dist > 1.0) discard_fragment(); // Cut off corners of quad
                
                float core = 1.0 - smoothstep(0.0, 0.3, dist);
                float glow = 1.0 - smoothstep(0.0, 1.0, dist);
                
                alpha = core + (glow * 0.5);
            }
            
            alpha *= in.fade;
            
            // Ensure we don't output opaque black by accident
            return float4(in.color.rgb, in.color.a * alpha);
        }
        """
        
        do {
            let library = try device.makeLibrary(source: shader, options: nil)
            let vert = library.makeFunction(name: "vertex_main")
            let frag = library.makeFunction(name: "fragment_main")
            
            let desc = MTLRenderPipelineDescriptor()
            desc.vertexFunction = vert
            desc.fragmentFunction = frag
            desc.colorAttachments[0].pixelFormat = .bgra8Unorm
            
            // Additive Blending
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
