//
//  Electrostatic.metal
//  Simulations
//

#include <metal_stdlib>
#define eps 0.0000001
#define PI 3.14159265359
#define TWO_PI 6.28318530718
using namespace metal;

struct ESUniforms {
    float2 resolution, dimensions;
    float scale, dt, k;
    float padding;
    int numCharges;
};

struct Charge {
    float2 position, velocity;
    float charge;
    bool fixed;
    float3 padding;
};

vertex float4 es_vertex(uint vertexID [[vertex_id]]) {
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

kernel void es_charge_compute(device Charge *charges [[buffer(1)]],
                                 constant ESUniforms &uniforms [[buffer(0)]],
                                 uint2 gid [[thread_position_in_grid]]) {
    uint index = gid.x + gid.y * uniforms.resolution.x;
    if (index >= uniforms.numCharges) return;
    Charge charge = charges[index];
    float currCharge = charge.charge;
    if (charge.fixed) return;
    float2 cv = charge.velocity;
    float2 cp = charge.position;
    float dt = uniforms.dt;
    float k = uniforms.k;

    auto computeAcceleration = [&](float2 fromPos) -> float2 {
        float2 totForce = float2(0.0);
        for (int i = 0; i < uniforms.numCharges; i++) {
            if (i == index) continue;
            // compute each charge's force/attraction to the current charge using Coulomb's Law
            Charge otherCharge = charges[i];
            float2 r_ab = otherCharge.position - fromPos;
            float distSq = dot(r_ab, r_ab) + eps*eps;
            float force = otherCharge.charge / distSq;
            totForce += force * normalize(r_ab);
        }
        
        totForce *= -k * currCharge;
        return totForce;
    };
    
    // range kutta
    float2 k1_v = cv;
    float2 k1_a = computeAcceleration(cp);
    
    float2 k2_v = cv + 0.5 * k1_a * dt;
    float2 k2_a = computeAcceleration(cp + 0.5 * k1_v * dt);
    
    float2 k3_v = cv + 0.5 * k2_a * dt;
    float2 k3_a = computeAcceleration(cp + 0.5 * k2_v * dt);
    
    float2 k4_v = cv + k3_a * dt;
    float2 k4_a = computeAcceleration(cp + k3_v * dt);
    
    charge.position += (k1_v + 2.0 * k2_v + 2.0 * k3_v + k4_v) * dt / 6.0;
    charge.velocity += (k1_a + 2.0 * k2_a + 2.0 * k3_a + k4_a) * dt / 6.0;
    
    charges[index] = charge;
}

kernel void es_field_compute(texture2d<float, access::read_write> field [[texture(0)]],
                                  constant ESUniforms &uniforms [[buffer(0)]],
                                  constant Charge *masses [[buffer(1)]],
                                  uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= uniforms.resolution.x || gid.y >= uniforms.resolution.y) {
        return;
    }
    float2 position = float2(gid)*uniforms.scale;
    
    const float k = uniforms.k;
    
    // electric field at the current pixel, x and y components
    float2 cfield = float2(0.0);
    
    // iterate through all the charges, calculate the electric field and direction at the current pixel
//    for (int i = 0; i < uniforms.numCharges; i++) {
//        Charge charge = masses[i];
//        float2 r_ab = charge.position - position;
//        float distSq = dot(r_ab, r_ab) + eps*eps;
//        float force = charge.charge / distSq;
//        cfield += force * normalize(r_ab);
//    }
    
    cfield *= k;
    
    // convert cfield x and y to magnitude and direction
    cfield.x = length(cfield);
    cfield.y = atan2(cfield.y, cfield.x);

    field.write(cfield.x, gid);
}

float3 hsv2rgb(float3 c ){
    float4 K = float4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    float3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}


float3 cmap(float2 point) {
    // point.x is the magnitude of the electric field at the current pixel (radius)
    // point.y is the direction of the electric field at the current pixel (atan2)
    
    // the magnitude of the electric field is the brightness of the pixel
    // the direction of the electric field is the hue of the pixel
//    float radius = step(0.0, point.x) * 0.294*exp(0.01*point.x*exp(-0.003*(point.x + 1.9))) * step(point.x, 333.0) + 1.0 * step(333.0, point.x);
    float hue = point.y / TWO_PI;
    float sat = exp(-0.01 * point.x);
    float val = 0.5 + 0.5 * tanh(5.0 * point.x);
    return hsv2rgb(float3(hue, sat, 1.0));

    
//    return step(0.0, val) * 0.294*exp(0.01*val*exp(-0.003*(val + 1.9))) * step(val, 333.0) + 1.0 * step(333.0, val);
//    return 0.294*exp(0.01*val*exp(-0.003*(val + 1.9))) * step(val, 333.0) + 1.0 * step(333.0, val);
}

fragment float4 es_fragment(float4 position [[position]],
                            constant ESUniforms &uniforms [[buffer(0)]],
                            device Charge *charges [[buffer(1)]]) {
    const float k = uniforms.k;
    
    // electric field at the current pixel, x and y components
    float2 cfield = float2(0.0);
    
    const int numCharges = uniforms.numCharges;
    for (int i = 0; i < numCharges; i++){
        Charge charge = charges[i];
        float2 r_ab = charge.position - float2(position.xy);
        float distSq = dot(r_ab, r_ab) + eps*eps;
        float force = charge.charge / distSq;
        cfield += force * normalize(r_ab);
    }
    
    cfield *= -k;
    
    // convert cfield x and y to magnitude and direction
    float2 convert = float2(length(cfield), atan2(cfield.y, cfield.x));
    float3 color = cmap(convert);
    
    float val = -12*convert.x / (11 * convert.x + 1) + 1;
    float modded = fmod(val * 10.0, 1.0);
    
    //    float modulation = step(0.5, cos(0.05 * dot(position.xy, normalize(float2(cos(convert.y), sin(convert.y))))));
    color *= 1.0 - modded;
    return float4(color, 1.0);
}
