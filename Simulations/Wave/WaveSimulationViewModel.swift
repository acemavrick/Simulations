//
//  WaveSimulationViewModel.swift
//  Simulations
//
//

import Foundation

class WaveSimulationViewModel: ObservableObject {
    @Published var tapLocation: CGPoint? = nil
    @Published var play = false
}
