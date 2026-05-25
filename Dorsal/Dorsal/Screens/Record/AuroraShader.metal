#include <metal_stdlib>
using namespace metal;

struct AuroraVertexOut {
    float4 position [[position]];
    float2 uv;
};

struct AuroraUniforms {
    float time;
    float2 resolution;
    float power;
    float4 color; 
    float isRecording;
    float entranceFactor;
};

vertex AuroraVertexOut aurora_vertex_main(uint vertexID [[vertex_id]]) {
    AuroraVertexOut out;
    float2 pos[4] = { float2(-1, -1), float2(1, -1), float2(-1, 1), float2(1, 1) };
    float2 uv[4]  = { float2(0, 1), float2(1, 1), float2(0, 0), float2(1, 0) };
    
    out.position = float4(pos[vertexID], 0, 1);
    out.uv = uv[vertexID];
    return out;
}

constant float2x2 aurora_m2 = float2x2(float2(0.95534, 0.29552), float2(-0.29552, 0.95534));

float2x2 aurora_mm2(float a) {
    float c = cos(a), s = sin(a);
    return float2x2(float2(c, s), float2(-s, c));
}

float aurora_tri(float x) {
    return clamp(abs(fract(x) - 0.5), 0.01, 0.49);
}

float2 aurora_tri2(float2 p) {
    return float2(aurora_tri(p.x) + aurora_tri(p.y), aurora_tri(p.y + aurora_tri(p.x)));
}

float aurora_triNoise2d(float2 p, float spd, float time) {
    float z = 1.8;
    float z2 = 2.5;
    float rz = 0.0;
    p = aurora_mm2(p.x * 0.06) * p;
    float2 bp = p;
    
    for (float i = 0.0; i < 5.0; i++) {
        float2 dg = aurora_tri2(bp * 1.85) * 0.75;
        dg = aurora_mm2(time * spd) * dg;
        p -= dg / z2;

        bp *= 1.3;
        z2 *= 0.45;
        z *= 0.42;
        p *= 1.21 + (rz - 1.0) * 0.02;

        rz += aurora_tri(p.x + aurora_tri(p.y)) * z;
        p = (aurora_m2 * -1.0) * p;
    }
    return clamp(1.0 / pow(rz * 29.0 + 0.05, 1.3), 0.0, 0.55);
}

float aurora_hash21(float2 n) {
    return fract(sin(dot(n, float2(12.9898, 4.1414))) * 43758.5453);
}

float4 aurora_render(float3 ro, float3 rd, float2 fragCoord, float time, float4 aurora_color, float power_input, float entrance_factor) {
    float4 col = float4(0);
    float4 avgCol = float4(0);
    
    float dropOffset = (1.0 - entrance_factor) * 5.0;
    
    for(float i=0.0; i<50.0; i++) {
        float of = 0.006 * aurora_hash21(fragCoord) * smoothstep(0.0, 15.0, i);
        float pt = ((0.8 + pow(i, 1.4) * 0.002) - ro.y) / (rd.y * 2.0 + 0.4);
        pt -= of;
        float3 bpos = ro + pt * rd;
        
        bpos.y += dropOffset;
        
        float2 p = bpos.zx * 0.4;
        p.x -= time * 0.08; 
        
        float rzt = aurora_triNoise2d(p, 0.06, time);
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

fragment float4 aurora_fragment_main(AuroraVertexOut in [[stage_in]],
                              constant AuroraUniforms& uniforms [[buffer(1)]]) {
    
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
        float4 aurora_val = smoothstep(0.0, 1.5, aurora_render(ro, rd, in.position.xy, uniforms.time, user_aurora_color, power_mod, entrance));
        aurora_val *= fade;
        return aurora_val;
    } else {
        return float4(0.0);
    }
}