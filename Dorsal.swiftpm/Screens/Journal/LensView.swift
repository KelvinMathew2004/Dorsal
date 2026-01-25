import SwiftUI
import MetalKit

/// A view that applies a "Bubble Lens" effect.
/// - When `image` is nil (Generating): It runs a continuous, efficient Metal loop.
/// - When `image` is present (Static): It pauses to save battery, waking up only for brief animation bursts on tap or change.
struct LensView: View {
    let image: UIImage?
    var shadowColor: Color = .black
    
    @State private var time: Float = 0
    // Removed seed randomization on change to prevent "jumping" effect
    @State private var seed: Float = Float.random(in: 0...100)
    
    // Controls the temporary burst animation (for tap/load effects)
    @State private var isBurstAnimating: Bool = false
    
    // Used to restart the burst task
    @State private var burstTrigger: Int = 0
    
    // Computed helper
    var isGenerating: Bool {
        image == nil
    }
    
    var body: some View {
        LensMetalView(
            image: image,
            shadowColor: shadowColor,
            time: time,
            seed: seed,
            paused: !(isGenerating || isBurstAnimating) // Run if generating OR bursting
        )
        // This task manages the animation loop logic
        // It restarts if we switch modes (Generating <-> Static) or if a burst is triggered
        .task(id: isGenerating ? "generating" : "burst-\(burstTrigger)") {
            // MODE 1: Generating (Infinite Loop, constant speed)
            if isGenerating {
                while !Task.isCancelled {
                    // Slow breathing speed
                    time += 0.008
                    try? await Task.sleep(nanoseconds: 16_000_000)
                }
                return
            }
            
            // MODE 2: Burst Animation (Decaying Speed)
            // Triggered when image loads or on tap
            guard isBurstAnimating else { return }
            
            // CONFIGURATION: Breathing Effect
            // Start very slow (0.008) and decay very slowly (0.992)
            var velocity: Float = 0.008
            let friction: Float = 0.992
            let stopThreshold: Float = 0.0001
            
            // Run until velocity is negligible
            while velocity > stopThreshold {
                if Task.isCancelled { return }
                
                time += velocity
                velocity *= friction
                
                try? await Task.sleep(nanoseconds: 16_000_000)
            }
            
            // Clean up state after burst finishes
            if !Task.isCancelled {
                withAnimation {
                    isBurstAnimating = false
                }
            }
        }
        .onChange(of: image) { _ in
            // If we transitioned to a valid image, trigger a "Spin Down" burst
            if image != nil {
                triggerBurst()
            }
        }
        .onAppear {
            // Trigger burst on initial load if image exists (Open View)
            if image != nil {
                triggerBurst()
            }
        }
        .onTapGesture {
            triggerBurst()
        }
    }
    
    func triggerBurst() {
        // If we are generating, we are already animating, so no need to trigger a burst
        guard !isGenerating else { return }
        
        isBurstAnimating = true
        burstTrigger += 1
    }
}

// MARK: - Metal View Representative

struct LensMetalView: UIViewRepresentable {
    let image: UIImage?
    let shadowColor: Color
    let time: Float
    let seed: Float
    let paused: Bool
    
    func makeUIView(context: Context) -> MTKView {
        let mtkView = MTKView()
        mtkView.device = MTLCreateSystemDefaultDevice()
        mtkView.delegate = context.coordinator
        mtkView.backgroundColor = .clear
        mtkView.enableSetNeedsDisplay = true
        
        // Start paused
        mtkView.isPaused = paused
        
        mtkView.framebufferOnly = false
        mtkView.autoResizeDrawable = true
        mtkView.contentMode = .scaleAspectFit
        
        context.coordinator.configurePipeline(for: mtkView)
        
        if let device = mtkView.device {
            context.coordinator.updateTexture(image: image, device: device)
        }
        
        return mtkView
    }
    
    func updateUIView(_ uiView: MTKView, context: Context) {
        if context.coordinator.currentImage !== image {
            if let device = uiView.device {
                context.coordinator.updateTexture(image: image, device: device)
            }
        }
        
        context.coordinator.updateState(time: time, seed: seed, shadowColor: shadowColor)
        
        // Toggle the render loop
        uiView.isPaused = paused
        
        // CRITICAL: Force one last redraw when pausing so it doesn't freeze on an empty frame
        if paused {
            uiView.setNeedsDisplay()
        }
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
        var currentShadowRGB: SIMD3<Float> = SIMD3(0, 0, 0)
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
                                      constant float& seed [[buffer(3)]],
                                      constant float3& shadowColor [[buffer(4)]]) {
            
            constexpr sampler s(address::clamp_to_edge, filter::linear);
            
            float2 uv = in.uv;
            float2 fragCoord = uv * resolution;
            
            float2 uvLens = fragCoord / resolution.x;
            float2 lensCenter = float2(0.5, 0.5 * resolution.y / resolution.x);
            
            // --- Organic Bubble Shape Logic ---
            float2 d = uvLens - lensCenter;
            float angle = atan2(d.y, d.x);
            float dist = length(d);
            
            float freq1 = 3.0; 
            float freq2 = 5.0; 
            
            // FAST Animation Speed
            float shapeTime = time * 2.0; 
            
            float perturbation = 0.015 * sin(angle * freq1 + seed + shapeTime) + 
                                 0.010 * cos(angle * freq2 + seed * 2.0 - shapeTime);
            
            // INCREASED RADIUS to reduce cropping
            // Base radius 0.47 + perturbation -> Max ~0.495 (nearly touches edge of 0.5)
            float r = 0.47 + perturbation; 
            
            if (dist < r) {
                float normDist = dist / r;
                
                // Sphere Normal
                float z = sqrt(max(0.0, 1.0 - normDist * normDist));
                float3 normal = normalize(float3(d.x, -d.y, z * 0.6));
                
                float3 viewDir = float3(0.0, 0.0, 1.0);

                // Base Color
                float4 baseColor;
                
                if (isGenerating > 0.5) {
                    // Procedural Gradient
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
                    // Chromatic Aberration
                    float shiftStrength = 0.015 * pow(normDist, 2.0);
                    float2 shift = normalize(d) * shiftStrength;
                    
                    // SCALE TEXTURE TO FIT (Slight Zoom Out)
                    // 1.05 scales the image down slightly so edges fit comfortably in the larger bubble
                    float textureScale = 1.05;
                    float2 centeredUV = uv - 0.5;
                    float2 textureUV = centeredUV * textureScale + 0.5;
                    
                    float rCh = texture.sample(s, textureUV - shift).r;
                    float gCh = texture.sample(s, textureUV).g;
                    float bCh = texture.sample(s, textureUV + shift).b;
                    
                    baseColor = float4(rCh, gCh, bCh, 1.0);
                }
                
                // Lighting & Iridescence
                float fresnelTerm = 1.0 - max(0.0, dot(normal, viewDir));
                float rimPower = pow(fresnelTerm, 2.5);
                float3 rainbow = 0.5 + 0.5 * cos(6.28318 * (float3(1.0, 1.0, 1.0) * fresnelTerm + float3(0.0, 0.33, 0.67)));
                
                float3 finalColor = baseColor.rgb;
                finalColor += rainbow * rimPower * 0.6;
                
                // VIGNETTE: Tint edges with shadowColor
                // vignetteFactor: 1.0 at center, 0.0 at edge (r)
                // The range [1.0, 0.75] controls the thickness of the inner shadow
                float vignetteFactor = smoothstep(1.0, 0.75, normDist);
                
                // Mix: when factor is 0 (edge), show shadowColor. When 1 (center), show finalColor.
                finalColor = mix(shadowColor, finalColor, vignetteFactor);
                
                // EDGE ALPHA: Wider smoothstep range = thicker soft edge
                float alpha = smoothstep(r, r - 0.05, dist);
                
                return float4(finalColor, alpha);
                
            } else {
                return float4(0.0, 0.0, 0.0, 0.0);
            }
        }
        """
        
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
        
        func updateState(time: Float, seed: Float, shadowColor: Color) {
            self.currentTime = time
            self.currentSeed = seed
            
            // Convert Color to RGB Float
            let uiColor = UIColor(shadowColor)
            var r: CGFloat = 0
            var g: CGFloat = 0
            var b: CGFloat = 0
            var a: CGFloat = 0
            uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
            self.currentShadowRGB = SIMD3(Float(r), Float(g), Float(b))
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
            
            // Pass Shadow Color
            var shadowUniform = currentShadowRGB
            encoder.setFragmentBytes(&shadowUniform, length: MemoryLayout<SIMD3<Float>>.stride, index: 4)
            
            encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
            encoder.endEncoding()
            commandBuffer.present(drawable)
            commandBuffer.commit()
        }
    }
}
