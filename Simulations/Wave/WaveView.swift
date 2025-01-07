//
//  WaveView.swift
//  Simulations
//
//

import SwiftUI

struct WaveView: View {
    @State var hovering = false
    @StateObject var viewModel = WaveViewModel()
    
    var body: some View {
        ZStack {
            WaveController(viewModel: viewModel)
                .gesture(
                    SpatialTapGesture()
                        .onEnded { value in
                            viewModel.tapLocation = value.location
                        }
                )
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            viewModel.tapLocation = value.location
                        }
                )
            
            HStack {
                Spacer()
                VStack(alignment: .leading) {
                    Spacer()
                    Text("\(String(format: "%0.0f x %0.0f", viewModel.resolution.x, viewModel.resolution.y)) px")
                    Text("dx: \(String(format: "%0.4f", viewModel.dx))")
                    Text("dt: \(String(format: "%0.4f", viewModel.dt))")
                    Text("c: \(String(format: "%0.4f", viewModel.c))")
                    Text("damp: \(String(format: "%0.4f", viewModel.dampening))")
                }
                .padding()
            }
            .allowsHitTesting(false)
            
            VStack {
                HStack {
                    Button(action: {
                        viewModel.play.toggle()
                    }) {
                        withAnimation {
                            Image(systemName: viewModel.play ? "pause" : "play")
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
