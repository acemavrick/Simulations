//
//  ContentView.swift
//
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        WaveView()
//        GravityView()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    ContentView()
}
