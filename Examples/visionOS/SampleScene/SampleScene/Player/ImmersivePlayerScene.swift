//
//  ImmersivePlayerScene.swift
//  SampleScene
//

import SwiftUI
import CompositorServices
import YBVRAppleSDK

/// How the compositor layer the SDK renders into is set up.
struct ContentStageConfiguration: CompositorLayerConfiguration {
    func makeConfiguration(capabilities: LayerRenderer.Capabilities,
                           configuration: inout LayerRenderer.Configuration) {
        configuration.depthFormat = .depth32Float
        configuration.colorFormat = .bgra8Unorm_srgb
        configuration.isFoveationEnabled = capabilities.supportsFoveation
        configuration.layout = .dedicated
        
        // Lets a pinch on a control room mini screen be told apart without ray casting.
        if capabilities.supportedTrackingAreasFormats.contains(.r8Uint) {
            configuration.trackingAreasFormat = .r8Uint
        }
    }
}

/// The immersive space the video plays in, rendered by the SDK through Compositor Services.
/// Keeps the controls window open while the video plays, and hands back to the list when done -
/// or once the system has closed the space.
struct ImmersivePlayerScene: Scene {
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @Environment(PlayerModel.self) private var player
    @Environment(NetworkMonitor.self) private var networkMonitor
    
    static let id = "ImmersivePlayerScene"
    
    var body: some Scene {
        ImmersiveSpace(id: Self.id) {
            CompositorLayer(configuration: ContentStageConfiguration()) { layerRenderer in
                player.prepare(layerRenderer: layerRenderer)
                layerRenderer.onSpatialEvent = player.handlePinches
                
                Task {
                    guard await player.start() else { return }
                    player.session.player?.getRenderer()?.startRenderLoop()
                    openWindow(id: SceneID.playerControls)
                }
            }
            .onAppear {
                dismissWindow(id: SceneID.videoList)
            }
            .onChange(of: networkMonitor.isConnected) { _, isConnected in
                guard !isConnected else { return }
                player.fail(with: PlayerNotifications.connectionLost)
            }
            .onChange(of: player.controlsRequest) {
                openWindow(id: SceneID.playerControls)
            }
            .onChange(of: player.isFinished) { _, finished in
                guard finished else { return }
                
                returnToList()
                Task { await dismissImmersiveSpace() }
            }
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed)
        .onChange(of: player.isSpaceClosedBySystem) { _, closed in
            guard closed else { return }
            returnToList()
        }
    }
    
    private func returnToList() {
        openWindow(id: SceneID.videoList)
        dismissWindow(id: SceneID.playerControls)
        player.end()
    }
}
