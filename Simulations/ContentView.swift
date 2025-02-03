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
}

struct ContentView: View {
    @State private var currentScreen: apps = .home
    
    var body: some View {
        switch currentScreen {
        case .home:
            Group {
                Text("Hello World, welcome to my humble collection of simulations!")
                Button("Waves") {
                    withAnimation {
                        currentScreen = .waves
                    }
                }
                Button("Electrostatics") {
                    withAnimation {
                        currentScreen = .electrostatics
                    }
                }
                Button("Gravity") {
                    withAnimation {
                        currentScreen = .gravity
                    }
                }
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
        }
    }
}


#Preview {
    ContentView()
}
