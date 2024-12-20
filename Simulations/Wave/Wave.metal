//
//  Wave.metal
//  Simulations
//  Simulates 2D waves according to the wave PDE, laplacian.
//

#include <metal_stdlib>

using namespace metal;

struct WaveSimUniforms {
    // for use in Wave Simulation
    float dx, dt, c, time, damper;
    float2 resolution, simSize;
    float3 c0, c1, c2, c3, c4, c5, c6;
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
float get(device float* buffer, int x, int y, float2 dims) {
    if (x < 0 || y < 0 || x >= dims.x || y >= dims.y) {
        return 0.0;
    }
    return buffer[int(x + y * dims.x)];
}

kernel void wave_compute(device float* u_p [[buffer(0)]],
                         device float* u_c [[buffer(1)]],
                         device float* u_n [[buffer(2)]],
                         constant WaveSimUniforms &uniforms [[buffer(3)]],
                         uint2 gid [[thread_position_in_grid]]) {
    // fill out
    int index = int(gid.y * uniforms.simSize.x + gid.x);
    
    if (gid.x >= uniforms.simSize.x || gid.y >= uniforms.simSize.y) {
        return;
    }
    
    if (gid.x == uniforms.simSize.x/2 && gid.y == uniforms.simSize.y/2) {
        u_n[index] = sin(uniforms.time*3.0)*2.002;
        return;
    }
    
    float laplacianMultiplier = uniforms.dx > 0.0 ? pow(uniforms.dt * uniforms.c / uniforms.dx, 2.0) : 0.0;
    float laplacian = laplacianMultiplier * (get(u_c, gid.x - 1, gid.y, uniforms.simSize) +
                                            get(u_c, gid.x + 1, gid.y, uniforms.simSize) +
                                            get(u_c, gid.x, gid.y - 1, uniforms.simSize) +
                                            get(u_c, gid.x, gid.y + 1, uniforms.simSize) - 4.0 * u_c[index]);
    
    
    float val = laplacian + 2.0 * u_c[index] - u_p[index];
    val *= uniforms.damper;
    u_n[index] = val;
}

kernel void wave_copy(device float* u_p [[buffer(0)]],
                      device float* u_c [[buffer(1)]],
                        device float* u_n [[buffer(2)]],
                      constant WaveSimUniforms &uniforms [[buffer(3)]],
                      uint2 gid [[thread_position_in_grid]]) {
    uint width = uniforms.simSize.x;
    uint height = uniforms.simSize.y;
    
    int index = gid.y * width + gid.x;
    
    if (gid.x >= width || gid.y >= height) {
        return;
    }
    
    u_p[index] = u_c[index];
    u_c[index] = u_n[index];
    
}

float3 cmap(constant WaveSimUniforms &uniforms,
            float val) {
    return uniforms.c0 + val*(uniforms.c1 + val*(uniforms.c2 + val*(uniforms.c3 + val*(uniforms.c4 + val*(uniforms.c5 + val*uniforms.c6)))));
}

fragment float4 wave_fragment(float4 fragCoord [[position]],
                              constant WaveSimUniforms &uniforms [[buffer(0)]],
                              constant float *u [[buffer(1)]]) {
    float2 index = fragCoord.xy / uniforms.resolution;
    float2 simIndex = index * uniforms.simSize;
    
    uint2 i = uint2(clamp(simIndex, float2(0.0), uniforms.simSize - 1.0));
    
    // Get the value of the wave at the current pixel
    float val = u[i.x + i.y * uint(uniforms.simSize.x)];
    return float4(cmap(uniforms, min(val, 1.0)), 1.0);
}

fragment float4 wave_fragment_grey(float4 fragCoord [[position]],
                              constant WaveSimUniforms &uniforms [[buffer(0)]],
                              constant float *u [[buffer(1)]]) {
    uint2 loc = uint2(fragCoord.xy);
    uint2 i = uint2(clamp(loc, uint2(0), uint2(uniforms.simSize - 1)));
    
    // Get the value of the wave at the current pixel
    float val = u[i.x + i.y * uint(uniforms.simSize.x)];
    return float4(float3(val+0.5), 1.0);
}

fragment float4 wave_fragment_test(float4 fragCoord [[position]],
                                   constant WaveSimUniforms &uniforms [[buffer(0)]]) {
    float2 val = uniforms.resolution/uniforms.simSize;
//    float3 color = mix(float3(0.0, 0.0, 1.0), float3(1.0, 0.0, 0.0), val);
    return float4(val,0.0, 1.0);
}
