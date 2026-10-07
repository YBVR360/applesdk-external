//
//  ContentView.swift
//  DemoApp
//
//  Created by Niko Inas on 23.09.24.
//

import SwiftUI
import YBVRAppleSDK

struct ContentView: View {
    @Environment(PlayerCoordinator.self) private var coordinator
    @Environment(\.dismissWindow) private var dismissWindow
    
    var body: some View {
        VideoListView()
            .font(.title)
            .onAppear {
                // Whatever a previous session left open goes away with it.
                dismissWindow(id: SceneID.playerControls)
                dismissWindow(id: SceneID.windowPlayer)
                dismissWindow(id: SceneID.recommendationsPanel)
                coordinator.overlay.reset()
            }
    }
}

#Preview(windowStyle: .automatic) {
    let app = AppEnvironment()
    
    ContentView()
        .environment(app)
        .environment(PlayerCoordinator(environment: app))
        .environment(NetworkMonitor())
        .environment(DirectPlayerViewModel())
}
