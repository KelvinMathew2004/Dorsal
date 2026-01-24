import SwiftUI
import MetalKit

/// A view that applies a static "Bubble Lens" effect with chromatic aberration and iridescence.
/// If an image is provided, it applies the effect to the image.
/// If image is nil, it generates a dynamic gradient inside the lens (for loading states).
struct LensView: View {
    let image: UIImage?
    
    @State private var time: Float = 0
    
    // Generates a random seed for the bubble shape.
    // Initialized randomly, and updated whenever the image changes.
    @State private var seed: Float = Float.random(in: 0...100)
    
    let timer = Timer.publish(every: 1/60, on: .main, in: .common).autoconnect()
    
    var body: some View {
        LensMetalView(
            image: image,
            time: time,
            seed: seed
        )
        .onReceive(timer) { _ in
            time += 0.016
        }
        .onChange(of: image) { _ in
            // Generate a new unique shape when the content changes
            seed = Float.random(in: 0...100)
        }
    }
}

// MARK: - Metal View Representative

struct LensMetalView: UIViewRepresentable {
    let image: UIImage?
    let time: Float
    let seed: Float
    
    func makeUIView(context: Context) -> MTKView {
        let mtkView = MTKView()
        mtkView.device = MTLCreateSystemDefaultDevice()
        mtkView.delegate = context.coordinator
        mtkView.backgroundColor = .clear
        mtkView.enableSetNeedsDisplay = true
        mtkView.isPaused = false
        mtkView.framebufferOnly = false
        mtkView.autoResizeDrawable = true
        mtkView.contentMode = .scaleAspectFit
        
        // Initialize Pipeline ONCE
        context.coordinator.configurePipeline(for: mtkView)
        
        // Set initial image
        if let device = mtkView.device {
            context.coordinator.updateTexture(image: image, device: device)
        }
        
        return mtkView
    }
    
    func updateUIView(_ uiView: MTKView, context: Context) {
        // Only update texture if image instance changed
        if context.coordinator.currentImage !== image {
            if let device = uiView.device {
                context.coordinator.updateTexture(image: image, device: device)
            }
        }
        context.coordinator.updateState(time: time, seed: seed)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, MTKViewDelegate {
        var commandQueue: MTLCommandQueue?
        var pipelineState: MTLRenderPipelineState?
        var texture: MTLTexture?
        var currentImage: UIImage?
        
        var currentTime: Float = 0
        var currentSeed: Float = 0
        var isGenerating: Float = 0
        
        let shaderSource = """
        #include <metal_stdlib>
        using namespace metal;

        struct VertexOut {
            float4 position [[position]];
            float2 uv;
        };
        
        vertex VertexOut vertex_main(uint vertexID [[vertex_id]]) {
            float2 positions[4] = { float2(-1, -1), float2(1, -1), float2(-1, 1), float2(1, 1) };
            float2 uvs[4] = { float2(0, 0), float2(1, 0), float2(0, 1), float2(1, 1) };
            
            VertexOut out;
            out.position = float4(positions[vertexID], 0, 1);
            out.uv = uvs[vertexID];
            return out;
        }

        fragment float4 fragment_main(VertexOut in [[stage_in]],
                                      texture2d<float> texture [[texture(0)]],
                                      constant float& time [[buffer(0)]],
                                      constant float2& resolution [[buffer(1)]],
                                      constant float& isGenerating [[buffer(2)]],
                                      constant float& seed [[buffer(3)]]) {
            
            constexpr sampler s(address::clamp_to_edge, filter::linear);
            
            float2 uv = in.uv;
            float2 fragCoord = uv * resolution;
            
            float2 uvLens = fragCoord / resolution.x;
            float2 lensCenter = float2(0.5, 0.5 * resolution.y / resolution.x);
            
            // --- Organic Bubble Shape Logic ---
            float2 d = uvLens - lensCenter;
            float angle = atan2(d.y, d.x);
            float dist = length(d);
            
            // FIX OUTLINE GLITCHES:
            // Ensure frequencies are Integers so sin(angle) connects seamlessly at -PI/PI
            float freq1 = 3.0; // Integer
            float freq2 = 5.0; // Integer
            
            // Perturbation with seed-based phase shift, but integer frequency
            float perturbation = 0.015 * sin(angle * freq1 + seed) + 
                                 0.010 * cos(angle * freq2 + seed * 2.0);
                                 
            float r = 0.44 + perturbation; 
            
            if (dist < r) {
                float normDist = dist / r;
                
                // --- 2. Surface Normal Calculation ---
                // Model as sphere for lighting
                float z = sqrt(max(0.0, 1.0 - normDist * normDist));
                float3 normal = normalize(float3(d.x, -d.y, z * 0.6));
                
                // Light setup
                float3 viewDir = float3(0.0, 0.0, 1.0);

                // --- 3. Base Color with Chromatic Aberration ---
                float4 baseColor;
                
                if (isGenerating > 0.5) {
                    // Procedural Gradient (Liquidy)
                    float3 c1 = float3(1.0, 0.6, 0.0);
                    float3 c2 = float3(0.6, 0.2, 0.9);
                    float3 c3 = float3(0.0, 0.4, 1.0);
                    float2 p = uv * 2.0 - 1.0;
                    float n1 = sin(p.x * 2.0 + time * 0.5) * 0.5 + 0.5;
                    float n2 = cos(p.y * 3.0 + time * 0.8) * 0.5 + 0.5;
                    float n3 = sin((p.x + p.y) * 4.0 - time) * 0.5 + 0.5;
                    float3 col = mix(c1, c2, n1);
                    col = mix(col, c3, n2);
                    col = mix(col, c1, n3 * 0.5);
                    baseColor = float4(col, 1.0);
                } else {
                    // CHROMATIC ABERRATION:
                    // Separate channels based on radial distance/normal
                    // This creates the refractive fringe effect
                    float shiftStrength = 0.015 * pow(normDist, 2.0); // Stronger at edges
                    float2 shift = normalize(d) * shiftStrength;
                    
                    float rCh = texture.sample(s, uv - shift).r;
                    float gCh = texture.sample(s, uv).g;
                    float bCh = texture.sample(s, uv + shift).b;
                    
                    baseColor = float4(rCh, gCh, bCh, 1.0);
                }
                
                // --- 4. BUBBLE LIGHTING & IRIDESCENCE ---
                
                // Fresnel Rim Light
                float fresnelTerm = 1.0 - max(0.0, dot(normal, viewDir));
                float rimPower = pow(fresnelTerm, 2.5);
                
                // Iridescence (Thin Film Interference)
                // Generate a rainbow gradient based on the fresnel angle (Cosine Palette)
                float3 rainbow = 0.5 + 0.5 * cos(6.28318 * (float3(1.0, 1.0, 1.0) * fresnelTerm + float3(0.0, 0.33, 0.67)));
                
                // --- 5. Composite ---
                float3 finalColor = baseColor.rgb;
                
                // Add Iridescent Rim
                finalColor += rainbow * rimPower * 0.6;
                
                // REMOVED: Specular Highlight (The white reflection)
                
                // --- 6. Anti-aliasing ---
                float alpha = smoothstep(r, r - 0.02, dist);
                
                return float4(finalColor, alpha);
                
            } else {
                return float4(0.0, 0.0, 0.0, 0.0);
            }
        }
        """
        
        // 1. New function to configure pipeline ONCE
        func configurePipeline(for view: MTKView) {
            guard let device = view.device else { return }
            commandQueue = device.makeCommandQueue()
            
            do {
                let library = try device.makeLibrary(source: shaderSource, options: nil)
                let pipelineDescriptor = MTLRenderPipelineDescriptor()
                pipelineDescriptor.vertexFunction = library.makeFunction(name: "vertex_main")
                pipelineDescriptor.fragmentFunction = library.makeFunction(name: "fragment_main")
                pipelineDescriptor.colorAttachments[0].pixelFormat = view.colorPixelFormat
                
                pipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
                pipelineDescriptor.colorAttachments[0].rgbBlendOperation = .add
                pipelineDescriptor.colorAttachments[0].alphaBlendOperation = .add
                pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
                pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
                pipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .one
                pipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
                
                pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
            } catch {
                print("Shader compilation error: \(error)")
            }
        }
        
        // 2. New function to update only the texture/image data
        func updateTexture(image: UIImage?, device: MTLDevice) {
            self.currentImage = image
            
            if let image = image, let cgImage = image.cgImage {
                isGenerating = 0.0
                let loader = MTKTextureLoader(device: device)
                do {
                    texture = try loader.newTexture(cgImage: cgImage, options: [
                        .origin: MTKTextureLoader.Origin.bottomLeft,
                        .SRGB: false
                    ])
                } catch { print("Texture loading error: \(error)") }
            } else {
                isGenerating = 1.0
                let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: 1, height: 1, mipmapped: false)
                descriptor.usage = [.shaderRead]
                texture = device.makeTexture(descriptor: descriptor)
            }
        }
        
        func updateState(time: Float, seed: Float) {
            self.currentTime = time
            self.currentSeed = seed
        }
        
        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
        
        func draw(in view: MTKView) {
            guard let drawable = view.currentDrawable,
                  let pipelineState = pipelineState,
                  let commandBuffer = commandQueue?.makeCommandBuffer(),
                  let rpd = view.currentRenderPassDescriptor else { return }
            
            rpd.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
            
            guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: rpd) else { return }
            
            encoder.setRenderPipelineState(pipelineState)
            if let texture = texture { encoder.setFragmentTexture(texture, index: 0) }
            
            var timeUniform = currentTime
            encoder.setFragmentBytes(&timeUniform, length: MemoryLayout<Float>.stride, index: 0)
            
            var res = SIMD2<Float>(Float(view.drawableSize.width), Float(view.drawableSize.height))
            encoder.setFragmentBytes(&res, length: MemoryLayout<SIMD2<Float>>.stride, index: 1)
            
            var genUniform = isGenerating
            encoder.setFragmentBytes(&genUniform, length: MemoryLayout<Float>.stride, index: 2)
            
            var seedUniform = currentSeed
            encoder.setFragmentBytes(&seedUniform, length: MemoryLayout<Float>.stride, index: 3)
            
            encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
            encoder.endEncoding()
            commandBuffer.present(drawable)
            commandBuffer.commit()
        }
    }
}
