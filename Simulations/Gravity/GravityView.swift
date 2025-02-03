//
//  GravityView.swift
//  Simulations
//
//  Created by Shubh Randeria on 1/3/25.
//

import SwiftUI

struct GravityView: View {
    var onBack: () -> Void
    @StateObject private var viewModel = GravityViewModel()
    @State private var hovering: Bool = false
    
    var body: some View {
        ZStack {
            GravityController(viewModel: viewModel)
                .gesture(
                    SpatialTapGesture()
                        .onEnded({ value in
                            viewModel.tapLocation = value.location
                            print("tap at \(viewModel.tapLocation!)")
                        })
                )
                .gesture(
                    DragGesture()
                        .onChanged({ value in
                            viewModel.tapLocation = value.location
                        })
                )
            
            HStack {
                VStack {
                    HomeAndPlayButton(onBack: onBack, model: viewModel, hovering: $hovering)
                    Spacer()
                }
                Spacer()
            }
            .padding(5)
            
            // info pane
            // read from viewModel
            HStack() {
                Spacer()
                VStack(alignment: .leading) {
                    Spacer()
                    Text("# Masses: \(viewModel.numMasses)")
                    Text("Resolution: \(String(format: "%.0f x %.0f", viewModel.resolution.x, viewModel.resolution.y))")
                    Text("Scale: \(String(format: "%0.4f", viewModel.scale))")
                    Text("Area: \(String(format: "%.0f x %.0f", viewModel.dimensions.x, viewModel.dimensions.y))")
                    Text("G: \(String(format: "%0.4f", viewModel.G))")
                    Text("dt: \(String(format: "%0.4f", viewModel.dt))")
                    Text("Min Coll Dist: \(String(format: "%0.4f", viewModel.collisionDist))")
                }
                .foregroundStyle(.white)
                .padding()
            }
            .allowsHitTesting(false)
        }
        .onHover(perform: { hovering in
            withAnimation {
                self.hovering = hovering
            }
        })
    }
}

