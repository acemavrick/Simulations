//
//  ContentView.swift
//
//

import SwiftUI

struct ContentView: View {
    @State var hovering = false
        @StateObject var simulationViewModel = WaveSimulationViewModel()
    
    var body: some View {
        // a play/pause button at bottom
        HStack {
            ZStack(alignment: .topLeading) {
                //               FractalView()
                
                GravityView()
                
                //                                WaveSimulationView(viewModel: simulationViewModel)
                //                                    .gesture(
                //                                        SpatialTapGesture()
                //                                            .onEnded { value in
                //                                                simulationViewModel.tapLocation = value.location
                //                                            }
                //                                    )
                //                                    .gesture(
                //                                        DragGesture()
                //                                            .onChanged { value in
                //                                                simulationViewModel.tapLocation = value.location
                //                                            }
                //                                    )
                //                
                //                                HStack {
                //                                    Button(action: {play()}) {
                //                                        Image(systemName: "play")
                //                                    }
                //                                    Button(action: {pause()}) {
                //                                        Image(systemName: "pause")
                //                                    }
                //                                }
                //                                .padding(3)
                //                                .background(.white.opacity(0.5))
                //                                .cornerRadius(5)
                //                                .padding(5)
                //                                .dynamicTypeSize(.large)
                //                                .opacity(hovering ? 1.0 : 0.0)
                //                                .animation(.easeInOut)
                //            }
                //            .aspectRatio(1, contentMode: .fit)
                //            .onHover(perform: { hovering in
                //                self.hovering = hovering
                //            })
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    ContentView()
}
