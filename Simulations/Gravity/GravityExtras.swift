//
//  GravityUniforms.swift
//  Simulations
//
//  Created by Shubh Randeria on 12/21/24.
//

import Foundation
import MetalKit

struct GravityUniforms {
    var numMasses: Int
    var resolution, size: SIMD2<Float>
    var G, dt, collisionDist: Float
    
    init(resolution: [Float], size: [Float], dt: Float, numMasses: Int) {
        self.G = 2.1
        self.dt = 0.02
        self.collisionDist = 1.0
        self.resolution = SIMD2<Float>(resolution[0], resolution[1])
        self.numMasses = numMasses
        self.size = SIMD2<Float>(size[0], size[1])
    }
}

struct PtMass {
    var position, velocity: SIMD2<Float>
    var mass: Float
    
    init(x: Float, y: Float, mass: Float, vx: Float = 0.0, vy: Float = 0.0) {
        self.position = SIMD2<Float>(x, y)
        self.mass = mass
        self.velocity = SIMD2<Float>(vx, vy)
    }
}

