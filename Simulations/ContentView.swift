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
                WaveSimulationView(viewModel: simulationViewModel)
                    .gesture(
                        SpatialTapGesture()
                            .onEnded { value in
                                simulationViewModel.tapLocation = value.location
                            }
                    )
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                simulationViewModel.tapLocation = value.location
                            }
                    )

                HStack {
                    Button(action: {play()}) {
                        Image(systemName: "play")
                    }
                    Button(action: {pause()}) {
                        Image(systemName: "pause")
                    }
                }
                .padding(3)
                .background(.white.opacity(0.5))
                .cornerRadius(5)
                .padding(5)
                .dynamicTypeSize(.large)
                .opacity(hovering ? 1.0 : 0.0)
                .animation(.easeInOut)
            }
//            .aspectRatio(1, contentMode: .fit)
            .onHover(perform: { hovering in
                self.hovering = hovering
            })
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red:0.2,green:0.2,blue:0.2))
//        .background(Color(red:0.274344,green:0.004462,blue:0.331359))
    }
    
    
    func play() {
        simulationViewModel.play = true
    }
    
    func pause() {
        simulationViewModel.play = false
    }
}

#Preview {
    ContentView()
}
