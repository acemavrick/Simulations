//
//  GravityUniforms.swift
//  Simulations
//
//

import Foundation
import MetalKit

struct GravityUniforms {
    var numMasses: Int
    var resolution: SIMD2<Float>
    var scale, G, dt, collisionDist: Float
    var bounce: Bool = false
    
    init(screen_resolution resolution: [Float], units_per_pixel scale: Float, dt: Float, numMasses: Int) {
        self.G = 11.1
        self.dt = 0.1
        self.collisionDist = 0.0
        self.resolution = SIMD2<Float>(resolution[0], resolution[1])
        self.numMasses = numMasses
        self.scale = scale
    }
    
    mutating func setResolution(_ resolution: CGSize) -> Bool{
        // return whether the resolution was changed
        let res = SIMD2<Float>(Float(resolution.width), Float(resolution.height))
        if res != self.resolution {
            self.resolution = res
            return true
        }
        return false
    }
    
    mutating func addMass(count: Int = 1) {
        self.numMasses += count
    }
}

struct PtMass {
    var position, velocity: SIMD2<Float>
    var mass: Float
    var fixed, collides: Bool
    
    init(x: Float, y: Float, mass: Float, vx: Float = 0.0, vy: Float = 0.0, fixed: Bool = false, collides: Bool = true) {
        self.position = SIMD2<Float>(x, y)
        self.mass = mass
        self.velocity = SIMD2<Float>(vx, vy)
        self.fixed = fixed
        self.collides = collides
    }
}

