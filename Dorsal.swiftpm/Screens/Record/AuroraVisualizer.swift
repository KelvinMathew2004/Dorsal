import SwiftUI
import MetalKit

// MARK: - SWIFTUI VIEW
struct AuroraVisualizer: View {
    var power: Float      // Audio power (normalized 0.0 to 1.0)
    var isPaused: Bool
    var color: Color = .cyan // Default, can be overridden with Theme.accent
    
    var body: some View {
        ZStack {
            Color.clear
            
            if MTLCreateSystemDefaultDevice() != nil {
                MetalAuroraView(power: isPaused ? 0 : power, color: color)
            } else {
                FallbackAuroraView(power: power, color: color)
            }
        }
    }
}

// MARK: - METAL VIEW REPRESENTABLE
struct MetalAuroraView: UIViewRepresentable {
    var power: Float
    var color: Color
    
    func makeUIView(context: Context) -> MTKView {
        let view = MTKView()
        view.device = MTLCreateSystemDefaultDevice()
        view.delegate = context.coordinator
        view.framebufferOnly = true
        view.colorPixelFormat = .bgra8Unorm
        view.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        view.preferredFramesPerSecond = 60
        view.isPaused = false
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
        context.coordinator.targetColor = color.simd4
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
    
    var startTime: Date = Date()
    
    // State
    var targetPower: Float = 0.0
    var currentPower: Float = 0.0
    var targetColor: SIMD4<Float> = SIMD4(0, 1, 1, 1)
    var currentColor: SIMD4<Float> = SIMD4(0, 1, 1, 1)
    
    struct Uniforms {
        var time: Float
        var power: Float
        var resolution: SIMD2<Float>
        var color: SIMD4<Float>
    }
    
    func setupPipeline(device: MTLDevice) {
        self.device = device
        self.commandQueue = device.makeCommandQueue()
        
        do {
            let library = try device.makeLibrary(source: AURORA_SHADER_SOURCE, options: nil)
            let vert = library.makeFunction(name: "vertex_main")
            let frag = library.makeFunction(name: "fragment_main")
            
            let desc = MTLRenderPipelineDescriptor()
            desc.vertexFunction = vert
            desc.fragmentFunction = frag
            desc.colorAttachments[0].pixelFormat = .bgra8Unorm
            
            // Additive Blending for "Light" effect
            desc.colorAttachments[0].isBlendingEnabled = true
            desc.colorAttachments[0].rgbBlendOperation = .add
            desc.colorAttachments[0].alphaBlendOperation = .add
            desc.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
            desc.colorAttachments[0].destinationRGBBlendFactor = .one
            desc.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
            desc.colorAttachments[0].destinationAlphaBlendFactor = .one
            
            self.pipelineState = try device.makeRenderPipelineState(descriptor: desc)
        } catch {
            print("Metal Shader Error: \(error)")
        }
    }
    
    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let desc = view.currentRenderPassDescriptor,
              let pipeline = pipelineState else { return }
        
        // Faster response for punchy visuals
        currentPower += (targetPower - currentPower) * 0.25
        currentColor = mix(currentColor, targetColor, t: 0.05)
        
        let commandBuffer = commandQueue.makeCommandBuffer()!
        let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: desc)!
        
        encoder.setRenderPipelineState(pipeline)
        
        let time = Float(Date().timeIntervalSince(startTime))
        let res = SIMD2<Float>(Float(view.drawableSize.width), Float(view.drawableSize.height))
        
        var uniforms = Uniforms(
            time: time,
            power: currentPower,
            resolution: res,
            color: currentColor
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
}

// MARK: - FALLBACK VIEW
struct FallbackAuroraView: View {
    var power: Float
    var color: Color
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<25) { i in
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.purple.opacity(0.8),
                                Color.pink.opacity(0.6),
                                color.opacity(0.4),
                                .clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: 200 + CGFloat(power * 500) * CGFloat.random(in: 0.9...1.3))
                    .opacity(0.6 + Double(power * 0.6))
                    .blur(radius: 15)
                    .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true).delay(Double(i)*0.04), value: power)
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .ignoresSafeArea()
    }
}

// MARK: - SHADER SOURCE
private let AURORA_SHADER_SOURCE = """
#include <metal_stdlib>
using namespace metal;

struct VertexOut {
    float4 position [[position]];
    float2 uv;
};

struct Uniforms {
    float time;
    float power;
    float2 resolution;
    float4 color;
};

vertex VertexOut vertex_main(uint vertexID [[vertex_id]]) {
    VertexOut out;
    float2 pos[4] = { float2(-1, -1), float2(1, -1), float2(-1, 1), float2(1, 1) };
    float2 uv[4]  = { float2(0, 1), float2(1, 1), float2(0, 0), float2(1, 0) };
    
    out.position = float4(pos[vertexID], 0, 1);
    out.uv = uv[vertexID];
    return out;
}

// --- NOISE & MATH ---
float hash(float2 p) {
    return fract(sin(dot(p, float2(12.9898, 78.233))) * 43758.5453);
}

float noise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i + float2(0.0, 0.0)), hash(i + float2(1.0, 0.0)), f.x),
               mix(hash(i + float2(0.0, 1.0)), hash(i + float2(1.0, 1.0)), f.x), f.y);
}

float fbm(float2 p) {
    float f = 0.0;
    float2x2 m = float2x2(1.6, 1.2, -1.2, 1.6);
    f += 0.5000 * noise(p); p = m * p;
    f += 0.2500 * noise(p); p = m * p;
    f += 0.1250 * noise(p); p = m * p;
    f += 0.0625 * noise(p); p = m * p;
    return f;
}

fragment float4 fragment_main(VertexOut in [[stage_in]],
                              constant Uniforms& uniforms [[buffer(1)]]) {
    
    float2 uv = in.uv;
    
    // Scale X by aspect to keep noise uniform
    float aspect = uniforms.resolution.x / uniforms.resolution.y;
    float2 p = float2(uv.x * aspect, uv.y);
    
    float3 finalColor = float3(0.0);
    
    // --- AURORAL CORONA EFFECT ---
    // Infinite vertical lines, multiple colors, intense brightness
    
    // 4 Layers for depth
    for (float i = 0.0; i < 4.0; i += 1.0) {
        
        // Time offset
        float t = uniforms.time * (0.1 + i * 0.05);
        
        // Coordinate for this layer
        float2 q = p;
        
        // 1. Vertical Stretch (Infinite Lines)
        // Extremely high Y-stretch (q.y * 0.1) creates long vertical rays
        // High X-freq (q.x * 15.0) creates many fine lines
        float2 stretch = float2(q.x * 15.0 + i * 5.0, q.y * 0.1 + t);
        
        // 2. Warp the lines (The Curtain Fold)
        // Large sine wave to make the whole curtain undulate slowly
        float warp = sin(q.y * 1.5 + t * 0.5) * 1.5;
        stretch.x += warp;
        
        // 3. Generate Noise
        float n = fbm(stretch);
        
        // 4. Threshold & Amplify
        // Only keep bright spots to make distinct rays
        // Amplify: power * 2.0 makes it very reactive
        float rays = smoothstep(0.3, 0.9, n);
        
        // 5. Vertical Fade
        // Rays originate from top (0.0)
        // Base length 0.6 + power extends it to full screen
        float len = 0.6 + uniforms.power * 1.0;
        float fade = smoothstep(len, 0.0, uv.y);
        
        // 6. Intensity Calculation
        // Base brightness 0.6 (Always visible)
        // Boosted by power heavily (up to 2.0x brighter)
        float intensity = rays * fade * (0.6 + uniforms.power * 2.0);
        
        // Minimum glow floor so it never disappears
        intensity = max(intensity, 0.05 * fade); 
        
        // 7. Multi-Color Gradient (Auroral Corona)
        // Top: Purple/Magenta
        // Middle: Pink/Red
        // Bottom: Green/Teal (Base color)
        
        float3 baseCol = uniforms.color.rgb; // e.g. Teal/Green
        float3 midCol = float3(1.0, 0.2, 0.6); // Hot Pink
        float3 topCol = float3(0.5, 0.0, 1.0); // Deep Purple
        
        float3 layerCol = baseCol;
        
        // Mix colors based on height (uv.y)
        if (uv.y < 0.3) {
            // Top 30%: Mix Purple -> Pink
            layerCol = mix(topCol, midCol, uv.y / 0.3);
        } else if (uv.y < 0.6) {
            // Middle 30%: Mix Pink -> Base
            layerCol = mix(midCol, baseCol, (uv.y - 0.3) / 0.3);
        }
        
        // Additive accumulation
        finalColor += layerCol * intensity * 0.5;
    }
    
    // Global boost at the top edge to simulate the light source
    finalColor += float3(0.1, 0.0, 0.2) * (1.0 - uv.y) * 0.3;
    
    float alpha = length(finalColor);
    alpha = smoothstep(0.0, 1.0, alpha); // Soft clamp
    
    return float4(finalColor, saturate(alpha));
}
"""
