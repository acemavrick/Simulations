//
//  Wave.metal
//  Simulations
//  Simulates 2D waves according to the wave PDE, laplacian.
//

#include <metal_stdlib>

# define PI 3.1415
# define TPI 6.283

using namespace metal;

struct WaveUniforms {
    // for use in Wave Simulation
    float dx, dt, c, time, damper;
    float padding0;
    float2 resolution;
    float4 c0, c1, c2, c3, c4, c5, c6;
};


vertex float4 wave_vertex(uint vertexID [[vertex_id]]) {
    float4 positions[6] = {
        float4(-1.0, -1.0, 0.0, 1.0),
        float4( 1.0, -1.0, 0.0, 1.0),
        float4(-1.0,  1.0, 0.0, 1.0),
        float4(-1.0,  1.0, 0.0, 1.0),
        float4( 1.0, -1.0, 0.0, 1.0),
        float4( 1.0,  1.0, 0.0, 1.0)
    };
    return positions[vertexID];
}

// function to get a value from the Buffer
float get(device float2* buffer, int x, int y, float2 dims) {
    if (x < 0 || y < 0 || x >= dims.x || y >= dims.y) {
        return 0.0;
    }
    return buffer[int(x + y * dims.x)].x * step(1, buffer[int(x + y * dims.x)].y);
}

kernel void wave_compute(device float2* u_p [[buffer(0)]],
                         device float2* u_c [[buffer(1)]],
                         device float2* u_n [[buffer(2)]],
                         constant WaveUniforms &uniforms [[buffer(3)]],
                         uint2 gid [[thread_position_in_grid]]) {
    // fill out
    uint index = gid.y * uniforms.resolution.x + gid.x;
    if (index >= uniforms.resolution.x * uniforms.resolution.y) return;
    
    // y is whether it is blocked
    if (step(1, u_c[index].y) == 0.0){
        u_n[index].y = 0.0;
        return;
    }
    
//    if ( ((gid.x < 990) || (gid.x > 1010 && gid.x < 1100) || (gid.x > 1120)) && gid.y > 500 && gid.y < 800) {
//        u_n[index] = 0.0;
//        return;
//    }
    
//    if (gid.x == 1055 && gid.y == 1) {
//        u_n[index] = sin(uniforms.time*50.2)*15.002;
//        return;
//    }
    
    float laplacianMultiplier = uniforms.dx > 0.0 ? pow(uniforms.dt * uniforms.c / uniforms.dx, 2.0) : 0.0;
    float laplacian = laplacianMultiplier * (get(u_c, gid.x - 1, gid.y, uniforms.resolution) +
                                            get(u_c, gid.x + 1, gid.y, uniforms.resolution) +
                                            get(u_c, gid.x, gid.y - 1, uniforms.resolution) +
                                            get(u_c, gid.x, gid.y + 1, uniforms.resolution) - 4.0 * u_c[index].x);
    
    float val = laplacian + 2.0 * u_c[index].x - u_p[index].x;
    val *= uniforms.damper;
    u_n[index].x = val;
}

kernel void wave_copy(device float2* u_p [[buffer(0)]],
                      device float2* u_c [[buffer(1)]],
                      device float2* u_n [[buffer(2)]],
                      constant WaveUniforms &uniforms [[buffer(3)]],
                      uint2 gid [[thread_position_in_grid]]) {

    uint index = gid.y * uniforms.resolution.x + gid.x;
    if (index >= uniforms.resolution.x * uniforms.resolution.y) return;
    
    u_p[index] = u_c[index];
    u_c[index] = u_n[index];
}

float4 cmap(constant WaveUniforms &uniforms,
            float val) {
    return uniforms.c0 + val*(uniforms.c1 + val*(uniforms.c2 + val*(uniforms.c3 + val*(uniforms.c4 + val*(uniforms.c5 + val*uniforms.c6)))));
}

fragment float4 wave_fragment(float4 fragCoord [[position]],
                              constant WaveUniforms &uniforms [[buffer(0)]],
                              constant float2 *u [[buffer(1)]]) {
    uint2 loc = uint2(fragCoord.xy);
    uint2 i = uint2(clamp(loc, uint2(0), uint2(uniforms.resolution - 1)));
    
    // Get the value of the wave at the current pixel
    float2 val = u[i.x + i.y * uint(uniforms.resolution.x)].xy;
    return float4(cmap(uniforms, min(val.x, 1.0))) * step(1.0, val.y);
}

fragment float4 wave_fragment_grey(float4 fragCoord [[position]],
                              constant WaveUniforms &uniforms [[buffer(0)]],
                              constant float2 *u [[buffer(1)]]) {
    uint2 loc = uint2(fragCoord.xy);
    uint2 i = uint2(clamp(loc, uint2(0), uint2(uniforms.resolution - 1)));
    
    // Get the value of the wave at the current pixel
    float2 val = u[i.x + i.y * uint(uniforms.resolution.x)].xy;
    return float4(float3(val.x+0.5), 1.0) * step(1.0, val.y);
}

// converted from https://www.shadertoy.com/view/WtdXR8
fragment float4 wave_fragment_blank(float4 fragCoord [[position]],
                                    constant WaveUniforms &uniforms [[buffer(0)]]) {
    float2 res = uniforms.resolution;
    float2 uv =  (2.0 * fragCoord.xy - res.xy) / min(res.x, res.y);
    
    for( float i = 1.0; i < 10.0; i++){
        uv.x += 0.6 / i * cos(i * 2.5* uv.y + 42);
        uv.y += 0.6 / i * cos(i * 1.5 * uv.x + 42);
    }
    
    return float4(float3(0.1)/abs(sin(42-uv.y-uv.x)),1.0);
}
