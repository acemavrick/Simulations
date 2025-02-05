//
//  WaveView.swift
//  Simulations
//
//

import SwiftUI

struct WaveView: View {
    var onBack: () -> Void
    
    @State private var hovering = false
    @StateObject private var model = WaveModel()
    
    private var numberFormatter: Formatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .none
        formatter.minimum = 0
        return formatter
    }
    
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
                VStack() {
                    Spacer()
                    VStack (alignment: .leading){
                        Text("\(String(format: "%0.0f x %0.0f", model.resolution.x, model.resolution.y)) px")
                        Text("dx: \(String(format: "%0.4f", model.dx))")
                        Text("dt: \(String(format: "%0.4f", model.dt))")
                        Text("c: \(String(format: "%0.4f", model.c))")
                        Text("damp: \(String(format: "%0.4f", model.dampening))")
                        HStack (spacing: 0) {
                            Text("Eff. FPS: ")
                            Text("\(String(format: "%0.0f", model.RPF, model.FPS))")
                            Text(" x ")
                            Text("\(String(format: "%0.1f", model.FPS))")
                                .foregroundStyle(model.FPS <= 30 ? .red : model.FPS <= 55 ? .yellow : .white)
                        }
                        Toggle("Dynamic RPF", isOn: $model.dynamicRPF.animation())
                            .toggleStyle(.checkbox)
                            .allowsHitTesting(true)
                        
                        if !model.dynamicRPF {
                            HStack (spacing: 0) {
                                Text("RPS: ")
                                TextField("", value: $model.RPF, formatter: numberFormatter)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .foregroundColor(.black)
                                    .fixedSize()
                                Stepper("", value: $model.RPF, in: 1...10000, step: 1)
                            }
                        }
                    }
                    .monospaced()
                    .padding()
                    .background(.black.opacity(self.hovering ? 0.8 : 0.4))
                    .cornerRadius(10)
                }
                .padding()
            }
            .foregroundStyle(.white)
//            .allowsHitTesting(false)
            
            VStack {
                HStack {
                    HomeAndPlayButton(onBack: onBack, model: model, hovering: $hovering)
                    Spacer()
                }
                Spacer()
            }
            .padding(5)
        }
        .onHover(perform: {hovering in
            withAnimation {
                self.hovering = hovering
            }
        })
        
    }
}
