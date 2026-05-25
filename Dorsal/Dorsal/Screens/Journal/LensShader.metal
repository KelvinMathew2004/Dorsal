#include <metal_stdlib>
using namespace metal;

struct LensVertexOut {
    float4 position [[position]];
    float2 uv;
};

vertex LensVertexOut lens_vertex_main(uint vertexID [[vertex_id]]) {
    float2 positions[4] = { float2(-1, -1), float2(1, -1), float2(-1, 1), float2(1, 1) };
    float2 uvs[4] = { float2(0, 0), float2(1, 0), float2(0, 1), float2(1, 1) };
    
    LensVertexOut out;
    out.position = float4(positions[vertexID], 0, 1);
    out.uv = uvs[vertexID];
    return out;
}

fragment float4 lens_fragment_main(LensVertexOut in [[stage_in]],
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