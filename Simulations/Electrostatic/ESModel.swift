//
//  ESModel.swift
//  Simulations
//
//  Created by Shubh Randeria on 1/17/25.
//

import Foundation
import SwiftUI

class ESModel: ObservableObject, HasPlayPauseToggle {
    @Published var play = true
    
    @Published var tapValue: SpatialTapGesture.Value? = nil
    @Published var dragValue: DragGesture.Value? = nil
    
    @Published var numCharges: Int = 0
    @Published var resolution = SIMD2<Float>(0.0, 0.0)
    @Published var scale: Float = 0.0
    @Published var dimensions = SIMD2<Float>(0.0, 0.0)
    @Published var dt: Float = 0.0
    @Published var k: Float = 0.0

    public func tap(at location: SpatialTapGesture.Value) {
        self.tapValue = location
    }
    
    public func drag(at location: DragGesture.Value) {
        self.dragValue = location
    }
}
