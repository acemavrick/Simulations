//
//  WaveSimulationViewModel.swift
//  Simulations
//
//

import Foundation
import SwiftUI

class WaveModel: ObservableObject, HasPlayPauseToggle {
    @Published var play = false
    @Published var visible = false

    @Published var tapValue: SpatialTapGesture.Value? = nil
    @Published var dragValue: DragGesture.Value? = nil
    
    @Published var dx: Float = -0.0
    @Published var dt: Float = -0.0
    @Published var c: Float = 0.0
    @Published var dampening: Float = 0.0
    @Published var resolution: SIMD2<Float> = SIMD2<Float>(0.0, 0.0)
    
    // RPF- Renders per Frame
    @Published var RPF: Double = 0;
    @Published var FPS: Double = 0;
    // True FPS - RPF * FPS -> Renders ("Frames") per Second
    
    @Published var dynamicRPF: Bool = true;

    public func tap(at location: SpatialTapGesture.Value) {
        self.tapValue = location
    }
    
    public func drag(at location: DragGesture.Value) {
        self.dragValue = location
    }
}
