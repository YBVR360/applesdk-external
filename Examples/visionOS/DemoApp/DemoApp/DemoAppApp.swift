//
//  DemoAppApp.swift
//  DemoApp
//
//  Created by Niko Inas on 23.09.24.
//

import SwiftUI
import CompositorServices
import YBVRAppleSDK

struct ContentStageConfiguration: CompositorLayerConfiguration {
    func makeConfiguration(capabilities: LayerRenderer.Capabilities, configuration: inout LayerRenderer.Configuration) {
        configuration.depthFormat = .depth32Float
        configuration.colorFormat = .bgra8Unorm_srgb
        
        configuration.isFoveationEnabled = capabilities.supportsFoveation
        configuration.layout = .dedicated
        
        // Enable hover effects on interactive Metal content (up to 255 concurrent objects).
        if capabilities.supportedTrackingAreasFormats.contains(.r8Uint) {
            configuration.trackingAreasFormat = .r8Uint
        }
    }
}

@main
struct DemoApp: App {
    /// App-wide state: configuration, the player factory, the video list. Shared with iOS.
    @State private var app: AppEnvironment
    /// Drives one playback session across the scenes below.
    @State private var coordinator: PlayerCoordinator
    @State private var networkMonitor = NetworkMonitor()
    /// Plain HLS playback, used for DRM content the signaling pipeline cannot handle.
    @State private var directPlayerVM = DirectPlayerViewModel()
    
    init() {
        let app = AppEnvironment()
        _app = State(initialValue: app)
        _coordinator = State(initialValue: PlayerCoordinator(environment: app))
    }
    
    var body: some Scene {
        WindowGroup(id: SceneID.startingScene) {
            ContentView()
                .task {
                    await app.initialize()
                }
                .environment(networkMonitor)
                .environment(app)
                .environment(coordinator)
                .environment(directPlayerVM)
        }
        .defaultSize(CGSize(width: 900, height: 600))
        .windowStyle(.plain)
        
        WindowGroup(id: SceneID.playerControls) {
            PlayerControlsWindow()
                .environment(coordinator)
        }
        .windowResizability(.contentSize)
        .windowStyle(.plain)
        .defaultLaunchBehavior(.suppressed)
        
        WindowGroup(id: SceneID.interactableOverlay, for: InteractableGraphic.self) { $interactableGraphic in
            if let interactableGraphic {
                InteractableView(interactableGraphic: interactableGraphic)
                    .environment(coordinator)
            }
        }
        .windowResizability(.contentSize)
        .windowStyle(.plain)
        .defaultLaunchBehavior(.suppressed)
        .defaultWindowPlacement { _, context in
            if let place = context.windows.first, place.id == SceneID.interactableOverlay {
                return WindowPlacement(.trailing(place))
            }
            return WindowPlacement()
        }
        
        WindowGroup(id: SceneID.recommendationsPanel) {
            RecommendationsPanel()
                .environment(coordinator)
        }
        .windowResizability(.contentSize)
        .defaultLaunchBehavior(.suppressed)
        .defaultWindowPlacement { _, context in
            // The test-harness panels sit above the controls window they were opened from.
            if let controls = context.windows.first(where: { $0.id == SceneID.playerControls }) {
                return WindowPlacement(.above(controls))
            }
            return WindowPlacement()
        }
        
        WindowGroup(id: SceneID.windowPlayer) {
            WindowPlayerView()
                .environment(coordinator)
        }
        .windowStyle(.plain)
        .defaultLaunchBehavior(.suppressed)
        .defaultSize(CGSize(width: 1280, height: 720))
        
        ImmersiveInteractionScene()
            .environment(coordinator)
        
        DirectPlayerImmersiveScene()
            .environment(directPlayerVM)
            .environment(coordinator)
    }
}
