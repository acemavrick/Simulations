//
//  WaveSimulationViewModel.swift
//  Simulations
//
//

import Foundation

class WaveViewModel: ObservableObject {
    @Published var play = false
    @Published var tapLocation: CGPoint? = nil
    
    @Published var dx: Float = -0.0
    @Published var dt: Float = -0.0
    @Published var c: Float = 0.0
    @Published var dampening: Float = 0.0
    @Published var resolution: SIMD2<Float> = SIMD2<Float>(0.0, 0.0)
}
