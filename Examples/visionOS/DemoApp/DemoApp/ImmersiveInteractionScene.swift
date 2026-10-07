//
//  ImmersiveInteractionScene.swift
//  DemoApp
//
//  Created by Niko Inas on 22.06.24.
//

import SwiftUI
import CompositorServices
import YBVRAppleSDK

/// The immersive space for signaling-driven content, rendered by the SDK's Compositor Services
/// renderer. For everything that does not play through `DirectPlayer`.
struct ImmersiveInteractionScene: Scene {
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @Environment(PlayerCoordinator.self) private var coordinator
    
    static let id = "ImmersiveInteractionScene"
    
    var body: some Scene {
        ImmersiveSpace(id: Self.id) {
            CompositorLayer(configuration: ContentStageConfiguration()) { layerRenderer in
                coordinator.prepareForImmersive(layerRenderer: layerRenderer)
                layerRenderer.onSpatialEvent = coordinator.handlePinches
                
                Task {
                    guard await coordinator.startPlayback() else { return }
                    
                    coordinator.session.player?.getRenderer()?.startRenderLoop()
                }
            }
            .onAppear {
                dismissWindow(id: SceneID.startingScene)
                dismissWindow(id: SceneID.windowPlayer)
            }
            .onChange(of: coordinator.overlay.isVisible) { _, visible in
                if visible {
                    openWindow(id: SceneID.playerControls)
                } else {
                    dismissWindow(id: SceneID.playerControls)
                }
            }
            .onChange(of: coordinator.isFinished) { _, finished in
                guard finished else { return }
                
                // The space closes itself.
                Task { await dismissImmersiveSpace() }
                coordinator.end()
                openWindow(id: SceneID.startingScene)
            }
            .onChange(of: coordinator.interactableState) { _, state in
                guard let state else { return }
                
                switch state.status {
                case .needsToShow:
                    openWindow(value: state.interactableGraphic)
                case .needsToDismiss:
                    dismissWindow(value: state.interactableGraphic)
                default:
                    break
                }
            }
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed)
    }
}
