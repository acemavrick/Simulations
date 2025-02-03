//
//  Structs.swift
//  A collection of structs used in the project.
//

import Foundation
import SwiftUI

struct Uniforms {
    var time: Float
    var resolution: SIMD2<Float>
}

protocol HasPlayPauseToggle: AnyObject {
    var play: Bool { get set }
}

struct HomeButton: View {
    var onBack: () -> Void
    @Binding var hovering: Bool
    var unstyled: Bool = false

    var body: some View {
        if (unstyled) {
            Button(action: {
                onBack()
            }) {
                Image(systemName: "house.fill")
            }
        } else {
            Button(action: {
                onBack()
            }) {
                Image(systemName: "house.fill")
            }
            .padding(3)
            .background(.white.opacity(0.5))
            .cornerRadius(5)
            .dynamicTypeSize(.large)
            .opacity(hovering ? 1.0 : 0.0)
        }
    }
}

struct PlayButton<Model: ObservableObject & HasPlayPauseToggle>: View {
    @ObservedObject var model: Model
    @Binding var hovering: Bool
    var unstyled: Bool = false
    
    var body: some View {
        if unstyled {
            Button(action: {
                withAnimation {
                    model.play.toggle()
                }
            }) {
                withAnimation {
                    Image(systemName: model.play ? "pause.fill" : "play.fill")
                }
            }
        } else {
            Button(action: {
                withAnimation {
                    model.play.toggle()
                }
            }) {
                withAnimation {
                    Image(systemName: model.play ? "pause.fill" : "play.fill")
                }
            }
            .padding(3)
            .background(.white.opacity(0.5))
            .cornerRadius(5)
            .dynamicTypeSize(.large)
            .opacity(hovering ? 1.0 : 0.0)

        }
    }
}

struct HomeAndPlayButton<Model: ObservableObject & HasPlayPauseToggle>: View {
    var onBack: () -> Void
    @ObservedObject var model: Model
    @Binding var hovering: Bool
    
    var body: some View {
        HStack (spacing: 2) {
            HomeButton(onBack: onBack, hovering: $hovering, unstyled: true)
                .shadow(radius: 3)
                .padding(3)
                .padding(.trailing, 0)
            PlayButton(model: model, hovering: $hovering, unstyled: true)
                .shadow(radius: 3)
                .padding(3)
                .padding(.leading, 0)
        }
        .background(.white.opacity(0.7))
        .cornerRadius(5)
        .opacity(hovering ? 1.0 : 0.0)
    }
}
            

