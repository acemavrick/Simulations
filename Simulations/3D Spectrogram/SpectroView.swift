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
                    HomeAndPlayButton(onBack: {
                        model.stopAudio()
                        onBack()
                    }, model: model, hovering: $hovering)
                        .padding()
                    Spacer()
                }
                Spacer()
            }
            
            HStack{
                VStack{
                    Spacer()
                    ZStack {
                        Picker("", selection: $model.songIndex) {
                            ForEach(0..<model.songs.count) { index in
                                Text(model.songs[index].name)
                            }
                        }
                        .pickerStyle(.menu)
                        .padding()
                        .opacity(hovering ? 1 : 0.0)
                        .foregroundStyle(.white)
                        
                        Text("\(model.songs[model.songIndex].name)")
                            .opacity(hovering ? 0 : 1.0)
                            .foregroundStyle(.white)
                            .font(.title3)
                            .padding()
                    }
//                    Text("\(model.songname).\(model.songext)")
//                        .foregroundStyle(.white)
//                        .fontDesign(.monospaced)
//                        .font(.title2)
//                        .padding()
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
