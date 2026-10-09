//
//  SampleSceneApp.swift
//  SampleScene
//

import SwiftUI
import CompositorServices
import YBVRAppleSDK

/// Identifiers of the app's windows.
enum SceneID {
    static let videoList = "video_list"
    static let playerControls = "player_controls"
    static let directPlayerControls = "direct_player_controls"
}

@main
struct SampleSceneApp: App {
    /// The account configuration, the player factory and the video list.
    @State private var app: AppEnvironment
    /// The video playing, across the immersive space and the controls window.
    @State private var player: PlayerModel
    /// APMP and FairPlay-protected content, which plays through `DirectPlayer` instead.
    @State private var directPlayback = DirectPlaybackModel()
    @State private var networkMonitor = NetworkMonitor()
    
    init() {
        let app = AppEnvironment()
        _app = State(initialValue: app)
        _player = State(initialValue: PlayerModel(players: app.players))
    }
    
    var body: some Scene {
        WindowGroup(id: SceneID.videoList) {
            VideoListView()
                .task {
                    guard !app.isReady else { return }
                    // Your YBVR app name: it picks the configuration and analytics for your account.
                    await app.initialize(appName: "yeap")
                }
                .environment(app)
                .environment(player)
                .environment(directPlayback)
                .environment(networkMonitor)
        }
        .defaultSize(CGSize(width: 900, height: 600))
        .windowStyle(.plain)
        
        WindowGroup(id: SceneID.playerControls) {
            PlayerControlsWindow()
                .environment(player)
        }
        .windowResizability(.contentSize)
        .windowStyle(.plain)
        .defaultLaunchBehavior(.suppressed)
        .defaultWindowPlacement { _, _ in
            WindowPlacement(.utilityPanel)
        }
        
        ImmersivePlayerScene()
            .environment(player)
            .environment(networkMonitor)
        
        WindowGroup(id: SceneID.directPlayerControls) {
            DirectPlayerControlsWindow()
                .environment(directPlayback)
        }
        .windowResizability(.contentSize)
        .windowStyle(.plain)
        .defaultLaunchBehavior(.suppressed)
        .defaultWindowPlacement { _, _ in
            WindowPlacement(.utilityPanel)
        }
        
        DirectPlayerImmersiveScene()
            .environment(directPlayback)
            .environment(networkMonitor)
    }
}
