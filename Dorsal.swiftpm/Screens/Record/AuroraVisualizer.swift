import SwiftUI
import MetalKit
#if canImport(UIKit)
import UIKit
#endif

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
            .opacity(isRecording ? 0.8 : 0.5)
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
        view.preferredFramesPerSecond = 60
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
    
    var startTime: Date = Date()
    var pausedTimeAccumulator: TimeInterval = 0
    var lastDrawTime: Date = Date()
    
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
            let library = try device.makeLibrary(source: AURORA_SHADER_SOURCE, options: nil)
            let vert = library.makeFunction(name: "vertex_main")
            let frag = library.makeFunction(name: "fragment_main")
            
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
              let pipeline = pipelineState else { return }
        
        currentPower += (targetPower - currentPower) * 0.1
        currentColor = mix(currentColor, targetColor, t: 0.05)
        
        let commandBuffer = commandQueue.makeCommandBuffer()!
        let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: desc)!
        
        encoder.setRenderPipelineState(pipeline)
        
        let now = Date()
        let deltaTime = Float(now.timeIntervalSince(lastDrawTime))
        
        if isPaused {
            pausedTimeAccumulator += Double(deltaTime)
        }
        
        let speedFactor: Float = 0.5
        let time = Float(now.timeIntervalSince(startTime) - pausedTimeAccumulator) * speedFactor
        
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
    float4 color; 
    float isRecording;
    float entranceFactor;
};

vertex VertexOut vertex_main(uint vertexID [[vertex_id]]) {
    VertexOut out;
    float2 pos[4] = { float2(-1, -1), float2(1, -1), float2(-1, 1), float2(1, 1) };
    float2 uv[4]  = { float2(0, 1), float2(1, 1), float2(0, 0), float2(1, 0) };
    
    out.position = float4(pos[vertexID], 0, 1);
    out.uv = uv[vertexID];
    return out;
}

constant float2x2 m2 = float2x2(float2(0.95534, 0.29552), float2(-0.29552, 0.95534));

float2x2 mm2(float a) {
    float c = cos(a), s = sin(a);
    return float2x2(float2(c, s), float2(-s, c));
}

float tri(float x) {
    return clamp(abs(fract(x) - 0.5), 0.01, 0.49);
}

float2 tri2(float2 p) {
    return float2(tri(p.x) + tri(p.y), tri(p.y + tri(p.x)));
}

float triNoise2d(float2 p, float spd, float time) {
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
        p = (m2 * -1.0) * p;
    }
    return clamp(1.0 / pow(rz * 29.0 + 0.05, 1.3), 0.0, 0.55);
}

float hash21(float2 n) {
    return fract(sin(dot(n, float2(12.9898, 4.1414))) * 43758.5453);
}

float4 aurora(float3 ro, float3 rd, float2 fragCoord, float time, float4 aurora_color, float power_input, float entrance_factor) {
    float4 col = float4(0);
    float4 avgCol = float4(0);
    
    float dropOffset = (1.0 - entrance_factor) * 5.0;
    
    for(float i=0.0; i<50.0; i++) {
        float of = 0.006 * hash21(fragCoord) * smoothstep(0.0, 15.0, i);
        float pt = ((0.8 + pow(i, 1.4) * 0.002) - ro.y) / (rd.y * 2.0 + 0.4);
        pt -= of;
        float3 bpos = ro + pt * rd;
        
        bpos.y += dropOffset;
        
        float2 p = bpos.zx * 0.4;
        p.x -= time * 0.08; 
        
        float rzt = triNoise2d(p, 0.06, time);
        float4 col2 = float4(0, 0, 0, rzt);

        float3 color_variation = (sin(1.0 - float3(2.15, -0.5, 1.2) + i * 0.043) * 0.5 + 0.5);
        col2.rgb = aurora_color.rgb * color_variation * rzt;

        avgCol = mix(avgCol, col2, 0.5);
        col += avgCol * exp2(-i * 0.065 - 2.5) * smoothstep(0.0, 5.0, i);
    }
    col *= (clamp(rd.y * 15.0 + 0.4, 0.0, 1.0));
    
    float baseIntensity = 0.15; 
    float finalIntensity = baseIntensity + power_input; 
    
    return col * (1.2 + finalIntensity) * entrance_factor;
}

fragment float4 fragment_main(VertexOut in [[stage_in]],
                              constant Uniforms& uniforms [[buffer(1)]]) {
    
    float2 iResolution = uniforms.resolution;
    
    float2 uv = (2.0 * in.position.xy - iResolution.xy) / iResolution.y;
    uv.y = -uv.y; 

    // MODIFIED: Horizon set to 0.4 (results in 70% sky, 30% water)
    // 2.0 * 0.7 - 1.0 = 0.4
    uv.y += 0.4; 

    float3 ro = float3(0, 0, -6.7);
    float3 rd = normalize(float3(uv, 1.3)); 
    
    float pitch = 0.0;
    float c = cos(pitch);
    float s = sin(pitch);
    float3x3 rotX = float3x3(1, 0, 0,  0, c, -s,  0, s, c);
    rd = rotX * rd;
    
    float fade = smoothstep(0.0, 0.01, abs(rd.y)) * 0.1 + 0.9;
    
    float4 user_aurora_color = uniforms.color; 
    float power_mod = uniforms.power * 5.0;
    float entrance = uniforms.entranceFactor;

    if (rd.y > 0.0) {
        float4 aurora_val = smoothstep(0.0, 1.5, aurora(ro, rd, in.position.xy, uniforms.time, user_aurora_color, power_mod, entrance));
        aurora_val *= fade;
        return aurora_val;
    } else {
        return float4(0.0);
    }
}
"""
