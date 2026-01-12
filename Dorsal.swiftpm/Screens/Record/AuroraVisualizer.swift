import SwiftUI
import MetalKit
#if canImport(UIKit)
import UIKit
#endif

// MARK: - SWIFTUI VIEW
struct AuroraVisualizer: View {
    var power: Float      // Audio power
    var isPaused: Bool
    var color: Color = .cyan
    
    var body: some View {
        // Use a GeometryReader to ensure we fill the space provided
        GeometryReader { proxy in
            if MTLCreateSystemDefaultDevice() != nil {
                MetalAuroraView(
                    power: isPaused ? 0 : power,
                    color: color
                )
            } else {
                Color.black.opacity(0.8)
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
        context.coordinator.targetColor = color.toMetalSimd()
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
    
    var targetPower: Float = 0.0
    var currentPower: Float = 0.0
    var targetColor: SIMD4<Float> = SIMD4(0, 1, 1, 1)
    var currentColor: SIMD4<Float> = SIMD4(0, 1, 1, 1)
    
    struct Uniforms {
        var time: Float
        var resolution: SIMD2<Float>
        var power: Float
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
            
            // Standard Alpha Blending
            desc.colorAttachments[0].isBlendingEnabled = true
            desc.colorAttachments[0].rgbBlendOperation = .add
            desc.colorAttachments[0].alphaBlendOperation = .add
            desc.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
            desc.colorAttachments[0].destinationRGBBlendFactor = .one
            desc.colorAttachments[0].sourceAlphaBlendFactor = .one
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
        
        // Smooth power and color
        currentPower += (targetPower - currentPower) * 0.1
        currentColor = mix(currentColor, targetColor, t: 0.05)
        
        let commandBuffer = commandQueue.makeCommandBuffer()!
        let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: desc)!
        
        encoder.setRenderPipelineState(pipeline)
        
        let time = Float(Date().timeIntervalSince(startTime))
        let res = SIMD2<Float>(Float(view.drawableSize.width), Float(view.drawableSize.height))
        
        var uniforms = Uniforms(
            time: time,
            resolution: res,
            power: currentPower,
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

// MARK: - PRIVATE HELPER
private extension Color {
    func toMetalSimd() -> SIMD4<Float> {
        #if canImport(UIKit)
        let uiColor = UIColor(self)
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        return SIMD4(Float(r), Float(g), Float(b), Float(a))
        #else
        return SIMD4(0, 1, 1, 1)
        #endif
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
    float2 resolution;
    float power;
    float4 color; // User tint
};

vertex VertexOut vertex_main(uint vertexID [[vertex_id]]) {
    VertexOut out;
    float2 pos[4] = { float2(-1, -1), float2(1, -1), float2(-1, 1), float2(1, 1) };
    float2 uv[4]  = { float2(0, 1), float2(1, 1), float2(0, 0), float2(1, 0) };
    
    out.position = float4(pos[vertexID], 0, 1);
    out.uv = uv[vertexID];
    return out;
}

// --- PORTED GLSL FUNCTIONS ---

float2x2 mm2(float a) {
    float c = cos(a);
    float s = sin(a);
    return float2x2(c, s, -s, c);
}

float tri(float x) {
    return clamp(abs(fract(x) - 0.5), 0.01, 0.49);
}

float2 tri2(float2 p) {
    return float2(tri(p.x) + tri(p.y), tri(p.y + tri(p.x)));
}

// The core Aurora noise function
float fbmAurora(float2 p, float spd, float time) {
    float z = 1.8;
    float z2 = 2.5;
    float rz = 0.0;
    
    p = mm2(p.x * 0.06) * p;
    float2 bp = p;
    
    for (float i = 0.0; i < 5.0; i++) {
        float2 dg = tri2(bp * 1.85) * 0.75;
        dg = mm2(time * spd) * dg;
        p -= dg / z2;
        
        bp *= 1.3;
        z2 *= 0.45;
        z *= 0.42;
        p *= 1.21 + (rz - 1.0) * 0.02;
        
        rz += tri(p.x + tri(p.y)) * z;
        p *= sin(time * 0.05) * cos(time * 0.01);
    }
    
    return clamp(1.0 / pow(rz * 20.0, 1.3), 0.0, 1.0);
}

float hash21(float2 p) {
    p = fract(p * float2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

// Helper to mix 3 colors based on height t
float3 colorGradient(float t, float3 c1, float3 c2, float3 c3) {
    // t goes from 0.0 (bottom/near) to 1.0 (top/far)
    if (t < 0.5) {
        // Bottom half: Mix Green -> Purple
        return mix(c1, c2, t * 2.0); 
    } else {
        // Top half: Mix Purple -> Deep Blue
        return mix(c2, c3, (t - 0.5) * 2.0); 
    }
}

fragment float4 fragment_main(VertexOut in [[stage_in]],
                              constant Uniforms& uniforms [[buffer(1)]]) {
    
    // Normalize coordinates
    float2 p = (in.position.xy - 0.5 * uniforms.resolution) / uniforms.resolution.y;
    
    // Camera setup: Look up at the sky
    float3 ro = float3(0.0, -3.0, -5.0); 
    float3 rd = normalize(float3(p, 1.5));
    
    // Tilt camera up
    float pitch = 0.4; 
    float c = cos(pitch);
    float s = sin(pitch);
    float3x3 rotX = float3x3(1, 0, 0,  0, c, -s,  0, s, c);
    rd = rotX * rd;
    
    float4 col = float4(0.0);
    float4 avgCol = float4(0.0);
    
    float powerMult = 1.0 + uniforms.power * 2.0;
    
    // --- DEFINITIVE AURORA COLORS (Refined for "Purple Hues") ---
    // Bottom: Teal/Cyan (Oxygen)
    float3 colBottom = float3(0.0, 0.9, 0.8); 
    // Middle: Royal Purple (Nitrogen/Oxygen mix) - Dominant color
    float3 colMiddle = float3(0.6, 0.1, 0.9);
    // Top: Deep Indigo/Blue (High altitude)
    float3 colTop    = float3(0.1, 0.0, 0.5);
    
    // Minimal influence from user color to avoid washing out the palette
    // Only 10% mix
    colBottom = mix(colBottom, uniforms.color.rgb, 0.1);
    
    for (float i = 0.0; i < 30.0; i++) {
        float of = 0.006 * hash21(in.position.xy) * smoothstep(0.0, 15.0, i);
        
        // Raymarch
        float pt = ((0.8 + pow(i, 1.4) * 0.002)) / (rd.y * 2.0 + 0.4);
        pt -= of;
        
        float3 bpos = float3(5.5) + pt * rd;
        float2 noiseP = bpos.zx;
        
        float rz = fbmAurora(noiseP, 0.06, uniforms.time);
        
        // --- COLOR LOGIC FIX ---
        // 'i' goes from 0 to 30.
        // i=0 is bottom/nearest layer. i=30 is highest/farthest layer.
        float height = i / 30.0;
        
        // Apply gradient based on loop index (height)
        float3 palette = colorGradient(height, colBottom, colMiddle, colTop);
        
        float4 col2 = float4(0.0, 0.0, 0.0, rz);
        col2.rgb = palette * rz;
        
        avgCol = mix(avgCol, col2, 0.5);
        col += avgCol * exp2(-i * 0.065 - 2.5) * smoothstep(0.0, 5.0, i);
    }
    
    col *= (clamp(rd.y * 15.0 + 0.4, 0.0, 1.0));
    
    float3 finalC = pow(col.rgb, float3(1.0)) * 1.5 * powerMult;
    finalC = smoothstep(0.0, 1.0, finalC);
    
    float alpha = length(finalC);
    
    return float4(finalC, saturate(alpha));
}
"""
