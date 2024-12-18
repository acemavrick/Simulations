//
//  Shader.metal
//  ShaderTest
//
//

#include <metal_stdlib>
#define PI 3.14159265359
#define u_res uniforms.resolution
#define u_time uniforms.time
using namespace metal;

struct Uniforms {
    float time;
    float2 resolution;
};

vertex float4 vertex_main(uint vertexID [[vertex_id]]) {
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

fragment float4 creation_silexars(float4 position [[position]],
                                  constant Uniforms& uniforms [[buffer(0)]]) {
    // https://www.pouet.net/prod.php?which=57245
    // Credits: Silexars, Danilo Guanabara
    // To test the setup
    
    float3 c;
    float l, z = u_time;
    for(int i = 0; i < 3; i++) {
        float2 uv, p = position.xy / u_res;
        uv = p;
        p -= 0.5;
        p.x *= u_res.x / u_res.y;
        z += 0.07;
        l = length(p);
        uv += p / l * (sin(z) + 1.0) * abs(sin(l * 9.0 - z - z));
        c[i] = 0.01 / length(fract(uv) - 0.5);
    }
    return float4(c / l, u_time);
}
