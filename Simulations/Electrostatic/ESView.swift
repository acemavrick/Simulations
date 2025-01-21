//
//  ESView.swift
//  Simulations
//
//  Created by Shubh Randeria on 1/17/25.
//

import SwiftUI

struct ESView: View {
    @StateObject private var model = ESModel()
    
    var body: some View {
        ZStack {
            ESController(model: model)
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
            
            // info pane
            // read from viewModel
            HStack() {
                Spacer()
                VStack(alignment: .leading) {
                    Spacer()
                    Text("# Charges: \(model.numCharges)")
                    Text("Resolution: \(String(format: "%.0f x %.0f", model.resolution.x, model.resolution.y))")
                    Text("Scale: \(String(format: "%0.4f", model.scale))")
                    Text("Area: \(String(format: "%.0f x %.0f", model.dimensions.x, model.dimensions.y))")
                    Text("k: \(String(format: "%0.4f", model.k))")
                    Text("dt: \(String(format: "%0.4f", model.dt))")
                }
                .foregroundStyle(.white)
                .padding()
            }
            .allowsHitTesting(false)
        }
    }
}

#Preview {
    ESView()
}
