//
//  ESExtras.swift
//  Simulations
//
//  Created by Shubh Randeria on 1/17/25.
//

import Foundation

struct ESUniforms {
    var resolution, dimensions: SIMD2<Float>
    var scale, dt, k: Float
    var padding: Float = 0.0
    var numCharges: Int
    
    init(screen_resolution resolution: [Float], units_per_pixel scale: Float, dt: Float, numCharges nc: Int) {
        self.k = 50.0
        self.dt = 0.1
        self.resolution = SIMD2<Float>(resolution[0], resolution[1])
        self.numCharges = nc
        self.scale = scale
        self.dimensions = SIMD2<Float>(resolution[0] * scale, resolution[1] * scale)
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
    
    mutating func addCharge(count: Int = 1) {
        self.numCharges += count
    }
}

struct Charge {
    var position, velocity: SIMD2<Float>
    var charge: Float
    var fixed: Bool
    var padding: SIMD3<Float>
    
    init(x: Float, y: Float, charge: Float, vx: Float = 0.0, vy: Float = 0.0, fixed: Bool = false) {
        self.position = SIMD2<Float>(x, y)
        self.charge = charge
        self.velocity = SIMD2<Float>(vx, vy)
        self.fixed = fixed
        self.padding = SIMD3<Float>(0.0, 0.0, 0.0)
    }
}
