#include <metal_stdlib>
using namespace metal;

struct WarpVertexOut {
    float4 position [[position]];
    float4 color;
    float2 uv;
    float fade;
    float speed;
    float isWarping;
    float randomVal;
};

struct WarpUniforms {
    float time;
    float speed;
    float2 resolution;
    float4 tint;
};

struct WarpStarData {
    float angle;
    float radius;
    float zOffset;
    float4 color;
};

vertex WarpVertexOut warp_vertex_main(uint vertexID [[vertex_id]],
                             uint instanceID [[instance_id]],
                             constant WarpStarData* stars [[buffer(0)]],
                             constant WarpUniforms& uniforms [[buffer(1)]]) {
    
    WarpStarData star = stars[instanceID];
    WarpVertexOut out;
    
    // 1. Speed Calculation
    float effectiveSpeed = 0.1 + (uniforms.speed * 3.0);
    
    // Z Depth: 10.0 (Far) -> 0.0 (Near)
    float z = fmod(star.zOffset - (uniforms.time * effectiveSpeed), 10.0);
    if (z < 0) z += 10.0;
    
    // 3. Perspective
    float depth = max(z, 0.01);
    float perspective = 1.0 / depth;
    
    // 4. Position (Uniform Space - calculations in square space first)
    float x = cos(star.angle) * star.radius;
    float y = sin(star.angle) * star.radius;
    
    // posSq is in uniform coordinate space (Y is -1..1, X is proportional)
    float2 posSq = float2(x * perspective, y * perspective);
    
    // Aspect Ratio
    float aspect = uniforms.resolution.x / uniforms.resolution.y;
    
    // --- QUAD SIZE ---
    // Randomize size based on instanceID to prevent uniform look
    // Simple pseudo-random
    float rnd = fract(sin(float(instanceID) * 12.9898) * 43758.5453);
    
    // SIZE VARIATION: 0.5x to 1.2x (Smaller average)
    float sizeVariation = 0.5 + (rnd * 0.7);
    
    // REDUCED BASE SIZE (0.12 -> 0.07)
    float baseSize = 0.07 * perspective * sizeVariation;
    baseSize = max(0.002, min(baseSize, 0.15));
    
    float isWarping = step(1.0, uniforms.speed);
    
    // Streak Calculation
    float targetStreak = 1.0 + (isWarping * 10.0); 
    float currentStreak = mix(1.0, targetStreak, smoothstep(0.0, 5.0, uniforms.speed));
    
    float streakLen = baseSize * currentStreak;
    float width = baseSize * (isWarping > 0.5 ? 0.3 : 1.0);
    
    // Orientation (In Uniform Space)
    float2 dir = normalize(posSq);
    if (length(posSq) < 0.0001) dir = float2(0, 1);
    float2 perp = float2(-dir.y, dir.x);
    
    // Vertex Expansion (In Uniform Space)
    float2 offset = float2(0,0);
    float2 uv = float2(0,0);
    
    if (vertexID == 0) {      // Bottom Left
         offset = (-dir * streakLen) - (perp * width);
         uv = float2(0, 0);
    } else if (vertexID == 1) { // Bottom Right
         offset = (-dir * streakLen) + (perp * width);
         uv = float2(1, 0);
    } else if (vertexID == 2) { // Top Left
         offset = (dir * streakLen) - (perp * width); 
         uv = float2(0, 1);
    } else if (vertexID == 3) { // Top Right
         offset = (dir * streakLen) + (perp * width);
         uv = float2(1, 1);
    }
    
    // Apply offset to uniform position
    float2 finalPosSq = posSq + offset;
    
    // Convert to NDC (Divide X by Aspect Ratio to correct for screen shape)
    out.position = float4(finalPosSq.x / aspect, finalPosSq.y, 0.0, 1.0);
    
    out.uv = uv;
    out.speed = uniforms.speed;
    out.isWarping = isWarping;
    out.randomVal = rnd; 
    
    // --- FADE LOGIC ---
    
    // Distance Fade
    float alpha = 1.0 - (z / 10.0);
    alpha = max(0.0, alpha);
    
    // Near Clip Fade
    if (z < 0.2) alpha *= (z / 0.2);
    
    // Tint
    float4 c = mix(star.color, uniforms.tint, 0.3);
    
    out.color = c;
    out.fade = alpha;
    
    return out;
}

fragment float4 warp_fragment_main(WarpVertexOut in [[stage_in]]) {
    float alpha = 0.0;
    
    if (in.speed > 1.0) {
        // -- WARP MODE (Streaks) --
        
        // FEWER LINES
        if (in.randomVal > 0.5) {
            discard_fragment();
        }
        
        // Cross-section
        float distX = abs(in.uv.x - 0.5) * 2.0;
        float coreX = pow(max(0.0, 1.0 - distX), 3.0);
        
        float tail = in.uv.y; 
        
        alpha = coreX * tail * 0.6;
        
    } else {
        // -- NORMAL MODE (Stars) --
        
        float2 center = in.uv * 2.0 - 1.0;
        
        // RANDOM SHAPES based on rnd val
        
        if (in.randomVal < 0.5) {
            // Type A: Soft Circle (Standard)
            float dist = length(center);
            if (dist < 1.0) {
                alpha = pow(1.0 - dist, 4.0);
                alpha += pow(1.0 - dist, 10.0) * 0.5;
            }
        } else if (in.randomVal < 0.8) {
            // Type B: Diamond / 4-Point Star (Twinkle)
            // Manhattan distance |x| + |y| creates a diamond
            float dist = abs(center.x) + abs(center.y);
            if (dist < 1.0) {
                alpha = pow(1.0 - dist, 5.0);
                alpha += pow(1.0 - dist, 15.0); // Hot core
            }
        } else {
            // Type C: Sharp Point (Distant/Small)
            float dist = length(center);
            if (dist < 1.0) {
                alpha = pow(1.0 - dist, 8.0);
            }
        }
    }
    
    alpha = saturate(alpha) * in.fade;
    
    return float4(in.color.rgb, in.color.a * alpha);
}