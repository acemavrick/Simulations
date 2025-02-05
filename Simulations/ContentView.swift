//
//  ContentView.swift
//
//

import SwiftUI

enum apps {
    case home
    case waves
    case electrostatics
    case gravity
    case spectroscape
}

struct ContentView: View {
    @State private var currentScreen: apps = .home
    
    @State private var buttonWavesHovering: Bool = false
    @State private var buttonElectrostaticsHovering: Bool = false
    @State private var buttonGravityHovering: Bool = false
    @State private var buttonSpectroscapeHovering: Bool = false

    var body: some View {
        switch currentScreen {
        case .home:
            Group {
                Text("Hello! Welcome to this humble collection of simulations!")
                    .font(.title)
                    .fontDesign(.rounded)
                
                Text("Please select a simulation to open.")
                    .font(.title3)
                
                Button("Waves", systemImage: "dot.radiowaves.left.and.right") {
                    withAnimation {
                        currentScreen = .waves
                    }
                }
                
                Button("Electrostatics", systemImage: "bolt.brakesignal") {
                    withAnimation {
                        currentScreen = .electrostatics
                    }
                }
                
                Button("Gravity", systemImage: "moonphase.waning.gibbous.inverse") {
                    withAnimation {
                        currentScreen = .gravity
                    }
                }
                
                Button("Spectroscape", systemImage: "waveform") {
                    withAnimation {
                        currentScreen = .spectroscape
                    }
                }
//                .disabled(true)
            }
        case .waves:
            WaveView {
                withAnimation {
                    currentScreen = .home
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .electrostatics:
            ESView {
                withAnimation {
                    currentScreen = .home
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .gravity:
            GravityView {
                withAnimation {
                    currentScreen = .home
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .spectroscape:
            SpectroscopeView {
                withAnimation {
                    currentScreen = .home
                }
            }
        }
    }
}


#Preview {
    ContentView()
}
