//
//  Wave.metal
//  Simulations
//  Simulates 2D waves according to the wave PDE, laplacian.
//

#include <metal_stdlib>

using namespace metal;

struct WaveSimUniforms {
    // for use in Wave Simulation
    float dx, dt, c;
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

float get(texture2d<float, access::read_write> t, uint x, uint y) {
    if (x >= t.get_width() || y >= t.get_height()) {
        return 0.0;
    }
    return t.read(uint2(x, y)).g;
}

kernel void wave_compute(texture2d<float, access::read_write> t [[texture(0)]],
                         constant WaveSimUniforms &uniforms [[buffer(0)]],
                         uint2 gid [[thread_position_in_grid]]) {
    
    // read from t, write to u_n
    if (gid.x >= uniforms.simSize.x || gid.y >= uniforms.simSize.y) {
        return;
    }
    
    float4 state = t.read(gid);
    float u_p = state.r;
    float u_c = state.g;
    
    float mult = uniforms.dx > 0.0 ? pow(uniforms.dt * uniforms.c / uniforms.dx, 2.0) : 0.0;
    /*
    [0 0 0 2 0 0 0,
     0 0 0 -27 0 0 0,
     0 0 0 270 0 0 0,
     2 -27 270 -490 270 -27 2,
        0 0 0 270 0 0 0,
        0 0 0 -27 0 0 0,
        0 0 0 2 0 0 0]
    */
    
//    float laplacian = mult * (
//    2*get(t, gid.x - 3, gid.y) - 27*get(t, gid.x - 2, gid.y) + 270*get(t, gid.x - 1, gid.y) +
//    2*get(t, gid.x, gid.y - 3) - 27*get(t, gid.x, gid.y - 2) + 270*get(t, gid.x, gid.y - 1) -
//    490*u_c + 270*get(t, gid.x, gid.y + 1) - 27*get(t, gid.x, gid.y + 2) + 2*get(t, gid.x, gid.y + 3) +
//    270*get(t, gid.x + 1, gid.y) - 27*get(t, gid.x + 2, gid.y) + 2*get(t, gid.x + 3, gid.y))/180.0;
    float laplacian = mult * (
    get(t, gid.x - 1, gid.y) - 4*u_c + get(t, gid.x + 1, gid.y) +
                              get(t, gid.x, gid.y - 1) + get(t, gid.x, gid.y + 1));
                              
    
    float calcVal = 2.0 * u_c - u_p + laplacian;
    state.b = calcVal;
    t.write(state, gid);
}

kernel void wave_copy(texture2d<float, access::read_write> t [[texture(0)]],
                      constant WaveSimUniforms &uniforms [[buffer(0)]],
                      uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= uniforms.simSize.x || gid.y >= uniforms.simSize.y) {
        return;
    }
    
    float4 state = t.read(gid);
    state.r = state.g;
    state.g = state.b;
    t.write(state, gid);
}

float3 cmap(constant WaveSimUniforms &uniforms,
            float val) {
    return uniforms.c0 + val*(uniforms.c1 + val*(uniforms.c2 + val*(uniforms.c3 + val*(uniforms.c4 + val*(uniforms.c5 + val*uniforms.c6)))));
}

fragment float4 wave_fragment(float4 fragCoord [[position]],
                              constant WaveSimUniforms &uniforms [[buffer(0)]],
                                texture2d<float, access::read> u_c [[texture(0)]]) {
    float2 loc = fragCoord.xy * uniforms.simSize / uniforms.resolution;
    float val = u_c.read(uint2(loc)).b;
    return float4(cmap(uniforms, min(val, 1.0)), 1.0);
}

fragment float4 wave_fragment_test(float4 fragCoord [[position]],
                                   constant WaveSimUniforms &uniforms [[buffer(0)]]) {
    float2 uv = fragCoord.xy / uniforms.resolution;
    float val = uv.x/uv.y;
    float3 color = mix(float3(0.0, 0.0, 1.0), float3(1.0, 0.0, 0.0), val);
    return float4(color, 1.0);
}
