//
//  WaveView.swift
//  Simulations
//
//

import SwiftUI

struct WaveView: View {
    @State var hovering = false
    @StateObject var model = WaveModel()
    
    var body: some View {
        ZStack {
            WaveController(model: model)
                .gesture(
                    SpatialTapGesture()
                        .onEnded { value in
                            model.tap(at: value)
                        }
                )
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            model.drag(at: value)
                        }
                )
            
            HStack {
                Spacer()
                VStack(alignment: .leading) {
                    Spacer()
                    Text("\(String(format: "%0.0f x %0.0f", model.resolution.x, model.resolution.y)) px")
                    Text("dx: \(String(format: "%0.4f", model.dx))")
                    Text("dt: \(String(format: "%0.4f", model.dt))")
                    Text("c: \(String(format: "%0.4f", model.c))")
                    Text("damp: \(String(format: "%0.4f", model.dampening))")
                }
                .padding()
            }
            .foregroundStyle(.white)
            .allowsHitTesting(false)
            
            VStack {
                HStack {
                    Button(action: {
                        model.play.toggle()
                    }) {
                        withAnimation {
                            Image(systemName: model.play ? "pause" : "play")
                        }
                    }
                    .padding(3)
                    .background(.white.opacity(0.5))
                    .cornerRadius(5)
                    .dynamicTypeSize(.large)
                    .opacity(hovering ? 1.0 : 0.0)
                    
                    Spacer()
                }
                Spacer()
            }
            .padding(3)
        }
        .onHover(perform: {hovering in
            withAnimation {
                self.hovering = hovering
            }
        })
    }
}

#Preview {
    WaveView()
}
