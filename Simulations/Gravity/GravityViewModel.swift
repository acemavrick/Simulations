//
//  GravityViewModel.swift
//  Simulations
//
//

import Foundation

class GravityViewModel: ObservableObject {
    // to be used
    @Published var play = true
    @Published var tapLocation: CGPoint? = nil
    
    // info to communicate to the user
    @Published var numMasses: Int = 0
    @Published var resolution = SIMD2<Float>(0.0, 0.0)
    @Published var scale: Float = 0.0
    @Published var dimensions = SIMD2<Float>(0.0, 0.0)
    @Published var dt: Float = 0.0
    @Published var G: Float = 0.0
    @Published var collisionDist: Float = 0.0
}
