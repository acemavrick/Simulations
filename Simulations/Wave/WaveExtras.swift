//
//  WaveSimUniforms.swift
//  Simulations
//
//

import Foundation
import MetalKit

struct WaveUniforms {
    var dx: Float
    var dt: Float
    var c: Float
    var time: Float = 0.0
    var damper: Float = 0.9998
    var padding0: Float = 0.0
    var resolution: SIMD2<Float>
    
    // colormap coefficients
    var c0, c1, c2, c3, c4, c5, c6: SIMD4<Float>
    
    init(dx: Float, dt: Float, c: Float, resolution: SIMD2<Float>) {
        self.dx = dx
        self.dt = dt
        self.c = c
        
        self.resolution = resolution

        // viridis
        self.c0 = SIMD4<Float>(0.274344,0.004462,0.331359, 1.0)
        self.c1 = SIMD4<Float>(0.108915,1.397291,1.388110, 1.0)
        self.c2 = SIMD4<Float>(-0.319631,0.243490,0.156419, 1.0)
        self.c3 = SIMD4<Float>(-4.629188,-5.882803,-19.646115, 1.0)
        self.c4 = SIMD4<Float>(6.181719,14.388598,57.442181, 1.0)
        self.c5 = SIMD4<Float>(4.876952,-13.955112,-66.125783, 1.0)
        self.c6 = SIMD4<Float>(-5.513165,4.709245,26.582180, 1.0)
    }
}
