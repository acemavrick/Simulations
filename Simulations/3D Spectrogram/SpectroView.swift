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
            SpectroController()
            
            HStack {
                VStack {
                    HomeButton(onBack: onBack, hovering: $hovering)
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
