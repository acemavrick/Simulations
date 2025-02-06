//
//  SpectroView.swift
//  Simulations
//
//

import SwiftUI
import SceneKit

struct SpectroscopeView: View {
    var onBack: () -> Void
    
    @StateObject private var model = SpectroscapeModel()
    @State private var hovering: Bool = false
    
    var body: some View {
        ZStack {
            SpectroController(model: model)
            
            HStack {
                VStack {
                    HomeButton(onBack: onBack, hovering: $hovering)
                        .padding()
                    Text("\(model.songname).\(model.songext)")
                        .foregroundStyle(.white)
                        .fontDesign(.monospaced)
                        .font(.title2)
                        .padding()
                    Spacer()
                }
                Spacer()
            }
        }
        .onHover { hovering in
            withAnimation {
                self.hovering = hovering
            }
        }
    }
}
