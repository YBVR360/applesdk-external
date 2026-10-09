//
//  DirectPlayerControlsWindow.swift
//  SampleScene
//

import SwiftUI
import YBVRAppleSDK

/// The shared playback controls for `DirectPlayer`, as a window in front of its immersive space.
struct DirectPlayerControlsWindow: View {
    @Environment(DirectPlaybackModel.self) private var player
    
    var body: some View {
        PlayerTransportControls(vm: player)
            .onAppear { player.isControlsWindowOpen = true }
            .onDisappear { player.isControlsWindowOpen = false }
    }
}
