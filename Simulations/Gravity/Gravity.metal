//
//  Gravity.metal
//  Simulations
//
//  Created by Shubh Randeria on 12/21/24.
//

#include <metal_stdlib>
using namespace metal;

struct PtMass {
    float2 position, velocity;
    float mass;
};

struct GravityUniforms {
    int numMasses;
    float2 resolution, size;
    float G, dt, collisionDist;
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

kernel void gravity_mass_compute(device PtMass *masses [[buffer(1)]],
                                 constant GravityUniforms &uniforms [[buffer(0)]],
                                 uint2 gid [[thread_position_in_grid]]) {
    uint index = gid.x + gid.y * uniforms.size.x;
    if (index >= uniforms.numMasses) return;
    PtMass mass = masses[index];
    if (mass.mass == 0.0) return;
    
    auto computeAcceleration = [&](float2 pos) -> float2 {
        float2 force = float2(0.0);
        for (int i = 0; i < uniforms.numMasses; i++) {
            if (i == index || masses[i].mass == 0.0) continue;
            float2 r = masses[i].position - pos;
            if (length(r) < 0.1) continue;
            float distSq = dot(r, r);
            float f = uniforms.G * masses[i].mass * mass.mass / distSq;
            force += f * normalize(r);
        }
        return force / mass.mass;
    };
    
    // range kutta
    float2 k1_v = mass.velocity;
    float2 k1_a = computeAcceleration(mass.position);
    
    float2 k2_v = mass.velocity + 0.5 * k1_a * uniforms.dt;
    float2 k2_a = computeAcceleration(mass.position + 0.5 * k1_v * uniforms.dt);
    
    float2 k3_v = mass.velocity + 0.5 * k2_a * uniforms.dt;
    float2 k3_a = computeAcceleration(mass.position + 0.5 * k2_v * uniforms.dt);
    
    float2 k4_v = mass.velocity + k3_a * uniforms.dt;
    float2 k4_a = computeAcceleration(mass.position + k3_v * uniforms.dt);
    
    mass.position += (k1_v + 2.0 * k2_v + 2.0 * k3_v + k4_v) * uniforms.dt / 6.0;
    mass.velocity += (k1_a + 2.0 * k2_a + 2.0 * k3_a + k4_a) * uniforms.dt / 6.0;
    
    masses[index] = mass;
}

kernel void gravity_collisions(device PtMass *masses [[buffer(1)]],
                               device PtMass *postMasses [[buffer(2)]],
                                 constant GravityUniforms &uniforms [[buffer(0)]],
                               uint2 gid [[thread_position_in_grid]]) {
    uint index = gid.x + gid.y * uniforms.size.x;
    if (index >= uniforms.numMasses) return;
    PtMass mass = masses[index];
    if (mass.mass == 0.0) return;
    
    // loop through all the masses to check for collisions
    for (int i = 0; i < uniforms.numMasses; i++) {
        if (i == index) continue;
        if (masses[i].mass == 0.0) continue;
        float2 r = mass.position - masses[i].position;
        if (length(r) < uniforms.collisionDist) {
            if (index < i) {
                // lower index always processes the collision
                // merge the two masses and update the velocity
                mass.velocity = (mass.velocity * mass.mass + masses[i].velocity * masses[i].mass) / (mass.mass + masses[i].mass);
                mass.mass += masses[i].mass;
            } else {
                // if the index is higher, just set the mass to 0
                mass.mass = 0.0;
            }
        }
    }
    
    postMasses[index] = mass;
}

kernel void gravity_collisions_copy(device PtMass *masses [[buffer(1)]],
                                    device PtMass *postMasses [[buffer(2)]],
                                    constant GravityUniforms &uniforms [[buffer(0)]],
                                    uint2 gid [[thread_position_in_grid]]) {
    uint index = gid.x + gid.y * uniforms.size.x;
    if (index >= uniforms.numMasses) return;
    masses[index] = postMasses[index];
}

kernel void gravity_field_compute(texture2d<float, access::read_write> field [[texture(0)]],
                                 constant GravityUniforms &uniforms [[buffer(0)]],
                                constant PtMass *masses [[buffer(1)]],
                               uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= uniforms.size.x || gid.y >= uniforms.size.y) {
        return;
    }
    
    float curr = field.read(gid).r;
    
    float tot_force = 0.0;
    
    // iterate through all the masses
    for (int i = 0; i < uniforms.numMasses; i++) {
        float2 mpos = masses[i].position;
        if (uint(mpos.x) == gid.x && uint(mpos.y) == gid.y){
            tot_force = -1.0;
            break;
        }
        float r = distance(float2(gid), mpos);
        tot_force += uniforms.G * masses[i].mass / (r * r);
    }
    
    if (curr < 0.0 && tot_force > 0.0) {
        if (curr > -.0003) {
            curr = 0.0;
        }
        field.write(curr * 0.9997, gid);
//        field.write(curr * 1.0, gid);
        return;
    }

    field.write(tot_force, gid);
}

float map(float val) {
    return 1.0-exp(-val);
}

fragment float4 gravity_fragment(float4 fragCoord [[position]],
                                 texture2d<float, access::read> field [[texture(0)]],
                                 constant GravityUniforms &uniforms [[buffer(0)]]) {
    // get the position of the current fragment
    float val = field.read(uint2(fragCoord.xy)).r;
    if (val < 0.0) return float4(float3(-val*.8), 1);
    return float4(float3(map(val)), 1.0);
}
