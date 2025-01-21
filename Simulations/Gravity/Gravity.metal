//
//  Gravity.metal
//  Simulations
//
//

#include <metal_stdlib>
#define eps 0.0000001
using namespace metal;

struct PtMass {
    float2 position, velocity;
    float mass;
    bool fixed, collides;
};

struct GravityUniforms {
    int numMasses;
    float2 resolution;
    float scale, G, dt, collisionDist;
    bool bounce;
};

vertex float4 gravity_vertex(uint vertexID [[vertex_id]]) {
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

float2 b2bInteraction_acceleration(float2 posA, float2 posB, float massB, float2 accA) {
    float2 r_ab = posB - posA;
    float distSq = dot(r_ab, r_ab) + eps*eps;
    float distSixth = distSq*distSq*distSq;
    float invDistCube = 1.0/sqrt(distSixth);
    float s = massB * invDistCube;
    return accA + s * r_ab;
}
    

kernel void gravity_mass_compute(device PtMass *masses [[buffer(1)]],
                                 constant GravityUniforms &uniforms [[buffer(0)]],
                                 uint2 gid [[thread_position_in_grid]]) {
    uint index = gid.x + gid.y * uniforms.resolution.x;
    if (index >= uniforms.numMasses) return;
    PtMass mass = masses[index];
    float mm = mass.mass;
    if (mm == 0.0 || mass.fixed) return;
    float2 mv = mass.velocity;
    float2 mp = mass.position;
    float dt = uniforms.dt;
    float G = uniforms.G;

    auto computeAcceleration = [&](float2 pos) -> float2 {
        float2 force = float2(0.0);
        for (int i = 0; i < uniforms.numMasses; i++) {
            if (i == index) continue;
            float2 r = masses[i].position - pos;
            float distSq = dot(r, r);
            float f = masses[i].mass / (distSq + 0.0001);
            force += f * normalize(r);
        }
        force *= -G;
        return force;
    };
    
    // range kutta
    float2 k1_v = mv;
    float2 k1_a = computeAcceleration(mp);
    
    float2 k2_v = mv + 0.5 * k1_a * dt;
    float2 k2_a = computeAcceleration(mp + 0.5 * k1_v * dt);
    
    float2 k3_v = mv + 0.5 * k2_a * dt;
    float2 k3_a = computeAcceleration(mp + 0.5 * k2_v * dt);
    
    float2 k4_v = mv + k3_a * dt;
    float2 k4_a = computeAcceleration(mp + k3_v * dt);
    
    mass.position += (k1_v + 2.0 * k2_v + 2.0 * k3_v + k4_v) * dt / 6.0;
    mass.velocity += (k1_a + 2.0 * k2_a + 2.0 * k3_a + k4_a) * dt / 6.0;
    
    masses[index] = mass;
}

kernel void gravity_collisions(device PtMass *masses [[buffer(1)]],
                               device PtMass *postMasses [[buffer(2)]],
                                 constant GravityUniforms &uniforms [[buffer(0)]],
                               uint2 gid [[thread_position_in_grid]]) {
    uint index = gid.x + gid.y * uniforms.resolution.x;
    if (index >= uniforms.numMasses) return;
    PtMass mass = masses[index];
    if (mass.mass == 0.0) return;
    if (!mass.collides) {
        postMasses[index] = mass;
        return;
    }
    
    // Loop through all the masses to check for collisions
    for (int i = 0; i < uniforms.numMasses; i++) {
        if (uint(i) == index || masses[i].mass == 0.0 || !masses[i].collides) continue;

        float2 r = mass.position - masses[i].position;
        float dist = length(r);

        if (dist < uniforms.collisionDist) {
            float isLowerIndex = step(float(i), float(index));
            float invIsLowerIndex = 1.0 - isLowerIndex;

            float combinedMass = mass.mass + masses[i].mass;
            float2 newVelocity = (mass.velocity * mass.mass + masses[i].velocity * masses[i].mass) / combinedMass;
            
            // 0.8 is for energy loss
            mass.velocity = newVelocity * 0.8 * invIsLowerIndex + mass.velocity * isLowerIndex;
            mass.mass = combinedMass * invIsLowerIndex;
            mass.fixed = masses[i].fixed || mass.fixed;
        }
    }

    
    postMasses[index] = mass;
}

kernel void gravity_collisions_copy(device PtMass *masses [[buffer(1)]],
                                    device PtMass *postMasses [[buffer(2)]],
                                    constant GravityUniforms &uniforms [[buffer(0)]],
                                    uint2 gid [[thread_position_in_grid]]) {
    uint index = gid.x + gid.y * uniforms.resolution.x;
    if (index >= uniforms.numMasses) return;
    masses[index] = postMasses[index];
}

kernel void gravity_field_compute(texture2d<float, access::read_write> field [[texture(0)]],
                                 constant GravityUniforms &uniforms [[buffer(0)]],
                                constant PtMass *masses [[buffer(1)]],
                               uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= uniforms.resolution.x || gid.y >= uniforms.resolution.y) {
        return;
    }
    float2 position = float2(gid)*uniforms.scale;
    
    float tot_force = 0.0;
    
    const float G = uniforms.G;
    
    // iterate through all the masses
    for (int i = 0; i < uniforms.numMasses; i++) {
        float2 accel = b2bInteraction_acceleration(position, masses[i].position, masses[i].mass, float2(0.0));
        tot_force += length(accel);
    }
    tot_force *= G;

    field.write(tot_force, gid);
}

float cmap(float val) {
//    return step(0.0, val) * 0.294*exp(0.01*val*exp(-0.003*(val + 1.9))) * step(val, 333.0) + 1.0 * step(333.0, val);
    return 0.294*exp(0.01*val*exp(-0.003*(val + 1.9))) * step(val, 333.0) + 1.0 * step(333.0, val);
}

fragment float4 gravity_fragment(float4 fragCoord [[position]],
                                 texture2d<float, access::read> field [[texture(0)]],
                                 constant GravityUniforms &uniforms [[buffer(0)]]) {
    // get the position of the current fragment
    float val = field.read(uint2(fragCoord.xy)).r;
    if (val < 0.0) return float4(float3(-val*.8), 1);
    return float4(float3(cmap(val)), 1.0);
}
